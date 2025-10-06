#!/bin/sh
set -e

echo "=== Traefik: Certificate Setup ==="

# Check if certificates exist
if [ ! -f "/certs/${DOMAIN}.pem" ] || [ ! -f "/certs/${DOMAIN}-key.pem" ]; then
    echo "Certificates not found. Generating..."
    
    # Install wget if not present
    apk add --no-cache wget
    
    # Download mkcert binary from official GitHub releases
    MKCERT_VERSION="v1.4.4"
    wget -O /usr/local/bin/mkcert \
        "https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-amd64"
    chmod +x /usr/local/bin/mkcert
    
    # Use host mkcert CA if mounted, otherwise create new
    if [ -f "/mkcert-ca/rootCA.pem" ] && [ -f "/mkcert-ca/rootCA-key.pem" ]; then
        echo "Using host mkcert CA from /mkcert-ca"
        mkdir -p /root/.local/share/mkcert
        ln -sf /mkcert-ca/rootCA.pem /root/.local/share/mkcert/rootCA.pem
        ln -sf /mkcert-ca/rootCA-key.pem /root/.local/share/mkcert/rootCA-key.pem
    else
        echo "No host mkcert CA found, creating container-only CA"
        mkcert -install
    fi
    
    # Generate certificates
    mkcert -cert-file /certs/${DOMAIN}.pem \
           -key-file /certs/${DOMAIN}-key.pem \
           ${DOMAIN} 127.0.0.1 ::1
    
    chmod 644 /certs/*.pem
    echo "Certificates generated successfully"
else
    echo "Using existing certificates"
fi

echo "=== Starting Traefik ==="

# Chain to original Traefik entrypoint
exec /entrypoint.sh "$@"
