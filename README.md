# Hubzilla Local Development

A fully containerized Hubzilla setup for local development with HTTPS support.

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Git
- mkcert (for SSL certificates)

### 1. SSL Setup
```bash
# Install mkcert
sudo apt install mkcert          # Linux
# brew install mkcert            # macOS

# Initialize (one-time setup)
mkcert -install
```

### 2. Clone and Configure
```bash
git clone https://github.com/Chattanooga-Digital-Dev/hubzilla.git
cd hubzilla
cp .env.example .env
```

**Edit .env file:**
- Set `MKCERT_PATH` to your mkcert directory (run `mkcert -CAROOT` to find it)
- Linux/WSL: `MKCERT_PATH=~/.local/share/mkcert`
- macOS: `MKCERT_PATH=~/Library/Application Support/mkcert`

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

3. **Create admin account (Step 3):** Use any email address

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

**Option 1:** Configure the included Stalwart mail server (see [docs/EMAIL_CONFIG.md](docs/EMAIL_CONFIG.md))

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

This setup is for local development only. For production deployment, see [docs/PRODUCTION.md](docs/PRODUCTION.md).

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Test changes: `docker compose down && docker compose build --no-cache && docker compose up -d`
4. Commit: `git commit -m "Description"`
5. Submit pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

Based on [dhitchenor/hubzilla](https://github.com/dhitchenor/hubzilla).
