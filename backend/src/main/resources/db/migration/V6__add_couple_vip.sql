-- 添加情侣会员字段到users表
ALTER TABLE users ADD COLUMN is_couple_vip BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN couple_partner_id BIGINT;

-- 添加情侣鸟标识到birds表
ALTER TABLE birds ADD COLUMN is_couple_bird BOOLEAN DEFAULT FALSE;
ALTER TABLE birds ADD COLUMN couple_bird_partner_id BIGINT;
