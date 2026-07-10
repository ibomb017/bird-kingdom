#!/bin/bash

# 🦜 Bird Kingdom Admin - 本地开发启动脚本
# 使用方法: ./start-dev.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🦜 Bird Kingdom Admin 本地开发环境启动中..."
echo ""

# 检查 Java 版本
if ! command -v java &> /dev/null; then
    echo "❌ 错误: 未找到 Java，请安装 Java 17+"
    exit 1
fi

# 检查 Node 版本
if ! command -v node &> /dev/null; then
    echo "❌ 错误: 未找到 Node.js，请安装 Node 18+"
    exit 1
fi

# 检查后端 JAR 是否存在
JAR_FILE="$SCRIPT_DIR/backend/target/admin-backend-1.0.0.jar"
if [ ! -f "$JAR_FILE" ]; then
    echo "📦 后端 JAR 不存在，正在编译..."
    cd "$SCRIPT_DIR/backend"
    mvn clean package -DskipTests -q
    if [ $? -ne 0 ]; then
        echo "❌ 编译失败"
        exit 1
    fi
    echo "✅ 编译完成"
    cd "$SCRIPT_DIR"
fi

# 停止可能存在的旧进程
echo "🔄 停止旧进程..."
pkill -f "admin-backend-1.0.0.jar" 2>/dev/null
lsof -ti:8081 | xargs kill -9 2>/dev/null
lsof -ti:3000 | xargs kill -9 2>/dev/null
sleep 1

# 创建日志目录
mkdir -p "$SCRIPT_DIR/logs"

# 启动后端
echo "🚀 启动后端服务 (端口 8081)..."
cd "$SCRIPT_DIR/backend"
nohup java -jar target/admin-backend-1.0.0.jar \
    --spring.datasource.url="jdbc:mysql://${DB_HOST:-localhost}:${DB_PORT:-3306}/${DB_NAME:-bird_kingdom}?useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true" \
    --spring.datasource.username="${DB_USER:-root}" \
    --spring.datasource.password="${DB_PASSWORD:-}" \
    > "$SCRIPT_DIR/logs/backend.log" 2>&1 &
BACKEND_PID=$!
echo "   后端 PID: $BACKEND_PID"

# 等待后端启动
echo "   等待后端启动..."
sleep 5

# 检查后端是否启动成功
if curl -s http://localhost:8081/api/admin/auth/login -o /dev/null; then
    echo "✅ 后端启动成功"
else
    echo "⚠️  后端可能仍在启动中，请检查日志: logs/backend.log"
fi

# 启动前端
echo "🚀 启动前端服务 (端口 3000)..."
cd "$SCRIPT_DIR"
npm run dev > "$SCRIPT_DIR/logs/frontend.log" 2>&1 &
FRONTEND_PID=$!
echo "   前端 PID: $FRONTEND_PID"

sleep 3

echo ""
echo "======================================"
echo "🎉 Bird Kingdom Admin 启动完成!"
echo "======================================"
echo ""
echo "🌐 前端地址: http://localhost:3000"
echo "🔧 后端地址: http://localhost:8081"
echo ""
echo "🔑 登录账号: admin"
echo "🔑 登录密码: 123456"
echo ""
echo "📋 查看日志:"
echo "   后端: tail -f logs/backend.log"
echo "   前端: tail -f logs/frontend.log"
echo ""
echo "🛑 停止服务: pkill -f 'admin-backend' && pkill -f 'vite'"
echo ""
