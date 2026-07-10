#!/bin/bash

# Bird Kingdom Swift 后端部署脚本
# 用法: ./deploy.sh [server_ip] [password]

set -e

# 服务器配置
SERVER_IP="${1:-47.84.177.155}"
SERVER_USER="root"
SERVER_PASSWORD="${2:-Chen_20040601}"
DEPLOY_PATH="/www/wwwroot/birdkingdom"

echo "=========================================="
echo "🐦 Bird Kingdom Swift 后端部署脚本"
echo "=========================================="
echo "服务器: $SERVER_USER@$SERVER_IP"
echo "部署目录: $DEPLOY_PATH"
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
    sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$1"
}

# SCP 上传文件的辅助函数
scp_upload() {
    sshpass -p "$SERVER_PASSWORD" scp -o StrictHostKeyChecking=no -r "$1" "$SERVER_USER@$SERVER_IP:$2"
}

echo "步骤 1/5: 停止并删除旧的 Java 后端..."
ssh_exec "
    # 停止 Java 进程
    pkill -f 'java.*birdkingdom' || true
    pkill -f 'java.*bird-kingdom' || true
    
    # 清理旧的 Java 文件
    rm -f $DEPLOY_PATH/*.jar
    rm -f $DEPLOY_PATH/nohup.out
    
    # 停止并删除旧的 Docker 容器（如果存在）
    docker stop birdkingdom-swift 2>/dev/null || true
    docker rm birdkingdom-swift 2>/dev/null || true
    
    echo '✅ 旧后端已清理'
"

echo "步骤 2/5: 创建部署目录..."
ssh_exec "mkdir -p $DEPLOY_PATH/swift-backend"

echo "步骤 3/5: 上传 Swift 后端源码..."
# 排除 .build 目录，只上传源码
echo "  正在打包源码..."
tar --exclude='.build' --exclude='.git' --exclude='*.tar.gz' -czf /tmp/swift-backend.tar.gz -C "$(dirname "$0")" .

echo "  正在上传..."
scp_upload "/tmp/swift-backend.tar.gz" "$DEPLOY_PATH/swift-backend/"

echo "步骤 4/5: 在服务器上解压并构建..."
ssh_exec "
    cd $DEPLOY_PATH/swift-backend
    tar -xzf swift-backend.tar.gz
    rm swift-backend.tar.gz
    
    # 检查 Docker 是否安装
    if ! command -v docker &> /dev/null; then
        echo '❌ Docker 未安装，请先安装 Docker'
        exit 1
    fi
    
    # 检查 docker-compose 是否安装
    if ! command -v docker-compose &> /dev/null; then
        echo '⚠️ docker-compose 未安装，尝试使用 docker compose'
        COMPOSE_CMD='docker compose'
    else
        COMPOSE_CMD='docker-compose'
    fi
    
    echo '正在构建 Docker 镜像（这可能需要几分钟）...'
    \$COMPOSE_CMD build
"

echo "步骤 5/5: 启动服务..."
ssh_exec "
    cd $DEPLOY_PATH/swift-backend
    
    if ! command -v docker-compose &> /dev/null; then
        COMPOSE_CMD='docker compose'
    else
        COMPOSE_CMD='docker-compose'
    fi
    
    \$COMPOSE_CMD up -d
    
    echo ''
    echo '等待服务启动...'
    sleep 5
    
    # 检查容器状态
    if docker ps | grep -q birdkingdom-swift; then
        echo '✅ Swift 后端已成功启动!'
        echo ''
        docker logs --tail 20 birdkingdom-swift
    else
        echo '❌ 服务启动失败，查看日志:'
        docker logs birdkingdom-swift
        exit 1
    fi
"

# 清理临时文件
rm -f /tmp/swift-backend.tar.gz

echo ""
echo "=========================================="
echo "✅ 部署完成!"
echo "=========================================="
echo "后端地址: http://$SERVER_IP:8080"
echo "健康检查: curl http://$SERVER_IP:8080/health"
echo ""
echo "常用命令:"
echo "  查看日志: docker logs -f birdkingdom-swift"
echo "  重启服务: docker restart birdkingdom-swift"
echo "  停止服务: docker stop birdkingdom-swift"
echo ""
