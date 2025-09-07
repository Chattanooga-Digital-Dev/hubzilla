#!/bin/bash
set -e

echo "=========================================="
echo "  Hubzilla Local Development SSL Setup"
echo "=========================================="

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if containers are running
if ! docker-compose ps | grep -q "hubzilla_itself"; then
    echo "❌ Hubzilla containers are not running."
    echo "   Please run: docker-compose up -d"
    exit 1
fi

echo "✅ Docker and containers are running"

# Get the CA certificate from the container
echo "📋 Extracting CA certificate from container..."

# Create ssl directory if it doesn't exist
mkdir -p ./ssl-host

# Copy CA certificate from container
if docker exec hubzilla_itself test -f /root/.local/share/mkcert/rootCA.pem; then
    docker cp hubzilla_itself:/root/.local/share/mkcert/rootCA.pem ./ssl-host/rootCA.pem
    echo "✅ CA certificate extracted to ./ssl-host/rootCA.pem"
else
    echo "❌ CA certificate not found in container. Try restarting containers:"
    echo "   docker-compose down && docker-compose up -d"
    exit 1
fi

# Detect OS and provide instructions
echo ""
echo "🔧 Next steps to trust the certificate:"

if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WSL_DISTRO_NAME" ]]; then
    echo ""
    echo "For Windows users:"
    echo "1. Open PowerShell as Administrator"
    echo "2. Run: certlm.msc"
    echo "3. Go to: Trusted Root Certification Authorities > Certificates"
    echo "4. Right-click > All Tasks > Import"
    echo "5. Import the file: $(pwd)/ssl-host/rootCA.pem"
    echo "6. Restart your browser"
    echo ""
    echo "Alternative (if you have mkcert installed on Windows):"
    echo "1. Copy: $(pwd)/ssl-host/rootCA.pem to Windows"
    echo "2. In Windows PowerShell (as Admin): mkcert -install rootCA.pem"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "For macOS users:"
    echo "1. Double-click: $(pwd)/ssl-host/rootCA.pem"
    echo "2. In Keychain Access, mark it as 'Always Trust'"
    echo "3. Restart your browser"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo ""
    echo "For Linux users:"
    echo "1. Install mkcert on your host system"
    echo "2. Run: CAROOT=./ssl-host mkcert -install"
    echo "3. Restart your browser"
fi

echo ""
echo "🌐 After installing the certificate:"
echo "   Visit: https://localhost"
echo "   You should see a green lock (secure connection)"
echo ""
echo "🔍 Troubleshooting:"
echo "   - Make sure you restart your browser after installing the certificate"
echo "   - Try visiting https://127.0.0.1 if localhost doesn't work"
echo "   - Check container logs: docker-compose logs hub"
echo ""
echo "=========================================="
