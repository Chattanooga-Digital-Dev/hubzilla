#!/bin/sh

# nginx startup script that waits for Hubzilla files before starting
echo "Waiting for Hubzilla files to be available..."

# Wait for the key Hubzilla files to be available
TIMEOUT=60
COUNTER=0
while [ ! -f /var/www/html/index.php ] && [ $COUNTER -lt $TIMEOUT ]; do
    echo "Waiting for Hubzilla files... ($COUNTER/$TIMEOUT)"
    sleep 1
    COUNTER=$((COUNTER + 1))
done

if [ ! -f /var/www/html/index.php ]; then
    echo "ERROR: Hubzilla files not found after $TIMEOUT seconds"
    exit 1
fi

# Also wait for nginx config to be available
while [ ! -f /etc/nginx/conf.d/default.conf ] && [ $COUNTER -lt $TIMEOUT ]; do
    echo "Waiting for nginx config... ($COUNTER/$TIMEOUT)"
    sleep 1
    COUNTER=$((COUNTER + 1))
done

if [ ! -f /etc/nginx/conf.d/default.conf ]; then
    echo "ERROR: Nginx config not found after $TIMEOUT seconds"
    exit 1
fi

echo "All files ready, testing nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "Nginx config test passed, starting nginx..."
    exec nginx -g "daemon off;"
else
    echo "ERROR: Nginx config test failed"
    exit 1
fi
