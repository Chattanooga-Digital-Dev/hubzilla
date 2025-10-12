#!/bin/bash

# Docker Secrets Loader
# Reads secrets from /run/secrets/ and exports them as environment variables
# Used by docker-stack.yml for secure password management in Docker Swarm

set -e

# Load database password
if [ -f /run/secrets/db_password ]; then
    export DB_PASSWORD=$(cat /run/secrets/db_password)
    export POSTGRES_PASSWORD=$(cat /run/secrets/db_password)
fi

# Load SMTP password
if [ -f /run/secrets/smtp_password ]; then
    export SMTP_PASS=$(cat /run/secrets/smtp_password)
fi

# Load Stalwart admin password
if [ -f /run/secrets/stalwart_admin_password ]; then
    export STALWART_ADMIN_PASSWORD=$(cat /run/secrets/stalwart_admin_password)
fi

# Verify critical secrets are loaded (only for services that need DB)
if [ ! -z "$DB_USER" ] && [ -z "$DB_PASSWORD" ]; then
    echo "ERROR: DB_PASSWORD secret not found"
    exit 1
fi

echo "Secrets loaded successfully"
