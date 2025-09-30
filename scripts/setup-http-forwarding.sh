#!/bin/bash

# HTTP Forwarding Setup Function
# Sets up HTTP forwarding for localhost to nginx container for URL rewrite testing
setup_http_forwarding() {
	# Use socat for proper HTTP proxying instead of netcat to avoid header issues
	# Install socat if not available
	which socat >/dev/null || apk add --no-cache socat

	# HTTPS forwarding with proper HTTP handling
	sh -c "while true; do socat TCP4-LISTEN:443,bind=127.0.0.1,reuseaddr,fork TCP4:${WEBSERVER_SERVICE_NAME}:443; done" &

	# HTTP forwarding with proper HTTP handling  
	sh -c "while true; do socat TCP4-LISTEN:80,bind=127.0.0.1,reuseaddr,fork TCP4:${WEBSERVER_SERVICE_NAME}:80; done" &
}
