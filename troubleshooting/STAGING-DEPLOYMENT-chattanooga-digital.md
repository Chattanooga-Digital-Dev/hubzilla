# Hubzilla Deployment to hubzilla.staging.chattanooga.digital

**Date:** October 12, 2025  
**Deployment Target:** https://hubzilla.staging.chattanooga.digital  
**Server Access:** Portainer only (no SSH access)  
**Network Architecture:** Traefik on dedicated overlay network

---

## Summary

Successfully deployed Hubzilla to the chattanooga.digital staging server after resolving network connectivity issues between Traefik and the Hubzilla hub container. The deployment uses a two-network topology where Traefik operates on its own dedicated overlay network (`traefik_net`) and Hubzilla services communicate internally via `hubzilla_internal`.

---

## Network Architecture

### Final Configuration

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

**traefik_net** (10.0.1.0/24)
- **Purpose:** External traffic routing
- **Members:** Traefik, Hub, Stalwart
- **Type:** External overlay network

**hubzilla_internal** (managed by Docker)
- **Purpose:** Internal service communication
- **Members:** Hub, Hub DB, Hub Cron, Stalwart, Cert Extractor
- **Type:** Swarm overlay network

---

## Issues Encountered and Solutions

### Issue 1: 504 Gateway Timeout (Hairpin NAT Problem)

**Problem:**
- Hubzilla setup wizard was unreachable with nginx 504 Gateway Timeout
- When Hubzilla's PHP code saw its own domain in request headers (`hubzilla.staging.chattanooga.digital`), it attempted to make outbound HTTP requests to itself for self-checks
- DNS resolved the domain to the external IP address, causing the container to attempt connection via the public internet
- This created a "hairpin NAT" scenario that timed out after 60 seconds

**Root Cause:**
Hubzilla performs self-checks during setup and operation by making HTTP/HTTPS requests to its own domain. Without internal DNS resolution, these requests route through the external IP causing timeouts.

**Solution Implemented:**
Modified `entrypoint.sh` to automatically add the domain to `/etc/hosts` inside the container, pointing it to Traefik's internal IP address.

```bash
# In entrypoint.sh (lines ~17-27)
# Point to Traefik's IP so HTTPS requests (port 443) work properly through the reverse proxy
TRAEFIK_IP=$(getent hosts traefik_traefik 2>/dev/null | awk '{print $1}' | head -1)
if [ -z "$TRAEFIK_IP" ]; then
    # Fallback: try to find gateway IP on traefik_net (usually .1 or .3)
    TRAEFIK_IP="10.0.1.3"
    echo "======== WARNING: Could not resolve traefik_traefik, using fallback IP: $TRAEFIK_IP ========"
fi
echo "$TRAEFIK_IP ${DOMAIN}" >> /etc/hosts
echo "======== NETWORK: Added ${DOMAIN} -> ${TRAEFIK_IP} to /etc/hosts ========"
```

**Why this approach:**
- Pointing to `127.0.0.1` wouldn't work because nginx only listens on port 80, not 443
- HTTPS requests need to go through Traefik for SSL termination
- By pointing to Traefik's internal IP, requests loop through the reverse proxy properly
- Service discovery (`getent hosts traefik_traefik`) automatically finds the correct IP

---

### Issue 2: Network Connectivity Between Traefik and Hubzilla

**Problem:**
- Initial deployment attempt failed with the same 504 timeout
- Container logs showed: `WARNING: Could not resolve traefik_traefik, using fallback IP: 10.0.1.3`
- Investigation revealed the hub container couldn't communicate with Traefik
- Traefik was on a dedicated network (`traefik_net`) that Hubzilla wasn't connected to

**Root Cause:**
The server uses a dedicated network topology where Traefik operates on its own overlay network. Services need to explicitly join `traefik_net` to communicate with Traefik.

**Solution Implemented:**
Modified `docker-stack.yml` to connect hub and stalwart services to both `traefik_net` and `hubzilla_internal`:

```yaml
networks:
  traefik_net:
    external: true
  hubzilla_internal:
    driver: overlay
    attachable: true

services:
  hub:
    # ... other configuration ...
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
        - "traefik.swarm.network=traefik_net"    # Specifies which network Traefik should use

  stalwart:
    # ... other configuration ...
    networks:
      - traefik_net          # For web UI access via Traefik
      - hubzilla_internal    # For SMTP communication with hub
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.stalwart.rule=Host(`mail.${DOMAIN}`)"
        - "traefik.http.routers.stalwart.entrypoints=websecure"
        - "traefik.http.routers.stalwart.tls=true"
        - "traefik.http.routers.stalwart.tls.certresolver=le"
        - "traefik.http.services.stalwart.loadbalancer.server.port=8080"
        - "traefik.swarm.network=traefik_net"    # Specifies which network Traefik should use
```

**Result:**
- Hub and Stalwart can communicate with Traefik on `traefik_net`
- Internal services communicate on `hubzilla_internal`
- DNS service discovery works: `getent hosts traefik_traefik` resolves correctly
- Hairpin NAT fix works: domain routes through Traefik's actual IP
- Deprecated `traefik.docker.network` label replaced with `traefik.swarm.network`

---

## Files Modified

### 1. `entrypoint.sh`
**Changes:**
- Added automatic detection of Traefik IP via service discovery (`getent hosts traefik_traefik`)
- Added domain to `/etc/hosts` pointing to detected Traefik IP
- Included fallback IP (10.0.1.3) for scenarios where service discovery fails

**Impact:** 
- Resolves hairpin NAT timeout issues
- Enables Hubzilla setup wizard and self-checks to function properly
- Automatic - no manual configuration needed per deployment

### 2. `docker-stack.yml`
**Changes:**
- Defined `traefik_net` as external network
- Connected `hub` service to `traefik_net` + `hubzilla_internal`
- Connected `stalwart` service to `traefik_net` + `hubzilla_internal`
- Updated Traefik labels from `traefik.docker.network` to `traefik.swarm.network`

**Impact:**
- Enables communication with Traefik on dedicated network
- Maintains internal service communication via `hubzilla_internal`
- Removes deprecation warnings from Traefik
- Clean two-network architecture

### 3. Docker Image Version
**Updated:** `catmanmatt/hubzilla-pg-nginx:v5` → `v6`
- Incorporates entrypoint.sh hairpin NAT fix
- Both `hub` and `hub_cron` services updated to v6
- Multi-arch support (AMD64 + ARM64)

---

## Deployment Process

### Prerequisites

1. **Portainer Access**
   - Access to Portainer instance at target server
   - Permissions to create/update stacks

2. **External Overlay Networks Must Exist**
   - `traefik_net` - Must be created and Traefik must be connected to it

3. **Docker Secrets Created**
   - `hubzilla_db_password` - PostgreSQL database password
   - `hubzilla_smtp_password` - SMTP authentication password
   - `hubzilla_stalwart_admin_password` - Stalwart mail server admin password

4. **Environment Variables**
   - `DOMAIN` - Must be set to deployment domain (e.g., `hubzilla.staging.chattanooga.digital`)

### Deployment Steps

#### Method 1: Git-Based Stack (Recommended)

1. **In Portainer → Stacks → Add Stack:**
   - Name: `hubzilla`
   - Build method: **Git Repository**
   - Repository URL: `https://github.com/Chattanooga-Digital-Dev/hubzilla`
   - Branch: `staging`
   - Compose path: `docker-stack.yml`
   
2. **Environment Variables:**
   - Load from `.env` file or set manually
   - Ensure `DOMAIN=hubzilla.staging.chattanooga.digital`

3. **Deploy Stack**

#### Method 2: Manual Stack File Upload

1. **In Portainer → Stacks → Add Stack:**
   - Name: `hubzilla`
   - Build method: **Web editor**
   - Paste contents of `docker-stack.yml`

2. **Environment Variables:**
   - Set all required variables manually
   - Critical: `DOMAIN=hubzilla.staging.chattanooga.digital`

3. **Deploy Stack**

### Update Existing Deployment

**Via Portainer:**
1. Navigate to **Stacks → hubzilla → Editor**
2. Click **Pull and redeploy** (for Git-based stacks)
3. **CRITICAL:** Ensure "Remove volumes" is **UNCHECKED**
4. Optional: Check "Prune services" to clean up old definitions
5. Click **Update**

**What Persists:**
- ✅ Database data (`db_data` volume)
- ✅ Hubzilla files/uploads (`web_root` volume)
- ✅ Mail data (`stalwart_data` volume)
- ✅ User accounts and content
- ✅ `.htconfig.php` configuration

**What Updates:**
- Network connections
- Service configuration
- Container images (if version changed)

### Verification Steps

1. **Check Service Logs:**
   ```
   Look for: "======== NETWORK: Added <domain> -> <IP> to /etc/hosts ========"
   Verify: IP should match Traefik's IP on traefik_net (not fallback)
   ```

2. **Verify Network Connectivity:**
   - Go to **Networks → traefik_net**
   - Confirm hub and stalwart containers are listed
   - Note their IP addresses

3. **Test External Access:**
   - Browser: `https://hubzilla.staging.chattanooga.digital`
   - Should load Hubzilla setup wizard or homepage (no 504 timeout)

---

## Testing and Verification

### Verify Network Configuration

**From Portainer Console on hub container:**

1. **Navigate to Container Console:**
   - **Stacks** → **hubzilla** → **hubzilla_hub** service
   - Click on running container
   - **Console** tab → **Connect**

2. **Check Network Interfaces:**
   ```bash
   ip addr show
   # Should show interfaces on both traefik_net and hubzilla_internal
   ```

3. **Verify Traefik Service Discovery:**
   ```bash
   getent hosts traefik_traefik
   # Should return: 10.0.1.x traefik_traefik
   ```

4. **Check /etc/hosts Entry:**
   ```bash
   cat /etc/hosts | grep hubzilla
   # Should show: 10.0.1.x hubzilla.staging.chattanooga.digital
   ```

5. **Test HTTPS Connection Through Traefik:**
   ```bash
   wget -O- --timeout=5 https://hubzilla.staging.chattanooga.digital/ | head -20
   # Should return HTML content (not timeout)
   ```

### Expected Results

```bash
# getent hosts should return Traefik IP on traefik_net
10.0.1.x traefik_traefik

# /etc/hosts should show domain pointing to Traefik
10.0.1.x hubzilla.staging.chattanooga.digital

# wget should return HTML content
<!DOCTYPE html>
<html prefix="og: http://ogp.me/ns#">
  <head>
    <title>Hubzilla</title>
    ...
```

---

## Retrieving Registration Tokens

When users register on Hubzilla with approval required (`REGISTER_POLICY=REGISTER_APPROVE`), administrators need to retrieve registration tokens to approve new accounts.

### Via Portainer Console

1. **Navigate to Database Container:**
   - **Stacks** → **hubzilla**
   - Find `hubzilla_hub_db` service
   - Click on running container
   - **Console** tab → **Connect**

2. **Run the Registration Query:**
   ```bash
   psql -U hubzilla -d hub -x -c "SELECT reg_email, reg_hash FROM register;"
   ```

3. **Example Output:**
   ```
   -[ RECORD 1 ]------------------------
   reg_email | user@example.com
   reg_hash  | abc123def456...
   -[ RECORD 2 ]------------------------
   reg_email | another@example.com
   reg_hash  | xyz789uvw012...
   ```

4. **Approve Registration:**
   - Share the registration URL with the user:
     ```
     https://hubzilla.staging.chattanooga.digital/regate/<reg_hash>
     ```
   - Example: `https://hubzilla.staging.chattanooga.digital/regate/abc123def456...`

### Via SSH (if available)

If you have SSH access to the Docker host:

```bash
# Find the database container
DB_CONTAINER=$(docker ps -q -f name=hubzilla_hub_db)

# Run the query
docker exec $DB_CONTAINER psql -U hubzilla -d hub -x -c "SELECT reg_email, reg_hash FROM register;"
```

### Notes
- The `reg_hash` is a unique token for each pending registration
- Once a user completes registration via the link, their record is removed from the `register` table
- If the table is empty, there are no pending registrations

---

## Troubleshooting Common Issues

### Issue: Service can't resolve traefik_traefik

**Symptoms:**
- Logs show: `WARNING: Could not resolve traefik_traefik, using fallback IP`
- 504 Gateway Timeout on web access

**Solution:**
1. Verify Traefik is running: **Services** → check traefik service status
2. Verify networks: **Networks → traefik_net** → confirm both Traefik and hub are listed
3. Check hub service network connections in stack file

### Issue: 504 Timeout Still Occurs

**Symptoms:**
- Domain resolves to wrong IP in `/etc/hosts`
- Fallback IP doesn't work

**Solution:**
1. Check actual Traefik IP: **Networks → traefik_net** → note Traefik's IP
2. Update fallback IP in `entrypoint.sh` if different from 10.0.1.3
3. Redeploy stack

### Issue: Stalwart Web UI Not Accessible

**Symptoms:**
- Can't access `https://mail.hubzilla.staging.chattanooga.digital`

**Solution:**
1. Verify Stalwart is on traefik_net: **Networks → traefik_net**
2. Check Stalwart labels include: `traefik.swarm.network=traefik_net`
3. Verify port 8080 is exposed in Stalwart container

---

## Lessons Learned

### 1. Network Topology Matters
- Always verify which networks Traefik uses before deploying
- Services must explicitly join Traefik's network to be routed
- Use `traefik.swarm.network` label to specify routing network

### 2. Hairpin NAT is Common with Reverse Proxies
- Containers attempting to reach themselves via public domain will timeout
- Solution: Add domain to `/etc/hosts` pointing to reverse proxy internal IP
- Never point to `127.0.0.1` when using external reverse proxy for HTTPS

### 3. Service Discovery is Reliable
- `getent hosts <service_name>` works across overlay networks
- Always implement fallback mechanisms for critical configurations
- DNS-based service discovery simplifies multi-server deployments

### 4. Portainer-Only Troubleshooting is Feasible
- Console access provides adequate shell for diagnostics
- Network inspection shows container connectivity clearly
- Service logs reveal startup and runtime issues effectively

### 5. Use Swarm-Specific Labels
- `traefik.docker.network` is deprecated in Swarm mode
- Use `traefik.swarm.network` to avoid warnings
- Properly specified network labels prevent routing issues

---

## Production Readiness Checklist

Before deploying to production, ensure:

- [ ] SSL certificates are valid and auto-renewing
- [ ] Database backups are configured
- [ ] Docker secrets are properly secured
- [ ] Email delivery is tested (SMTP via Stalwart)
- [ ] Registration policy is set appropriately
- [ ] Admin account is created and secured
- [ ] Domain DNS is pointing to server
- [ ] Firewall rules allow ports 80, 443, 25, 587, 465, 143, 993
- [ ] Traefik access logs are enabled for monitoring
- [ ] Regular update schedule is planned

---

## Related Documentation

- [Original Troubleshooting Session](./STAGING-DEPLOYMENT-Troubleshooting.md)
- [Oracle Cloud Setup Guide](./ORACLE-CLOUD-SWARM-SETUP.md)
- Main README.md (needs update for staging deployments)

---

## Conclusion

The deployment to chattanooga.digital succeeded by implementing two key fixes:

1. **Hairpin NAT Resolution:** Automatically detecting and routing domain requests through Traefik's internal IP prevents timeout loops when Hubzilla performs self-checks.

2. **Network Connectivity:** Connecting services to both `traefik_net` (for external routing) and `hubzilla_internal` (for internal communication) enables proper traffic flow in dedicated network topologies.

The solution uses a clean two-network architecture that separates external routing concerns from internal service communication, making it maintainable and easy to understand. The configuration is now production-ready for the chattanooga.digital staging environment.
