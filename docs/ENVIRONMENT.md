# Environment Variables

Copy `.env.example` to `.env` and configure:


## Required
```bash

# 1. Find your path: mkcert -CAROOT
# 2. Copy that exact path to MKCERT_PATH below
MKCERT_PATH=YOUR_MKCERT_PATH_HERE

Examples: 
    Linux/WSL:
    MKCERT_PATH=~/.local/share/mkcert

    macOS:
    MKCERT_PATH=~/Library/Application Support/mkcert  

    Windows WSL2:
    MKCERT_PATH=/mnt/c/Users/USERNAME/AppData/Local/mkcert
```

```bash
# Site
DOMAIN=localhost
ADMIN_EMAIL=admin@yourdomain.com
TIMEZONE=Etc/UTC

# Database
DB_HOST=hub_db
DB_NAME=hub
DB_USER=hubzilla
DB_PASSWORD=P@55w0rD
DB_TYPE=postgres
DB_PORT=5432

# Mail Server
STALWART_ADMIN_PASSWORD=admin123
SMTP_HOST=stalwart
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.com
SMTP_USER=admin@yourdomain.com
SMTP_PASS=admin123
```

## Optional
```bash
# Registration
REQUIRE_EMAIL=0                    # Disable for local dev
REGISTER_POLICY=REGISTER_OPEN      # REGISTER_OPEN, REGISTER_APPROVE, REGISTER_CLOSED

# Debug
DEBUG_PHP=0
LOG_LEVEL=DEBUG                    # For email processor

# Add-ons
ADDON_LIST=logrot nsfw superblock diaspora pubcrawl

# Logging
ENABLE_LOGROT=0
LOGROT_PATH=log
LOGROT_SIZE=5242880
LOGROT_MAXFILES=20
```
