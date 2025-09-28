# Production Deployment

**Warning: This setup is for local development only.**

## Suggested Changes for Production

### SSL Certificates
- Replace mkcert with real SSL certificates (Let's Encrypt, commercial CA)
- Update nginx configuration for production certificates

### Security
```bash
# Enable email verification
REQUIRE_EMAIL=1

# Set proper registration policy
REGISTER_POLICY=REGISTER_APPROVE  # or REGISTER_CLOSED

# Use strong passwords
DB_PASSWORD=strong_random_password
STALWART_ADMIN_PASSWORD=strong_random_password
```

### Domain Configuration
```bash
# Set real domain
DOMAIN=yourdomain.com
ADMIN_EMAIL=admin@yourdomain.com
SMTP_DOMAIN=yourdomain.com
```

### Infrastructure
- Set up proper backup procedures for database and volumes
- Configure monitoring and logging
- Review container security settings
- Set up reverse proxy with rate limiting
- Configure firewall rules

### Database
- Use managed PostgreSQL service or dedicated database server
- Configure regular automated backups
- Set up database monitoring

### Mail Server
- Configure SPF, DKIM, DMARC records
- Set up proper mail routing
- Consider using external mail service (SendGrid, etc.)

## Not Recommended for Production
- localhost certificates
- Default passwords
- Development-focused container configurations
- Integrated mail server without proper DNS records
