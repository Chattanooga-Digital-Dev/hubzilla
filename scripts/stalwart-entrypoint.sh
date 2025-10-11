#!/bin/bash

# Stalwart Mail Server Entrypoint Script
# Works for both local development (mkcert) and staging/production (Let's Encrypt)

set -e

echo "======== CONFIGURING: Stalwart SSL certificates ========"

# Detect environment based on available certificate sources
if [ -f "/var/ssl-shared/${DOMAIN}.pem" ]; then
	# LOCAL DEVELOPMENT MODE - using mkcert certificates from Traefik
	echo "Environment: Local Development (mkcert)"
	
	# Source the SSL setup function for local dev
	if [ -f "/usr/local/bin/setup-stalwart-ssl.sh" ]; then
		. /usr/local/bin/setup-stalwart-ssl.sh
		setup_stalwart_ssl
	else
		echo "ERROR: setup-stalwart-ssl.sh not found for local development"
		exit 1
	fi
	
elif [ -d "/certs" ]; then
	# STAGING/PRODUCTION MODE - using Let's Encrypt from cert_extractor
	echo "Environment: Staging/Production (Let's Encrypt)"
	
	# Use MAIL_DOMAIN if set, otherwise fall back to DOMAIN
	CERT_DOMAIN="${MAIL_DOMAIN:-$DOMAIN}"
	
	# Wait for SSL certificates to be extracted by cert_extractor
	max_wait=60
	count=0
	
	CERT_FILE="/certs/${CERT_DOMAIN}.crt"
	KEY_FILE="/certs/${CERT_DOMAIN}.key"
	
	while [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; do
		if [ $count -ge $max_wait ]; then
			echo "ERROR: SSL certificates not found after ${max_wait} seconds"
			echo "Expected files:"
			echo "  - $CERT_FILE"
			echo "  - $KEY_FILE"
			echo "Make sure Traefik has obtained Let's Encrypt certificates"
			exit 1
		fi
		echo "Waiting for SSL certificates to be extracted... (${count}/${max_wait})"
		sleep 1
		count=$((count + 1))
	done
	
	# Create SSL directory in Stalwart
	mkdir -p /opt/stalwart/etc/ssl
	
	# Copy certificates from cert_extractor volume
	echo "Copying SSL certificates to Stalwart..."
	cp "$CERT_FILE" "/opt/stalwart/etc/ssl/${CERT_DOMAIN}.pem"
	cp "$KEY_FILE" "/opt/stalwart/etc/ssl/${CERT_DOMAIN}-key.pem"
	
	# Set proper permissions
	chmod 644 "/opt/stalwart/etc/ssl/${CERT_DOMAIN}.pem"
	chmod 600 "/opt/stalwart/etc/ssl/${CERT_DOMAIN}-key.pem"
	
	# Verify certificates were copied
	if [ -f "/opt/stalwart/etc/ssl/${CERT_DOMAIN}.pem" ] && [ -f "/opt/stalwart/etc/ssl/${CERT_DOMAIN}-key.pem" ]; then
		echo "======== SUCCESS: Stalwart SSL certificates configured ========"
		echo "Certificate: /opt/stalwart/etc/ssl/${CERT_DOMAIN}.pem"
		echo "Key: /opt/stalwart/etc/ssl/${CERT_DOMAIN}-key.pem"
	else
		echo "======== ERROR: Failed to copy SSL certificates ========"
		exit 1
	fi
else
	echo "ERROR: Cannot detect certificate source"
	echo "Neither /var/ssl-shared nor /certs directory found"
	exit 1
fi

echo "======== STARTING: Stalwart Mail Server ========"

# Start Stalwart with the configuration
exec /usr/local/bin/stalwart --config=/opt/stalwart/etc/config.toml
