#!/bin/bash

# 🦜 Bird Kingdom Admin Deployment Script
SERVER_IP="100.71.65.58"
SSH_PORT="217"
SERVER_USER="root"
SERVER_PASS="Chen_20040601"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="/www/wwwroot/birdkingdom-admin"

echo "========================================"
echo "🦜 Deploying Bird Kingdom Admin Web"
echo "========================================"

# Check sshpass
if ! command -v sshpass &> /dev/null; then
    echo "⚠️ sshpass is not installed. Installing via brew..."
    brew install hudochenkov/sshpass/sshpass || { echo "❌ Failed to install sshpass"; exit 1; }
fi

ssh_exec() {
    sshpass -p "$SERVER_PASS" ssh -p $SSH_PORT -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

# Nginx Path Detection
NGINX_CONF_DIR="/etc/nginx/conf.d"
if ssh_exec "[ -d /www/server/panel/vhost/nginx ]"; then
    NGINX_CONF_DIR="/www/server/panel/vhost/nginx"
elif ssh_exec "[ -d /www/server/nginx/conf/vhost ]"; then
    NGINX_CONF_DIR="/www/server/nginx/conf/vhost"
fi
echo "📍 Nginx Config Dir: $NGINX_CONF_DIR"
NGINX_CONF="$NGINX_CONF_DIR/birdkingdom-admin.conf"


# Build Frontend
echo "📦 Building Frontend..."
cd "$LOCAL_DIR"
npm run build

if [ ! -d "dist" ]; then
    echo "❌ Build failed: dist directory not found"
    exit 1
fi

scp_upload() {
    sshpass -p "$SERVER_PASS" scp -P $SSH_PORT -o StrictHostKeyChecking=no -r "$1" "$SERVER_USER@$SERVER_IP:$2"
}

# Create Remote Directory
echo "📂 Creating remote directory: $REMOTE_DIR"
ssh_exec "mkdir -p $REMOTE_DIR"

# Upload Files
echo "📤 Uploading dist folder..."
# Remove old dist if exists
ssh_exec "rm -rf $REMOTE_DIR/dist"
scp_upload "dist" "$REMOTE_DIR/"

# Nginx Root is now .../dist
ROOT_DIR="$REMOTE_DIR/dist"

# Configure Nginx
echo "⚙️ Configuring Nginx on Port 8088..."
ssh_exec "cat > $NGINX_CONF << EOF
server {
    listen 8088;
    server_name _;
    root /www/wwwroot/birdkingdom-admin/dist;
    index index.html;

    # Handle SPA routing
    location / {
        try_files \\\$uri \\\$uri/ /index.html;
    }
}
EOF

# Reload Nginx
nginx -t && nginx -s reload

# 同步到主站 /admin/ 目录 (birdkingdom.xyz/admin/ 需要)
echo '📂 Syncing to main site /admin/ directory...'
rm -rf /www/wwwroot/birdkingdom/admin/*
cp -r /www/wwwroot/birdkingdom-admin/dist/* /www/wwwroot/birdkingdom/admin/
echo '✅ Main site admin synced'
"

echo "========================================"
echo "✅ Deployment Complete!"
echo "🌍 Admin Access: https://birdkingdom.xyz/admin/dashboard"
echo "========================================"
