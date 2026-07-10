-- Admin Web 系统配置所需数据表
-- 执行此SQL文件以创建系统配置相关的所有表

USE bird_kingdom;

-- 1. 系统配置表
CREATE TABLE IF NOT EXISTS system_config (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    config_key VARCHAR(100) NOT NULL UNIQUE COMMENT '配置键',
    config_value TEXT NOT NULL COMMENT '配置值',
    value_type VARCHAR(20) DEFAULT 'STRING' COMMENT '值类型: STRING, NUMBER, BOOLEAN, JSON',
    description VARCHAR(500) COMMENT '配置描述',
    category VARCHAR(50) DEFAULT 'GENERAL' COMMENT '配置分类',
    is_public BOOLEAN DEFAULT FALSE COMMENT '是否公开（前端可见）',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统配置表';

-- 2. 管理员角色表（如果不存在）
CREATE TABLE IF NOT EXISTS admin_roles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_code VARCHAR(50) NOT NULL UNIQUE COMMENT '角色代码',
    role_name VARCHAR(100) NOT NULL COMMENT '角色名称',
    description VARCHAR(500) COMMENT '角色描述',
    permissions TEXT COMMENT '权限列表（JSON数组）',
    status TINYINT DEFAULT 1 COMMENT '状态: 1-启用, 0-禁用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员角色表';

-- 3. 管理员登录日志表
CREATE TABLE IF NOT EXISTS admin_login_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    admin_id BIGINT NOT NULL COMMENT '管理员ID',
    username VARCHAR(100) COMMENT '用户名',
    nickname VARCHAR(100) COMMENT '昵称',
    login_ip VARCHAR(50) COMMENT '登录IP',
    user_agent TEXT COMMENT '用户代理',
    login_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '登录时间',
    login_result BOOLEAN DEFAULT TRUE COMMENT '登录结果: true-成功, false-失败',
    failure_reason VARCHAR(200) COMMENT '失败原因',
    INDEX idx_admin (admin_id),
    INDEX idx_time (login_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员登录日志';

-- 4. 用户活跃度记录表
CREATE TABLE IF NOT EXISTS user_activity_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL COMMENT '用户ID',
    activity_date DATE NOT NULL COMMENT '活跃日期',
    login_count INT DEFAULT 1 COMMENT '当天登录次数',
    last_login_time DATETIME COMMENT '最后登录时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_date (user_id, activity_date),
    INDEX idx_user (user_id),
    INDEX idx_date (activity_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户活跃度记录表';

-- 5. 插入默认系统配置
INSERT INTO system_config (config_key, config_value, value_type, description, category, is_public) VALUES
('app.name', '鸟鸟王国', 'STRING', '应用名称', 'APP', TRUE),
('app.version', '1.0.0', 'STRING', '应用版本号', 'APP', TRUE),
('app.customer_service_phone', '400-123-4567', 'STRING', '客服电话', 'APP', TRUE),

('splash.price', '99', 'NUMBER', '开屏单价（元）', 'SPLASH', FALSE),
('splash.slots_per_day', '10', 'NUMBER', '每日开屏展位数', 'SPLASH', FALSE),
('splash.duration_seconds', '3', 'NUMBER', '开屏展示时长（秒）', 'SPLASH', FALSE),

('vip.monthly_price', '9.9', 'NUMBER', '月度VIP价格（元）', 'VIP', TRUE),
('vip.yearly_price', '88', 'NUMBER', '年度VIP价格（元）', 'VIP', TRUE),
('vip.lifetime_price', '298', 'NUMBER', '终身VIP价格（元）', 'VIP', TRUE),

('forum.max_images', '9', 'NUMBER', '帖子最大图片数', 'FORUM', FALSE),
('forum.max_content_length', '5000', 'NUMBER', '帖子最大字符数', 'FORUM', FALSE),
('forum.enable_comment', 'true', 'BOOLEAN', '是否允许评论', 'FORUM', FALSE),

('system.maintenance_mode', 'false', 'BOOLEAN', '维护模式', 'SYSTEM', FALSE),
('system.maintenance_message', '系统维护中，请稍后访问', 'STRING', '维护提示信息', 'SYSTEM', TRUE)
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- 6. 插入默认角色（如果admin_roles表为空）
INSERT INTO admin_roles (role_code, role_name, description, permissions) VALUES
('SUPER_ADMIN', '超级管理员', '拥有所有权限', '["ALL"]'),
('ADMIN', '管理员', '可管理用户、内容、财务', '["USER_MANAGE", "CONTENT_MANAGE", "FINANCE_MANAGE"]'),
('REVIEWER', '审核员', '仅可审核内容', '["CONTENT_REVIEW"]'),
('CUSTOMER_SERVICE', '客服', '可查看数据、处理反馈', '["DATA_VIEW", "FEEDBACK_MANAGE"]')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- 7. 确保admin_users表有roleCode字段
-- ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS role_code VARCHAR(50) DEFAULT 'ADMIN' COMMENT '角色代码';
-- (上面的语法在MySQL中不支持，需要手动检查)

COMMIT;

SELECT 'System configuration tables created successfully!' AS message;
