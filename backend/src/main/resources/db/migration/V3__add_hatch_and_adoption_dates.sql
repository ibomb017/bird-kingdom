-- 添加破壳日期、领养日期和生日类型字段
ALTER TABLE birds ADD COLUMN hatch_date DATE NULL COMMENT '破壳日期';
ALTER TABLE birds ADD COLUMN adoption_date DATE NULL COMMENT '领养日期';
ALTER TABLE birds ADD COLUMN birthday_type VARCHAR(20) NULL COMMENT '生日类型：HATCH或ADOPTION';

-- 将现有的 birth_date 数据迁移到 hatch_date
UPDATE birds SET hatch_date = birth_date WHERE birth_date IS NOT NULL;

-- 设置默认生日类型为破壳日期
UPDATE birds SET birthday_type = 'HATCH' WHERE hatch_date IS NOT NULL;

-- 删除旧的 birth_date 字段
ALTER TABLE birds DROP COLUMN birth_date;

-- 添加索引
CREATE INDEX idx_birds_hatch_date ON birds(hatch_date);
CREATE INDEX idx_birds_adoption_date ON birds(adoption_date);
