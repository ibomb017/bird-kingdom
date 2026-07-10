#!/bin/bash

# ============================================
# Bird Kingdom 消息通知功能部署脚本
# ============================================

set -e  # 遇到错误立即退出

echo "=========================================="
echo "开始部署消息通知功能..."
echo "=========================================="

# 数据库配置
DB_HOST="rm-cn-xja3vvihf0003pj2o.rwlb.rds.aliyuncs.com"
DB_PORT="3306"
DB_NAME="bird_kingdom"
DB_USER="ibomb017"
DB_PASS="Chen_20040601"

# 服务器配置
SERVER_HOST="47.84.177.155"
SERVER_USER="root"
SERVER_PASS="Chen_20040601"

echo "步骤 1: 创建数据库表"
echo "------------------------------------------"
mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USER} -p${DB_PASS} ${DB_NAME} << 'EOF'
-- 创建 user_notification 表
CREATE TABLE IF NOT EXISTS `user_notification` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '通知ID',
    `receiver_id` BIGINT NOT NULL COMMENT '接收者用户ID',
    `sender_id` BIGINT NOT NULL COMMENT '发送者用户ID',
    `notification_type` VARCHAR(50) NOT NULL COMMENT '通知类型: POST_LIKE, POST_FAVORITE, POST_COMMENT, COMMENT_REPLY, COMMENT_LIKE, NEW_FOLLOWER',
    `content` TEXT NULL COMMENT '通知内容（如评论内容）',
    `post_id` BIGINT NULL COMMENT '相关帖子ID',
    `comment_id` BIGINT NULL COMMENT '相关评论ID',
    `is_read` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否已读：0-未读，1-已读',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    INDEX `idx_notification_receiver` (`receiver_id`, `is_read`, `created_at` DESC),
    INDEX `idx_notification_sender` (`sender_id`),
    INDEX `idx_notification_post` (`post_id`),
    INDEX `idx_notification_type` (`notification_type`),
    CONSTRAINT `fk_notification_receiver` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_notification_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户消息通知表';

-- 只有在索引不存在时才创建（避免重复索引错误）
SELECT COUNT(*) INTO @exists FROM information_schema.statistics 
WHERE table_schema = DATABASE() 
AND table_name = 'user_notification' 
AND index_name = 'uk_notification_unique';

SET @query = IF(@exists = 0, 
    'ALTER TABLE `user_notification` ADD UNIQUE INDEX `uk_notification_unique` (`receiver_id`, `sender_id`, `notification_type`, `post_id`, `comment_id`)',
    'SELECT "Index already exists" AS message');

PREPARE stmt FROM @query;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT '✅ 数据库表创建成功！' AS status;
EOF

if [ $? -eq 0 ]; then
    echo "✅ 数据库表创建成功"
else
    echo "❌ 数据库表创建失败"
    exit 1
fi

echo ""
echo "步骤 2: 打包Swift后端"
echo "------------------------------------------"
cd "$(dirname "$0")/../backend-swift"

echo "开始构建 Release 版本..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Swift 后端构建成功"
else
    echo "❌ Swift 后端构建失败"
    exit 1
fi

echo ""
echo "步骤 3: 上传到服务器"
echo "------------------------------------------"

# 创建目标目录
sshpass -p "${SERVER_PASS}" ssh ${SERVER_USER}@${SERVER_HOST} "mkdir -p /root/bird-kingdom-swift"

# 上传二进制文件
echo "上传二进制文件..."
sshpass -p "${SERVER_PASS}" scp .build/release/App ${SERVER_USER}@${SERVER_HOST}:/root/bird-kingdom-swift/

if [ $? -eq 0 ]; then
    echo "✅ 文件上传成功"
else
    echo "❌ 文件上传失败"
    exit 1
fi

echo ""
echo "步骤 4: 重启服务"
echo "------------------------------------------"

sshpass -p "${SERVER_PASS}" ssh ${SERVER_USER}@${SERVER_HOST} << 'ENDSSH'
# 停止旧服务
pkill -f "bird-kingdom-swift/App" || true
sleep 2

# 启动新服务
cd /root/bird-kingdom-swift
nohup ./App serve --env production --hostname 0.0.0.0 --port 8080 > app.log 2>&1 &

# 等待服务启动
sleep 3

# 检查服务状态
if pgrep -f "bird-kingdom-swift/App" > /dev/null; then
    echo "✅ 服务启动成功"
    echo "进程ID: $(pgrep -f 'bird-kingdom-swift/App')"
else
    echo "❌ 服务启动失败"
    echo "最后10行日志："
    tail -10 app.log
    exit 1
fi
ENDSSH

if [ $? -eq 0 ]; then
    echo "✅ 服务重启成功"
else
    echo "❌ 服务重启失败"
    exit 1
fi

echo ""
echo "步骤 5: 测试API"
echo "------------------------------------------"

# 等待服务完全启动
sleep 2

# 测试健康检查
echo "测试健康检查..."
response=$(curl -s -o /dev/null -w "%{http_code}" http://${SERVER_HOST}:8080/)
if [ "$response" = "200" ]; then
    echo "✅ 服务响应正常 (HTTP $response)"
else
    echo "⚠️  服务响应异常 (HTTP $response)"
fi

echo ""
echo "=========================================="
echo "✅ 消息通知功能部署完成！"
echo "=========================================="
echo ""
echo "API 端点："
echo "  - 获取通知列表: GET http://${SERVER_HOST}:8080/api/v1/notifications"
echo "  - 获取未读数量: GET http://${SERVER_HOST}:8080/api/v1/notifications/unread-count"
echo "  - 标记单条已读: POST http://${SERVER_HOST}:8080/api/v1/notifications/{id}/read"
echo "  - 标记全部已读: POST http://${SERVER_HOST}:8080/api/v1/notifications/mark-all-read"
echo ""
echo "触发通知的操作："
echo "  - 点赞帖子 → POST_LIKE 通知"
echo "  - 收藏帖子 → POST_FAVORITE 通知"
echo "  - 评论帖子 → POST_COMMENT 通知"
echo "  - 回复评论 → COMMENT_REPLY 通知"
echo "  - 关注用户 → NEW_FOLLOWER 通知"
echo ""
