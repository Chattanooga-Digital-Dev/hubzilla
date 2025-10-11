#!/bin/bash

# Stalwart Mail Server Entrypoint Script - Staging Version
# Handles SSL certificate setup from Traefik cert-extractor

set -e

echo "======== CONFIGURING: Stalwart SSL certificates ========"

# Wait for SSL certificates to be extracted by cert_extractor
max_wait=60
count=0

CERT_FILE="/certs/${MAIL_DOMAIN}.crt"
KEY_FILE="/certs/${MAIL_DOMAIN}.key"

while [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; do
	if [ $count -ge $max_wait ]; then
		echo "ERROR: SSL certificates not found after ${max_wait} seconds"
		echo "Expected files:"
		echo "  - $CERT_FILE"
		echo "  - $KEY_FILE"
		echo "Make sure Traefik has obtained Let's Encrypt certificates for mail.${DOMAIN}"
		exit 1
	fi
	echo "Waiting for SSL certificates to be extracted... (${count}/${max_wait})"
	echo "Looking for: $CERT_FILE and $KEY_FILE"
	sleep 1
	count=$((count + 1))
done

# Create SSL directory in Stalwart
mkdir -p /opt/stalwart/etc/ssl

# Copy certificates from cert_extractor volume
echo "Copying SSL certificates to Stalwart..."
cp "$CERT_FILE" "/opt/stalwart/etc/ssl/${MAIL_DOMAIN}.pem"
cp "$KEY_FILE" "/opt/stalwart/etc/ssl/${MAIL_DOMAIN}-key.pem"

# Set proper permissions
chmod 644 "/opt/stalwart/etc/ssl/${MAIL_DOMAIN}.pem"
chmod 600 "/opt/stalwart/etc/ssl/${MAIL_DOMAIN}-key.pem"

# Verify certificates were copied
if [ -f "/opt/stalwart/etc/ssl/${MAIL_DOMAIN}.pem" ] && [ -f "/opt/stalwart/etc/ssl/${MAIL_DOMAIN}-key.pem" ]; then
	echo "======== SUCCESS: Stalwart SSL certificates configured ========"
	echo "Certificate: /opt/stalwart/etc/ssl/${MAIL_DOMAIN}.pem"
	echo "Key: /opt/stalwart/etc/ssl/${MAIL_DOMAIN}-key.pem"
else
	echo "======== ERROR: Failed to copy SSL certificates ========"
	exit 1
fi

echo "======== STARTING: Stalwart Mail Server ========"

# Start Stalwart with the configuration
exec /usr/local/bin/stalwart --config=/opt/stalwart/etc/config.toml
