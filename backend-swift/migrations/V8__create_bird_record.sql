-- 创建鸟儿记录表（产蛋/洗澡周期记录）
-- V8__create_bird_record.sql

CREATE TABLE IF NOT EXISTS bird_record (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bird_id BIGINT NOT NULL COMMENT '鸟儿ID',
    record_type VARCHAR(32) NOT NULL COMMENT '记录类型：EGG_LAYING（产蛋）/BATHING（洗澡）',
    record_date DATE NOT NULL COMMENT '记录日期（开始日期）',
    end_date DATE NULL COMMENT '结束日期（可选）',
    notes TEXT NULL COMMENT '备注',
    egg_count INT NULL COMMENT '产蛋数量（仅产蛋类型）',
    hatched_count INT NULL COMMENT '孵化成功数量（仅产蛋类型）',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_bird_id (bird_id),
    INDEX idx_record_type (record_type),
    INDEX idx_record_date (record_date),
    FOREIGN KEY (bird_id) REFERENCES bird(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='鸟儿周期记录表（产蛋/洗澡）';
