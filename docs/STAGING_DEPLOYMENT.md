# Staging Deployment Guide

Deploy Hubzilla to Docker Swarm using Portainer with Traefik reverse proxy.

**Date:** October 12, 2025  
**Deployment Target:** https://hubzilla.staging.chattanooga.digital  
**Server Access:** Portainer only (no SSH access)

---

## Overview

This guide covers deploying Hubzilla to a Docker Swarm environment via Portainer. The deployment uses a two-network topology where Traefik operates on a dedicated overlay network for external routing, while Hubzilla services communicate internally via a separate overlay network.

### Key Components

- **Docker Swarm Stack** - Orchestrated multi-service deployment
- **Portainer** - Web-based deployment and management interface
- **Traefik** - Reverse proxy with automatic Let's Encrypt SSL
- **Docker Secrets** - Secure password management
- **Two-Network Architecture** - Separated external routing and internal communication

---

## Network Architecture

```
┌────── traefik_net (10.0.1.0/24) ──────────┐
│                                            │
│  ┌──────────┐     External Traffic        │
│  │ Traefik  │◄────── Port 80/443          │
│  └─────┬────┘                              │
│        │                                   │
└────────┼───────────────────────────────────┘
         │
         │ HTTPS/TLS
         │
┌────────┼─── hubzilla services ─────────────┐
│        │                                    │
│  ┌─────▼─────┐    ┌───────────┐           │
│  │    Hub    │◄──►│  Hub DB   │           │
│  │  (nginx)  │    │(postgres) │           │
│  └─────┬─────┘    └───────────┘           │
│        │                                   │
│        │ SMTP                              │
│        │                                   │
│  ┌─────▼─────┐                            │
│  │ Stalwart  │                            │
│  │   Mail    │                            │
│  └───────────┘                            │
│                                            │
│  Network: hubzilla_internal (internal)    │
│  Network: traefik_net (hub & stalwart)    │
└────────────────────────────────────────────┘
```

### Network Details

**traefik_net** (External, 10.0.1.0/24)
- **Purpose:** External traffic routing
- **Members:** Traefik, Hub, Stalwart
- **Type:** External overlay network (must already exist)

**hubzilla_internal** (Internal)
- **Purpose:** Internal service communication
- **Members:** Hub, Hub DB, Hub Cron, Stalwart, Cert Extractor
- **Type:** Swarm overlay network (created by stack)

---

## Prerequisites

### 1. Portainer Access
- Access to Portainer instance on target server
- Permissions to create/update stacks

### 2. External Networks
The following external networks must already exist:
- **traefik_net** - Traefik must be connected to this network

Verify in Portainer: **Networks** → Check for `traefik_net`

### 3. Docker Secrets
Three Docker secrets must be created before deployment:

| Secret Name | Description |
|-------------|-------------|
| `hubzilla_db_password` | PostgreSQL database password |
| `hubzilla_smtp_password` | SMTP authentication password |
| `hubzilla_stalwart_admin_password` | Stalwart mail admin password |

**Create secrets via Portainer:**
1. Navigate to **Secrets** → **Add Secret**
2. Enter secret name (exactly as listed above)
3. Paste password value
4. Click **Create Secret**

Repeat for all three secrets.

### 4. Environment Variables
Required environment variable in stack deployment:
- `DOMAIN` - Your deployment domain (e.g., `hubzilla.staging.chattanooga.digital`)

---

## Deployment Process

### Method 1: Git-Based Stack (Recommended)

1. **In Portainer → Stacks → Add Stack:**
   - **Name:** `hubzilla`
   - **Build method:** Git Repository
   - **Repository URL:** `https://github.com/Chattanooga-Digital-Dev/hubzilla`
   - **Branch:** `staging`
   - **Compose path:** `docker-stack.yml`

2. **Environment Variables:**
   Set the following:
   ```
   DOMAIN=hubzilla.staging.chattanooga.digital
   ```
   All other variables are loaded from the repository's `.env` file.

3. **Click Deploy Stack**

### Method 2: Manual Stack Upload

1. **In Portainer → Stacks → Add Stack:**
   - **Name:** `hubzilla`
   - **Build method:** Web editor
   - Paste contents of `docker-stack.yml`

2. **Environment Variables:**
   Set all required variables from `.env` file manually, including:
   - `DOMAIN`
   - Database configuration
   - SMTP configuration
   - All other environment variables

3. **Click Deploy Stack**

---

## Stack Update Procedure

When updating an existing deployment:

1. **Navigate to:** Stacks → hubzilla → Editor

2. **For Git-based stacks:**
   - Click **Pull and redeploy**

3. **For manual stacks:**
   - Update stack definition in editor
   - Click **Update the stack**

4. **CRITICAL OPTIONS:**
   - ✅ **Prune services** (recommended - removes old service definitions)
   - ❌ **Re-pull images** (only if you updated Docker image versions)
   - ❌ **Remove volumes** (**NEVER CHECK THIS** - will delete all data)

### What Persists During Updates

✅ **Persisted:**
- Database data (`db_data` volume)
- Hubzilla files/uploads (`web_root` volume)
- Mail data (`stalwart_data` volume)
- User accounts and content
- `.htconfig.php` configuration

🔄 **Updated:**
- Network connections
- Service configuration
- Container images (if version changed)

---

## Network Configuration Deep Dive

### The Hairpin NAT Problem

During initial deployment, Hubzilla's setup wizard was unreachable with 504 Gateway Timeout errors. The root cause:

1. Hubzilla performs self-checks by making HTTP/HTTPS requests to its own domain
2. DNS resolved the domain to the external public IP address
3. Container attempted connection via public internet (hairpin NAT)
4. Requests timed out after 60 seconds

### The Solution

Modified `entrypoint.sh` to automatically add the domain to `/etc/hosts` inside the container, pointing to Traefik's internal IP:

```bash
# Point to Traefik's IP so HTTPS requests (port 443) work through reverse proxy
TRAEFIK_IP=$(getent hosts traefik_traefik 2>/dev/null | awk '{print $1}' | head -1)
if [ -z "$TRAEFIK_IP" ]; then
    # Fallback: try to find gateway IP on traefik_net (usually .1 or .3)
    TRAEFIK_IP="10.0.1.3"
    echo "WARNING: Could not resolve traefik_traefik, using fallback IP: $TRAEFIK_IP"
fi
echo "$TRAEFIK_IP ${DOMAIN}" >> /etc/hosts
```

**Why this works:**
- Pointing to `127.0.0.1` wouldn't work (nginx only listens on port 80, not 443)
- HTTPS requests must go through Traefik for SSL termination
- Service discovery (`getent hosts`) automatically finds correct Traefik IP
- Requests loop through reverse proxy properly with valid SSL

### Connecting Services to Traefik

Services must explicitly join `traefik_net` to communicate with Traefik:

```yaml
services:
  hub:
    networks:
      - traefik_net          # For Traefik communication
      - hubzilla_internal    # For DB, cron, mail communication
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.hubzilla.rule=Host(`${DOMAIN}`)"
        - "traefik.http.routers.hubzilla.entrypoints=websecure"
        - "traefik.http.routers.hubzilla.tls=true"
        - "traefik.http.routers.hubzilla.tls.certresolver=le"
        - "traefik.http.services.hubzilla.loadbalancer.server.port=80"
        - "traefik.swarm.network=traefik_net"    # Critical: specifies routing network
```

**Important:** Use `traefik.swarm.network` label (not the deprecated `traefik.docker.network`).

---

## Verification Steps

### 1. Check Service Logs

In Portainer:
1. **Stacks** → **hubzilla** → Select service (e.g., `hubzilla_hub`)
2. Click running container
3. **Logs** tab

**Look for:**
```
======== NETWORK: Added hubzilla.staging.chattanooga.digital -> 10.0.1.x to /etc/hosts ========
```

**Verify IP is NOT the fallback** - should match Traefik's actual IP on traefik_net.

### 2. Verify Network Connectivity

In Portainer:
1. **Networks** → **traefik_net**
2. Confirm `hubzilla_hub` and `hubzilla_stalwart` containers are listed
3. Note their IP addresses

### 3. Test External Access

Open in browser:
- Main site: `https://hubzilla.staging.chattanooga.digital`
- Mail admin: `https://mail.hubzilla.staging.chattanooga.digital`

Should load without 504 Gateway Timeout errors.

### 4. Test Internal Connectivity

From container console in Portainer (`hubzilla_hub` container):

```bash
# Check network interfaces
ip addr show

# Verify Traefik service discovery
getent hosts traefik_traefik
# Should return: 10.0.1.x traefik_traefik

# Check /etc/hosts entry
cat /etc/hosts | grep hubzilla
# Should show: 10.0.1.x hubzilla.staging.chattanooga.digital

# Test HTTPS connection through Traefik
wget -O- --timeout=5 https://hubzilla.staging.chattanooga.digital/ | head -20
# Should return HTML content (not timeout)
```

---

## Retrieving Registration Tokens

When users register with approval required (`REGISTER_POLICY=REGISTER_APPROVE`), admins retrieve tokens to approve accounts.

### Via Portainer Console

1. **Navigate:** Stacks → hubzilla → `hubzilla_hub_db` service
2. Click running container
3. **Console** tab → **Connect**
4. Run query:
   ```bash
   psql -U hubzilla -d hub -x -c "SELECT reg_email, reg_hash FROM register;"
   ```
### Via SSH on the server
docker exec $(docker ps -q -f name=hub_db) psql -U hubzilla -d hub -x -c "SELECT reg_email, reg_hash FROM register;"

5. **Example Output:**
   ```
   -[ RECORD 1 ]------------------------
   reg_email | user@example.com
   reg_hash  | abc123def456...
   ```

6. **Approve Registration:**
   Share URL with user:
   ```
   https://hubzilla.staging.chattanooga.digital/regate/<reg_hash>
   ```

**Notes:**
- `reg_hash` is a unique token per pending registration
- Once user completes registration via link, record is removed from `register` table
- Empty table = no pending registrations

---

## Troubleshooting

### Service Can't Resolve traefik_traefik

**Symptoms:**
- Logs show: `WARNING: Could not resolve traefik_traefik, using fallback IP`
- 504 Gateway Timeout on web access

**Solution:**
1. Verify Traefik is running: **Services** → check `traefik` status
2. Verify networks: **Networks** → **traefik_net** → confirm Traefik and hub are listed
3. Check hub service has both networks in `docker-stack.yml`:
   ```yaml
   networks:
     - traefik_net
     - hubzilla_internal
   ```

### 504 Timeout Still Occurs

**Symptoms:**
- Domain resolves to wrong IP in `/etc/hosts`
- Fallback IP doesn't work

**Solution:**
1. Check actual Traefik IP: **Networks** → **traefik_net** → note Traefik's IP
2. Update fallback IP in `entrypoint.sh` if different from `10.0.1.3`
3. Rebuild image and redeploy:
   ```bash
   docker build -t catmanmatt/hubzilla-pg-nginx:v7 .
   docker push catmanmatt/hubzilla-pg-nginx:v7
   ```
4. Update image version in `docker-stack.yml`
5. Redeploy stack in Portainer

### Stalwart Web UI Not Accessible

**Symptoms:**
- Can't access `https://mail.hubzilla.staging.chattanooga.digital`

**Solution:**
1. Verify Stalwart on traefik_net: **Networks** → **traefik_net**
2. Check Stalwart labels in `docker-stack.yml`:
   ```yaml
   - "traefik.enable=true"
   - "traefik.swarm.network=traefik_net"
   ```
3. Verify port 8080 exposed in Stalwart service
4. Check Stalwart service logs for startup errors

### Database Connection Errors

**Symptoms:**
- Hub service logs show database connection failures

**Solution:**
1. Verify database is running: **Services** → `hubzilla_hub_db`
2. Check database service logs
3. Verify `hubzilla_db_password` secret exists and is correctly named
4. Verify database environment variables in `.env`:
   ```
   DB_HOST=hub_db
   DB_NAME=hub
   DB_USER=hubzilla
   DB_TYPE=postgres
   DB_PORT=5432
   ```

### Missing Docker Secrets

**Symptoms:**
- Service won't start
- Logs show: `secret not found`

**Solution:**
1. **Secrets** → verify all three secrets exist:
   - `hubzilla_db_password`
   - `hubzilla_smtp_password`
   - `hubzilla_stalwart_admin_password`
2. Ensure secret names match exactly (case-sensitive)
3. If missing, create secrets as described in Prerequisites
4. Redeploy stack

---

## Production Readiness Checklist

Before deploying to production:

- [ ] SSL certificates auto-renewing (verify in Traefik logs)
- [ ] Docker secrets properly secured
- [ ] Email delivery tested (SMTP via Stalwart)
- [ ] Registration policy configured (`REGISTER_POLICY` in `.env`)
- [ ] Admin account created and secured
- [ ] Domain DNS pointing to server
- [ ] Firewall rules allow ports: 80, 443, 25, 587, 465, 143, 993
- [ ] Traefik access logs enabled for monitoring

---

## Key Files

- **docker-stack.yml** - Docker Swarm stack definition
- **.env** - Environment variables (non-sensitive)
- **entrypoint.sh** - Container startup script (includes hairpin NAT fix)
- **config/nginx-internal-production.conf** - Nginx configuration
- **stalwart-config/config.toml** - Mail server configuration
- **scripts/load-secrets.sh** - Docker secrets loader
- **scripts/stalwart-entrypoint.sh** - Mail server startup

---

## Additional Resources

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Portainer Documentation](https://docs.portainer.io/)
- [Traefik Swarm Documentation](https://doc.traefik.io/traefik/providers/docker/#docker-swarm-mode)
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)

---