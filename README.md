# Hubzilla Local Development with Docker

A fully containerized Hubzilla setup for local development with HTTPS support and automated SSL certificate generation.

## Features

- **HTTPS with valid certificates** - Uses mkcert for browser-trusted localhost certificates
- **PostgreSQL database** - Persistent data storage with health checks
- **All Docker volumes** - No bind mounts, fully portable setup
- **No email verification** - Simplified local development workflow
- **localhost domain** - Works on any machine without DNS configuration
- **URL rewrite testing** - Internal HTTP forwarding for setup wizard validation
- **Automated setup** - SSL generation, database initialization, and configuration

## Disclaimer

This guide was developed with AI assistance and is provided "as-is" without warranty. Please research any commands before running them. This code is in early development, may contain bugs, and is intended for local development and testing only. **Not for production use.**

## Prerequisites

- Docker & Docker Compose
- Git

## Quick Start for Developers

### 1. Clone and Configure

```bash
git clone <your-repo-url>
cd hubzilla
```

### 2. Build and Start Containers

```bash
# Build containers from scratch and start all services
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
   ```

3. **Create Administrator Account (Step 3):**
   - Fill in your desired admin credentials
   - Use any email address (verification bypassed for local development)

4. **Complete the remaining setup steps** following the wizard

Since email is disabled for local development, manually verify your account:

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

## Docker Volumes

All data is stored in Docker volumes for portability:

- `hubzilla_db_data` - PostgreSQL database files
- `hubzilla_web_root` - Hubzilla application files
- `hubzilla_ssl_certs` - SSL certificates (shared between containers)
- `hubzilla_nginx_config` - Nginx site configuration

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

# Regenerate certificates (if needed)
docker exec hubzilla_itself mkcert -key-file /var/ssl-shared/localhost-key.pem -cert-file /var/ssl-shared/localhost.pem localhost 127.0.0.1 ::1
```

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

## Configuration Files

### Environment Variables (.env)

Key settings for local development:

```bash
# Site Configuration
DOMAIN=localhost
SITE_NAME=My Cool Site
ADMIN_EMAIL=example@gmail.com
REQUIRE_EMAIL=0           # Disables email verification

# Database Configuration
DB_TYPE=postgres
DB_HOST=hub_db
DB_NAME=hub
DB_USER=hubzilla
DB_PASSWORD=P@55w0rD
DB_PORT=5432

# PostgreSQL Container Variables
POSTGRES_PASSWORD=P@55w0rD
POSTGRES_USER=hubzilla
POSTGRES_DB=hub
```

### Docker Compose Services

- `hub_db` (PostgreSQL) - Database service with health checks
- `hub` (Hubzilla) - Main application with PHP-FPM
- `hub_web` (Nginx) - Reverse proxy with SSL termination
- `hub_cron` (Cron) - Background task processing

## Troubleshooting

### Common Issues

**Problem:** "Database install failed" during setup wizard
**Solution:** This was a known issue that has been fixed. Ensure you're using the latest version of the project.

**Problem:** Containers fail to start
**Solution:**
```bash
# Check container status
docker compose ps

# View detailed logs
docker compose logs

# Restart with fresh build
docker compose down
docker compose build --no-cache
docker compose up -d
```

**Problem:** "Connection refused" errors
**Solution:**
```bash
# Wait for database initialization (first start takes 30-60 seconds)
docker logs hubzilla_database

# Check network connectivity
docker exec hubzilla_itself ping hub_db
```

**Problem:** SSL certificate errors in browser
**Solution:**
```bash
# Simply accept the certificate in your browser
# Click "Advanced" -> "Accept Risk and Continue" when visiting https://localhost
# This is normal for local development with self-signed certificates
```

**Problem:** URL rewrite test fails in setup wizard
**Solution:** This has been resolved with socat-based HTTP forwarding. Ensure containers are fully started.

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

## Development Workflow

### Making Changes

1. **Code Changes:** Edit files and rebuild containers
   ```bash
   docker compose build --no-cache
   docker compose up -d --force-recreate
   ```

2. **Database Changes:** Access PostgreSQL directly
   ```bash
   docker exec -it hubzilla_database psql -U hubzilla -d hub
   ```

3. **Configuration Changes:** Edit `.env` and restart
   ```bash
   docker compose down
   docker compose up -d
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
- Use external PostgreSQL database for scalability
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
