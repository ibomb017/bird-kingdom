-- 添加死亡日期、软删除标记和用户ID字段
ALTER TABLE birds ADD COLUMN death_date DATE NULL COMMENT '死亡日期';
ALTER TABLE birds ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE COMMENT '是否已删除（软删除）';
ALTER TABLE birds ADD COLUMN deleted_at DATETIME NULL COMMENT '删除时间';
ALTER TABLE birds ADD COLUMN user_id BIGINT NULL COMMENT '所属用户ID';

-- 为已存在的数据设置默认值
UPDATE birds SET is_deleted = FALSE WHERE is_deleted IS NULL;

-- 添加索引以提高查询性能
CREATE INDEX idx_birds_user_id ON birds(user_id);
CREATE INDEX idx_birds_is_deleted ON birds(is_deleted);
CREATE INDEX idx_birds_death_date ON birds(death_date);
