# Hubzilla Local Development with Docker

A fully containerized Hubzilla setup for local development with HTTPS support.

## Features

- **HTTPS with certificates** - Uses mkcert for browser-trusted localhost certificates
- **PostgreSQL database** - Persistent data storage
- **localhost domain** - Works on any machine without DNS configuration
- **URL rewrite testing** - Internal HTTP forwarding for setup wizard validation

## Disclaimer

This project was developed with AI assistance and is provided "as-is" without warranty. Please research any commands before running them. This code is in early development, may contain bugs, and is intended for local development and testing only. **Not for production use.**

## Prerequisites

- Docker & Docker Compose
- Git
- mkcert (for TLS/SSL certificates)

## SSL Setup

Install mkcert to get trusted SSL certificates without browser warnings:

**Step 1 (optional): Install NSS tools (Linux only - required for Firefox support)**
```bash
# Debian/Ubuntu/Linux Mint
sudo apt install libnss3-tools
```
*Note: Firefox on Linux uses its own certificate store (NSS) instead of the system store. Windows and macOS Firefox can use the system certificate store that mkcert configures automatically.*

**Step 2: Install mkcert**
```bash
# Debian/Ubuntu/Linux Mint
sudo apt install mkcert

# macOS
brew install mkcert

# Windows
# Download from https://github.com/FiloSottile/mkcert/releases
```

**Step 3: Initialize mkcert**
```bash
mkcert -install
```

**What `mkcert -install` does:**
- Creates a local Certificate Authority (CA) on your system
- Installs the rootCA certificate into your system's trust store
- Enables browsers to trust certificates signed by this CA
- One-time setup - only needs to be run once per system

**Configuration:** The docker-compose.yml is already configured to access your mkcert certificates via the `MKCERT_PATH` environment variable in your `.env` file. Run `mkcert -CAROOT` to find the correct path for your system.

## Quick Start for Developers

### 1. Clone and Configure

```bash
git clone https://github.com/Chattanooga-Digital-Dev/hubzilla.git
cd hubzilla
cp .env.example .env
```

### 2. Build and Start Containers

```bash
# Build containers and start all services
docker compose build --no-cache
docker compose up -d

# Monitor startup (optional but recommended)
docker logs -f hubzilla_itself
# Press Ctrl+C to exit log monitoring when you see "Starting php-fpm"
```

### 3. Complete Hubzilla Setup

1. **Open the setup wizard in your browser:**
   ```
   https://localhost
   ```

2. **Database Configuration (Step 2 of setup wizard):**
   ```
   Database Server Name: hub_db
   Database Port: 5432
   Database Login Name: hubzilla
   Database Login Password: P@55w0rD
   Database Name: hub
   Database Type: PostgreSQL
   ```

3. **Create Administrator Account (Step 3):**
   - Fill in your desired admin credentials
   - Use any email address (verification bypassed for local development)

4. **Complete the remaining setup steps** following the wizard

### 4. Email Verification

**Option 1: Use Stalwart Email Server (Recommended)**

The project includes an integrated email server that can send verification emails. First, configure the email server:

1. **Access Stalwart Admin Interface:**
   - Go to https://localhost:8080
   - Login with username: `admin` and password from your `.env` file (`STALWART_ADMIN_PASSWORD`)

2. **Create Domain:**
   - Navigate to "Domains" section
   - Create a new domain named `example.com`

3. **Create Admin Email Account:**
   - Go to "Accounts" section
   - Create new account with these settings:
     - **Name:** Admin
     - **Login Name:** admin@example.com
     - **Email:** admin@example.com
     - **Password:** Use the same as `STALWART_ADMIN_PASSWORD`

4. **Create Channel Email Aliases:**
   - Create the following aliases under admin@example.com:
     - music@example.com
     - education@example.com
     - tech@example.com
     - volunteer@example.com
     - community@example.com

5. **Configure Email Client (Thunderbird):**
   - **Full Name:** Admin
   - **Email Address:** admin@example.com
   - **IMAP Server:** localhost, Port 993, SSL/TLS, Normal Password
   - **SMTP Server:** localhost, Port 587, STARTTLS, Normal Password

**Option 2: Manual Verification (Backup Method)**

If you prefer to bypass email verification entirely:

```bash
# Get your verification token (replace with your actual email)
docker exec hubzilla_itself sh -c 'PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT reg_hash FROM register WHERE reg_email='\''your-email@example.com'\'';"'

# Visit verification URL with the returned token
# https://localhost/register/verify/YOUR_TOKEN_HERE
```

### 5. Access Your Hubzilla Instance

Your Hubzilla instance is now ready at: **https://localhost**

## Container Architecture

| Container | Purpose | Internal IP | Ports |
|-----------|---------|-------------|--------|
| `hubzilla_itself` | PHP-FPM + Hubzilla app | 172.20.0.20 | 9000 |
| `hubzilla_webserver` | Nginx reverse proxy | 172.20.0.10 | 80, 443 |
| `hubzilla_database` | PostgreSQL database | 172.20.0.30 | 5432 |
| `hubzilla_cronjob` | Background tasks | 172.20.0.40 | - |
| `hubzilla_mailserver` | Stalwart mail server | 172.20.0.50 | 25, 143, 993, 465, 587, 8080 |

### Docker Compose Services

- `hub_db` (PostgreSQL) - Database service with health checks
- `hub` (Hubzilla) - Main application with PHP-FPM
- `hub_web` (Nginx) - Reverse proxy with SSL termination
- `hub_cron` (Cron) - Background task processing
- `stalwart` (Stalwart) - Integrated SMTP/IMAP mail server for local development

### Mail Server Ports

- **25** - SMTP (incoming mail)
- **143** - IMAP (plain text)
- **993** - IMAPS (IMAP over SSL)
- **465** - SMTP over SSL
- **587** - SMTP submission (STARTTLS)
- **8080** - Web administration interface

## Docker Volumes

All data is stored in Docker volumes for portability:

- `db_data` - PostgreSQL database files
- `web_root` - Hubzilla application files
- `ssl_certs` - SSL certificates (shared between containers)
- `nginx_config` - Nginx site configuration
- `stalwart_data` - Mail server data and configuration

## Stalwart Mail Server

The project includes an integrated Stalwart mail server for local development, eliminating the need for external email services during testing.

### Features

- **Full SMTP/IMAP Support** - Send and receive emails locally
- **Multiple Protocol Support** - SMTP, IMAP, SMTPS, IMAPS  
- **Web Administration** - Management interface at https://localhost:8080
- **CalDAV Integration** - Calendar events can be uploaded via email attachments
- **Channel-based Email Routing** - Different email aliases route to different Hubzilla channels

### Initial Setup

After starting the containers, configure the mail server:

1. **Access Admin Interface:**
   - Go to https://localhost:8080
   - Login with username: `admin` and password from `.env` (`STALWART_ADMIN_PASSWORD`)

2. **Create Domain:**
   - Navigate to "Domains" section
   - Create a new domain named `example.com`

3. **Create Admin Account:**
   - Go to "Accounts" section
   - Create account:
     - **Name:** Admin
     - **Login:** admin@example.com
     - **Email:** admin@example.com
     - **Password:** Use same as `STALWART_ADMIN_PASSWORD`

4. **Create Channel Aliases:**
   - Create the following aliases under admin@example.com:
     - `tech@example.com` - Technical discussions → tech channel
     - `music@example.com` - Music events → music channel
     - `education@example.com` - Educational content → education channel
     - `volunteer@example.com` - Volunteer coordination → volunteer channel
     - `community@example.com` - Community events → community channel

### Email Client Configuration

Configure Thunderbird or other email clients with these settings:

- **Account:** admin@example.com
- **IMAP Server:** localhost, Port 993, SSL/TLS
- **SMTP Server:** localhost, Port 587, STARTTLS
- **Authentication:** Normal Password
- **Password:** Value from `STALWART_ADMIN_PASSWORD` in `.env`

### Testing Email Functionality

Once configured, you can:
- Receive verification emails through Thunderbird during Hubzilla registration
- Send test emails to alias email addresses (tech@, music@, etc.)

## Email-to-Calendar Processing

The project includes a Python application that processes emails with calendar attachments and uploads events to appropriate Hubzilla channels via CalDAV.  Emails with .ics calendar attachments can be processed by manually running the email_processor.py script in the email-calendar/ directory. **Automatic processing via cron job is planned for future development.**

### Location and Setup

The email processor is located in the `email-calendar/` directory:

```bash
cd email-calendar

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate  # Linux/macOS/WSL
# venv\Scripts\activate   # Windows

# Install dependencies
pip install -r requirements.txt
```

### How It Works

1. **Email Monitoring** - Connects to Stalwart IMAP server to scan for new emails
2. **Attachment Processing** - Extracts `.ics` calendar files from email attachments
3. **Content Sanitization** - Removes problematic characters, emojis, and formatting that could cause database errors
4. **Channel Routing** - Routes calendar events to appropriate Hubzilla channels based on email recipient address
5. **CalDAV Upload** - Uploads sanitized events to Hubzilla calendars via CalDAV protocol

### Channel Routing

Events are automatically routed to channels based on the email recipient:

| Email Address | Target Channel | Use Case |
|---------------|----------------|----------|
| `tech@yourdomain.com` | tech | Technical meetups, conferences |
| `music@yourdomain.com` | music | Concerts, performances, studio time |
| `education@yourdomain.com` | education | Classes, workshops, seminars |
| `volunteer@yourdomain.com` | volunteer | Volunteer opportunities, shifts |
| `community@yourdomain.com` | community | Community events, meetings |
| `admin@yourdomain.com` | admin | Administrative events (fallback) |

### Running the Processor

```bash
# From the email-calendar directory
python email_processor.py
```

The processor will:
- Connect to the local Stalwart mail server
- Scan for emails with `.ics` attachments
- Display processing results and upload status
- Upload events to the appropriate Hubzilla channel calendars

### Configuration

The processor uses environment variables from the project root `.env` file:

```bash
SMTP_USER=admin@yourdomain.com
STALWART_ADMIN_PASSWORD=admin123
LOG_LEVEL=DEBUG  # Optional: DEBUG, INFO, WARNING, ERROR
```

### Testing

To test the email-to-calendar functionality:

1. Ensure Docker containers are running
2. Send an email with a `.ics` calendar attachment to one of the configured addresses
3. Run the email processor
4. Check the corresponding Hubzilla channel calendar for the uploaded event

## Environment Variables

Configure the project by copying `.env.example` to `.env` and updating the values:

```bash
cp .env.example .env
```

### Required Configuration

**Cross-Platform SSL Setup**
```bash
# Path to mkcert root CA directory (run `mkcert -CAROOT` to find yours)
MKCERT_PATH=~/.local/share/mkcert  # Linux/WSL
# MKCERT_PATH=~/Library/Application Support/mkcert  # macOS
# MKCERT_PATH=/mnt/c/Users/USERNAME/AppData/Local/mkcert  # Windows WSL
```

**Hubzilla Site Configuration**
```bash
DOMAIN=localhost
ADMIN_EMAIL=admin@yourdomain.com
TIMEZONE=Etc/UTC
REQUIRE_EMAIL=0  # Disable for local development
REGISTER_POLICY=REGISTER_OPEN  # Options: REGISTER_OPEN, REGISTER_APPROVE, REGISTER_CLOSED
```

**Database Configuration**
```bash
DB_HOST=hub_db
DB_NAME=hub
DB_USER=hubzilla
DB_PASSWORD=P@55w0rD
DB_TYPE=postgres
DB_PORT=5432
```

**Mail Server Configuration**
```bash
# Stalwart Mail Server
STALWART_ADMIN_PASSWORD=admin123
SMTP_HOST=stalwart
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.com
SMTP_USER=admin@yourdomain.com
SMTP_PASS=admin123
SMTP_USE_STARTTLS=YES
```

### Optional Configuration

**Logging**
```bash
ENABLE_LOGROT=0
LOGROT_PATH=log
LOGROT_SIZE=5242880  # Size in bytes
LOGROT_MAXFILES=20
```

**Debug Settings**
```bash
DEBUG_PHP=0
LOG_LEVEL=DEBUG  # For email processor: DEBUG, INFO, WARNING, ERROR
```

**Hubzilla Add-ons**
```bash
ADDON_LIST=logrot nsfw superblock diaspora pubcrawl
```

## Development Commands

### Viewing Logs

```bash
# All containers
docker compose logs

# Specific containers
docker logs hubzilla_itself      # Main Hubzilla application
docker logs hubzilla_webserver   # Nginx web server
docker logs hubzilla_database    # PostgreSQL database
docker logs hubzilla_cronjob     # Background cron jobs

# Follow logs in real-time
docker logs -f hubzilla_itself
```

### Accessing Containers

```bash
# Hubzilla application container
docker exec -it hubzilla_itself bash

# Database container (psql access)
docker exec -it hubzilla_database psql -U hubzilla -d hub

# Nginx container
docker exec -it hubzilla_webserver sh

# Check container status
docker compose ps
```

### Database Operations

```bash
# Connect to PostgreSQL directly
docker exec -it hubzilla_database psql -U hubzilla -d hub

# Run SQL commands from host
docker exec hubzilla_itself sh -c 'PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT count(*) FROM account;"'

# Backup database
docker exec hubzilla_database pg_dump -U hubzilla -d hub > hubzilla_backup.sql

# Restore database
docker exec -i hubzilla_database psql -U hubzilla -d hub < hubzilla_backup.sql
```

### SSL Certificate Management

```bash
# View certificate details
docker exec hubzilla_itself openssl x509 -in /var/ssl-shared/localhost.pem -text -noout

# Test SSL connection
docker exec hubzilla_itself openssl s_client -connect hubzilla_webserver:443 -verify_return_error </dev/null
``

## Complete Cleanup Instructions

### Option 1: Remove Everything (Nuclear Option)

```bash
# Stop all containers
docker compose down

# Remove all volumes (⚠️ DELETES ALL DATA)
docker volume rm hubzilla_db_data hubzilla_web_root hubzilla_ssl_certs hubzilla_nginx_config

# Remove all images
docker image rm hubzilla-hub hubzilla-hub_cron

# Remove network
docker network rm hubzilla_hubzilla

# Clean up unused Docker resources
docker system prune -a --volumes
```

### Option 2: Selective Cleanup

```bash
# Just restart containers (keeps data)
docker compose down
docker compose up -d

# Reset database only (keeps SSL certs and configs)
docker compose down
docker volume rm hubzilla_db_data
docker compose up -d

# Reset everything except database
docker compose down
docker volume rm hubzilla_web_root hubzilla_ssl_certs hubzilla_nginx_config
docker compose up -d
```

### Option 3: Full System Docker Cleanup

```bash
# ⚠️ WARNING: This affects ALL Docker containers/volumes on your system
docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
docker volume rm $(docker volume ls -q)
docker image rm $(docker image ls -aq)
docker network prune -f
```

## Troubleshooting

### Common Issues

**Problem:** Containers fail to start
**Solution:**
```bash
# Check container status
docker compose ps

# View detailed logs
docker compose logs

**Problem:** "Connection refused" errors
**Solution:**
```bash
# Wait for database initialization (first start takes 30-60 seconds)
docker logs hubzilla_database

# Check network connectivity
docker exec hubzilla_itself ping hub_db
```

### Health Checks

```bash
# Check all services are healthy
docker compose ps

# Test database connectivity
docker exec hubzilla_itself sh -c 'PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT version();"'

# Test web server response
curl -k -I https://localhost

# Test internal HTTP forwarding
docker exec hubzilla_itself curl -k -s https://localhost/setup/testrewrite
```

### Git Workflow

```bash
# Regular development commits
git add .
git commit -m "Description of changes"

# Before major changes, ensure clean state
docker compose down
git status  # Should show clean working directory
```

## Production Notes

⚠️ **This setup is for local development only!**

For production deployment:
- Replace mkcert certificates with real SSL certificates (Let's Encrypt, etc.)
- Configure proper domain names instead of localhost
- Enable email verification (`REQUIRE_EMAIL=1`)
- Review all security settings in `.env`
- Configure proper backup procedures
- Set up monitoring and logging
- Review and harden container security

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Test thoroughly: `docker compose down && docker compose build --no-cache && docker compose up -d`
5. Commit your changes: `git commit -m "Description"`
6. Push to your fork: `git push origin feature-name`
7. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Attribution

This project is based on [dhitchenor/hubzilla](https://github.com/dhitchenor/hubzilla), also licensed under the MIT License.

## Support

If you encounter issues:

1. Check this README for troubleshooting steps
2. Review container logs: `docker compose logs`
3. Ensure you're using the latest version: `git pull`
4. Try a complete cleanup and fresh start
5. Open an issue with detailed logs and steps to reproduce
