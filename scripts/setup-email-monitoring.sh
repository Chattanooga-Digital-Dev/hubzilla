#!/bin/bash

# Email Configuration Monitor Function  
# Runs in background to apply email configuration after Hubzilla setup completes
setup_email_monitoring() {
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
}
