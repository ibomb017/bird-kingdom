-- 百科相关表初始化脚本
-- 使用 UTF-8 编码
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- 创建鸟类百科表
CREATE TABLE IF NOT EXISTS bird_encyclopedia (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL COMMENT '鸟类名称',
    scientific_name VARCHAR(100) COMMENT '学名',
    category VARCHAR(50) COMMENT '分类',
    tags VARCHAR(200) COMMENT '标签，逗号分隔',
    description TEXT COMMENT '简介描述',
    feeding_tips TEXT COMMENT '喂养要点',
    habitat VARCHAR(100) COMMENT '原产地',
    lifespan INT COMMENT '平均寿命（年）',
    color_hex VARCHAR(10) COMMENT '代表颜色',
    image_url VARCHAR(255) COMMENT '图片URL',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建症状表
CREATE TABLE IF NOT EXISTS symptoms (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL COMMENT '症状名称',
    description TEXT COMMENT '症状描述',
    possible_causes TEXT COMMENT '可能原因，逗号分隔',
    suggestions TEXT COMMENT '处理建议，逗号分隔',
    severity VARCHAR(20) COMMENT '严重程度: low, medium, high',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建羽色基因表
CREATE TABLE IF NOT EXISTS color_genes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL COMMENT '羽色名称',
    code VARCHAR(20) COMMENT '基因代码',
    display_color VARCHAR(10) COMMENT '显示颜色（十六进制）',
    is_dominant BOOLEAN DEFAULT FALSE COMMENT '是否显性',
    description TEXT COMMENT '描述',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 插入鸟类百科数据
INSERT INTO bird_encyclopedia (name, scientific_name, category, tags, description, feeding_tips, habitat, lifespan, color_hex) VALUES
('文鸟', 'Lonchura striata', '雀形目', '适合新手,群居,易繁殖', '文鸟是最受欢迎的观赏鸟之一，性格温顺，叫声悦耳。原产于东南亚，现已广泛人工繁殖。', '主食为谷物种子，需补充青菜和钙质。保持清洁饮水，定期日光浴。', '东南亚热带地区', 8, '#8B4513'),
('牡丹鹦鹉', 'Agapornis', '鹦形目', '情侣鸟,活泼,色彩丰富', '牡丹鹦鹉又称爱情鸟，因其成双成对的习性而得名。羽色艳丽，性格活泼好动。', '以混合种子为主，搭配新鲜蔬果。需要较大活动空间和玩具。', '非洲大陆', 15, '#2E8B57'),
('虎皮鹦鹉', 'Melopsittacus undulatus', '鹦形目', '会说话,聪明,适合新手', '虎皮鹦鹉是最常见的宠物鹦鹉，因背部条纹似虎皮而得名。聪明活泼，可训练说话。', '谷物种子为主，定期提供蔬菜水果。需要磨嘴石和钙质补充。', '澳大利亚内陆', 10, '#4169E1'),
('金丝雀', 'Serinus canaria', '雀形目', '歌声优美,独居,观赏性强', '金丝雀以其优美的歌声闻名，是传统的笼养观赏鸟。雄鸟善鸣，羽色金黄。', '专用金丝雀粮为主，补充蛋黄和青菜。保持安静环境有助于鸣唱。', '加那利群岛', 12, '#FFD700'),
('珍珠鸟', 'Taeniopygia guttata', '雀形目', '小巧可爱,群居,易饲养', '珍珠鸟体型小巧，羽毛上有珍珠般的白色斑点。性格温和，适合群养。', '小米、谷子为主食，需要沙砾帮助消化。喜欢水浴。', '澳大利亚', 7, '#DC143C'),
('玄凤鹦鹉', 'Nymphicus hollandicus', '鹦形目', '亲人,冠羽,中型', '玄凤鹦鹉头顶有漂亮的冠羽，性格温顺亲人。可以学会简单的口哨和词语。', '滋养丸搭配种子，新鲜蔬果不可少。需要大笼子和陪伴时间。', '澳大利亚', 20, '#FFA500'),
('太平洋鹦鹉', 'Forpus coelestis', '鹦形目', '小型,安静,适合公寓', '太平洋鹦鹉是最小的鹦鹉之一，叫声轻柔，适合公寓饲养。性格独立但可亲近。', '小型鹦鹉专用粮，搭配小块蔬果。需要玩具和攀爬设施。', '南美洲西部', 15, '#87CEEB'),
('和尚鹦鹉', 'Myiopsitta monachus', '鹦形目', '聪明,会说话,群居', '和尚鹦鹉是唯一会筑巢的鹦鹉，智商高，学语能力强。性格活泼，需要社交。', '混合种子和滋养丸，大量新鲜蔬果。需要大空间和互动。', '南美洲', 25, '#32CD32');

-- 插入症状数据
INSERT INTO symptoms (name, description, possible_causes, suggestions, severity) VALUES
('掉毛明显', '羽毛大量脱落，超出正常换羽范围', '换羽期,营养不良,寄生虫,压力过大,皮肤病', '检查是否为正常换羽期,补充蛋白质和维生素,保持环境清洁,如持续严重请就医', 'medium'),
('精神萎靡', '活动减少，嗜睡，反应迟钝', '生病初期,温度不适,营养不足,年龄老化', '保持适宜温度（25-28℃）,提供安静休息环境,观察是否有其他症状,建议尽快就医检查', 'high'),
('食欲下降', '进食量明显减少或拒食', '消化问题,口腔疾病,环境变化,食物不新鲜', '更换新鲜食物,检查嘴部是否异常,尝试提供喜欢的食物,超过24小时请就医', 'medium'),
('嗉囊肿大', '嗉囊部位明显鼓起，触感硬或软', '嗉囊炎,消化不良,异物堵塞,细菌感染', '暂停喂食观察,轻柔按摩帮助消化,保持温暖,建议尽快就医', 'high'),
('呼吸急促', '呼吸频率加快，张嘴呼吸', '呼吸道感染,环境闷热,惊吓应激,心脏问题', '保持通风,降低环境温度,减少惊扰,紧急就医', 'high'),
('粪便异常', '粪便颜色、形态或气味异常', '消化问题,饮食变化,肠道感染,肝脏问题', '记录粪便变化,检查近期饮食,保持饮水清洁,持续异常请就医', 'medium'),
('眼睛异常', '眼睛红肿、流泪或有分泌物', '眼部感染,维生素A缺乏,异物刺激,结膜炎', '用生理盐水清洁,补充维生素A,检查笼内是否有刺激物,建议就医', 'medium'),
('脚部问题', '脚趾肿胀、脱皮或站立困难', '脚气病,栖杆不当,缺乏运动,痛风', '更换合适粗细的栖杆,保持笼底清洁,检查饮食是否均衡,严重时就医', 'low'),
('打喷嚏', '频繁打喷嚏，可能伴有鼻涕', '感冒,粉尘刺激,过敏,呼吸道感染', '保持环境清洁无尘,适当保暖,观察是否加重,持续请就医', 'medium'),
('羽毛蓬松', '羽毛持续蓬松不收紧', '体温调节,生病前兆,寒冷,不适', '检查环境温度,观察其他症状,提供温暖环境,如持续请就医', 'medium');

-- 插入羽色基因数据
INSERT INTO color_genes (name, code, display_color, is_dominant, description) VALUES
('绿色（原始）', 'GG', '#228B22', TRUE, '牡丹鹦鹉的原始野生色，为显性基因'),
('黄化', 'yy', '#FFD700', FALSE, '缺乏黑色素，呈现黄色，隐性基因'),
('蓝化', 'bb', '#4169E1', FALSE, '缺乏黄色素，呈现蓝色，隐性基因'),
('白化', 'aa', '#F5F5F5', FALSE, '同时缺乏黑色素和黄色素，隐性基因'),
('紫罗兰', 'vv', '#9370DB', FALSE, '特殊的蓝色变异，带紫色调'),
('橙脸', 'of', '#FF8C00', TRUE, '面部呈橙色，部分显性'),
('桃脸', 'pf', '#FFB6C1', TRUE, '面部呈粉红色，原始桃脸牡丹特征'),
('深绿', 'DD', '#006400', TRUE, '深色因子，使颜色加深'),
('浅绿', 'Dd', '#90EE90', TRUE, '单深色因子，颜色适中'),
('橄榄', 'OO', '#808000', FALSE, '橄榄色变异');
