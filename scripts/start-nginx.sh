#!/bin/sh
#
# Wait for the SSL certificate to be present before starting nginx.
#

set -e

CERT_FILE="/etc/nginx/ssl/localhost.pem"

# Wait for the certificate to exist
until [ -f "${CERT_FILE}" ]; do
  echo "Waiting for SSL certificate: ${CERT_FILE}"
  sleep 2
done

echo "SSL certificate found. Starting nginx."

# Execute the original command
exec nginx -g 'daemon off;'
