-- V9: 为 splash_quota_daily 添加 price 字段，解决价格硬编码问题
-- 之前价格硬编码在代码中为 9.9，现在改为从数据库读取
-- 注意：MySQL 5.7 不支持 ADD COLUMN IF NOT EXISTS

ALTER TABLE splash_quota_daily 
ADD COLUMN price DECIMAL(10, 2) NOT NULL DEFAULT 9.90 COMMENT '每次购买价格';
