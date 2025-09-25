import os
import logging
from typing import List, Optional
from dataclasses import dataclass
from dotenv import load_dotenv
from imap_tools import MailBoxStartTls, MailMessage
from icalendar import Calendar, Event

@dataclass
class EmailEvent:
    subject: str
    sender: str
    ics_content: str
    events: List[Event]

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
    """Test the email processor"""
    try:
        processor = EmailProcessor()
        email_events = processor.connect_and_process()
        
        print(f"\n=== EMAIL PROCESSING RESULTS ===")
        print(f"Found {len(email_events)} emails with calendar events:")
        
        for email_event in email_events:
            print(f"\nEmail: {email_event.subject}")
            print(f"   From: {email_event.sender}")
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
        
        if len(email_events) == 0:
            print("\nNo emails with .ics attachments found.")
            print("   To test: send an email with a calendar .ics attachment to admin@example.com")
            
    except Exception as e:
        print(f"Error: {e}")
        print("Make sure Docker containers are running and Stalwart is accessible")

if __name__ == "__main__":
    main()
