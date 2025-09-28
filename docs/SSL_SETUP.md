# SSL Setup

## Install mkcert
```bash
sudo apt install mkcert          # Linux
brew install mkcert              # macOS
```

**Windows:** Download from https://github.com/FiloSottile/mkcert/releases

**Windows + WSL2 setup:** Install mkcert on Windows host (not WSL2) so `mkcert -install` adds the CA certificate to Windows certificate store, making Windows browsers trust the certificates.

## Setup
```bash
# MUST run as Administrator on Windows
mkcert -install
# Confirms popup to add CA to Windows certificate store
mkcert -CAROOT  # Shows path - copy this
```

**If automatic installation fails on Windows:**
1. Press Win+R → type `mmc` → Add Certificates snap-in → Computer account
2. Navigate: Trusted Root Certification Authorities → Certificates  
3. Right-click → All Tasks → Import → Select `rootCA.pem` from path above

## Configure .env
```bash
# Set MKCERT_PATH to the path from above
MKCERT_PATH=~/.local/share/mkcert                    # Linux/WSL
MKCERT_PATH=~/Library/Application Support/mkcert     # macOS
MKCERT_PATH=/mnt/c/Users/USERNAME/AppData/Local/mkcert  # Windows WSL2
```

## Troubleshooting
- **Firefox on Linux:** `sudo apt install libnss3-tools && mkcert -install`
- **SSL errors:** Check MKCERT_PATH in .env matches `mkcert -CAROOT` output
