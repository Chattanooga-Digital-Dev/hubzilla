#!/bin/bash
source .env
mkdir -p certs
mkcert -cert-file certs/${DOMAIN}.pem \
       -key-file certs/${DOMAIN}-key.pem \
       ${DOMAIN} 127.0.0.1 ::1
echo "Certificates generated for Traefik: certs/${DOMAIN}.pem and certs/${DOMAIN}-key.pem"
