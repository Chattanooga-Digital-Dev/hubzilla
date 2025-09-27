import os
import logging
from typing import List, Optional
from dataclasses import dataclass
from dotenv import load_dotenv
from imap_tools import MailBoxStartTls, MailMessage
from icalendar import Calendar, Event
import caldav
import ssl
from urllib.parse import urlparse

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
        self.base_url = 'https://localhost/cdav/'
        self.password = os.getenv('STALWART_ADMIN_PASSWORD', 'admin123')
        
        # Email to channel mapping
        self.email_to_channel = {
            'tech@example.com': 'tech',
            'music@example.com': 'music',
            'education@example.com': 'education',
            'volunteer@example.com': 'volunteer',
            'community@example.com': 'community',
            'admin@example.com': 'admin'  # fallback
        }
        
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
            # Determine target channel
            channel = self.get_channel_from_email(email_event.to)
            
            # Create CalDAV client for the channel
            client = caldav.DAVClient(
                url=self.base_url,
                username=channel,
                password=self.password,
                ssl_verify_cert=False  # For local development
            )
            
            # Get the calendar
            calendar_url = f"{self.base_url}calendars/{channel}/default/"
            calendar = client.calendar(url=calendar_url)
            
            # Upload each event
            for i, event in enumerate(email_event.events):
                try:
                    # Generate unique UID if not present
                    if 'UID' not in event:
                        import uuid
                        event.add('UID', str(uuid.uuid4()))
                    
                    # Convert event to iCal string
                    event_ical = event.to_ical().decode('utf-8')
                    
                    # Debug: Log the iCal data being uploaded
                    self.logger.debug(f"Uploading iCal data to {channel}:")
                    self.logger.debug(f"Length: {len(event_ical)} chars")
                    self.logger.debug(f"First 200 chars: {event_ical[:200]}")
                    
                    # Create the event in Hubzilla
                    calendar.save_event(event_ical)
                    
                    summary = event.get('SUMMARY', 'No title')
                    self.logger.info(f"✅ Uploaded '{summary}' to {channel} channel")
                    
                except Exception as e:
                    self.logger.error(f"❌ Failed to upload event {i+1}: {e}")
                    return False
            
            return True
            
        except Exception as e:
            self.logger.error(f"❌ CalDAV upload failed: {e}")
            return False

class EmailProcessor:
    def __init__(self):
        load_dotenv()
        
        # Use existing Stalwart configuration
        self.host = 'localhost'  # Connect from host to container
        self.port = 143          # IMAP port with STARTTLS
        self.use_ssl = False     # STARTTLS (starts plain, upgrades to TLS)
        
        # Use existing Stalwart credentials
        self.username = os.getenv('SMTP_USER')
        self.password = os.getenv('STALWART_ADMIN_PASSWORD')
        
        # Validate required credentials exist
        if not self.username:
            raise ValueError("SMTP_USER environment variable is required")
        if not self.password:
            raise ValueError("STALWART_ADMIN_PASSWORD environment variable is required")
        
        # IMAP folder settings
        self.folder = os.getenv('IMAP_FOLDER', 'INBOX')
        self.mark_read = os.getenv('IMAP_MARK_READ', 'false').lower() == 'true'
        
        # Setup logging
        log_level = os.getenv('LOG_LEVEL', 'INFO')
        debug_mode = os.getenv('DEBUG', 'false').lower() == 'true'
        
        logging.basicConfig(
            level=getattr(logging, log_level),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
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
                    
                    # Check if email has attachments
                    if not msg.attachments:
                        continue
                        
                    # Look for .ics attachments
                    for attachment in msg.attachments:
                        if attachment.filename and attachment.filename.lower().endswith('.ics'):
                            self.logger.info(f"Found .ics attachment: {attachment.filename}")
                            
                            # Parse the .ics content
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
        # Initialize email processor and CalDAV client
        processor = EmailProcessor()
        caldav_client = HubzillaCalDAVClient()
        
        # Process emails
        email_events = processor.connect_and_process()
        
        print(f"\n=== EMAIL PROCESSING RESULTS ===")
        print(f"Found {len(email_events)} emails with calendar events:")
        
        # Display and upload events
        for email_event in email_events:
            print(f"\nEmail: {email_event.subject}")
            print(f"   From: {email_event.sender}")
            print(f"   To: {email_event.to}")
            print(f"   Events found: {len(email_event.events)}")
            
            # Show event details
            for i, event in enumerate(email_event.events, 1):
                summary = event.get('SUMMARY', 'No title')
                dtstart = event.get('DTSTART')
                location = event.get('LOCATION', 'No location')
                
                print(f"   Event {i}: {summary}")
                if dtstart:
                    print(f"      Start: {dtstart.dt}")
                if location:
                    print(f"      Location: {location}")
            
            # Upload to Hubzilla calendar
            channel = caldav_client.get_channel_from_email(email_event.to)
            print(f"   Target: {channel} channel calendar")
            
            if caldav_client.upload_event(email_event):
                print(f"   ✅ Successfully uploaded to {channel} channel")
            else:
                print(f"   ❌ Failed to upload to {channel} channel")
        
        if len(email_events) == 0:
            print("\nNo emails with .ics attachments found.")
            print("   To test: send an email with a calendar .ics attachment to tech@example.com")
            
    except Exception as e:
        print(f"Error: {e}")
        print("Make sure Docker containers are running and Stalwart is accessible")

if __name__ == "__main__":
    main()
