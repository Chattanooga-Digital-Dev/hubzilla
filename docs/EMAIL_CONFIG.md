# Email Configuration

## Stalwart Mail Server Setup

### Access Admin Interface
- URL: https://localhost:8080
- Login: `admin` / password from `.env` (`STALWART_ADMIN_PASSWORD`)

[<img src="screenshots/Stalwart.png" width="500" alt="Stalwart Mail Server Web Interface"/>](screenshots/Stalwart.png)

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

[<img src="screenshots/Thunderbird.png" width="500" alt="Thunderbird Email Client with Email Aliases"/>](screenshots/Thunderbird.png)

## Troubleshooting Thunderbird & Stalwart

### View recent logs:
```bash
docker logs hubzilla_mailserver
```
### Follow logs in real-time:
```bash
docker logs -f hubzilla_mailserver
```
### View last 50 lines:
```bash
docker logs --tail 50 hubzilla_mailserver
```
### Search for errors:
```bash
docker logs hubzilla_mailserver 2>&1 | grep -i error
```
### Search for IMAP-related issues:
```bash
docker logs hubzilla_mailserver 2>&1 | grep -i imap
```
### If Thunderbird won’t trust your local HTTPS endpoint, you probably need to import your mkcert CA under Authorities:
   1. Open Preferences → Privacy & Security → Certificates → View Certificates…

   2. Select the Authorities tab

   3. Click Import… and choose your mkcert rootCA.pem (default locations):

      - Linux/macOS (Homebrew, APT): $HOME/.local/share/mkcert/rootCA.pem

      - macOS (official pkg or brew install): $HOME/Library/Application Support/mkcert/rootCA.pem

      - Windows (choco, Scoop, manual): %APPDATA%\mkcert\rootCA.pem

   4. Tick Trust this CA to identify websites, click OK, then restart Thunderbird.
