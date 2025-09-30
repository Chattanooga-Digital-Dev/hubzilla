import os
import logging
import re
from typing import List, Optional
from dataclasses import dataclass
from dotenv import load_dotenv
from imap_tools import MailBoxStartTls, MailMessage
from icalendar import Calendar, Event
import caldav
import ssl
import requests
from urllib.parse import urlparse

def sanitize_ical_content(ical_string: str) -> str:
    """Sanitize final iCal content to remove problematic escape sequences"""
    # Remove escaped commas that cause PostgreSQL issues
    ical_string = ical_string.replace('\\,', ',')
    ical_string = ical_string.replace('\\;', ';')
    ical_string = ical_string.replace('\\n', ' ')
    ical_string = ical_string.replace('\\\\', '')
    
    # Remove markdown formatting
    ical_string = ical_string.replace('**', '')
    ical_string = ical_string.replace('*', '')
    
    return ical_string

def sanitize_calendar_content(text: str, max_length: int = 250) -> str:
    """Sanitize calendar content to prevent PostgreSQL database errors"""
    if not text:
        return ""
    
    text = str(text)
    
    # Remove emojis
    emoji_pattern = re.compile("["
        u"\U0001F600-\U0001F64F"  # emoticons
        u"\U0001F300-\U0001F5FF"  # symbols & pictographs
        u"\U0001F680-\U0001F6FF"  # transport & map symbols
        u"\U0001F1E0-\U0001F1FF"  # flags (iOS)
        u"\U00002702-\U000027B0"
        u"\U000024C2-\U0001F251"
        "]+", flags=re.UNICODE)
    text = emoji_pattern.sub('', text)
    
    # Replace newlines and multiple spaces with single space
    text = re.sub(r'\s+', ' ', text)
    
    # Remove problematic characters that cause PostgreSQL issues
    text = text.replace('\\', '')
    text = text.replace('\n', ' ')
    text = text.replace('\r', ' ')
    text = text.replace('\t', ' ')
    
    # Remove HTML tags if present
    text = re.sub(r'<[^>]+>', '', text)
    
    # Truncate if too long
    if len(text) > max_length:
        text = text[:max_length].strip() + '...'
    
    text = text.strip()
    
    return text

@dataclass
class EmailEvent:
    subject: str
    sender: str
    to: str
    ics_content: str
    events: List[Event]

class HubzillaCalDAVClient:
    """CalDAV client for uploading events to Hubzilla calendars"""
    
    def __init__(self):
        self.base_url = os.getenv('CALDAV_BASE_URL', 'https://localhost/cdav/')
        self.password = os.getenv('STALWART_ADMIN_PASSWORD', 'admin123')
        
        # Email to channel mapping - routes events to appropriate Hubzilla channels
        # Parse from EMAIL_CHANNEL_MAPPING env var (format: email:channel|email:channel)
        mapping_str = os.getenv('EMAIL_CHANNEL_MAPPING', 'admin@example.com:admin')
        self.email_to_channel = {}
        for pair in mapping_str.split('|'):
            if ':' in pair:
                email, channel = pair.split(':', 1)
                self.email_to_channel[email.strip()] = channel.strip()
        
        self.logger = logging.getLogger(__name__)
    
    def get_channel_from_email(self, to_address: str) -> str:
        """Determine which channel to use based on email To address"""
        # Handle tuple format from imap_tools
        if isinstance(to_address, tuple):
            to_address = to_address[0]
        
        # Extract email address if it contains display name
        if '<' in to_address and '>' in to_address:
            to_address = to_address.split('<')[1].split('>')[0]
        
        channel = self.email_to_channel.get(to_address.lower(), 'admin')
        self.logger.info(f"Routing {to_address} → {channel} channel")
        return channel
    
    def upload_event(self, email_event: EmailEvent) -> bool:
        """Upload calendar event to appropriate Hubzilla channel"""
        try:
            channel = self.get_channel_from_email(email_event.to)
            
            # Create CalDAV client for the channel
            client = caldav.DAVClient(
                url=self.base_url,
                username=channel,
                password=self.password,
                ssl_verify_cert=False  # For local development
            )
            
            calendar_url = f"{self.base_url}calendars/{channel}/default/"
            calendar = client.calendar(url=calendar_url)
            
            # Upload each event
            for i, event in enumerate(email_event.events):
                try:
                    # Sanitize event content to prevent database errors
                    if 'SUMMARY' in event:
                        event['SUMMARY'] = sanitize_calendar_content(str(event['SUMMARY']), 100)
                    if 'DESCRIPTION' in event:
                        event['DESCRIPTION'] = sanitize_calendar_content(str(event['DESCRIPTION']), 250)
                    if 'LOCATION' in event:
                        event['LOCATION'] = sanitize_calendar_content(str(event['LOCATION']), 150)
                    
                    # Generate unique UID if not present
                    if 'UID' not in event:
                        import uuid
                        event.add('UID', str(uuid.uuid4()))
                    
                    # Convert individual VEVENT to complete VCALENDAR document
                    # CalDAV requires full calendar structure, not just individual events
                    from icalendar import Calendar as ICalendar
                    
                    cal = ICalendar()
                    cal.add('prodid', '-//Email Processor//Email to Calendar//EN')
                    cal.add('version', '2.0')
                    cal.add('calscale', 'GREGORIAN')
                    cal.add_component(event)
                    
                    event_ical_bytes = cal.to_ical()
                    event_ical_string = event_ical_bytes.decode('utf-8')
                    event_ical_string = sanitize_ical_content(event_ical_string)
                    event_ical_bytes = event_ical_string.encode('utf-8')
                    
                    print(f"\n=== iCal Content for {channel} channel ===")
                    print(f"Length: {len(event_ical_string)} characters")
                    print(f"Content:\n{event_ical_string}")
                    print("=== End iCal Content ===")
                    
                    # Use manual HTTP PUT approach (bypass caldav library for reliability)
                    import requests
                    import base64
                    import uuid
                    event_filename = f"email-event-{uuid.uuid4()}.ics"
                    event_url = f"{self.base_url}calendars/{channel}/default/{event_filename}"
                    
                    self.logger.info(f"Trying manual PUT to: {event_url}")
                    
                    # Create proper basic auth header
                    auth_string = f"{channel}:{self.password}"
                    auth_bytes = auth_string.encode('ascii')
                    auth_header = base64.b64encode(auth_bytes).decode('ascii')
                    
                    response = requests.put(
                        event_url,
                        data=event_ical_bytes,  # Send binary data like curl --data-binary
                        headers={
                            'Content-Type': 'text/calendar; charset=utf-8',
                            'Authorization': f'Basic {auth_header}'
                        },
                        verify=False
                    )
                    
                    if response.status_code in [200, 201, 204]:
                        self.logger.info(f"Manual upload succeeded: {response.status_code}")
                    else:
                        self.logger.error(f"Manual upload failed: {response.status_code}")
                        self.logger.error(f"Response: {response.text[:200]}")
                        return False
                    
                    summary = event.get('SUMMARY', 'No title')
                    self.logger.info(f"Uploaded '{summary}' to {channel} channel")
                    
                except Exception as e:
                    self.logger.error(f"Failed to upload event {i+1}: {e}")
                    return False
            
            return True
            
        except Exception as e:
            self.logger.error(f"CalDAV upload failed: {e}")
            return False

class EmailProcessor:
    def __init__(self):
        load_dotenv()
        
        # Use existing Stalwart configuration
        self.host = os.getenv('IMAP_HOST', 'localhost')
        self.port = int(os.getenv('IMAP_PORT', '143'))
        self.use_ssl = os.getenv('IMAP_USE_SSL', 'false').lower() == 'true'
        
        # Use existing Stalwart credentials
        self.username = os.getenv('SMTP_USER')
        self.password = os.getenv('STALWART_ADMIN_PASSWORD')
        
        if not self.username:
            raise ValueError("SMTP_USER environment variable is required")
        if not self.password:
            raise ValueError("STALWART_ADMIN_PASSWORD environment variable is required")
        
        self.folder = os.getenv('IMAP_FOLDER', 'INBOX')
        self.mark_read = os.getenv('IMAP_MARK_READ', 'false').lower() == 'true'
        
        # Setup logging
        log_level = os.getenv('LOG_LEVEL', 'DEBUG')
        debug_mode = os.getenv('DEBUG', 'false').lower() == 'true'
        
        logging.basicConfig(
            level=getattr(logging, log_level),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            force=True  # Override any existing logging config
        )
        self.logger = logging.getLogger(__name__)
        
        if debug_mode:
            self.logger.info(f"Email Processor initialized:")
            self.logger.info(f"  IMAP Server: {self.host}:{self.port}")
            self.logger.info(f"  Username: {self.username}")
            self.logger.info(f"  Folder: {self.folder}")
            self.logger.info(f"  CalDAV upload: Enabled")
    
    def connect_and_process(self) -> List[EmailEvent]:
        """Connect to IMAP server and process emails with .ics attachments"""
        try:
            self.logger.info(f"Connecting to IMAP server {self.host}:{self.port}")
            
            with MailBoxStartTls(self.host, self.port).login(
                self.username, self.password, self.folder
            ) as mailbox:
                self.logger.info(f"Successfully connected and logged in")
                
                # Search for emails with attachments
                emails = list(mailbox.fetch())
                self.logger.info(f"Found {len(emails)} emails in {self.folder}")
                
                email_events = []
                
                for msg in emails:
                    self.logger.debug(f"Processing email: {msg.subject}")
                    self.logger.debug(f"  To: {msg.to}")
                    self.logger.debug(f"  From: {msg.from_}")
                    
                    if not msg.attachments:
                        continue
                        
                    # Look for .ics attachments
                    for attachment in msg.attachments:
                        if attachment.filename and attachment.filename.lower().endswith('.ics'):
                            self.logger.info(f"Found .ics attachment: {attachment.filename}")
                            
                            events = self._parse_ics_attachment(attachment.payload)
                            if events:
                                email_events.append(EmailEvent(
                                    subject=msg.subject,
                                    sender=msg.from_,
                                    to=msg.to,
                                    ics_content=attachment.payload.decode('utf-8'),
                                    events=events
                                ))
                
                return email_events
                
        except Exception as e:
            self.logger.error(f"Error processing emails: {e}")
            raise
    
    def _parse_ics_attachment(self, ics_data: bytes) -> List[Event]:
        """Parse .ics attachment and extract events"""
        try:
            calendar = Calendar.from_ical(ics_data)
            events = []
            
            for component in calendar.walk():
                if component.name == "VEVENT":
                    events.append(component)
                    
            self.logger.info(f"Parsed {len(events)} events from .ics file")
            return events
            
        except Exception as e:
            self.logger.error(f"Error parsing .ics file: {e}")
            return []

def main():
    """Test the email processor with CalDAV upload"""
    try:
        processor = EmailProcessor()
        caldav_client = HubzillaCalDAVClient()
        
        email_events = processor.connect_and_process()
        
        print(f"\n=== EMAIL PROCESSING RESULTS ===")
        print(f"Found {len(email_events)} emails with calendar events:")
        
        for email_event in email_events:
            print(f"\nEmail: {email_event.subject}")
            print(f"   From: {email_event.sender}")
            print(f"   To: {email_event.to}")
            print(f"   Events found: {len(email_event.events)}")
            
            for i, event in enumerate(email_event.events, 1):
                summary = event.get('SUMMARY', 'No title')
                dtstart = event.get('DTSTART')
                location = event.get('LOCATION', 'No location')
                
                print(f"   Event {i}: {summary}")
                if dtstart:
                    print(f"      Start: {dtstart.dt}")
                if location:
                    print(f"      Location: {location}")
            
            channel = caldav_client.get_channel_from_email(email_event.to)
            print(f"   Target: {channel} channel calendar")
            
            if caldav_client.upload_event(email_event):
                print(f"   Successfully uploaded to {channel} channel")
            else:
                print(f"   Failed to upload to {channel} channel")
        
        if len(email_events) == 0:
            print("\nNo emails with .ics attachments found.")
            print("   To test: send an email with a calendar .ics attachment to tech@example.com")
            
    except Exception as e:
        print(f"Error: {e}")
        print("Make sure Docker containers are running and Stalwart is accessible")

if __name__ == "__main__":
    main()
