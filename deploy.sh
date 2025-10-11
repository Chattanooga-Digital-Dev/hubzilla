#!/bin/bash

# Hubzilla Staging Deployment Script
# Deploys Hubzilla from GitHub to Docker Swarm with secrets management
#
# Usage:
#   ./deploy.sh          # First-time deployment (creates secrets)
#   ./deploy.sh update   # Update deployment (keeps existing secrets)

set -e

STACK_NAME="hubzilla"
REPO_URL="https://github.com/YOUR_USERNAME/hubzilla.git"
BRANCH="staging"
DEPLOY_DIR="/opt/hubzilla"

echo "========================================="
echo "Hubzilla Staging Deployment"
echo "========================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Check if Docker Swarm is initialized
if ! docker info | grep -q "Swarm: active"; then
    echo "ERROR: Docker Swarm is not active"
    echo "Initialize with: docker swarm init"
    exit 1
fi

# Clone or update repository
if [ ! -d "$DEPLOY_DIR" ]; then
    echo "Cloning repository..."
    git clone -b "$BRANCH" "$REPO_URL" "$DEPLOY_DIR"
else
    echo "Updating repository..."
    cd "$DEPLOY_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
fi

cd "$DEPLOY_DIR"

# Copy staging environment file
if [ ! -f .env ]; then
    echo "Creating .env from .env.staging..."
    cp .env.staging .env
fi

# Create secrets (only if not in update mode)
if [ "$1" != "update" ]; then
    echo ""
    echo "========================================="
    echo "Creating Docker Secrets"
    echo "========================================="
    
    # Check if secrets already exist
    if docker secret ls | grep -q "hubzilla_db_password"; then
        echo "WARNING: Secrets already exist."
        read -p "Do you want to recreate them? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Keeping existing secrets"
        else
            echo "Removing old secrets..."
            docker secret rm hubzilla_db_password 2>/dev/null || true
            docker secret rm hubzilla_smtp_password 2>/dev/null || true
            docker secret rm hubzilla_stalwart_admin_password 2>/dev/null || true
            
            echo "Creating new secrets..."
            read -sp "Enter database password: " DB_PASS
            echo
            read -sp "Enter SMTP password: " SMTP_PASS
            echo
            read -sp "Enter Stalwart admin password: " STALWART_PASS
            echo
            
            echo "$DB_PASS" | docker secret create hubzilla_db_password -
            echo "$SMTP_PASS" | docker secret create hubzilla_smtp_password -
            echo "$STALWART_PASS" | docker secret create hubzilla_stalwart_admin_password -
            
            echo "Secrets created successfully"
        fi
    else
        echo "Creating secrets..."
        read -sp "Enter database password: " DB_PASS
        echo
        read -sp "Enter SMTP password: " SMTP_PASS
        echo
        read -sp "Enter Stalwart admin password: " STALWART_PASS
        echo
        
        echo "$DB_PASS" | docker secret create hubzilla_db_password -
        echo "$SMTP_PASS" | docker secret create hubzilla_smtp_password -
        echo "$STALWART_PASS" | docker secret create hubzilla_stalwart_admin_password -
        
        echo "Secrets created successfully"
    fi
fi

echo ""
echo "========================================="
echo "Deploying Stack"
echo "========================================="

# Deploy stack
docker stack deploy -c docker-stack.yml "$STACK_NAME"

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Check status with:"
echo "  docker stack ps $STACK_NAME"
echo "  docker service logs ${STACK_NAME}_hub -f"
echo ""
echo "Access your site at:"
echo "  https://$(grep DOMAIN .env | cut -d= -f2)"
echo ""
