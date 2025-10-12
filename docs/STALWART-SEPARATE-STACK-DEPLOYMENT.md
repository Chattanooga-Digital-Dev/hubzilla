# Stalwart Mail Stack Deployment Guide

**Date:** October 12, 2025  
**Purpose:** Deploy Stalwart mail server as a separate stack in staging environments

---

## Overview

The Stalwart mail server has been separated into its own Docker Swarm stack (`docker-stack-stalwart.yml`) to enable independent deployment and management in staging/production environments.

**Key Changes:**
- Stalwart runs in a separate `mail` stack
- Service name: `mail_stalwart` (stack + service naming)
- Hubzilla connects via `SMTP_HOST=mail_stalwart`
- Shares `traefik_net` network for connectivity
- Uses same Docker secrets as before

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

### Issue: Stalwart Fails with "DB_PASSWORD secret not found"

**Symptoms:**
- Stalwart container exits immediately
- Logs show: `ERROR: DB_PASSWORD secret not found`

**Solution:**
This was the original issue that's now fixed. If you still see this:
1. Ensure you're using the updated `load-secrets.sh` script
2. Verify you're deploying from the latest `staging` branch
3. The fix makes DB_PASSWORD optional for services without DB_USER

### Issue: Cannot Access Stalwart Web UI

**Symptoms:**
- `https://mail.staging.chatthub.online` returns 404 or timeout

**Solution:**
1. Verify Stalwart is on `traefik_net`: **Networks → traefik_net**
2. Check Traefik labels on mail_stalwart service
3. Verify DNS points `mail.staging.chatthub.online` to server IP

---

## Rollback Procedure

If you need to rollback to the integrated deployment:

1. **Stop mail stack:**
   - Portainer: **Stacks → mail → Stop Stack**

2. **Revert hubzilla stack to old version:**
   - Use git to checkout previous commit
   - Redeploy with old `docker-stack.yml`

3. **Update .env:**
   ```bash
   SMTP_HOST=stalwart  # (old integrated name)
   ```

---

## File Changes Summary

### Modified Files
1. **scripts/load-secrets.sh** - Made DB_PASSWORD check conditional
2. **docker-stack.yml** - Removed Stalwart and cert_extractor services
3. **.env** - Changed `SMTP_HOST=mail_stalwart`
4. **.env.staging.example** - Changed `SMTP_HOST=mail_stalwart`

### New Files
1. **docker-stack-stalwart.yml** - Separate mail server stack

### Unchanged Files
- **docker-compose.yml** - Local development still has integrated Stalwart
- **stalwart-config/config.toml** - No changes needed
- **scripts/stalwart-entrypoint.sh** - No changes needed

---

## Benefits of Separate Stack

1. **Independent Scaling** - Scale mail services without affecting Hubzilla
2. **Isolated Updates** - Update mail stack without touching Hubzilla
3. **Clearer Portainer UI** - Separate stacks in different sections
4. **Easier Troubleshooting** - Isolated logs and metrics per stack
5. **Resource Management** - Set different resource limits per stack

---

## Next Steps

After successful deployment:

1. **Test Email Sending:**
   - Register new user on Hubzilla
   - Verify registration email is sent

2. **Test Email Receiving:**
   - Send email to `admin@staging.chatthub.online`
   - Verify it appears in Stalwart

3. **Monitor Logs:**
   - Watch for connection issues between hub and mail_stalwart
   - Check SSL certificate renewal

4. **Document Production Deployment:**
   - Same process for `portainer.staging.chattanooga.digital`
   - Update environment variables for that domain

---

## Related Documentation

- [Staging Deployment Guide](./STAGING-DEPLOYMENT-chattanooga-digital.md)
- [Oracle Cloud Swarm Setup](./ORACLE-CLOUD-SWARM-SETUP.md)
- Main [README.md](../README.md)

---

## Support

If issues persist:
1. Check service logs in Portainer
2. Verify network connectivity with `nslookup` and `telnet`
3. Review Traefik dashboard at port 8080
4. Ensure all Docker secrets are properly created
