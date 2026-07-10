#!/bin/bash

# SMS Proxy 定时健康检查与自愈脚本
# 每5分钟运行一次，检查服务状态，并在故障时自动重启

LOG_FILE="/www/wwwroot/birdkingdom/sms-proxy/health.log"
HEALTH_URL="http://localhost:8082/internal/sms/health"
CONTAINER_NAME="birdkingdom-sms-proxy"

# 创建日志目录 (如果不存在)
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始健康检查..." >> "$LOG_FILE"

# 1. 检查 Docker 容器是否在运行
if ! docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 警告: $CONTAINER_NAME 容器未处于运行状态！尝试重新启动或创建..." >> "$LOG_FILE"
    
    # 尝试启动现有容器
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        docker start "$CONTAINER_NAME" >> "$LOG_FILE" 2>&1
    else
        # 如果容器彻底丢失，在 sms-proxy 目录执行启动
        cd /www/wwwroot/birdkingdom/sms-proxy
        docker run -d \
            --name "$CONTAINER_NAME" \
            --restart unless-stopped \
            --network host \
            --env-file .env \
            birdkingdom-sms-proxy >> "$LOG_FILE" 2>&1
    fi
    
    sleep 5
fi

# 2. 检查 HTTP 接口是否正常响应
RESPONSE=$(curl -s -m 10 "$HEALTH_URL")

if echo "$RESPONSE" | grep -q "UP"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 服务正常运行" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 警告: 服务接口响应异常或超时！返回值: $RESPONSE" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在重启 $CONTAINER_NAME 容器进行自愈..." >> "$LOG_FILE"
    docker restart "$CONTAINER_NAME" >> "$LOG_FILE" 2>&1
    
    # 重启后验证
    sleep 10
    RETRY_RESPONSE=$(curl -s -m 10 "$HEALTH_URL")
    if echo "$RETRY_RESPONSE" | grep -q "UP"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 自愈成功，服务已恢复" >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 严重警告: 自愈失败，服务重启后依然无法响应！" >> "$LOG_FILE"
    fi
fi
