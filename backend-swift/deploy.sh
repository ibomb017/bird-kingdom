#!/bin/bash

# Bird Kingdom 后端部署脚本
# 用法: ./deploy.sh [server_ip] [password]
# 
# 此脚本会部署：
# 1. Swift 后端 (8080 端口)
# 2. SMS 代理服务 (8082 端口)

# set -e

# 服务器配置
SERVER_IP="${1:-47.84.177.155}"
SERVER_PORT=217
SERVER_USER="root"
SERVER_PASSWORD="${2:-Chen_20040601}"
DEPLOY_PATH="/www/wwwroot/birdkingdom"

echo "=========================================="
echo "🐦 Bird Kingdom 全栈后端部署脚本"
echo "=========================================="
echo "服务器: $SERVER_USER@$SERVER_IP:$SERVER_PORT"
echo "部署目录: $DEPLOY_PATH"
echo "部署内容: Swift 后端 (8080) + SMS 代理 (8082)"
echo ""

# 检查 sshpass 是否安装
if ! command -v sshpass &> /dev/null; then
    echo "⚠️ sshpass 未安装，正在安装..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install hudochenkov/sshpass/sshpass
    else
        echo "请手动安装 sshpass: apt-get install sshpass 或 yum install sshpass"
        exit 1
    fi
fi

# SSH 执行命令的辅助函数
ssh_exec() {
    sshpass -p "$SERVER_PASSWORD" ssh -p $SERVER_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no "$SERVER_USER@$SERVER_IP" "$1"
}

# SCP 上传文件的辅助函数
scp_upload() {
    sshpass -p "$SERVER_PASSWORD" scp -P $SERVER_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no -r "$1" "$SERVER_USER@$SERVER_IP:$2" 2>/dev/null
}

echo "步骤 0/7: 检查服务器连接..."
if ! ssh_exec "echo '连接成功'" > /dev/null; then
    echo "❌ 无法连接到服务器 $SERVER_IP:$SERVER_PORT"
    exit 1
fi
echo "✅ 连接检查通过"
echo ""

echo "步骤 0.5/7: 检查及修复数据库状态..."
ssh_exec "
    # 检查3306端口是否监听
    if ! netstat -tlnp | grep -q ':3306'; then
        echo '⚠️ 数据库未运行(端口3306未监听)，尝试启动...'
        service mysql start || systemctl start mysql || /etc/init.d/mysql start
        sleep 5
    else
        echo '✅ 数据库端口(3306)监听中'
    fi

    # 二次检查
    if ! netstat -tlnp | grep -q ':3306'; then
        echo '❌ 数据库启动失败！请登录服务器手动检查 MySQL 服务'
        exit 1
    fi
    
    # 尝试简单的连接测试
    if command -v mysql >/dev/null; then
         if mysql -uroot -p$SERVER_PASSWORD -e 'SELECT 1' >/dev/null 2>&1; then
             echo '✅ 数据库连接验证成功'
         else
             echo '⚠️ 数据库端口运行中，但本地连接测试失败(可能是密码错误或权限问题)，尝试继续...'
         fi
    fi
"
if [ $? -ne 0 ]; then
    echo "❌ 数据库检查未通过，终止部署"
    exit 1
fi


# ============================================
# 步骤 1: 停止旧服务
# ============================================
echo "步骤 1/7: 停止旧服务..."
ssh_exec "
    # 停止 Swift 后端 Docker 容器
    docker stop birdkingdom-swift 2>/dev/null || true
    docker rm birdkingdom-swift 2>/dev/null || true
    
    # 停止 SMS 代理服务
    pkill -f 'sms-proxy' 2>/dev/null || true
    pkill -f 'java.*8082' 2>/dev/null || true
    
    echo '✅ 旧服务已停止'
"

# ============================================
# 步骤 2: 创建部署目录
# ============================================
echo "步骤 2/7: 创建部署目录..."
ssh_exec "mkdir -p $DEPLOY_PATH/swift-backend $DEPLOY_PATH/sms-proxy"

# ============================================
# 步骤 3: 打包并上传 Swift 后端
# ============================================
echo "步骤 3/7: 打包上传 Swift 后端..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWIFT_DIR="$SCRIPT_DIR"

echo "  正在打包 Swift 后端源码..."
tar --exclude='.build' --exclude='.git' --exclude='*.tar.gz' --exclude='.env' -czf /tmp/swift-backend.tar.gz -C "$SWIFT_DIR" .

echo "  正在上传 Swift 后端..."
scp_upload "/tmp/swift-backend.tar.gz" "$DEPLOY_PATH/swift-backend/"
rm -f /tmp/swift-backend.tar.gz

echo "步骤 3.5/7: 上传 Swift 后端配置文件 (.env)..."
if [ -f "$SWIFT_DIR/../.env.swift.prod" ]; then
    echo "  正在上传生产环境配置 .env.swift.prod 为 .env..."
    scp_upload "$SWIFT_DIR/../.env.swift.prod" "$DEPLOY_PATH/swift-backend/.env"
else
    echo "  ⚠️ 本地没有找到 .env.swift.prod 配置！"
fi

# ============================================
# 步骤 4: 打包并上传 SMS 代理
# ============================================
echo "步骤 4/7: 打包上传 SMS 代理..."
SMS_DIR="$(dirname "$SCRIPT_DIR")/sms-proxy"

if [ -d "$SMS_DIR" ]; then
    echo "  正在打包 SMS 代理源码..."
    tar --exclude='target' --exclude='.git' --exclude='*.tar.gz' -czf /tmp/sms-proxy.tar.gz -C "$SMS_DIR" .
    
    echo "  正在上传 SMS 代理..."
    scp_upload "/tmp/sms-proxy.tar.gz" "$DEPLOY_PATH/sms-proxy/"
    rm -f /tmp/sms-proxy.tar.gz
    
    echo "步骤 4.5/7: 上传 SMS 代理配置文件 (.env)..."
    if [ -f "$SWIFT_DIR/../.env.sms.prod" ]; then
        echo "  正在上传生产环境配置 .env.sms.prod 为 .env..."
        scp_upload "$SWIFT_DIR/../.env.sms.prod" "$DEPLOY_PATH/sms-proxy/.env"
    else
        echo "  ⚠️ 本地没有找到 .env.sms.prod 配置！"
    fi
else
    echo "  ⚠️ SMS 代理目录不存在: $SMS_DIR，跳过"
fi

# ============================================
# 步骤 5: 在服务器上部署 Swift 后端
# ============================================
echo "步骤 5/7: 部署 Swift 后端..."
ssh_exec "
    cd $DEPLOY_PATH/swift-backend
    tar -xzf swift-backend.tar.gz
    rm -f swift-backend.tar.gz
    
    # 检查是否存在 .env 文件，如果存在则跳过创建（保留用户已配置的环境变量）
    if [ -f .env ]; then
        echo "  ⚠️ .env 文件已存在，跳过覆盖（保留现有配置）"
    else
        # 创建生产环境配置
        cat > .env << 'ENVEOF'
# Bird Kingdom Swift 后端 - 生产环境配置
HOST=0.0.0.0
PORT=8080

# 数据库配置 - 服务器直连
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=Chen_20040601
DB_NAME=bird_kingdom
DB_USE_SSL=false

# JWT 配置
JWT_SECRET=YmlyZ2tpbmdkb21fcHJvZHVjdGlvbl9zZWNyZXRfa2V5XzIwMjQ=

# SMS 代理配置
SMS_PROXY_URL=http://host.docker.internal:8082/internal/sms/send
SMS_PROXY_API_KEY=birdkingdom-sms-proxy-2026-production-key

# 生产模式
APP_DEV_MODE=false
ENVEOF
        echo '  配置文件已创建'
    fi
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        echo '❌ Docker 未安装'
        exit 1
    fi
    
    # 使用 docker-compose 构建和启动
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD='docker-compose'
    else
        COMPOSE_CMD='docker compose'
    fi
    
    echo '  正在构建 Docker 镜像（可能需要几分钟）...'
    # Fix DNS issue for swift package resolve (use Aliyun/China DNS)
    sed -i '/nameserver 8.8.8.8/d' /etc/resolv.conf
    grep -q "223.5.5.5" /etc/resolv.conf || echo "nameserver 223.5.5.5" >> /etc/resolv.conf
    grep -q "114.114.114.114" /etc/resolv.conf || echo "nameserver 114.114.114.114" >> /etc/resolv.conf
    \$COMPOSE_CMD build --no-cache
    \$COMPOSE_CMD up -d
    
    echo '✅ Swift 后端部署完成'
"

# ============================================
# 步骤 6: 在服务器上部署 SMS 代理
# ============================================
echo "步骤 6/7: 部署 SMS 代理..."
ssh_exec "
    cd $DEPLOY_PATH/sms-proxy
    
    if [ -f 'sms-proxy.tar.gz' ]; then
        tar -xzf sms-proxy.tar.gz
        rm -f sms-proxy.tar.gz
        
# 创建 SMS 代理配置 (同理，不覆盖现有配置)
        if [ ! -f .env ]; then
            cat > .env << 'ENVEOF'
SERVER_PORT=8082
API_KEY=birdkingdom-sms-proxy-2026-production-key

# 邮件配置
EMAIL_PASSWORD=DJhp2VNDVPDQcHsp

# 阿里云短信配置
ALIYUN_SMS_ACCESS_KEY_ID=LTAI5tSSgxxxxxxxxx
ALIYUN_SMS_ACCESS_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
ALIYUN_SMS_SIGN_NAME=鸟鸟王国
ALIYUN_SMS_TEMPLATE_CODE=SMS_123456789
ENVEOF
            echo '  配置文件已创建'
        else
            echo '  ⚠️ .env 文件已存在，跳过覆盖（保留现有配置）'
        fi
        
        echo '  正在停止旧的 SMS 容器...'
        docker stop birdkingdom-sms-proxy 2>/dev/null || true
        docker rm birdkingdom-sms-proxy 2>/dev/null || true
        
        echo '  正在构建 SMS 代理 Docker 镜像（包含 Maven 构建）...'
        docker build --network host -t birdkingdom-sms-proxy .
        
        echo '  正在启动 SMS 代理容器...'
        # 使用 host 网络模式，彻底避免 Docker bridge 网卡在重启后发生 DNS/外网阻断问题
        docker run -d \
            --name birdkingdom-sms-proxy \
            --restart unless-stopped \
            --network host \
            --env-file .env \
            birdkingdom-sms-proxy
            
        echo '  正在配置定时健康监视自愈任务...'
        chmod +x check_sms_health.sh
        CRON_JOB="*/5 * * * * /www/wwwroot/birdkingdom/sms-proxy/check_sms_health.sh"
        (crontab -l 2>/dev/null | grep -Fv "check_sms_health.sh" ; echo "$CRON_JOB") | crontab -
            
        echo '✅ SMS 代理部署与健康监控配置完成 (Docker)'
    else
        echo '  ⚠️ SMS 代理包不存在，跳过部署'
    fi
"

# ============================================
# 步骤 7: 验证部署
# ============================================
echo "步骤 7/7: 验证部署..."
sleep 5

ssh_exec "
    echo ''
    echo '=========================================='
    echo '服务状态检查'
    echo '=========================================='
    
    # 检查 Swift 后端
    echo -n 'Swift 后端 (8080): '
    if docker ps | grep -q birdkingdom-swift; then
        echo '✅ 运行中'
    else
        echo '❌ 未运行'
    fi
    
    # 检查 SMS 代理
    echo -n 'SMS 代理 (8082): '
    if docker ps | grep -q birdkingdom-sms-proxy; then
        echo '✅ 运行中 (Docker)'
    else
        echo '❌ 未运行'
    fi
    
    echo ''
    echo '端口监听状态:'
    netstat -tlnp 2>/dev/null | grep -E ':8080|:8082' || echo '无监听端口'
    
    echo ''
    echo 'Docker 容器状态:'
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'NAMES|birdkingdom'
"

echo ""
echo "=========================================="
echo "✅ 部署完成!"
echo "=========================================="
echo "Swift 后端: https://$SERVER_IP:8080 (通过 Nginx: https://birdkingdom.xyz)"
echo "SMS 代理: http://$SERVER_IP:8082 (内部使用)"
echo ""
echo "常用命令:"
echo "  查看 Swift 日志: docker logs -f birdkingdom-swift"
echo "  查看 SMS 日志: tail -f $DEPLOY_PATH/sms-proxy/sms-proxy.log"
echo "  重启 Swift: docker restart birdkingdom-swift"
echo ""
