#!/bin/bash

# 🦜 Bird Kingdom Admin - 服务器部署脚本
# 服务器: 47.84.177.155 (公网) / 100.71.65.58 (Tailscale)
# 使用方法: ./deploy-admin.sh

set -e

SERVER_IP="100.71.65.58"
SERVER_USER="root"
REMOTE_DIR="/opt/bird-kingdom-admin"
JAR_NAME="admin-backend-1.0.0.jar"
LOCAL_JAR="backend/target/$JAR_NAME"

echo "🦜 Bird Kingdom Admin 部署脚本"
echo "======================================"
echo ""

# 检查 JAR 文件
if [ ! -f "$LOCAL_JAR" ]; then
    echo "📦 JAR 文件不存在，正在编译..."
    cd backend
    mvn clean package -DskipTests -q
    cd ..
fi

echo "✅ JAR 文件已准备: $LOCAL_JAR"

# 上传 JAR 文件和配置文件
echo "📤 上传 JAR 文件和配置文件到服务器..."
scp -P 217 -o StrictHostKeyChecking=no "$LOCAL_JAR" "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/$JAR_NAME"
scp -P 217 -o StrictHostKeyChecking=no scripts/birdkingdom-admin.service scripts/birdkingdom-admin.logrotate scripts/db_backup.sh "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/"

echo "🚀 配置并重启远程服务..."
ssh -p 217 -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << EOF
    cd $REMOTE_DIR
    
    # 停止旧进程（如果存在独立的非 systemd 运行实例）
    pkill -f "$JAR_NAME" 2>/dev/null || true
    sleep 2
    
    # 创建相关目录
    mkdir -p logs scripts backups
    
    # 移动系统配置文件和脚本
    mv birdkingdom-admin.service /etc/systemd/system/
    mv birdkingdom-admin.logrotate /etc/logrotate.d/
    mv db_backup.sh scripts/
    chmod +x scripts/db_backup.sh
    
    # 加载 systemd 并启用开机自启
    systemctl daemon-reload
    systemctl enable birdkingdom-admin
    
    # 启动/重启服务
    systemctl restart birdkingdom-admin
    
    # 配置定时任务：每天凌晨2:00自动备份数据库
    CRON_CMD="0 2 * * * /opt/bird-kingdom-admin/scripts/db_backup.sh >> /opt/bird-kingdom-admin/backups/backup.log 2>&1"
    (crontab -l 2>/dev/null | grep -F "db_backup.sh" >/dev/null) || (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    
    echo "⌛️ 等待服务启动中..."
    sleep 5
    
    # 检查进程与服务状态
    if systemctl is-active --quiet birdkingdom-admin; then
        echo "✅ Admin 后端启动成功 (Systemd 托管)!"
        tail -20 logs/admin-backend.log
    else
        echo "❌ 启动失败，Systemd 状态："
        systemctl status birdkingdom-admin --no-pager | head -n 30
        echo "📋 最近日志："
        tail -50 logs/admin-backend.log
    fi
EOF

echo ""
echo "======================================"
echo "🎉 部署与维护配置完成!"
echo ""
echo "🔧 后端地址 (Systemd 托管): http://$SERVER_IP:8081"
echo "📋 查看日志: ssh $SERVER_USER@$SERVER_IP 'tail -f $REMOTE_DIR/logs/admin-backend.log'"
echo "💾 自动备份: 每天凌晨 2:00 备份至 $REMOTE_DIR/backups/"
echo ""
