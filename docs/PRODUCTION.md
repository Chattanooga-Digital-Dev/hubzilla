# Production Deployment Guide

This guide outlines considerations and best practices for deploying Hubzilla and the Stalwart mail server in a production Docker Swarm environment using Portainer.

## Production Deployment Overview

The recommended production approach leverages a multi-stack Docker Swarm deployment:
- **Hubzilla Stack:** Deploys the main Hubzilla application.
- **Stalwart Mail Stack:** Deploys the separate Stalwart mail server.
- **Traefik:** Acts as a reverse proxy with automatic Let's Encrypt SSL.
- **Portainer:** Provides web-based management for Docker Swarm.
- **Docker Secrets:** Manages sensitive data securely.
- **Two-Network Architecture:** Ensures security separation between external routing and internal communication.

For detailed deployment instructions, refer to the [Hubzilla Stack Deployment Guide (Staging)](HUBZILLA-STAGING_DEPLOYMENT.md) and the [Stalwart Mail Stack Deployment Guide](STALWART-SEPARATE-STACK-DEPLOYMENT.md).

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
- **Production:** Portainer stack deployment with `docker-stack.yml` and `docker-stack-stalwart.yml`

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

**Passwords:**
- Use strong, randomly generated passwords
- Store in Docker Secrets (never commit to git)
- Rotate regularly

See [HUBZILLA-STAGING_DEPLOYMENT.md](HUBZILLA-STAGING_DEPLOYMENT.md#prerequisites) for details.

---

## Infrastructure Requirements

### Database
- PostgreSQL 16 with persistent volumes.
- Automated backup strategy.
- Regular maintenance (VACUUM, ANALYZE).
- Monitoring for performance and disk space.

### Backups
Configure regular backups for all persistent volumes:
- **Hubzilla Database:** `db_data` volume
- **Hubzilla Files/Uploads:** `web_root` volume
- **Stalwart Mail Data:** `stalwart_data` volume

**Backup strategy example:**
```bash
# Database backup
docker exec <postgres_container> pg_dump -U hubzilla -d hub > backup-$(date +%Y%m%d).sql

# Volume backups (example for web_root, repeat for other volumes)
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

See [HUBZILLA-STAGING_DEPLOYMENT.md](HUBZILLA-STAGING_DEPLOYMENT.md#stack-update-procedure) for details.

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

- [Hubzilla Stack Deployment Guide (Staging)](HUBZILLA-STAGING_DEPLOYMENT.md)
- [Stalwart Mail Stack Deployment Guide](STALWART-SEPARATE-STACK-DEPLOYMENT.md)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Portainer Documentation](https://docs.portainer.io/)
- [Hubzilla Documentation](https://hubzilla.org/page/hubzilla/Home)
