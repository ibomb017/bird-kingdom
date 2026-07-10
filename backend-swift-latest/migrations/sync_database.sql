-- ============================================
-- Bird Kingdom 数据库同步脚本
-- 日期: 2025-12-28
-- 目的: 同步Swift后端所需的表结构
-- ============================================

-- ============================================
-- 第1部分: 创建新增的用户行为分析表
-- ============================================

-- 1. 用户行为记录表
CREATE TABLE IF NOT EXISTS `user_behaviors` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `behavior_type` VARCHAR(50) NOT NULL COMMENT '行为类型: VIEW, LIKE, UNLIKE, FAVORITE, UNFAVORITE, COMMENT, SHARE, SEARCH, FOLLOW, UNFOLLOW, CREATE',
    `target_type` VARCHAR(50) NULL COMMENT '目标类型: POST, USER, COMMENT, KEYWORD',
    `target_id` BIGINT NULL COMMENT '目标ID',
    `content` TEXT NULL COMMENT '相关内容',
    `metadata` TEXT NULL COMMENT '额外元数据',
    `duration` INT NULL COMMENT '浏览时长（秒）',
    `bird_species` VARCHAR(100) NULL COMMENT '鸟品种',
    `post_type` VARCHAR(50) NULL COMMENT '帖子类型',
    `latitude` DOUBLE NULL COMMENT '纬度',
    `longitude` DOUBLE NULL COMMENT '经度',
    `device_type` VARCHAR(50) NULL COMMENT '设备类型',
    `app_version` VARCHAR(50) NULL COMMENT '客户端版本',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_user_behaviors_user_id` (`user_id`),
    INDEX `idx_user_behaviors_behavior_type` (`behavior_type`),
    INDEX `idx_user_behaviors_target` (`target_type`, `target_id`),
    INDEX `idx_user_behaviors_created_at` (`created_at`),
    CONSTRAINT `fk_user_behaviors_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户行为记录表';

-- 2. 搜索日志表
CREATE TABLE IF NOT EXISTS `search_logs` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NULL COMMENT '用户ID',
    `keyword` VARCHAR(255) NOT NULL COMMENT '搜索关键词',
    `result_count` INT NULL COMMENT '搜索结果数量',
    `has_clicked` TINYINT(1) NULL COMMENT '是否点击了结果',
    `clicked_post_id` BIGINT NULL COMMENT '点击的帖子ID',
    `scene` VARCHAR(50) NULL COMMENT '搜索场景',
    `search_duration_ms` INT NULL COMMENT '搜索耗时（毫秒）',
    `ip_address` VARCHAR(50) NULL COMMENT 'IP地址',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_search_logs_keyword` (`keyword`),
    INDEX `idx_search_logs_user_id` (`user_id`),
    INDEX `idx_search_logs_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='搜索日志表';

-- 3. 用户兴趣画像表
CREATE TABLE IF NOT EXISTS `user_interests` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `interest_type` VARCHAR(50) NOT NULL COMMENT '兴趣类型',
    `interest_value` VARCHAR(255) NOT NULL COMMENT '兴趣值',
    `score` DOUBLE NOT NULL DEFAULT 0 COMMENT '兴趣分数',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_interests` (`user_id`, `interest_type`, `interest_value`),
    INDEX `idx_user_interests_user_id` (`user_id`),
    INDEX `idx_user_interests_score` (`score` DESC),
    CONSTRAINT `fk_user_interests_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户兴趣画像表';

-- ============================================
-- 第2部分: 删除冗余表
-- 说明: forum_comments 表是冗余的，系统使用 post_comments
-- ============================================

-- 检查并删除冗余的 forum_comments 表（如果存在且没有有用数据）
-- 先检查是否有数据
SELECT COUNT(*) AS forum_comments_count FROM forum_comments;
-- 如果没有数据或数据已迁移到 post_comments，可以删除
-- DROP TABLE IF EXISTS forum_comments;

-- ============================================
-- 第3部分: 确保所有必需的索引存在
-- ============================================

-- forum_posts 表索引
ALTER TABLE `forum_posts` ADD INDEX IF NOT EXISTS `idx_forum_posts_author` (`author_id`);
ALTER TABLE `forum_posts` ADD INDEX IF NOT EXISTS `idx_forum_posts_created` (`created_at` DESC);
ALTER TABLE `forum_posts` ADD INDEX IF NOT EXISTS `idx_forum_posts_type` (`post_type`);
ALTER TABLE `forum_posts` ADD INDEX IF NOT EXISTS `idx_forum_posts_location` (`latitude`, `longitude`);

-- post_comments 表索引
ALTER TABLE `post_comments` ADD INDEX IF NOT EXISTS `idx_post_comments_post` (`post_id`);
ALTER TABLE `post_comments` ADD INDEX IF NOT EXISTS `idx_post_comments_author` (`author_id`);

-- user_follows 表索引
ALTER TABLE `user_follows` ADD INDEX IF NOT EXISTS `idx_user_follows_follower` (`follower_id`);
ALTER TABLE `user_follows` ADD INDEX IF NOT EXISTS `idx_user_follows_following` (`following_id`);

-- post_likes 表索引
ALTER TABLE `post_likes` ADD INDEX IF NOT EXISTS `idx_post_likes_post` (`post_id`);
ALTER TABLE `post_likes` ADD INDEX IF NOT EXISTS `idx_post_likes_user` (`user_id`);

-- post_favorites 表索引
ALTER TABLE `post_favorites` ADD INDEX IF NOT EXISTS `idx_post_favorites_post` (`post_id`);
ALTER TABLE `post_favorites` ADD INDEX IF NOT EXISTS `idx_post_favorites_user` (`user_id`);

-- ============================================
-- 第4部分: 数据验证查询
-- ============================================

-- 查看所有表
SHOW TABLES;

-- 查看新建表的结构
DESCRIBE user_behaviors;
DESCRIBE search_logs;
DESCRIBE user_interests;

SELECT '数据库同步完成！' AS status;
