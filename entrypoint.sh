#!/bin/bash

# Source and execute HTTP forwarding setup
source /scripts/setup-http-forwarding.sh
setup_http_forwarding

### CHECK FOR, AND SET THE DATABASE ###
# Skip database initialization if this is the cron container
if [ "$1" = "crond" ]; then
    echo "======== CRON CONTAINER: Skipping database initialization ========" 
    cd /var/www/html
    exec "$@"
    exit 0
fi

# Source and execute database setup script
source /scripts/setup-database.sh
setup_database

cd /var/www/html

# Source and execute SMTP setup script
source /scripts/setup-smtp.sh
setup_smtp

# Source and execute permissions setup script
source /scripts/setup-permissions.sh
setup_permissions

# Source and execute SSL setup script
source /scripts/setup-ssl.sh
setup_ssl

# Generate nginx configuration from template
if [ -f "/etc/hubzilla/default.conf.template" ]; then
	echo "======== GENERATING: nginx configuration from template ========"
	mkdir -p /var/nginx-config
	# Generate config file from template using DOMAIN environment variable
	envsubst '${DOMAIN}' < /etc/hubzilla/default.conf.template > /var/nginx-config/default.conf
	chmod 644 /var/nginx-config/default.conf
	echo "======== SUCCESS: nginx configuration generated for domain: ${DOMAIN} ========"
else
	echo "======== ERROR: nginx config template not found at /etc/hubzilla/default.conf.template ========"
	echo "Available files in /etc/hubzilla/:"
	ls -la /etc/hubzilla/ || echo "Directory does not exist"
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

# Source and execute email monitoring setup
source /scripts/setup-email-monitoring.sh
setup_email_monitoring

echo "Starting $@"
exec "$@"
