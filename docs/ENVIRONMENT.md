# Environment Variables

Copy `.env.example` to `.env` and configure:

## Required
```bash
# SSL
MKCERT_PATH=~/.local/share/mkcert  # Path from `mkcert -CAROOT`

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
