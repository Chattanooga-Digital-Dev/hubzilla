# SSL Setup

## Install mkcert
```bash
sudo apt install mkcert    # Linux
brew install mkcert        # macOS
```

## Setup
```bash
mkcert -install
mkcert -CAROOT  # Shows path - copy this
```

## Configure .env
```bash
# Set MKCERT_PATH to the path from above
MKCERT_PATH=~/.local/share/mkcert     # Linux/WSL
MKCERT_PATH=~/Library/Application Support/mkcert  # macOS
```

## Troubleshooting
- **Firefox on Linux:** `sudo apt install libnss3-tools && mkcert -install`
- **SSL errors:** Check MKCERT_PATH in .env matches `mkcert -CAROOT` output
