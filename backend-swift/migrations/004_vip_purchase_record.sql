-- VIP 购买记录表
-- 用于防止同一笔 Apple 交易被恢复到多个账号

CREATE TABLE IF NOT EXISTS vip_purchase_record (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    original_transaction_id VARCHAR(255) NOT NULL UNIQUE,
    product_id VARCHAR(255) NOT NULL,
    purchase_date DATETIME NOT NULL,
    expires_date DATETIME NULL,
    verification_status VARCHAR(50) DEFAULT 'verified',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_original_transaction_id (original_transaction_id),
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 添加说明
COMMENT ON TABLE vip_purchase_record IS 'VIP 购买记录表，用于防止 Apple 交易被多账号恢复';
