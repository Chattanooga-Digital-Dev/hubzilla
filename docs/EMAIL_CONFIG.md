# Email Configuration

## Stalwart Mail Server Setup

### Access Admin Interface
- URL: https://localhost:8080
- Login: `admin` / password from `.env` (`STALWART_ADMIN_PASSWORD`)

### Create Domain
1. Go to "Domains" → Create new domain: `example.com`

### Create Admin Account
1. Go to "Accounts" → Create account:
   - Name: Admin
   - Login: admin@example.com
   - Email: admin@example.com
   - Password: Same as `STALWART_ADMIN_PASSWORD`

### Create Channel Aliases
Create these aliases under admin@example.com:
- tech@example.com
- music@example.com
- education@example.com
- volunteer@example.com
- community@example.com

## Email Client Setup (Thunderbird)
- Account: admin@example.com
- IMAP: localhost:993 (SSL/TLS)
- SMTP: localhost:587 (STARTTLS)
- Password: Value from `STALWART_ADMIN_PASSWORD`

## Bypass Email Verification
```bash
# Get verification token
docker exec hubzilla_itself sh -c 'PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT reg_hash FROM register WHERE reg_email='\''your-email@example.com'\'';"'

# Visit: https://localhost/register/verify/TOKEN
```
