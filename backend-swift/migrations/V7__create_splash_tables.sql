-- 创建开屏庆生相关表
-- V7__create_splash_tables.sql

-- 1. 每日名额表
CREATE TABLE IF NOT EXISTS splash_quota_daily (
    display_date DATE PRIMARY KEY COMMENT '展示日期（主键）',
    total_slots INT NOT NULL DEFAULT 10 COMMENT '每日总名额',
    sold_slots INT NOT NULL DEFAULT 0 COMMENT '已售出名额',
    reserved_slots INT NOT NULL DEFAULT 0 COMMENT '已预订名额（待支付）',
    version INT NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='开屏庆生每日名额表';

-- 2. 订单表
CREATE TABLE IF NOT EXISTS splash_order (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL COMMENT '用户ID',
    slot_id BIGINT NULL COMMENT '关联的展示槽ID',
    display_date DATE NOT NULL COMMENT '展示日期',
    amount DECIMAL(10, 2) NOT NULL DEFAULT 9.90 COMMENT '订单金额',
    payment_method VARCHAR(32) NULL COMMENT '支付方式：APPLE_IAP/WECHAT/ALIPAY',
    payment_id VARCHAR(128) NULL COMMENT '支付平台订单号',
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' COMMENT '状态：PENDING/PAID/CANCELLED/EXPIRED/REFUNDED',
    expire_at DATETIME NOT NULL COMMENT '订单过期时间（15分钟）',
    paid_at DATETIME NULL COMMENT '支付时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_display_date (display_date),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='开屏庆生订单表';

-- 3. 展示槽表
CREATE TABLE IF NOT EXISTS splash_display_slot (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT NOT NULL COMMENT '关联订单ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    display_date DATE NOT NULL COMMENT '展示日期',
    image_url VARCHAR(512) NULL COMMENT '图片URL',
    oss_object_key VARCHAR(256) NULL COMMENT 'OSS对象键',
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING_UPLOAD' COMMENT '状态：PENDING_UPLOAD/PENDING_REVIEW/APPROVED/REJECTED',
    slot_number INT NOT NULL DEFAULT 0 COMMENT '槽位编号',
    review_status VARCHAR(32) NULL COMMENT '审核状态',
    review_reason VARCHAR(256) NULL COMMENT '审核原因',
    reviewed_at DATETIME NULL COMMENT '审核时间',
    reviewed_by BIGINT NULL COMMENT '审核人ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_order_id (order_id),
    INDEX idx_display_date (display_date),
    INDEX idx_status (status),
    FOREIGN KEY (order_id) REFERENCES splash_order(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='开屏庆生展示槽表';

-- 4. 初始化未来30天的名额数据
INSERT IGNORE INTO splash_quota_daily (display_date, total_slots, sold_slots, reserved_slots)
SELECT 
    DATE_ADD(CURDATE(), INTERVAL n DAY) as display_date,
    10 as total_slots,
    0 as sold_slots,
    0 as reserved_slots
FROM (
    SELECT 0 as n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
    UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9
    UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14
    UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19
    UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23 UNION SELECT 24
    UNION SELECT 25 UNION SELECT 26 UNION SELECT 27 UNION SELECT 28 UNION SELECT 29
    UNION SELECT 30
) numbers;
