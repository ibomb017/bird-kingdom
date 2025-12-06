-- 添加视频支持字段到forum_posts表
ALTER TABLE forum_posts ADD COLUMN media_type VARCHAR(20) DEFAULT 'IMAGE';
ALTER TABLE forum_posts ADD COLUMN video_url VARCHAR(500);
ALTER TABLE forum_posts ADD COLUMN video_cover VARCHAR(500);
ALTER TABLE forum_posts ADD COLUMN video_duration INT;
