# Staging Deployment Guide

Deploy Hubzilla to Docker Swarm using GitHub and Docker Secrets.

## Prerequisites

- Docker Swarm initialized on your server
- Traefik stack already deployed with Let's Encrypt
- GitHub repository with staging branch
- SSH access to staging server

## Initial Setup

### 1. Push Code to GitHub

On your local machine:

```bash
# Make sure you're on the staging branch
git checkout staging
git push origin staging
```

### 2. SSH to Staging Server

```bash
ssh ubuntu@your-staging-server
```

### 3. Download and Run Deployment Script

```bash
# Download the deployment script
curl -o deploy.sh https://raw.githubusercontent.com/YOUR_USERNAME/hubzilla/staging/deploy.sh
chmod +x deploy.sh

# Edit the script to set your GitHub repo URL
nano deploy.sh
# Change: REPO_URL="https://github.com/YOUR_USERNAME/hubzilla.git"

# Run first-time deployment
sudo ./deploy.sh
```

The script will:
1. Clone your repository to `/opt/hubzilla`
2. Prompt you to create three Docker secrets:
   - Database password
   - SMTP password
   - Stalwart admin password
3. Deploy the stack to Docker Swarm

## Updating the Deployment

When you push changes to GitHub:

```bash
# On staging server
cd /opt/hubzilla
sudo ./deploy.sh update
```

This will pull the latest code and redeploy without recreating secrets.

## Manual Deployment Steps

If you prefer manual deployment:

### 1. Clone Repository

```bash
sudo mkdir -p /opt/hubzilla
cd /opt/hubzilla
sudo git clone -b staging https://github.com/YOUR_USERNAME/hubzilla.git .
```

### 2. Create Environment File

```bash
sudo cp .env.staging .env
# Edit if needed
sudo nano .env
```

### 3. Create Docker Secrets

```bash
# Database password
echo "YOUR_STRONG_DB_PASSWORD" | sudo docker secret create hubzilla_db_password -

# SMTP password
echo "YOUR_STRONG_SMTP_PASSWORD" | sudo docker secret create hubzilla_smtp_password -

# Stalwart admin password (should match SMTP password)
echo "YOUR_STRONG_SMTP_PASSWORD" | sudo docker secret create hubzilla_stalwart_admin_password -
```

### 4. Deploy Stack

```bash
sudo docker stack deploy -c docker-stack.yml hubzilla
```

## Verifying Deployment

### Check Stack Status

```bash
# List all services
docker stack ps hubzilla

# Check specific service logs
docker service logs hubzilla_hub -f
docker service logs hubzilla_stalwart -f
docker service logs hubzilla_hub_db -f
```

### Check Service Health

```bash
# All services should show 1/1 replicas
docker stack services hubzilla
```

### Test the Site

Open in browser:
- Main site: https://hubzilla.staging.chatthub.online
- Mail admin: https://mail.staging.chatthub.online

## Troubleshooting

### Services Won't Start

```bash
# Check service logs
docker service logs hubzilla_hub --tail 100

# Check if secrets exist
docker secret ls | grep hubzilla

# Check network connectivity
docker network ls | grep apps_net
```

### Certificate Issues

```bash
# Check Traefik logs
docker service logs traefik_traefik -f

# Verify cert_extractor is running
docker service logs hubzilla_cert_extractor -f
```

### Database Connection Errors

```bash
# Check database is healthy
docker service ps hubzilla_hub_db

# Test database connectivity
docker exec $(docker ps -q -f name=hubzilla_hub_db) \
  psql -U hubzilla -d hub -c "SELECT 1"
```

### Mail Server Issues

```bash
# Check Stalwart logs
docker service logs hubzilla_stalwart -f

# Verify certificates are extracted
docker exec $(docker ps -q -f name=hubzilla_stalwart) \
  ls -la /opt/stalwart/etc/ssl/
```

## Updating Secrets

To change passwords after deployment:

```bash
# Remove old secrets
docker secret rm hubzilla_db_password
docker secret rm hubzilla_smtp_password
docker secret rm hubzilla_stalwart_admin_password

# Create new secrets
echo "NEW_PASSWORD" | docker secret create hubzilla_db_password -
echo "NEW_PASSWORD" | docker secret create hubzilla_smtp_password -
echo "NEW_PASSWORD" | docker secret create hubzilla_stalwart_admin_password -

# Redeploy stack
docker stack deploy -c docker-stack.yml hubzilla
```

**Note:** Changing database password requires updating the database as well.

## Rollback

If deployment fails:

```bash
# Remove the stack
docker stack rm hubzilla

# Check previous working commit
git log --oneline

# Checkout previous version
git checkout <commit-hash>

# Redeploy
docker stack deploy -c docker-stack.yml hubzilla
```

## Security Notes

- Secrets are encrypted in Docker Swarm
- Never commit passwords to GitHub
- .env.staging does not contain sensitive data
- Rotate passwords regularly
- Use strong, unique passwords for each secret
