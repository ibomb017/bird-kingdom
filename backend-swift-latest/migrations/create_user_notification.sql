-- ============================================
-- Bird Kingdom 消息通知表创建脚本
-- 日期: 2025-12-29
-- 目的: 创建 user_notification 表用于存储用户消息通知
-- ============================================

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
    CONSTRAINT `fk_notification_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_notification_post` FOREIGN KEY (`post_id`) REFERENCES `forum_posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户消息通知表';

-- 创建唯一索引，防止重复通知
-- 例如：同一个用户对同一个帖子的点赞，只创建一次通知
ALTER TABLE `user_notification` 
ADD UNIQUE INDEX `uk_notification_unique` (`receiver_id`, `sender_id`, `notification_type`, `post_id`, `comment_id`);

-- 查看表结构
DESCRIBE user_notification;

-- 查看索引
SHOW INDEX FROM user_notification;

SELECT '消息通知表创建完成！' AS status;
