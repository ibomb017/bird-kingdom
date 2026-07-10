-- ============================================
-- 用户行为分析相关表 - Bird Kingdom
-- 版本: 1.0
-- 日期: 2025-12-28
-- ============================================

-- 用户行为记录表
-- 用于记录用户在平台上的所有互动行为，支撑个性化推荐
CREATE TABLE IF NOT EXISTS `user_behaviors` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `behavior_type` VARCHAR(50) NOT NULL COMMENT '行为类型: VIEW, LIKE, UNLIKE, FAVORITE, UNFAVORITE, COMMENT, SHARE, SEARCH, FOLLOW, UNFOLLOW, CREATE',
    `target_type` VARCHAR(50) NULL COMMENT '目标类型: POST, USER, COMMENT, KEYWORD',
    `target_id` BIGINT NULL COMMENT '目标ID（帖子ID、用户ID等）',
    `content` TEXT NULL COMMENT '相关内容（搜索关键词、评论内容等）',
    `metadata` TEXT NULL COMMENT '额外元数据（JSON格式）',
    `duration` INT NULL COMMENT '浏览时长（秒）- 针对 VIEW 行为',
    `bird_species` VARCHAR(100) NULL COMMENT '鸟品种（用于兴趣分析）',
    `post_type` VARCHAR(50) NULL COMMENT '帖子类型（用于内容偏好分析）',
    `latitude` DOUBLE NULL COMMENT '纬度',
    `longitude` DOUBLE NULL COMMENT '经度',
    `device_type` VARCHAR(50) NULL COMMENT '设备类型',
    `app_version` VARCHAR(50) NULL COMMENT '客户端版本',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_user_id` (`user_id`),
    INDEX `idx_behavior_type` (`behavior_type`),
    INDEX `idx_target_type_id` (`target_type`, `target_id`),
    INDEX `idx_created_at` (`created_at`),
    INDEX `idx_bird_species` (`bird_species`),
    CONSTRAINT `fk_user_behaviors_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户行为记录表';

-- 搜索日志表
-- 用于分析热门搜索和改进搜索质量
CREATE TABLE IF NOT EXISTS `search_logs` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NULL COMMENT '用户ID（匿名搜索时可为空）',
    `keyword` VARCHAR(255) NOT NULL COMMENT '搜索关键词',
    `result_count` INT NULL COMMENT '搜索结果数量',
    `has_clicked` TINYINT(1) NULL COMMENT '用户是否点击了结果',
    `clicked_post_id` BIGINT NULL COMMENT '点击的帖子ID',
    `scene` VARCHAR(50) NULL COMMENT '搜索场景（home, explore, profile等）',
    `search_duration_ms` INT NULL COMMENT '搜索耗时（毫秒）',
    `ip_address` VARCHAR(50) NULL COMMENT 'IP地址（用于地域分析）',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_keyword` (`keyword`),
    INDEX `idx_user_id` (`user_id`),
    INDEX `idx_created_at` (`created_at`),
    INDEX `idx_scene` (`scene`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='搜索日志表';

-- 用户兴趣画像表
-- 定期聚合计算用户兴趣
CREATE TABLE IF NOT EXISTS `user_interests` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL COMMENT '用户ID',
    `interest_type` VARCHAR(50) NOT NULL COMMENT '兴趣类型（bird_species, post_type, author等）',
    `interest_value` VARCHAR(255) NOT NULL COMMENT '兴趣值（具体的品种名、帖子类型等）',
    `score` DOUBLE NOT NULL DEFAULT 0 COMMENT '兴趣分数（0-100）',
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_interest` (`user_id`, `interest_type`, `interest_value`),
    INDEX `idx_user_id` (`user_id`),
    INDEX `idx_score` (`score` DESC),
    CONSTRAINT `fk_user_interests_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户兴趣画像表';

-- ============================================
-- 示例数据（可选）
-- ============================================

-- 插入一些测试用的行为数据
-- INSERT INTO `user_behaviors` (`user_id`, `behavior_type`, `target_type`, `target_id`, `bird_species`, `post_type`)
-- VALUES (1, 'VIEW', 'POST', 1, '玄凤鹦鹉', 'NORMAL');

-- ============================================
-- 有用的查询示例
-- ============================================

-- 获取热门搜索词（最近7天）
-- SELECT keyword, COUNT(*) as search_count 
-- FROM search_logs 
-- WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
-- GROUP BY keyword 
-- ORDER BY search_count DESC 
-- LIMIT 10;

-- 获取用户最感兴趣的鸟品种
-- SELECT interest_value, score 
-- FROM user_interests 
-- WHERE user_id = ? AND interest_type = 'bird_species' 
-- ORDER BY score DESC 
-- LIMIT 5;

-- 统计用户行为分布
-- SELECT behavior_type, COUNT(*) as count 
-- FROM user_behaviors 
-- WHERE user_id = ? 
-- GROUP BY behavior_type;
