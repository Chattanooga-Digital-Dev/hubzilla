#!/bin/bash

# SMTP Configuration Function
# Configures system-level SMTP settings for ssmtp
setup_smtp() {
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
}
