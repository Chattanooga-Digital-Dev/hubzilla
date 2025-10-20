# Hubzilla Stack Deployment Guide (Staging)

Deploy the Hubzilla application stack to Docker Swarm using Portainer with a Traefik reverse proxy.

**Deployment Target:** https://hubzilla.staging.chattanooga.digital  
**Server Access:** Portainer only (no SSH access)

---

## Overview

This guide covers deploying the main Hubzilla application stack. It assumes you have already deployed the separate [Stalwart Mail Stack](STALWART-SEPARATE-STACK-DEPLOYMENT.md).

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
│  Network: hubzilla_internal (internal)    │
│  Network: traefik_net (hub only)          │
└────────────────────────────────────────────┘
```

### Network Details

**traefik_net** (External, 10.0.1.0/24)
- **Purpose:** External traffic routing and cross-stack communication.
- **Members:** Traefik, Hub, and the Stalwart service from the `mail` stack.
- **Type:** External overlay network (must already exist).

**hubzilla_internal** (Internal)
- **Purpose:** Internal service communication for the Hubzilla stack.
- **Members:** Hub, Hub DB, Hub Cron.
- **Type:** Swarm overlay network (created by the `hubzilla` stack).

---

## Prerequisites

### 1. Stalwart Mail Stack
The Stalwart mail stack must be deployed and running before you proceed. See the [Stalwart Mail Stack Deployment Guide](STALWART-SEPARATE-STACK-DEPLOYMENT.md) for instructions.

### 2. Portainer Access
- Access to a Portainer instance on the target server.
- Permissions to create/update stacks.

### 3. External Networks
The `traefik_net` external overlay network must already exist.

### 4. Docker Secrets
The following three Docker secrets must be created before deployment:

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

---

## Stack Update Procedure

When updating an existing deployment:

1. **Navigate to:** Stacks → hubzilla → Editor

2. Click **Pull and redeploy**

3. Click **Update the stack**

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

### Hubzilla and Stalwart Connectivity Issues

**Symptoms:**
- Hubzilla cannot send emails.
- Logs show errors like `Connection refused` to `mail_stalwart`.

**Solution:**
1.  Ensure the `mail` stack is running and healthy.
2.  Verify that both the `hubzilla_hub` and `mail_stalwart` services are connected to the `traefik_net` network.
3.  From the `hubzilla_hub` container console, test DNS resolution and connectivity:
    ```bash
    # Should resolve to the mail_stalwart container's IP
    nslookup mail_stalwart

    # Should connect successfully
    telnet mail_stalwart 587
    ```
4.  Check the `SMTP_HOST` variable in your `.env` file is set to `mail_stalwart`.

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
