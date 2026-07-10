#!/bin/bash

# =========================================================================
# birdkingdom.xyz - Domestic Server Reverse Proxy Deployment Script
# =========================================================================

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (using sudo)."
    exit 1
fi

echo "=========================================="
echo "Starting Proxy & Compliance Setup..."
echo "=========================================="

# 1. Detect Package Manager and Install Nginx
if [ -x "$(command -v apt-get)" ]; then
    echo "[+] Debian/Ubuntu system detected. Updating and installing Nginx..."
    apt-get update -y
    apt-get install -y nginx
elif [ -x "$(command -v yum)" ]; then
    echo "[+] CentOS/RHEL system detected. Installing Nginx..."
    yum install -y epel-release
    yum install -y nginx
else
    echo "[-] Error: Unsupported system package manager. Please install Nginx manually."
    exit 1
fi

# 2. Create Directory Structures
echo "[+] Creating directory structures..."
mkdir -p /var/www/birdkingdom
mkdir -p /etc/nginx/certs

# 3. Copy Compliance Page and Configuration (relative to script path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

if [ -f "$SCRIPT_DIR/index.html" ]; then
    echo "[+] Copying index.html to /var/www/birdkingdom/..."
    cp "$SCRIPT_DIR/index.html" /var/www/birdkingdom/index.html
else
    echo "[-] Warning: index.html not found in script directory. Creating default..."
    echo "<h1>网站建设中</h1>" > /var/www/birdkingdom/index.html
fi

if [ -f "$SCRIPT_DIR/nginx_proxy.conf" ]; then
    echo "[+] Copying nginx_proxy.conf to /etc/nginx/conf.d/birdkingdom.conf..."
    cp "$SCRIPT_DIR/nginx_proxy.conf" /etc/nginx/conf.d/birdkingdom.conf
else
    echo "[-] Error: nginx_proxy.conf not found. Cannot configure proxy."
    exit 1
fi

# 4. Handle SSL Certificates (Self-signed temporary certs if not provided)
if [ ! -f /etc/nginx/certs/birdkingdom.xyz.pem ] || [ ! -f /etc/nginx/certs/birdkingdom.xyz.key ]; then
    echo "[!] SSL Certificates not found in /etc/nginx/certs/."
    echo "[!] Creating temporary self-signed certificates to prevent Nginx from failing to start..."
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/certs/birdkingdom.xyz.key \
        -out /etc/nginx/certs/birdkingdom.xyz.pem \
        -subj "/C=CN/ST=Zhejiang/L=Hangzhou/O=BirdKingdom/CN=birdkingdom.xyz"
    
    echo "[!] Self-signed certificate created."
    echo "[!] IMPORTANT: Please upload your real SSL certificates (from Alibaba Cloud/Tencent Cloud) to:"
    echo "    - /etc/nginx/certs/birdkingdom.xyz.pem"
    echo "    - /etc/nginx/certs/birdkingdom.xyz.key"
fi

# 5. Enable and Test Nginx
echo "[+] Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "[+] Nginx configuration test succeeded. Starting and enabling Nginx..."
    systemctl enable nginx
    systemctl restart nginx
    echo "=========================================="
    echo "✔ Deployment Successful!"
    echo "✔ Compliance page is live on HTTP/HTTPS."
    echo "✔ Nginx is configured to forward API calls to Singapore."
    echo "=========================================="
else
    echo "[-] Error: Nginx configuration test failed. Please verify conf.d/birdkingdom.conf."
    exit 1
fi
