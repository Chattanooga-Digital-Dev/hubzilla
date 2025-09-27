# Email-to-Calendar Integration

This directory contains the Python application for processing emails and uploading calendar events to Hubzilla channels via CalDAV.

## Files

- `email_processor.py` - Main application script
- `requirements.txt` - Python dependencies  
- `README.md` - This file

## Setup

**Step 1: Create virtual environment**
```bash
# Linux/WSL/macOS users:
python3 -m venv venv

# Windows users:
python -m venv venv
```

**Step 2: Activate virtual environment**
```bash
# Linux/WSL/macOS users:
source venv/bin/activate

# Windows users:
venv\Scripts\activate
```

**Step 3: Install dependencies and run**
```bash
# All users (after activation):
pip install -r requirements.txt
python email_processor.py
```

## Configuration

The application uses environment variables from the project root `.env` file:
- `SMTP_USER` - Email username 
- `STALWART_ADMIN_PASSWORD` - Email and CalDAV password
- `LOG_LEVEL` - Logging level (default: DEBUG)

## How It Works

1. Connects to Stalwart email server via IMAP
2. Searches for emails with `.ics` calendar attachments
3. Routes events to appropriate Hubzilla channels based on email address:
   - `tech@example.com` → tech channel
   - `music@example.com` → music channel  
   - `admin@example.com` → admin channel
   - etc.
4. Sanitizes calendar content to prevent database errors
5. Uploads events via CalDAV to Hubzilla calendars

## Features

- Content sanitization (removes emojis, special characters)
- Channel-based routing
- CalDAV integration with Hubzilla
- Debug logging and file output
