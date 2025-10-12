#!/bin/bash

# Simplified entrypoint for hub container with internal nginx
# Removed: socat forwarding, nginx config generation, SSL generation (Traefik handles all of this)

### CHECK FOR, AND SET THE DATABASE ###
# Skip database initialization if this is the cron container
if [ "$1" = "crond" ]; then
    echo "======== CRON CONTAINER: Skipping database initialization ========" 
    cd /var/www/html
    exec "$@"
    exit 0
fi

# Skip database initialization if running supervisord (main hub container)
if [ "$1" = "supervisord" ]; then
    echo "======== HUB CONTAINER: Running with supervisord (nginx + php-fpm) ========"
    
    # Add domain to /etc/hosts to prevent hairpin NAT timeout
    # Point to Traefik's IP so HTTPS requests (port 443) work properly through the reverse proxy
    # Try to resolve traefik service IP, fallback to common gateway if not found
    TRAEFIK_IP=$(getent hosts traefik_traefik 2>/dev/null | awk '{print $1}' | head -1)
    if [ -z "$TRAEFIK_IP" ]; then
        # Fallback: try to find gateway IP on apps_net (usually .1 or .3)
        TRAEFIK_IP="10.0.1.3"
        echo "======== WARNING: Could not resolve traefik_traefik, using fallback IP: $TRAEFIK_IP ========"
    fi
    echo "$TRAEFIK_IP ${DOMAIN}" >> /etc/hosts
    echo "======== NETWORK: Added ${DOMAIN} -> ${TRAEFIK_IP} to /etc/hosts ========"
    
    # Continue with database checks below
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

cd /var/www/html

cat <<SMTPCONF > /etc/ssmtp/ssmtp.conf
mailhub=${SMTP_HOST}:${SMTP_PORT}
UseSTARTTLS=${SMTP_USE_STARTTLS}
root=${SMTP_USER}
rewriteDomain=${SMTP_DOMAIN}
FromLineOverride=YES
SMTPCONF
if [ "${SMTP_PASS:-'nil'}" != "nil" ]; then
	cat <<SMTPCONF >> /etc/ssmtp/ssmtp.conf
AuthUser=${SMTP_USER}
AuthPass=${SMTP_PASS}
SMTPCONF
fi
echo "root:${SMTP_USER}" > /etc/ssmtp/revaliases
echo "www-data:${SMTP_USER}" >> /etc/ssmtp/revaliases

# Arrange permissions for folders
for folder in addon extend log store view widget; do
	echo "Fixing folder: $folder"
	if [ "$folder" = "view" ]; then
        chmod -R 755 $folder 2>/dev/null || true
	else
		chmod 755 $folder 2>/dev/null || true
    fi
done

# Make scripts executable
echo "Setting executable permissions on scripts..."
for script in /scripts/*.sh; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo "Made $(basename $script) executable"
    fi
done

chown www-data:www-data . 2>/dev/null || true

# SSL Certificate and CA setup - only for local development with mkcert
# In staging/production, Traefik handles SSL with Let's Encrypt
if [ -d "/mkcert-ca" ] && [ -f "/mkcert-ca/rootCA.pem" ]; then
    echo "======== LOCAL DEVELOPMENT MODE: Setting up mkcert SSL ========"
    
    # Wait for Traefik to generate mkcert certificates
    echo "Waiting for Traefik to generate SSL certificates..."
    mkdir -p /var/ssl-shared
    COUNT=0
    while [ ! -f "/var/ssl-shared/${DOMAIN}.pem" ] || [ ! -f "/var/ssl-shared/${DOMAIN}-key.pem" ]; do
        if [ $COUNT -ge 30 ]; then
            echo "WARNING: SSL certificates not found after 30 seconds"
            break
        fi
        sleep 1
        COUNT=$((COUNT + 1))
    done
    
    if [ -f "/var/ssl-shared/${DOMAIN}.pem" ]; then
        echo "SUCCESS: SSL certificates found"
    fi
    
    # Install mkcert CA in system trust store
    echo "Installing mkcert CA in system trust store..."
    cp /mkcert-ca/rootCA.pem /usr/local/share/ca-certificates/mkcert-rootCA.crt
    update-ca-certificates >/dev/null 2>&1
    echo "SUCCESS: mkcert CA installed"
else
    echo "======== STAGING/PRODUCTION MODE: Using Let's Encrypt via Traefik ========"
    echo "Skipping mkcert setup - Traefik handles SSL with Let's Encrypt"
fi

### START .HTCONFIG.PHP ###
if [ ${FORCE_CONFIG:-0} != 0 ]; then
	if [ -f .htconfig.php ]; then
		echo "======== SKIPPING: .htconfig.php auto-generation (preserves existing setup) ========"
	else
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
App::\$config['system']['timezone'] = '${TIMEZONE}';
App::\$config['system']['baseurl'] = 'https://${DOMAIN}';
App::\$config['system']['sitename'] = 'Hubzilla';
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
BASE

		chown www-data:www-data .htconfig.php
		
		echo "======== INSTALLING: addons ========"
		for a in ${ADDON_LIST=logrot nsfw superblock diaspora pubcrawl}; do
			util/addons install $a
			case "$a" in
				diaspora)
					util/config system diaspora_allowed 1
				;;
			esac
		done
		util/service_class system default_service_class firstclass
		util/config system ignore_imagick true
		util/config system register_policy ${REGISTER_POLICY}
	fi
fi

chown -R www-data:www-data /var/www/html/* 2>/dev/null || true
chown -R www-data:www-data /var/www/html/.* 2>/dev/null || true

# Check if this is initial setup
ACCOUNT_COUNT=$(sql 'SELECT count(*) FROM account;' 2>/dev/null | tail -1 | tr -d ' ')
if [ "${ACCOUNT_COUNT:-0}" = "0" ]; then
	echo "======== INITIAL SETUP: No .htconfig.php found, setup wizard will show ========"
else
	echo "======== EXISTING INSTALLATION: .htconfig.php present ========"
fi

# Source and execute email monitoring setup
source /scripts/setup-email-monitoring.sh
setup_email_monitoring

echo "Starting $@"
exec "$@"
