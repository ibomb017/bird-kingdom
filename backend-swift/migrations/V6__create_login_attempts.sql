-- P0 安全修复：创建登录尝试记录表，用于防止暴力破解
-- 记录每次登录尝试，限制失败次数

CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(20) NOT NULL COMMENT '尝试登录的手机号',
    ip_address VARCHAR(45) NOT NULL COMMENT '客户端IP地址',
    success BOOLEAN NOT NULL DEFAULT FALSE COMMENT '是否成功',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '尝试时间',
    
    INDEX idx_phone_created (phone, created_at),
    INDEX idx_ip_created (ip_address, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='登录尝试记录表';
