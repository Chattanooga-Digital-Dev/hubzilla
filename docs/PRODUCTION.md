# Production Deployment

This repository provides production-ready deployment via Docker Swarm and Portainer. For complete production deployment instructions, see the [Staging Deployment Guide](STAGING_DEPLOYMENT.md).

## Production Deployment Overview

The recommended production approach uses:
- **Docker Swarm** for orchestration
- **Portainer** for web-based management
- **Traefik** with Let's Encrypt for automatic SSL
- **Docker Secrets** for secure password management
- **Two-network architecture** for security separation

See [STAGING_DEPLOYMENT.md](STAGING_DEPLOYMENT.md) for complete instructions.

---

## Production Configuration Differences

### SSL Certificates
- **Local:** mkcert for localhost certificates
- **Production:** Let's Encrypt via Traefik (automatic renewal)

### Password Management
- **Local:** Plain text in `.env` file
- **Production:** Docker Secrets (encrypted at rest)

### Network Architecture
- **Local:** Single bridge network
- **Production:** Dual overlay networks (external routing + internal communication)

### Deployment Method
- **Local:** `docker compose up -d`
- **Production:** Portainer stack deployment with `docker-stack.yml`

---

## Security Checklist

### Required Configuration

**Email & Registration:**
```bash
# Enable email verification
REQUIRE_EMAIL=1

# Set registration policy
REGISTER_POLICY=REGISTER_APPROVE  # Recommended for production
# Options: REGISTER_OPEN, REGISTER_APPROVE, REGISTER_CLOSED
```

**Domain Configuration:**
```bash
DOMAIN=yourdomain.com
ADMIN_EMAIL=admin@yourdomain.com
SMTP_DOMAIN=yourdomain.com
```

**Passwords:**
- Use strong, randomly generated passwords
- Store in Docker Secrets (never commit to git)
- Rotate regularly

### Docker Secrets Setup

Production deployments use Docker Secrets for sensitive data:

```bash
# Create secrets (in Portainer or via CLI)
echo "strong_random_password" | docker secret create hubzilla_db_password -
echo "strong_smtp_password" | docker secret create hubzilla_smtp_password -
echo "strong_admin_password" | docker secret create hubzilla_stalwart_admin_password -
```

See [STAGING_DEPLOYMENT.md](STAGING_DEPLOYMENT.md#prerequisites) for details.

---

## Infrastructure Requirements

### Database
- PostgreSQL 16 with persistent volumes
- Automated backup strategy
- Regular maintenance (VACUUM, ANALYZE)
- Monitoring for performance and disk space

### Backups
Configure regular backups for:
- Database (`db_data` volume)
- User uploads (`web_root` volume)
- Mail data (`stalwart_data` volume)

**Backup strategy example:**
```bash
# Database backup
docker exec <postgres_container> pg_dump -U hubzilla -d hub > backup-$(date +%Y%m%d).sql

# Volume backups
docker run --rm -v hubzilla_web_root:/data -v $(pwd):/backup alpine tar czf /backup/web_root-$(date +%Y%m%d).tar.gz /data
```

### Monitoring
- Container health checks (configured in docker-stack.yml)
- Traefik access logs
- Application logs via Portainer
- Database performance metrics
- Disk space alerts

### Firewall Rules
Required open ports:
- **80** - HTTP (redirects to HTTPS)
- **443** - HTTPS
- **25** - SMTP (receiving mail)
- **587** - SMTP submission (sending mail)
- **465** - SMTPS (SSL/TLS)
- **143** - IMAP
- **993** - IMAPS (SSL/TLS)

---

## Mail Server Configuration

### DNS Records
Configure these DNS records for proper mail delivery:

**MX Record:**
```
yourdomain.com.  IN  MX  10  mail.yourdomain.com.
```

**A Record:**
```
mail.yourdomain.com.  IN  A  YOUR_SERVER_IP
```

**SPF Record:**
```
yourdomain.com.  IN  TXT  "v=spf1 mx ~all"
```

**DKIM Configuration:**
- Generate DKIM keys in Stalwart admin interface
- Add DKIM TXT record to DNS

**DMARC Record:**
```
_dmarc.yourdomain.com.  IN  TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

### Reverse DNS (PTR Record)
Configure reverse DNS with your hosting provider:
```
YOUR_SERVER_IP  PTR  mail.yourdomain.com.
```

**Note:** Proper DNS configuration is critical for email deliverability and preventing spam classification.

---

## Production Readiness Checklist

Before going live:

**Security:**
- [ ] All passwords use strong, random values
- [ ] Docker Secrets properly configured
- [ ] Registration policy set appropriately
- [ ] Email verification enabled
- [ ] Firewall rules configured
- [ ] SSL certificates auto-renewing

**Infrastructure:**
- [ ] Database backups automated
- [ ] Volume backups configured
- [ ] Monitoring/alerting set up
- [ ] DNS records configured (MX, SPF, DKIM, DMARC, PTR)
- [ ] Domain pointing to server

**Testing:**
- [ ] Email delivery tested (send/receive)
- [ ] Registration workflow tested
- [ ] SSL certificates valid and trusted
- [ ] All services accessible via HTTPS
- [ ] Backup/restore procedures tested

**Documentation:**
- [ ] Admin credentials securely stored
- [ ] Backup procedures documented
- [ ] Recovery procedures documented
- [ ] Update schedule planned

---

## Maintenance

### Regular Tasks

**Weekly:**
- Review application logs
- Check disk space
- Verify backups completed

**Monthly:**
- Test backup restoration
- Review user registrations
- Update Docker images if security patches available
- Review and rotate logs

**Quarterly:**
- Rotate passwords/secrets
- Review security configurations
- Update documentation

### Updates

**Updating the Stack:**
1. Test updates in staging environment first
2. Backup database and volumes
3. Use Portainer to pull and redeploy
4. Verify services healthy after update

See [STAGING_DEPLOYMENT.md](STAGING_DEPLOYMENT.md#stack-update-procedure) for details.

---

## Scaling Considerations

Docker Swarm supports horizontal scaling:

```yaml
deploy:
  replicas: 2  # Run multiple instances
```

**Considerations:**
- Database should remain single instance
- Web/hub services can scale horizontally
- Shared volumes needed for multi-instance deployments
- Load balancing handled by Traefik

---

## Alternative Deployment Options

### External Mail Service
Consider using external mail providers for production:
- **SendGrid** - Reliable SMTP relay
- **Mailgun** - Developer-friendly API
- **AWS SES** - Cost-effective for high volume

Configure SMTP settings in `.env` to point to external service.

### Managed Database
For high-availability production:
- Use managed PostgreSQL (AWS RDS, Digital Ocean, etc.)
- Update `DB_HOST` in `.env` to point to managed instance
- Remove `hub_db` service from `docker-stack.yml`

### Cloud Deployment
The Docker Swarm deployment works on:
- Self-hosted servers
- AWS EC2
- Digital Ocean Droplets
- Linode
- Oracle Cloud
- Any Docker Swarm-capable infrastructure

---

## Support Resources

- [Staging Deployment Guide](STAGING_DEPLOYMENT.md) - Complete production deployment instructions
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Portainer Documentation](https://docs.portainer.io/)
- [Hubzilla Documentation](https://hubzilla.org/page/hubzilla/Home)
