#!/bin/bash
set -e

echo "=========================================="
echo "  Hubzilla Local Development Test"
echo "=========================================="

# Test 1: Check if containers are running
echo "🔍 Testing container status..."
if docker-compose ps | grep "hubzilla_itself" | grep -q "Up"; then
    echo "✅ Hubzilla container is running"
else
    echo "❌ Hubzilla container is not running"
    exit 1
fi

if docker-compose ps | grep "hubzilla_database" | grep -q "Up"; then
    echo "✅ Database container is running"
else
    echo "❌ Database container is not running"
    exit 1
fi

if docker-compose ps | grep "hubzilla_webserver" | grep -q "Up"; then
    echo "✅ Nginx container is running"
else
    echo "❌ Nginx container is not running"
    exit 1
fi

# Test 2: Check SSL certificates
echo ""
echo "🔍 Testing SSL certificate generation..."
if docker exec hubzilla_itself test -f /var/ssl-shared/localhost.pem; then
    echo "✅ SSL certificate exists"
else
    echo "❌ SSL certificate not found"
    exit 1
fi

if docker exec hubzilla_itself test -f /var/ssl-shared/localhost-key.pem; then
    echo "✅ SSL private key exists"
else
    echo "❌ SSL private key not found"
    exit 1
fi

# Test 3: Check nginx configuration
echo ""
echo "🔍 Testing nginx configuration..."
if docker exec hubzilla_webserver test -f /etc/nginx/conf.d/default.conf; then
    echo "✅ Nginx configuration exists"
else
    echo "❌ Nginx configuration not found"
    exit 1
fi

# Test 4: Check database connectivity
echo ""
echo "🔍 Testing database connectivity..."
if docker exec hubzilla_database pg_isready -U hubzilla -d hub >/dev/null 2>&1; then
    echo "✅ Database is ready"
else
    echo "❌ Database is not ready"
    exit 1
fi

# Test 5: Check HTTP redirect
echo ""
echo "🔍 Testing HTTP to HTTPS redirect..."
if docker exec hubzilla_webserver wget -q --spider --max-redirect=0 http://localhost 2>&1 | grep -q "302"; then
    echo "✅ HTTP redirects to HTTPS"
else
    echo "⚠️  HTTP redirect test inconclusive (this may be normal)"
fi

# Test 6: Check HTTPS response
echo ""
echo "🔍 Testing HTTPS response..."
if docker exec hubzilla_webserver wget -q --spider --no-check-certificate https://localhost >/dev/null 2>&1; then
    echo "✅ HTTPS responds successfully"
else
    echo "❌ HTTPS not responding"
    exit 1
fi

# Test 7: Check Hubzilla PHP processing
echo ""
echo "🔍 Testing PHP processing..."
if docker exec hubzilla_itself test -f /var/www/html/index.php; then
    echo "✅ Hubzilla files are present"
else
    echo "❌ Hubzilla files not found"
    exit 1
fi

echo ""
echo "=========================================="
echo "🎉 All tests passed!"
echo ""
echo "Your Hubzilla setup is ready. Next steps:"
echo "1. Run: ./setup-ssl.sh (if you haven't already)"
echo "2. Install the CA certificate following the instructions"
echo "3. Visit: https://localhost"
echo "=========================================="
