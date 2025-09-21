#!/bin/bash

# Set up HTTP forwarding for localhost to nginx container for URL rewrite testing
# This allows Hubzilla's setup wizard to test URL rewriting via localhost
# Use socat for proper HTTP proxying instead of netcat to avoid header issues

# Install socat if not available
which socat >/dev/null || apk add --no-cache socat

# HTTPS forwarding with proper HTTP handling
sh -c 'while true; do socat TCP4-LISTEN:443,bind=127.0.0.1,reuseaddr,fork TCP4:hubzilla_webserver:443; done' &

# HTTP forwarding with proper HTTP handling  
sh -c 'while true; do socat TCP4-LISTEN:80,bind=127.0.0.1,reuseaddr,fork TCP4:hubzilla_webserver:80; done' &

### CHECK FOR, AND SET THE DATABASE ###
# Skip database initialization if this is the cron container
if [ "$1" = "crond" ]; then
    echo "======== CRON CONTAINER: Skipping database initialization ========" 
    cd /var/www/html
    exec "$@"
    exit 0
fi

CNT=0
case "${DB_TYPE}" in
	# WARNING # mysql is still largely untested..
	[Mm][Yy][Ss][Qq][Ll]|[Mm][Yy][Ss][Qq][Ll][Ii]|[Mm][Aa][Rr][Ii][Aa][Dd][Bb]|0)
		srv() {	mysql -u "${DB_USER:-hubzilla}" -p "${DB_PASSWORD:-hubzilla}" -h "${DB_HOST:-mariadb}" -P "${DB_PORT:-3306}" "$@"; }
		db()  { srv -D "${DB_NAME:-hub}" "$@"; }
		sql() { db -e "$@" ; }
		while ! srv -e "status" > /dev/null; do
			echo "Waiting for MariaDB/MySQL to be ready ($((CNT+=1)))"
			sleep 2
		done
		if ! sql 'SELECT count(*) FROM pconfig;' >/dev/null; then
			echo "======== SKIPPING: database schema (will be handled by setup wizard) ========"
			# Don't install schema here - let setup wizard handle it
			FORCE_CONFIG=0
		else
			echo "======== DATABASE: schema already exists ========"
			FORCE_CONFIG=1
		fi
		DB_TYPE=0
	;;
	[Pp][Ss][Qq][Ll]|[Pp][Gg][Ss][Qq][Ll]|[Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss]|1)
		db() { PGPASSWORD="${DB_PASSWORD=hubzilla}" psql -h "${DB_HOST=postgres}" -p "${DB_PORT=5432}" -U "${DB_USER=hubzilla}" -d "${DB_NAME=hub}" -wt "$@"; }
		sql() {	db -c "$@"; }
		while ! sql '\q'; do
			echo "Waiting for Postgres to be ready ($((CNT+=1)))"
			sleep 2
		done
		if ! sql 'SELECT count(*) FROM pconfig;' >/dev/null; then
			echo "======== SKIPPING: database schema (will be handled by setup wizard) ========"
			# Don't install schema here - let setup wizard handle it
			FORCE_CONFIG=0
		else
			echo "======== DATABASE: schema already exists ========"
			FORCE_CONFIG=1
		fi
		DB_TYPE=1
	;;
	*)
		echo "======== ERROR: Unknown DB_TYPE=${DB_TYPE=Unknown} ========"
		echo "======== RESULT: Skipping DB Setup/Check ========"
		FORCE_CONFIG=0
	;;
esac

# Define global database functions for later use
case "${DB_TYPE}" in
	0|[Mm][Yy][Ss][Qq][Ll]|[Mm][Yy][Ss][Qq][Ll][Ii]|[Mm][Aa][Rr][Ii][Aa][Dd][Bb]) # MySQL
		sql() { mysql -u "${DB_USER}" -p"${DB_PASSWORD}" -h "${DB_HOST}" -P "${DB_PORT}" -D "${DB_NAME}" -e "$@" 2>/dev/null | tail -1; }
	;;
	1|[Pp][Ss][Qq][Ll]|[Pp][Gg][Ss][Qq][Ll]|[Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss]|postgres) # PostgreSQL  
		sql() { PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -wt -c "$@" 2>/dev/null; }
	;;
	*)
		sql() { echo "0"; }  # Default to 0 for unknown DB types
	;;
esac

cd /var/www/html

cat <<SMTPCONF > /etc/ssmtp/ssmtp.conf
mailhub=${SMTP_HOST}:${SMTP_PORT}
UseSTARTTLS=${SMTP_USE_STARTTLS}
root=${SMTP_USER}
rewriteDomain=${SMTP_DOMAIN}
FromLineOverride=YES
hostname=${SMTP_DOMAIN}
SMTPCONF
if [ "${SMTP_PASS:-'nil'}" != "nil" ]; then
	cat <<SMTPCONF >> /etc/ssmtp/ssmtp.conf
AuthUser=${SMTP_USER}
AuthPass=${SMTP_PASS}
SMTPCONF
fi
echo "root:${SMTP_USER}@${SMTP_DOMAIN}" > /etc/ssmtp/revaliases
echo "www-data:${SMTP_USER}@${SMTP_DOMAIN}" >> /etc/ssmtp/revaliases

# Arrange permissions for folders
for folder in "${folders=addon extend log store view widget}"; do
	echo "Fixing folder: $folder"
	if [ "$folder" = view ]; then
        chmod -R 755 $folder
	else
		chmod 755 $folder
    fi
done

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
	mkcert -key-file /var/ssl-shared/localhost-key.pem -cert-file /var/ssl-shared/localhost.pem localhost 127.0.0.1 ::1
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

# Copy nginx configuration to shared volume
if [ -f "/etc/hubzilla/default.conf" ]; then
	echo "======== COPYING: nginx configuration ========"
	mkdir -p /var/nginx-config
	cp /etc/hubzilla/default.conf /var/nginx-config/
	chmod 644 /var/nginx-config/default.conf
	echo "======== SUCCESS: nginx configuration copied ========"
else
	echo "======== WARNING: nginx config not found at /etc/hubzilla/default.conf ========"
fi

chown www-data:www-data .

### START .HTCONFIG.PHP ###
# Disable automatic .htconfig.php regeneration to preserve existing installations
# This was causing registration and configuration issues on container restart
echo "======== SKIPPING: .htconfig.php auto-generation (preserves existing setup) ========"
FORCE_CONFIG=0

if [ ${FORCE_CONFIG:-0} != 0 ]; then
	[ -f .htconfig.php ] && rm '.htconfig.php'
	random_string() {	tr -dc '0-9a-f' </dev/urandom | head -c ${1:-64} ; }
	cat <<BASE > .htconfig.php
<?php
\$db_host = '${DB_HOST}';
\$db_port = '${DB_PORT}';
\$db_user = '${DB_USER}';
\$db_pass = '${DB_PASSWORD}';
\$db_data = '${DB_NAME}';
\$db_type = '${DB_TYPE}';

// The following configuration maybe configured later in the Admin interface
// They can also be set by 'util/pconfig'
App::\$config['system']['timezone'] = '${TIMEZONE}';
App::\$config['system']['baseurl'] = 'https://${DOMAIN}';
App::\$config['system']['sitename'] = '${SITE_NAME}';
App::\$config['system']['location_hash'] = '$(random_string)';
App::\$config['system']['transport_security_header'] = 1;
App::\$config['system']['content_security_policy'] = 1;
App::\$config['system']['admin_email'] = '${ADMIN_EMAIL}';
App::\$config['system']['max_import_size'] = 200000;
App::\$config['system']['maximagesize'] = 8000000;
App::\$config['system']['directory_mode']  = DIRECTORY_MODE_NORMAL;
App::\$config['system']['theme'] = 'redbasic';

// LOGROT Plugin Settings
App::\$config['logrot']['logrotpath'] = '${LOGROT_PATH}';
App::\$config['logrot']['logrotsize'] = '${LOGROT_SIZE}';
App::\$config['logrot']['logretained'] = '${LOGROT_MAXFILES}';

// PHP Error Logging Settings
error_reporting(E_ERROR | E_WARNING | E_PARSE );
ini_set('error_log','log/php.out');
//ini_set('log_errors','1');
//ini_set('display_errors', '0');
BASE

case "${VERIFY_EMAIL}" in
	[Yy]|[Yy][Ee][Ss]|[Oo][Nn]|1)
		util/config system verify_email 1
	;;
	*)
		util/config system verify_email 0
	;;
esac

# LOGROT section of .htconfig.php
case "${ENABLE_LOGROT}" in
	[Yy]|[Yy][Ee][Ss]|[Oo][Nn]|1)
		if grep -qE "//App.*logrot" '.htconfig.php'; then
			LINES=$(grep -nE "//App.*logrot" '.htconfig.php' | cut -d : -f 1)
			echo "${LINES[*]}"
			for i in ${LINES[@]}; do
				sed $i's|//App|App|g' .htconfig.php;
			done
		elif grep -qE "App.*logrot" '.htconfig.php'; then
			:
		fi
	;;
	*)
		if grep -qE "//App.*logrot" '.htconfig.php'; then
			:
		elif grep -qE "App.*logrot" '.htconfig.php'; then
			LINES=$(grep -nE "//App.*logrot" '.htconfig.php' | cut -d : -f 1)
			echo "${LINES[*]}"
			for i in ${LINES[@]}; do
				sed $i's|App|//App|g' .htconfig.php;
			done
		fi
	;;
esac

# PHP section of .htconfig.php
case "${DEBUG_PHP}" in
	[Yy]|[Yy][Ee][Ss]|[Oo][Nn]|1)
		if grep -q "//ini_set('log_errors','1')" '.htconfig.php'; then
			sed "s|//ini_set('log_errors','1');|ini_set('log_errors','1');|g" .htconfig.php
			sed "s|//ini_set('display_errors','0');|ini_set('display_errors','0');|g" .htconfig.php
		else
			:
		fi
	;;
	*)
		if grep -q "//ini_set('log_errors','1')" '.htconfig.php'; then
			:
		else
			sed "s|ini_set('log_errors','1');|//ini_set('log_errors','1');|g" .htconfig.php
			sed "s|ini_set('display_errors','0');|//ini_set('display_errors','0');|g" .htconfig.php
		fi
	;;
esac

	if [ ${REDIS_PATH:-"nil"} != "nil" ]; then
		util/config system session_save_handler redis
		util/config system session_save_path ${REDIS_PATH}
		util/config system session_custom true
	fi

	echo "======== INSTALLING: addons ========"
	for a in ${ADDON_LIST=logrot nsfw superblock diaspora pubcrawl}; do
		util/addons install $a
		case "$a" in
			diaspora)
				util/config system diaspora_allowed 1
			;;
			xmpp)
				util/config xmpp bosh_proxy "https://${DOMAIN}/http-bind"
			;;
			ldapauth)
				util/config ldapauth ldap_server ldap://${LDAP_SERVER}
				util/config ldapauth ldap_binddn ${LDAP_ROOT_DN}
				util/config ldapauth ldap_bindpw ${LDAP_ADMIN_PASSWORD}
				util/config ldapauth ldap_searchdn ${LDAP_BASE}
				util/config ldapauth ldap_userattr uid
				util/config ldapauth create_account 1
			;;
		esac
	done
	util/service_class system default_service_class firstclass
	util/config system ignore_imagick true
	util/config system register_policy ${REGISTER_POLICY}
	#util/config system disable_email_validation 1

chown www-data:www-data .htconfig.php
fi
### END .HTCONFIG.PHP ###

# Extra configurations needed if Hubzilla version is 4 or below
CURVER=$(printf "%d" "${HZ_VERSION}")
MAXVER=$(printf "%d" "5")
if [ CURVER -lt MAXVER ]; then

	echo "======== RUNNING: udall ========"
	util/udall
	echo "======== SUCCESS: udall ========"
	echo "======== RUNNING: z6convert ========"
	echo "This may take a while..."
	php util/z6convert.php
	R=$?
	if [ $R -ne 0 ]; then
		echo "======== FAILED: z6convert ========"
	else
		echo "======== SUCCESS: z6convert ========"
	fi
fi

chown -R www-data:www-data /var/www/html/*
chown -R www-data:www-data /var/www/html/.*

# Simple installation check - preserve .htconfig.php if it exists
if [ -f /var/www/html/.htconfig.php ]; then
	echo "======== EXISTING INSTALLATION: .htconfig.php found, preserving it ========"
else
	echo "======== INITIAL SETUP: No .htconfig.php found, setup wizard will show ========"
fi

# Set email configuration after all setup is complete
# This runs in background and waits for Hubzilla setup to be completed
# Only applies the configuration once - skips if already configured
(
	echo "======== STARTING: Email configuration monitor ========"
	# Wait up to 30 minutes for setup completion, checking every 30 seconds
	for i in $(seq 1 60); do
		sleep 30
		# Check if .htconfig.php exists and database has config table with data
		if [ -f .htconfig.php ] && sql 'SELECT count(*) FROM config;' >/dev/null 2>&1; then
			# Check if email configuration already exists
			EXISTING_EMAIL=$(sql "SELECT v FROM config WHERE cat='system' AND k='from_email';" | head -1 | tr -d ' ')
			if [ -n "$EXISTING_EMAIL" ] && [ "$EXISTING_EMAIL" != "" ]; then
				echo "======== SKIPPING: Email configuration already exists ($EXISTING_EMAIL) ========"
				break
			else
				echo "======== DETECTED: Hubzilla setup completed, applying email config ========"
				util/config system admin_email admin@example.com
				util/config system sender_email admin@example.com
				util/config system from_email admin@example.com
				util/config system reply_address admin@example.com
				echo "======== SUCCESS: Email configuration applied automatically (one-time only) ========"
				break
			fi
		else
			echo "======== WAITING: Setup not complete yet (attempt $i/60) ========"
		fi
	done
) &

echo "Starting $@"
exec "$@"
