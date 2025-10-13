# Environment Variables

This document covers environment variable configuration for both local development and staging/production deployments.

---

## Local Development Environment Variables

For local development, copy `.env.example` to `.env` and configure the following variables. All values are stored in plain text in the `.env` file.

### SSL Configuration (Local Only)

```bash
# Required for local development HTTPS
# 1. Find your path: mkcert -CAROOT
# 2. Copy that exact path to MKCERT_PATH below
MKCERT_PATH=YOUR_MKCERT_PATH_HERE

# Examples: 
#   Linux/WSL:
#   MKCERT_PATH=~/.local/share/mkcert
#
#   macOS:
#   MKCERT_PATH=~/Library/Application Support/mkcert  
#
#   Windows WSL2:
#   MKCERT_PATH=/mnt/c/Users/USERNAME/AppData/Local/mkcert
```

**Note:** `MKCERT_PATH` is only needed for local development. Staging/production deployments use Let's Encrypt via Traefik.

### Site Configuration

```bash
# Domain
DOMAIN=localhost                    # For local dev
# DOMAIN=yourdomain.com             # For staging/production

# Admin contact
ADMIN_EMAIL=admin@yourdomain.com

# Timezone (see: https://www.php.net/manual/en/timezones.php)
TIMEZONE=America/New_York
```

### Database Configuration

```bash
# Database connection
DB_HOST=hub_db                      # Container name
DB_NAME=hub                         # Database name
DB_USER=hubzilla                    # Database username
DB_TYPE=postgres                    # Database type
DB_PORT=5432                        # PostgreSQL port

# Database password (local development)
DB_PASSWORD=P@55w0rD                # Change for production
```

**Note:** For staging/production, `DB_PASSWORD` is managed via Docker Secrets, not `.env`.

### Mail Server Configuration

```bash
# Stalwart admin password (local development)
STALWART_ADMIN_PASSWORD=admin123    # Change for production

# SMTP settings
SMTP_HOST=stalwart                  # Container name
SMTP_PORT=587                       # SMTP submission port
SMTP_DOMAIN=localhost               # For local dev
# SMTP_DOMAIN=yourdomain.com        # For staging/production
SMTP_USER=admin@yourdomain.com
SMTP_USE_STARTTLS=YES

# SMTP password (local development)
SMTP_PASS=admin123                  # Change for production

# Mail domain
MAIL_DOMAIN=mail.localhost          # For local dev
# MAIL_DOMAIN=mail.yourdomain.com   # For staging/production
```

**Note:** For staging/production, `STALWART_ADMIN_PASSWORD` and `SMTP_PASS` are managed via Docker Secrets.

### Registration & Email

```bash
# Require email verification
REQUIRE_EMAIL=0                     # 0=disabled (local), 1=enabled (production)

# Registration policy
REGISTER_POLICY=REGISTER_OPEN       # Options:
                                    # REGISTER_OPEN - Anyone can register
                                    # REGISTER_APPROVE - Admin approval required
                                    # REGISTER_CLOSED - Registration disabled
```

**Recommended for production:** `REQUIRE_EMAIL=1` and `REGISTER_POLICY=REGISTER_APPROVE`

### Add-ons

```bash
# Hubzilla add-ons to enable
ADDON_LIST=logrot nsfw superblock diaspora pubcrawl
```

### Logging Configuration

```bash
# Log rotation
ENABLE_LOGROT=0                     # 0=disabled, 1=enabled
LOGROT_PATH=log                     # Log directory
LOGROT_SIZE=5242880                 # 5MB in bytes
LOGROT_MAXFILES=20                  # Keep last 20 log files

# PHP debugging
DEBUG_PHP=0                         # 0=disabled, 1=enabled (verbose)

# Python email processor logging
LOG_LEVEL=INFO                      # DEBUG, INFO, WARNING, ERROR
```

### Email-to-Calendar Processing

```bash
# IMAP connection
IMAP_HOST=mail.localhost            # For local dev
# IMAP_HOST=mail.yourdomain.com     # For staging/production
IMAP_PORT=143                       # IMAP port
IMAP_USE_SSL=false                  # false for STARTTLS, true for SSL
IMAP_FOLDER=INBOX                   # Folder to monitor
IMAP_MARK_READ=false                # Mark processed emails as read

# CalDAV configuration
CALDAV_BASE_URL=https://localhost/cdav/              # For local dev
# CALDAV_BASE_URL=https://yourdomain.com/cdav/      # For staging/production

# Email to channel routing (comma-separated)
EMAIL_CHANNEL_MAPPING=tech@yourdomain.com:tech|music@yourdomain.com:music|education@yourdomain.com:education|volunteer@yourdomain.com:volunteer|community@yourdomain.com:community|admin@yourdomain.com:admin

# Service names (for Docker networking)
WEBSERVER_SERVICE_NAME=hub          # Hub container name
```

---

## Staging/Production Environment Variables

For staging and production deployments via Docker Swarm and Portainer:

### Configuration Location
Environment variables are stored in `.env` in the repository root (non-sensitive values only).

### Sensitive Values
Passwords and secrets are managed via **Docker Secrets**, not environment variables:

**Required secrets:**
- `hubzilla_db_password` - Database password
- `hubzilla_smtp_password` - SMTP password  
- `hubzilla_stalwart_admin_password` - Mail server admin password

**Creating secrets in Portainer:**
1. Navigate to **Secrets** → **Add Secret**
2. Enter secret name exactly as listed
3. Paste password value
4. Click **Create Secret**

See [Hubzilla Staging Deployment Guide](HUBZILLA-STAGING_DEPLOYMENT.md#prerequisites) for details.

### Key Differences from Local

**Removed variables:**
- `MKCERT_PATH` - Not used (Let's Encrypt instead)
- `DB_PASSWORD` - Managed via Docker Secret
- `SMTP_PASS` - Managed via Docker Secret
- `STALWART_ADMIN_PASSWORD` - Managed via Docker Secret

**Changed variables:**
```bash
# Use real domain names
DOMAIN=hubzilla.staging.chattanooga.digital
SMTP_DOMAIN=staging.chattanooga.digital
MAIL_DOMAIN=mail.staging.chattanooga.digital

# Enable security features
REQUIRE_EMAIL=1
REGISTER_POLICY=REGISTER_APPROVE

# Disable debug modes
DEBUG_PHP=0
LOG_LEVEL=INFO
```

### Viewing Staging Configuration

See the current staging `.env` file in the repository for a complete production-ready example.

---

## Environment Variable Loading

### Local Development (docker-compose.yml)
All variables loaded from `.env` file via `env_file` directive:
```yaml
services:
  hub:
    env_file:
      - .env
```

### Staging/Production (docker-stack.yml)
- Non-sensitive variables loaded from `.env`
- Sensitive values loaded from Docker Secrets via `load-secrets.sh` script
- Secrets mounted at `/run/secrets/` in containers

---

## Security Best Practices

### Local Development
- Use simple passwords for convenience
- Don't commit `.env` to git (already in `.gitignore`)
- Keep `.env.example` updated with non-sensitive defaults

### Staging/Production
- Generate strong random passwords (15+ characters)
- Store passwords only in Docker Secrets
- Never commit passwords to git
- Rotate secrets regularly
- Use `REGISTER_POLICY=REGISTER_APPROVE` or `REGISTER_CLOSED`
- Enable `REQUIRE_EMAIL=1`

---

## Reference

- [Hubzilla Stack Deployment Guide (Staging)](HUBZILLA-STAGING_DEPLOYMENT.md)
- [Stalwart Mail Stack Deployment Guide](STALWART-SEPARATE-STACK-DEPLOYMENT.md)
- [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
