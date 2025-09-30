# Development Guide

## Container Commands
```bash
# Restart everything
docker compose down && docker compose up -d

## Reset Data
```bash
# Reset database only
docker compose down
docker volume rm hubzilla_db_data
docker compose up -d

# Reset everything
docker compose down
docker volume rm hubzilla_db_data hubzilla_web_root hubzilla_ssl_certs hubzilla_nginx_config hubzilla_stalwart_data
docker image rm hubzilla-hub hubzilla-hub_cron hubzilla-hub_web
docker compose build --no-cache
docker compose up -d
```

# View logs
docker compose logs
docker logs -f hubzilla_itself     # Follow specific container

# Access containers
docker exec -it hubzilla_itself bash
docker exec -it hubzilla_database psql -U hubzilla -d hub
```

## Database Operations
```bash
# Connect to database
docker exec -it hubzilla_database psql -U hubzilla -d hub

# Run SQL from host
docker exec hubzilla_itself sh -c 'PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT count(*) FROM account;"'

# Backup
docker exec hubzilla_database pg_dump -U hubzilla -d hub > backup.sql

# Restore
docker exec -i hubzilla_database psql -U hubzilla -d hub < backup.sql
```

## Health Checks
```bash
# Check container status
docker compose ps

# Test database
docker exec hubzilla_itself sh -c 'PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT version();"'

# Test web server
curl -k -I https://localhost

```

## Container Network
**Note:** Service names (for Docker networking) are shown first, with container names in parentheses. Use service names in scripts and docker-compose.yml configuration. Use container names for `docker exec` and `docker logs` commands.

| Service Name (Container Name) | IP | Purpose |
|-----------|----|----|
| hub_web (hubzilla_webserver) | 172.20.0.10 | Nginx proxy |
| hub (hubzilla_itself) | 172.20.0.20 | PHP-FPM app |
| hub_db (hubzilla_database) | 172.20.0.30 | PostgreSQL |
| hub_cron (hubzilla_cronjob) | 172.20.0.40 | Background tasks |
| stalwart (hubzilla_mailserver) | 172.20.0.50 | Stalwart mail |
