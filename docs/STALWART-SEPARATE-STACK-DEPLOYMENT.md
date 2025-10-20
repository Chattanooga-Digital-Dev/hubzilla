# Stalwart Mail Stack Deployment Guide

**Purpose:** Deploy Stalwart mail server as a separate stack in staging environments

---

## Overview

This guide details the deployment of the Stalwart mail server as a standalone Docker Swarm stack. Separating the mail server from the main Hubzilla application provides better isolation, scalability, and easier management.

This stack should be deployed **before** the main [Hubzilla Stack](HUBZILLA-STAGING_DEPLOYMENT.md).

### Key Features
- **Independent Deployment:** Manage and update the mail server without affecting the Hubzilla application.
- **Automated SSL:** A dedicated service extracts SSL certificates from Traefik and provides them to Stalwart.
- **Cross-Stack Communication:** Securely communicates with the Hubzilla stack over a shared Docker network.

---

## Architecture

```
┌────── traefik_net (10.0.1.0/24) ──────────┐
│                                            │
│  ┌──────────┐     External Traffic        │
│  │ Traefik  │◄────── Port 80/443          │
│  └─────┬────┘                              │
│        │                                   │
│        ├──────────────┐                    │
│        │              │                    │
└────────┼──────────────┼────────────────────┘
         │              │
         │              │
┌────────┼──────────────┼────────────────────┐
│ Stack: hubzilla       │                    │
│        │              │                    │
│  ┌─────▼─────┐    ┌──▼────────┐           │
│  │    Hub    │    │  Hub DB   │           │
│  │  (nginx)  │    │(postgres) │           │
│  └─────┬─────┘    └───────────┘           │
│        │                                   │
│  Network: hubzilla_internal (internal)    │
│  Network: traefik_net (hub only)          │
└────────┼───────────────────────────────────┘
         │
         │ SMTP (port 587)
         │
┌────────┼───────────────────────────────────┐
│ Stack: mail           │                    │
│        │              │                    │
│  ┌─────▼──────────┐   ┌──────────────┐    │
│  │  mail_stalwart │   │cert_extractor│    │
│  │   (Stalwart)   │◄──┤  (traefik    │    │
│  │                │   │   certs)     │    │
│  └────────────────┘   └──────────────┘    │
│                                            │
│  Network: mailserver_internal (internal)  │
│  Network: traefik_net (stalwart only)     │
└────────────────────────────────────────────┘
```

---

## Prerequisites

### 1. External Networks Must Exist
- `traefik_net` - Created and Traefik connected to it

### 2. Docker Secrets Must Be Created
These should already exist from your previous deployment:
- `hubzilla_db_password` - PostgreSQL database password
- `hubzilla_smtp_password` - SMTP authentication password
- `hubzilla_stalwart_admin_password` - Stalwart admin password

### 3. Environment Variables
Update your `.env` file:
```bash
SMTP_HOST=mail_stalwart
DOMAIN=hubzilla.staging.chatthub.online
SMTP_DOMAIN=staging.chatthub.online
```

---

## SSL Certificate Handling

The Stalwart mail server requires direct access to SSL certificates for secure communication. In this multi-stack deployment, certificates are managed by Traefik and then shared with the Stalwart stack using a dedicated `cert_extractor` service.

### How it Works
1.  **Traefik Certificate Generation:** Traefik, running in its own stack, obtains and manages Let's Encrypt SSL certificates for your domains (e.g., `hubzilla.yourdomain.com`, `mail.yourdomain.com`). These certificates are stored in a Docker volume (e.g., `traefik_certs`).
2.  **`cert_extractor` Service:** The `cert_extractor` service (`ldez/traefik-certs-dumper`) is part of the `mail` stack. It is configured to mount the `traefik_certs` volume (read-only) and copy the relevant SSL certificate files (e.g., `mail.yourdomain.com.json`) to a shared volume accessible by the `mail_stalwart` service.
3.  **`stalwart-entrypoint.sh` Script:** The `mail_stalwart` service uses a custom entrypoint script (`scripts/stalwart-entrypoint.sh`). This script is responsible for:
    *   Waiting for the `cert_extractor` to finish copying the certificates.
    *   Parsing the `.json` certificate file to extract the certificate and private key.
    *   Moving these extracted `.pem` and `.key` files into the specific directory that Stalwart expects (`/opt/stalwart/etc/ssl/`).
    *   Ensuring correct file permissions.
    *   Finally, starting the Stalwart mail server.

This automated process ensures that Stalwart always has the latest, valid SSL certificates without manual intervention.

---

## Deployment Steps

### Step 1: Deploy Mail Stack First

**Via Portainer:**
1. Navigate to **Stacks → Add Stack**
2. Name: `mail`
3. Build method: **Git Repository**
   - Repository URL: `https://github.com/Chattanooga-Digital-Dev/hubzilla`
   - Branch: `staging`
   - Compose path: `docker-stack-stalwart.yml`
4. Environment Variables:
   ```
   DOMAIN=hubzilla.staging.chatthub.online
   SMTP_DOMAIN=staging.chatthub.online
   ```
5. Click **Deploy Stack**

### Step 2: Verify Mail Stack is Running

Check logs for:
```
cert_extractor: Successfully extracted certificates
mail_stalwart: ======== SUCCESS: Stalwart SSL certificates configured ========
mail_stalwart: ======== STARTING: Stalwart Mail Server ========
```

### Step 3: Update Hubzilla Stack

**Via Portainer:**
1. Navigate to **Stacks → hubzilla → Editor**
2. Click **Pull and redeploy**
3. **CRITICAL:** Ensure "Remove volumes" is **UNCHECKED**
4. Optional: Check "Prune services" to clean up old Stalwart service
5. Click **Update**

### Step 4: Verify Connectivity

**Test from hub container console:**
```bash
# Test DNS resolution
nslookup mail_stalwart

# Test SMTP connectivity
telnet mail_stalwart 587
```

Expected output:
```
220 mail.staging.chatthub.online Stalwart SMTP
```

---

## Service Names and DNS

### Service Discovery in Docker Swarm

Docker Swarm automatically creates DNS entries using the pattern:
```
<stack-name>_<service-name>
```

**Examples:**
- Stack: `mail`, Service: `stalwart` → DNS: `mail_stalwart`
- Stack: `hubzilla`, Service: `hub` → DNS: `hubzilla_hub`

### Cross-Stack Communication

Services on the same overlay network (`traefik_net`) can communicate using their full service names:
- Hubzilla hub connects to Stalwart: `mail_stalwart:587`
- Traefik routes to both stacks via `traefik_net`

---

## Troubleshooting

### Issue: mail_stalwart not found

**Symptoms:**
- Hub logs show: `Connection refused to mail_stalwart:587`
- DNS lookup fails for `mail_stalwart`

**Solution:**
1. Verify mail stack is running: **Stacks → mail**
2. Check both stacks are on `traefik_net`: **Networks → traefik_net**
3. Verify service name: **Services** → should see `mail_stalwart`

### Issue: SSL Certificate Errors

**Symptoms:**
- Stalwart logs: `ERROR: SSL certificates not found after 60 seconds`

**Solution:**
1. Verify Traefik has obtained Let's Encrypt certificates
2. Check `traefik_data` volume exists and is accessible
3. Verify cert_extractor is running: **Stacks → mail → cert_extractor**

### Issue: Cannot Access Stalwart Web UI

**Symptoms:**
- `https://mail.staging.chatthub.online` returns 404 or timeout

**Solution:**
1. Verify Stalwart is on `traefik_net`: **Networks → traefik_net**
2. Check Traefik labels on mail_stalwart service
3. Verify DNS points `mail.staging.chatthub.online` to server IP
---

## Benefits of Separate Stack

1. **Independent Scaling** - Scale mail services without affecting Hubzilla
2. **Isolated Updates** - Update mail stack without touching Hubzilla
3. **Clearer Portainer UI** - Separate stacks in different sections
4. **Easier Troubleshooting** - Isolated logs and metrics per stack
5. **Resource Management** - Set different resource limits per stack

---

## Related Documentation

- [Staging Deployment Guide](./STAGING-DEPLOYMENT-chattanooga-digital.md)
- [Oracle Cloud Swarm Setup](./ORACLE-CLOUD-SWARM-SETUP.md)
- Main [README.md](../README.md)

---
