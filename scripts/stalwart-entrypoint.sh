#!/bin/bash

# Stalwart Mail Server Entrypoint Script
# Handles SSL certificate setup before starting Stalwart

set -e

# Source the SSL setup function
. /usr/local/bin/setup-stalwart-ssl.sh

# Run SSL certificate setup
setup_stalwart_ssl

# Start Stalwart with the original command
exec /usr/local/bin/stalwart --config=/opt/stalwart/etc/config.toml
