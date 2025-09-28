#!/bin/bash

# Database Setup Function
# Handles database connection testing and sets up global database functions
setup_database() {
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
}
