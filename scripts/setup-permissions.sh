#!/bin/bash

# Sets proper permissions on Hubzilla folders and scripts
setup_permissions() {
	for folder in "${folders=addon extend log store view widget}"; do
		echo "Fixing folder: $folder"
		if [ "$folder" = view ]; then
			chmod -R 755 $folder
		else
			chmod 755 $folder
		fi
	done
	
	echo "Setting executable permissions on scripts..."
	chmod +x /scripts/*.sh
	
	# Stalwart-specific script permissions
	if [ -f "/scripts/setup-stalwart-ssl.sh" ]; then
		chmod +x /scripts/setup-stalwart-ssl.sh
		echo "Made setup-stalwart-ssl.sh executable"
	fi
	
	if [ -f "/scripts/stalwart-entrypoint.sh" ]; then
		chmod +x /scripts/stalwart-entrypoint.sh
		echo "Made stalwart-entrypoint.sh executable"
	fi
}
