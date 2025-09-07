# Hubzilla Local Development Refactoring - Complete Session Summary

**Date**: September 6, 2025  
**Objective**: Refactor Hubzilla Docker project for portable local development with SSL support  
**Status**: Under Development - troubleshooting needed

## Table of Contents

1. [Initial Problem & Requirements](#initial-problem--requirements)
2. [Key Technical Challenge](#key-technical-challenge)
3. [Solution Discovery](#solution-discovery)
4. [Refactoring Steps](#refactoring-steps)
5. [Current Code State](#current-code-state)
6. [Architecture Changes](#architecture-changes)
7. [User Experience](#user-experience)
8. [Future Troubleshooting Notes](#future-troubleshooting-notes)

## Initial Problem & Requirements

### Original Setup Issues
- **External dependencies**: Used external Traefik network for SSL termination
- **Bind mounts**: Mixed bind mounts (`${LOC_DB}`, `${LOC_NGINXCONF}`) and volumes
- **Hardcoded domain**: `domain.com` instead of localhost
- **Email verification**: Required email verification for registration
- **Not portable**: Users needed to configure local paths and DNS

### Requirements
- ✅ Fully portable - works with just `git clone` + `docker-compose up`
- ✅ Use SSL with browser-valid certificates (Hubzilla requirement)
- ✅ Use PostgreSQL database
- ✅ Disable email verification for local development
- ✅ Work with WSL2/Windows setup
- ✅ Use only Docker volumes (no bind mounts)

## Key Technical Challenge

**Critical Discovery**: Hubzilla explicitly prohibits self-signed certificates.

> From Hubzilla documentation: "You SHOULD use SSL. If you use SSL, you MUST use a 'browser valid' certificate. You CANNOT use self-signed certificates!"

This eliminated typical self-signed certificate approaches and required finding a solution that creates truly "browser-valid" certificates for localhost development.

## Solution Discovery

**mkcert**: The breakthrough solution that creates locally-trusted certificates:

- Creates a local Certificate Authority (CA) on the development machine
- Generates certificates **signed by this trusted CA** (not self-signed!)
- Browsers treat these as valid because they trust the local CA
- Perfect for localhost development while meeting Hubzilla's "browser-valid" requirement

## Refactoring Steps

### Step 1: Update docker-compose.yml
**Files modified**: `docker-compose.yml`

**Changes**:
- ❌ **Removed**: External `public` network dependency (Traefik)
- ❌ **Removed**: All Traefik labels and configuration
- ✅ **Added**: Direct port exposure (`80:80`, `443:443`)
- ✅ **Converted**: `${LOC_DB}` bind mount → `db_data` volume
- ✅ **Converted**: `${LOC_NGINXCONF}` bind mount → `nginx_config` volume
- ✅ **Added**: `ssl_certs` volume for certificate sharing
- ✅ **Simplified**: Single `hubzilla` network instead of external dependencies

**Git Commit**: `"Step 1: Convert to all-volumes, remove Traefik, add SSL ports"`

### Step 2: Update Dockerfile
**Files modified**: `Dockerfile`

**Changes**:
- ✅ **Added**: `curl` and `wget` packages
- ✅ **Added**: mkcert binary download and installation
```dockerfile
&& wget -O /usr/local/bin/mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64 \
&& chmod +x /usr/local/bin/mkcert
```

**Git Commit**: `"Step 2: Add mkcert installation to Dockerfile"`

### Step 3: Update entrypoint.sh
**Files modified**: `entrypoint.sh`, `docker-compose.yml`

**Changes**:
- ✅ **Added**: SSL certificate generation logic with persistence check
- ✅ **Added**: Shared volume mounting for certificate access
- ✅ **Generated**: Certificates for `localhost`, `127.0.0.1`, `::1`
- ✅ **Implemented**: Proper permissions and ownership

**Key Logic**:
```bash
# Generate SSL certificates if they don't exist
if [ ! -f "/var/ssl-shared/localhost.pem" ] || [ ! -f "/var/ssl-shared/localhost-key.pem" ]; then
    echo "======== GENERATING: SSL certificates ========"
    mkdir -p /var/ssl-shared
    mkcert -install
    mkcert -key-file /var/ssl-shared/localhost-key.pem -cert-file /var/ssl-shared/localhost.pem localhost 127.0.0.1 ::1
    chmod 644 /var/ssl-shared/*.pem
    echo "======== SUCCESS: SSL certificates generated ========"
else
    echo "======== SSL certificates already exist, skipping generation ========"
fi
```

**Git Commit**: `"Step 3: Add SSL certificate generation with shared volume"`

### Step 4: Update nginx.conf → default.conf
**Files modified**: `config/nginx.conf` → `config/default.conf`, `entrypoint.sh`

**Changes**:
- ✅ **Restructured**: Full nginx.conf → site-specific configuration
- ✅ **Renamed**: `nginx.conf` → `default.conf` (site configuration)
- ✅ **Updated**: `server_name domain.com` → `server_name localhost`
- ✅ **Added**: SSL server block with HTTPS termination
- ✅ **Added**: HTTP → HTTPS redirect
- ✅ **Added**: Volume-based configuration copying

**SSL Configuration**:
```nginx
server {
    listen 443 ssl http2;
    server_name localhost;
    
    ssl_certificate /etc/nginx/ssl/localhost.pem;
    ssl_certificate_key /etc/nginx/ssl/localhost-key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    # ... rest of SSL config
}
```

**Git Commit**: `"Step 4: Update nginx config for localhost SSL termination"`

### Step 5: Update .env
**Files modified**: `.env`

**Changes**:
- ✅ **Updated**: `DOMAIN=domain.com` → `DOMAIN=localhost`
- ✅ **Updated**: `REQUIRE_EMAIL=1` → `REQUIRE_EMAIL=0`
- ❌ **Removed**: `LOC_NGINXCONF=./config/nginx.conf`
- ❌ **Removed**: `LOC_DB=./db`
- ✅ **Simplified**: Comments and documentation

**Git Commit**: `"Step 5: Update .env for localhost, disable email verification, remove bind mount variables"`

### Step 6: Create Documentation & Scripts
**Files created**: `README.md`, `setup-ssl.sh`, `test-setup.sh`, updated `block.github/README.md`

**Changes**:
- ✅ **Created**: Comprehensive setup documentation
- ✅ **Created**: Automated SSL setup script with OS-specific instructions
- ✅ **Created**: Test validation script
- ✅ **Updated**: Project README to highlight local development focus

**Git Commit**: `"Step 6: Add user setup documentation and test scripts"`

## Current Code State

### File Structure
```
hubzilla/
├── README.md                 # Comprehensive setup guide
├── docker-compose.yml        # All-volumes configuration
├── Dockerfile                # Includes mkcert installation
├── entrypoint.sh             # SSL generation + nginx config copying
├── .env                      # Localhost configuration
├── setup-ssl.sh              # User SSL setup script
├── test-setup.sh             # Validation script
├── config/
│   └── default.conf          # nginx site configuration (localhost + SSL)
└── block.github/
    └── README.md             # Updated with local dev info
```

### Docker Architecture
```yaml
# docker-compose.yml structure
services:
  hub_db:          # PostgreSQL with db_data volume
  hub_web:         # nginx with SSL termination, ports 80/443
  hub:             # Hubzilla with SSL cert generation
  hub_cron:        # Hubzilla cron jobs

volumes:
  db_data:         # PostgreSQL data
  web_root:        # Hubzilla files
  ssl_certs:       # SSL certificates (shared)
  nginx_config:    # nginx configuration (shared)

networks:
  hubzilla:        # Internal network only
```

### Certificate Flow
1. **Generation**: Hubzilla container generates mkcert certificates on first startup
2. **Storage**: Certificates stored in `ssl_certs` Docker volume
3. **Sharing**: Volume mounted to both Hubzilla (`/var/ssl-shared`) and nginx (`/etc/nginx/ssl`)
4. **Persistence**: Certificates persist across container restarts
5. **Validation**: Only generated if they don't already exist

## Architecture Changes

### Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| **SSL** | External Traefik + Let's Encrypt | mkcert + nginx SSL termination |
| **Storage** | Mixed bind mounts + volumes | All Docker volumes |
| **Domain** | domain.com | localhost |
| **Portability** | Required local configuration | Git clone + docker-compose up |
| **Dependencies** | External Traefik network | Self-contained |
| **Email** | Required verification | Disabled for local dev |

### Network Flow
```
Browser (Windows) 
    ↓ https://localhost
nginx container (SSL termination)
    ↓ http://hub:9000 (internal)
Hubzilla container (PHP-FPM)
    ↓ 
PostgreSQL container
```

## User Experience

### Current Workflow
```bash
# 1. Clone and start
git clone <repo>
cd hubzilla
docker-compose up -d

# 2. Setup SSL (one-time)
./setup-ssl.sh
# Follow OS-specific instructions to install CA

# 3. Access
# Visit: https://localhost (green lock!)
```

### What Happens Automatically
1. **Container startup**: All containers start with proper dependencies
2. **Certificate generation**: mkcert creates localhost certificates if needed
3. **Configuration copying**: nginx gets proper SSL configuration
4. **Database initialization**: PostgreSQL creates Hubzilla schema if needed
5. **Volume persistence**: All data persists across restarts

## Future Troubleshooting Notes

### Common Issues & Solutions

**Issue**: Browser shows "Not Secure" despite setup
**Solution**: 
- Ensure CA certificate properly installed on host OS (not just WSL)
- Restart browser completely after certificate installation
- Try `https://127.0.0.1` instead of `https://localhost`

**Issue**: Containers fail to start
**Solution**:
```bash
# Check logs
docker-compose logs

# Clean restart
docker-compose down && docker-compose up -d
```

**Issue**: SSL certificates not generated
**Solution**:
- Check container logs: `docker-compose logs hub`
- Verify mkcert installation: `docker exec hubzilla_itself mkcert --version`
- Check certificate location: `docker exec hubzilla_itself ls -la /var/ssl-shared/`

**Issue**: nginx configuration not loading
**Solution**:
- Check config copy: `docker exec hubzilla_webserver ls -la /etc/nginx/conf.d/`
- Verify nginx syntax: `docker exec hubzilla_webserver nginx -t`

### Key Technical Details

**Certificate Storage**: 
- Generated in: `/var/ssl-shared/` (Hubzilla container)
- Accessed by: `/etc/nginx/ssl/` (nginx container)
- Volume: `ssl_certs`

**nginx Configuration**:
- Copied from: `/var/www/html/config/default.conf` (Hubzilla container)
- Loaded from: `/etc/nginx/conf.d/default.conf` (nginx container)
- Volume: `nginx_config`

**Database**:
- Type: PostgreSQL 16-alpine
- Volume: `db_data`
- Access: `docker exec -it hubzilla_database psql -U hubzilla -d hub`

### WSL/Windows Specific Notes

**Certificate Installation**: The CA certificate must be installed on Windows (not just WSL) for browsers running on Windows to trust it.

**Volume Performance**: Docker volumes perform better than bind mounts in WSL2 environment.

**Networking**: nginx container exposes ports 80/443 directly, accessible from Windows via localhost.

### Validation Commands
```bash
# Test complete setup
./test-setup.sh

# Check individual components
docker-compose ps                              # Container status
docker-compose logs hub                        # Hubzilla logs
docker exec hubzilla_itself mkcert --version   # mkcert availability
docker exec hubzilla_webserver nginx -t        # nginx config test
```

This document serves as a complete reference for understanding the refactoring process and current system state for future maintenance and troubleshooting.
