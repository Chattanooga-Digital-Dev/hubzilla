# Hubzilla Local Development with Docker

A fully containerized Hubzilla setup for local development with HTTPS support using mkcert-generated certificates.

## Features

- 🔒 **HTTPS with valid certificates** - Uses mkcert for browser-trusted localhost certificates
- 🐘 **PostgreSQL database** - Persistent data storage
- 📦 **All Docker volumes** - No bind mounts, fully portable
- 🚫 **No email verification** - Simplified local development
- 🌐 **localhost domain** - Works on any machine without DNS configuration

## Quick Start

1. **Clone and start containers:**
   ```bash
   git clone <your-repo-url>
   cd hubzilla
   docker-compose up -d
   ```

2. **Setup SSL certificates (one-time):**
   ```bash
   chmod +x setup-ssl.sh
   ./setup-ssl.sh
   ```

3. **Visit your site:**
   ```
   https://localhost
   ```

## Detailed Setup

### Prerequisites

- Docker & Docker Compose
- Git

### Step-by-Step Installation

1. **Start the containers:**
   ```bash
   docker-compose up -d
   ```
   
   This will:
   - Pull required Docker images
   - Start PostgreSQL database
   - Generate SSL certificates automatically
   - Start Hubzilla and nginx

2. **Install the CA certificate:**
   
   Run the setup script:
   ```bash
   ./setup-ssl.sh
   ```
   
   Follow the OS-specific instructions provided by the script.

3. **Access Hubzilla:**
   - Open browser and go to: `https://localhost`
   - You should see a green lock indicating a secure connection
   - Complete the Hubzilla setup wizard

### Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Browser       │────│   nginx (SSL)    │────│   Hubzilla      │
│   (Windows)     │    │   localhost:443  │    │   PHP-FPM       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                │                ┌───────┴─────────┐
                                │                │   PostgreSQL    │
                                │                │   Database      │
                                │                └─────────────────┘
                                │
                        ┌───────┴────────┐
                        │   Docker       │
                        │   Volumes      │
                        │   (Persistent) │
                        └────────────────┘
```

## Docker Volumes

All data is stored in Docker volumes for portability:

- `db_data` - PostgreSQL database
- `web_root` - Hubzilla application files
- `ssl_certs` - SSL certificates (shared between containers)
- `nginx_config` - Nginx site configuration

## Configuration

### Environment Variables (.env)

Key settings for local development:

```bash
DOMAIN=localhost
REQUIRE_EMAIL=0           # No email verification needed
DB_TYPE=postgres
DB_HOST=hub_db
# ... other settings
```

### SSL Certificates

- Automatically generated using mkcert during container startup
- Valid for: localhost, 127.0.0.1, ::1
- Stored in `ssl_certs` Docker volume
- Persist across container restarts

## Troubleshooting

### Certificate Issues

**Problem:** Browser shows "Not Secure" warning
**Solution:** 
1. Ensure you ran `./setup-ssl.sh` and followed the OS-specific instructions
2. Restart your browser completely
3. Try `https://127.0.0.1` instead of `https://localhost`

### Container Issues

**Problem:** Containers fail to start
**Solution:**
```bash
# Check logs
docker-compose logs

# Restart clean
docker-compose down
docker-compose up -d
```

**Problem:** Database connection errors
**Solution:**
```bash
# Wait for database to be ready (can take 30-60 seconds on first start)
docker-compose logs hub_db

# Check database health
docker-compose ps
```

### WSL/Windows Specific

**Problem:** Certificate not working in Windows browser
**Solution:**
1. The certificate needs to be installed on Windows, not just WSL
2. Copy `./ssl-host/rootCA.pem` to Windows
3. Install it in Windows certificate store
4. Restart browser

## Development

### Accessing Containers

```bash
# Hubzilla container
docker exec -it hubzilla_itself bash

# Database container
docker exec -it hubzilla_database psql -U hubzilla -d hub

# nginx container
docker exec -it hubzilla_webserver sh
```

### Logs

```bash
# All containers
docker-compose logs

# Specific container
docker-compose logs hub
docker-compose logs hub_db
docker-compose logs hub_web
```

### Database Access

Connect to PostgreSQL:
```bash
docker exec -it hubzilla_database psql -U hubzilla -d hub
```

## Cleaning Up

To completely remove everything:

```bash
# Stop and remove containers
docker-compose down

# Remove volumes (WARNING: This deletes all data)
docker-compose down -v

# Remove SSL certificate from system (optional)
# Follow OS-specific instructions to remove from certificate store
```

## Production Notes

⚠️ **This setup is for local development only!**

For production:
- Use real SSL certificates (Let's Encrypt, etc.)
- Configure proper domain names
- Enable email verification
- Review security settings
- Use external database
- Configure backups

## Contributing

1. Fork the repository
2. Make changes
3. Test with `docker-compose up -d`
4. Submit pull request

## License

[License information here]
