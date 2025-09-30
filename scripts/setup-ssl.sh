#!/bin/bash

setup_ssl() {
	# Generate SSL certificates if they don't exist
	if [ ! -f "/var/ssl-shared/localhost.pem" ] || [ ! -f "/var/ssl-shared/localhost-key.pem" ]; then
		echo "======== GENERATING: SSL certificates ========"
		mkdir -p /var/ssl-shared
		# Check if we have a host mkcert CA mounted, otherwise create our own
		if [ -f "/root/.local/share/mkcert/rootCA.pem" ] && [ -f "/root/.local/share/mkcert/rootCA-key.pem" ]; then
			echo "Using existing mkcert CA from host system"
		else
			echo "No host mkcert CA found, attempting to detect and use host CA"
			
			# Try to detect and use host mkcert CA based on platform
			HOST_CA_FOUND=false
			
			# WSL2/Windows detection
			if command -v powershell.exe >/dev/null 2>&1; then
				echo "Detected WSL environment, looking for Windows mkcert CA"
				WIN_PROFILE=$(powershell.exe -c 'Write-Host -NoNewLine $env:LOCALAPPDATA' 2>/dev/null || echo "")
				if [ -n "$WIN_PROFILE" ]; then
					WSL_WIN_PROFILE=$(echo "$WIN_PROFILE" | sed 's|\\|/|g' | sed 's|C:|/mnt/c|')
					WSL_MKCERT_DIR="$WSL_WIN_PROFILE/mkcert"
					echo "Looking for Windows mkcert CA at: $WSL_MKCERT_DIR"
					if [ -f "$WSL_MKCERT_DIR/rootCA.pem" ] && [ -f "$WSL_MKCERT_DIR/rootCA-key.pem" ]; then
						echo "Found Windows mkcert CA, copying to container"
						mkdir -p /root/.local/share/mkcert
						cp "$WSL_MKCERT_DIR/rootCA.pem" /root/.local/share/mkcert/
						cp "$WSL_MKCERT_DIR/rootCA-key.pem" /root/.local/share/mkcert/
						HOST_CA_FOUND=true
					fi
				fi
			fi
			
			# macOS detection (if running in macOS Docker)
			if [ "$HOST_CA_FOUND" = "false" ] && [ -d "/host-home" ]; then
				echo "Checking for macOS mkcert CA"
				MACOS_MKCERT_DIR="/host-home/Library/Application Support/mkcert"
				if [ -f "$MACOS_MKCERT_DIR/rootCA.pem" ] && [ -f "$MACOS_MKCERT_DIR/rootCA-key.pem" ]; then
					echo "Found macOS mkcert CA, copying to container"
					mkdir -p /root/.local/share/mkcert
					cp "$MACOS_MKCERT_DIR/rootCA.pem" /root/.local/share/mkcert/
					cp "$MACOS_MKCERT_DIR/rootCA-key.pem" /root/.local/share/mkcert/
					HOST_CA_FOUND=true
				fi
			fi
			
			# Linux detection (if running in Linux Docker)
			if [ "$HOST_CA_FOUND" = "false" ] && [ -d "/host-home" ]; then
				echo "Checking for Linux mkcert CA"
				LINUX_MKCERT_DIR="/host-home/.local/share/mkcert"
				if [ -f "$LINUX_MKCERT_DIR/rootCA.pem" ] && [ -f "$LINUX_MKCERT_DIR/rootCA-key.pem" ]; then
					echo "Found Linux mkcert CA, copying to container"
					mkdir -p /root/.local/share/mkcert
					cp "$LINUX_MKCERT_DIR/rootCA.pem" /root/.local/share/mkcert/
					cp "$LINUX_MKCERT_DIR/rootCA-key.pem" /root/.local/share/mkcert/
					HOST_CA_FOUND=true
				fi
			fi
			
			if [ "$HOST_CA_FOUND" = "false" ]; then
				echo "No host mkcert CA found, creating new container-only CA"
				echo "WARNING: This CA will only be trusted inside the container"
				echo "For browser trust, please set up mkcert on your host system"
				echo "See README for platform-specific setup instructions"
				mkcert -install
			fi
		fi
		mkcert -key-file /var/ssl-shared/localhost-key.pem -cert-file /var/ssl-shared/localhost.pem ${DOMAIN} 127.0.0.1 ::1
		# Set proper permissions
		chmod 644 /var/ssl-shared/*.pem
		echo "======== SUCCESS: SSL certificates generated ========"
	else
		echo "======== SSL certificates already exist, skipping generation ========"
		# Ensure mkcert CA is installed for existing certificates
		mkcert -install >/dev/null 2>&1 || true
	fi

	# Install mkcert root CA in system trust store for Hubzilla SSL validation
	echo "======== INSTALLING: mkcert CA in system trust store ========"
	if [ -f "/root/.local/share/mkcert/rootCA.pem" ]; then
		# Ensure ca-certificates package is available
		which update-ca-certificates >/dev/null || apk add --no-cache ca-certificates
		# Copy mkcert CA to system CA directory
		cp /root/.local/share/mkcert/rootCA.pem /usr/local/share/ca-certificates/mkcert-rootCA.crt
		# Update system CA certificates
		update-ca-certificates >/dev/null 2>&1
		echo "======== SUCCESS: mkcert CA installed in system trust store ========"
	else
		echo "======== WARNING: mkcert CA not found, SSL validation may fail ========"
	fi
}
