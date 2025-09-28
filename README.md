# Hubzilla Local Development

A fully containerized Hubzilla setup for local development with HTTPS support.

## Features

- **HTTPS with valid certificates** - Uses mkcert for browser-trusted localhost certificates
- **PostgreSQL database** - Persistent data storage
- **localhost domain** - Should work locally on any machine without DNS configuration

## Disclaimer

This project was developed with AI assistance and is provided "as-is" without warranty. Please research any commands before running them. This code is in early development, may contain bugs, and is intended for local development and testing only. **Not for production use.**

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Git
- mkcert (for SSL certificates)


### 1. SSL Setup
```bash
# Linux/WSL
sudo apt install mkcert

# macOS  
brew install mkcert

# Windows: Download from https://github.com/FiloSottile/mkcert/releases
# NOTE: For Windows+WSL2, install mkcert on Windows host (not WSL2)
# This ensures mkcert -install adds the CA to Windows certificate store

# Initialize (one-time setup) - MUST run as Administrator
mkcert -install
# Confirms popup to add CA to Windows certificate store

# If automatic installation fails in Windows, manually add certificate:
# 1. Press Win+R → type 'mmc' → Add Certificates snap-in → Computer account
# 2. Navigate: Trusted Root Certification Authorities → Certificates
# 3. Right-click → All Tasks → Import → Select rootCA.pem from mkcert -CAROOT path
```

### 2. Clone and Configure
```bash
git clone https://github.com/Chattanooga-Digital-Dev/hubzilla.git
cd hubzilla
cp .env.example .env
```

**Edit .env file:**
1. Find your mkcert path: `mkcert -CAROOT`
2. Set `MKCERT_PATH` in .env to that exact path

**Common paths:**
- Linux/WSL: `MKCERT_PATH=~/.local/share/mkcert`
- macOS: `MKCERT_PATH=~/Library/Application Support/mkcert`
- Windows+WSL2: `MKCERT_PATH=/mnt/c/Users/USERNAME/AppData/Local/mkcert`

### 3. Build and Start
```bash
docker compose build --no-cache
docker compose up -d

# Monitor startup (optional)
docker logs -f hubzilla_itself
# Exit with Ctrl+C when you see "Starting php-fpm"
```

### 4. Complete Setup
1. **Open setup wizard:** https://localhost

2. **Database configuration (Step 2):**
   ```
   Database Server Name: hub_db
   Database Port: 5432
   Database Login Name: hubzilla
   Database Login Password: P@55w0rD
   Database Name: hub
   Database Type: PostgreSQL
   ```

3. **Create admin account (Step 3):** 
- Use admin@example.com for the email address

4. **Complete remaining steps** in the wizard

### 5. Access Your Site
Your Hubzilla instance: **https://localhost**

## Container Overview

| Service | Purpose | Port |
|---------|---------|------|
| `hub` | Hubzilla PHP application | - |
| `hub_web` | Nginx reverse proxy | 443 |
| `hub_db` | PostgreSQL database | 5432 |
| `hub_cron` | Background tasks | - |
| `stalwart` | Local mail server | 8080 |

## Development Commands

```bash
# View logs
docker compose logs
docker logs -f hubzilla_itself

# Access containers
docker exec -it hubzilla_itself bash
docker exec -it hubzilla_database psql -U hubzilla -d hub

# Restart services
docker compose restart

# Stop everything
docker compose down
```

## Email Verification

**Option 1:** Configure the included Stalwart mail server and Thunderbird email application 
- (see [docs/EMAIL_CONFIG.md](docs/EMAIL_CONFIG.md)) for instructions

**Option 2:** Manual verification
```bash
# Get verification token
docker exec hubzilla_itself sh -c 'PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT reg_hash FROM register WHERE reg_email='\''your-email@example.com'\'';"'

# Visit: https://localhost/register/verify/YOUR_TOKEN_HERE
```

## Troubleshooting

**Containers won't start:**
```bash
docker compose ps
docker compose logs
```

**Database connection errors:**
```bash
# Wait 30-60s for database initialization on first start
docker logs hubzilla_database
```

**Reset everything:**
```bash
docker compose down
docker volume rm hubzilla_db_data hubzilla_web_root hubzilla_ssl_certs hubzilla_nginx_config
docker compose up -d
```

## Documentation

- [SSL Setup Details](docs/SSL_SETUP.md) - Complete mkcert configuration
- [Email Configuration](docs/EMAIL_CONFIG.md) - Stalwart mail server setup
- [Environment Variables](docs/ENVIRONMENT.md) - Complete .env reference
- [Development Guide](docs/DEVELOPMENT.md) - Advanced commands and debugging
- [Email-to-Calendar](docs/EMAIL_CALENDAR.md) - Calendar processing features

## Production Warning

This setup is for local development only. For production deployment suggestions, see [docs/PRODUCTION.md](docs/PRODUCTION.md).

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Test changes: `docker compose down && docker compose build --no-cache && docker compose up -d`
4. Commit: `git commit -m "Description"`
5. Submit pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

Based on [dhitchenor/hubzilla](https://github.com/dhitchenor/hubzilla).
