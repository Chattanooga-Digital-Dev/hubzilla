#!/bin/bash

# Permissions Setup Function
# Sets proper permissions on Hubzilla folders
setup_permissions() {
	# Arrange permissions for folders
	for folder in "${folders=addon extend log store view widget}"; do
		echo "Fixing folder: $folder"
		if [ "$folder" = view ]; then
			chmod -R 755 $folder
		else
			chmod 755 $folder
		fi
	done
}
