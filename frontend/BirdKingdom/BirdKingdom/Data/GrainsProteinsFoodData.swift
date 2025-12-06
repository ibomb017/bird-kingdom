import Foundation

// MARK: - 谷物种子类食物数据 (60+种)
extension BirdFood {
    static let grainsFoods: [BirdFood] = [
        // ========== 谷物 ==========
        BirdFood(name: "小米", category: .grains, safetyLevel: .safe, description: "鸟类主食之一", notes: "可以是主要食物来源，营养均衡", nutrients: ["碳水化合物", "蛋白质", "维生素B", "铁"]),
        BirdFood(name: "黍子/糜子", category: .grains, safetyLevel: .safe, description: "传统鸟食", notes: "营养价值高", nutrients: ["碳水化合物", "蛋白质", "铁"]),
        BirdFood(name: "燕麦", category: .grains, safetyLevel: .safe, description: "营养丰富的谷物", notes: "生燕麦片或煮熟的都可以", nutrients: ["纤维素", "蛋白质", "铁", "锰"]),
        BirdFood(name: "燕麦片", category: .grains, safetyLevel: .safe, description: "加工燕麦", notes: "原味无糖的", nutrients: ["纤维素", "蛋白质", "铁"]),
        BirdFood(name: "即食燕麦", category: .grains, safetyLevel: .caution, description: "快熟燕麦", notes: "确保无添加糖和调味", nutrients: ["纤维素", "蛋白质"]),
        BirdFood(name: "糙米", category: .grains, safetyLevel: .safe, description: "比白米更有营养", notes: "煮熟后喂食", nutrients: ["纤维素", "锰", "硒", "镁"]),
        BirdFood(name: "白米饭", category: .grains, safetyLevel: .safe, description: "常见主食", notes: "煮熟的米饭，少量喂食，营养较低", nutrients: ["碳水化合物", "蛋白质"]),
        BirdFood(name: "黑米", category: .grains, safetyLevel: .safe, description: "富含花青素", notes: "煮熟后喂食", nutrients: ["花青素", "纤维素", "铁"]),
        BirdFood(name: "红米", category: .grains, safetyLevel: .safe, description: "营养丰富", notes: "煮熟后喂食", nutrients: ["纤维素", "铁", "锌"]),
        BirdFood(name: "糯米", category: .grains, safetyLevel: .caution, description: "黏性大", notes: "煮熟后少量，黏性可能影响消化", nutrients: ["碳水化合物"]),
        BirdFood(name: "荞麦", category: .grains, safetyLevel: .safe, description: "无麸质谷物", notes: "煮熟或生的都可以", nutrients: ["蛋白质", "纤维素", "镁", "芦丁"]),
        BirdFood(name: "藜麦", category: .grains, safetyLevel: .safe, description: "超级谷物，蛋白质完整", notes: "煮熟后喂食，含所有必需氨基酸", nutrients: ["蛋白质", "纤维素", "铁", "镁"]),
        BirdFood(name: "大麦", category: .grains, safetyLevel: .safe, description: "健康谷物", notes: "煮熟后喂食", nutrients: ["纤维素", "硒", "维生素B", "铜"]),
        BirdFood(name: "小麦", category: .grains, safetyLevel: .safe, description: "常见谷物", notes: "全麦更有营养", nutrients: ["碳水化合物", "蛋白质", "纤维素"]),
        BirdFood(name: "小麦胚芽", category: .grains, safetyLevel: .safe, description: "小麦的营养精华", notes: "少量添加", nutrients: ["维生素E", "叶酸", "锌"]),
        BirdFood(name: "玉米粒", category: .grains, safetyLevel: .safe, description: "鸟类喜爱", notes: "新鲜或干燥的都可以", nutrients: ["碳水化合物", "纤维素", "维生素B", "叶黄素"]),
        BirdFood(name: "爆米花(原味)", category: .grains, safetyLevel: .caution, description: "膨化玉米", notes: "只能是无盐无油无糖的原味爆米花，自己用热风机做的最安全", nutrients: ["碳水化合物", "纤维素"]),
        BirdFood(name: "高粱", category: .grains, safetyLevel: .safe, description: "无麸质谷物", notes: "煮熟后喂食", nutrients: ["蛋白质", "纤维素", "铁"]),
        BirdFood(name: "薏米/薏仁", category: .grains, safetyLevel: .safe, description: "药食两用", notes: "煮熟后喂食", nutrients: ["蛋白质", "纤维素", "维生素B1"]),
        BirdFood(name: "粟", category: .grains, safetyLevel: .safe, description: "传统鸟食", notes: "可作为主食", nutrients: ["碳水化合物", "蛋白质"]),
        BirdFood(name: "稗子", category: .grains, safetyLevel: .safe, description: "野生谷物", notes: "适量喂食", nutrients: ["碳水化合物", "蛋白质"]),
        BirdFood(name: "加纳利籽", category: .grains, safetyLevel: .safe, description: "金丝雀主食", notes: "营养均衡", nutrients: ["碳水化合物", "蛋白质", "脂肪"]),
        BirdFood(name: "苔麸", category: .grains, safetyLevel: .safe, description: "埃塞俄比亚谷物", notes: "煮熟后喂食", nutrients: ["蛋白质", "纤维素", "铁"]),
        BirdFood(name: "苋籽", category: .grains, safetyLevel: .safe, description: "古老谷物", notes: "煮熟后喂食", nutrients: ["蛋白质", "纤维素", "钙"]),
        
        // ========== 种子 ==========
        BirdFood(name: "葵花籽", category: .grains, safetyLevel: .safe, description: "鸟儿最爱的零食", notes: "无盐的，适量喂食！脂肪含量高(约50%)，过量会导致肥胖和脂肪肝", nutrients: ["维生素E", "镁", "硒", "健康脂肪"]),
        BirdFood(name: "葵花籽(带壳)", category: .grains, safetyLevel: .safe, description: "带壳葵花籽", notes: "让鸟自己剥壳可以锻炼喙", nutrients: ["维生素E", "镁", "硒"]),
        BirdFood(name: "南瓜籽", category: .grains, safetyLevel: .safe, description: "营养丰富的种子", notes: "无盐无调味，生的或烤的都可以", nutrients: ["锌", "镁", "蛋白质", "铁"]),
        BirdFood(name: "亚麻籽", category: .grains, safetyLevel: .safe, description: "富含Omega-3", notes: "磨碎后更易吸收，整粒可能直接排出", nutrients: ["Omega-3", "纤维素", "蛋白质", "木酚素"]),
        BirdFood(name: "奇亚籽", category: .grains, safetyLevel: .safe, description: "超级种子", notes: "可以泡水后喂食，会形成凝胶", nutrients: ["Omega-3", "纤维素", "钙", "蛋白质"]),
        BirdFood(name: "芝麻", category: .grains, safetyLevel: .safe, description: "钙含量高", notes: "少量喂食", nutrients: ["钙", "铁", "镁", "锌"]),
        BirdFood(name: "黑芝麻", category: .grains, safetyLevel: .safe, description: "比白芝麻营养更丰富", notes: "少量喂食", nutrients: ["钙", "铁", "花青素", "维生素E"]),
        BirdFood(name: "麻籽/火麻仁", category: .grains, safetyLevel: .safe, description: "优质蛋白来源", notes: "适量喂食，脂肪含量高", nutrients: ["蛋白质", "Omega脂肪酸", "纤维素", "镁"]),
        BirdFood(name: "苏子/紫苏籽", category: .grains, safetyLevel: .safe, description: "传统鸟食", notes: "适量喂食，富含α-亚麻酸", nutrients: ["Omega-3", "蛋白质", "纤维素"]),
        BirdFood(name: "油菜籽", category: .grains, safetyLevel: .safe, description: "小型种子", notes: "适量喂食", nutrients: ["蛋白质", "脂肪", "钙"]),
        BirdFood(name: "红花籽", category: .grains, safetyLevel: .safe, description: "鹦鹉喜爱", notes: "适量喂食", nutrients: ["蛋白质", "脂肪", "维生素E"]),
        BirdFood(name: "尼日尔籽", category: .grains, safetyLevel: .safe, description: "金翅雀最爱", notes: "小型鸟类喜欢", nutrients: ["蛋白质", "脂肪"]),
        BirdFood(name: "西瓜籽", category: .grains, safetyLevel: .safe, description: "可以喂食", notes: "无盐的", nutrients: ["蛋白质", "镁", "锌"]),
        BirdFood(name: "冬瓜籽", category: .grains, safetyLevel: .safe, description: "可以喂食", notes: "晒干后喂食", nutrients: ["蛋白质", "脂肪"]),
        BirdFood(name: "木瓜籽", category: .grains, safetyLevel: .caution, description: "有辛辣味", notes: "少量，有些鸟不喜欢", nutrients: ["蛋白质"]),
        BirdFood(name: "番茄籽", category: .grains, safetyLevel: .dangerous, description: "番茄的籽", notes: "番茄整体对鸟有风险，建议避免", nutrients: []),
        BirdFood(name: "罂粟籽", category: .grains, safetyLevel: .safe, description: "烘焙用种子", notes: "食品级的安全，少量", nutrients: ["钙", "镁", "锌"]),
        BirdFood(name: "芥菜籽", category: .grains, safetyLevel: .caution, description: "辛辣种子", notes: "少量，辛辣", nutrients: ["硒", "镁"]),
        BirdFood(name: "萝卜籽", category: .grains, safetyLevel: .safe, description: "可发芽喂食", notes: "发芽后营养更高", nutrients: ["维生素C", "蛋白质"]),
    ]
    
    // ========== 蛋白质类食物数据 (40+种) ==========
    static let proteinsFoods: [BirdFood] = [
        // ========== 蛋类 ==========
        BirdFood(name: "煮熟的鸡蛋", category: .proteins, safetyLevel: .safe, description: "优质蛋白来源", notes: "全熟蛋，切碎喂食，蛋黄蛋白都可以", nutrients: ["蛋白质", "维生素D", "维生素B12", "硒"]),
        BirdFood(name: "蛋黄", category: .proteins, safetyLevel: .safe, description: "营养密集", notes: "煮熟的蛋黄，富含卵磷脂，对羽毛有益", nutrients: ["蛋白质", "维生素A", "维生素D", "胆碱"]),
        BirdFood(name: "蛋白", category: .proteins, safetyLevel: .safe, description: "纯蛋白质", notes: "煮熟的蛋白", nutrients: ["蛋白质", "硒"]),
        BirdFood(name: "蛋壳", category: .proteins, safetyLevel: .safe, description: "天然钙质来源", notes: "洗净烘干后碾碎成粉，是极好的钙补充", nutrients: ["钙", "磷"]),
        BirdFood(name: "鹌鹑蛋", category: .proteins, safetyLevel: .safe, description: "小型蛋", notes: "煮熟后喂食，营养密度高", nutrients: ["蛋白质", "维生素B12", "铁"]),
        BirdFood(name: "鸭蛋", category: .proteins, safetyLevel: .safe, description: "比鸡蛋更大", notes: "煮熟后喂食", nutrients: ["蛋白质", "维生素D", "维生素B12"]),
        BirdFood(name: "生鸡蛋", category: .proteins, safetyLevel: .dangerous, description: "可能含沙门氏菌", notes: "生蛋可能携带沙门氏菌，且生蛋白含抗生物素蛋白会阻碍生物素吸收", nutrients: []),
        
        // ========== 肉类 ==========
        BirdFood(name: "煮熟的鸡肉", category: .proteins, safetyLevel: .safe, description: "瘦肉蛋白", notes: "无调味，切成小块，去皮去骨", nutrients: ["蛋白质", "维生素B6", "烟酸", "硒"]),
        BirdFood(name: "煮熟的火鸡肉", category: .proteins, safetyLevel: .safe, description: "瘦肉蛋白", notes: "无调味，切成小块", nutrients: ["蛋白质", "维生素B6", "硒"]),
        BirdFood(name: "煮熟的鱼肉", category: .proteins, safetyLevel: .safe, description: "Omega-3来源", notes: "去骨，无调味，避免高汞鱼类(金枪鱼、旗鱼等)", nutrients: ["蛋白质", "Omega-3", "维生素D", "碘"]),
        BirdFood(name: "煮熟的三文鱼", category: .proteins, safetyLevel: .safe, description: "富含Omega-3", notes: "去骨，无调味", nutrients: ["蛋白质", "Omega-3", "维生素D"]),
        BirdFood(name: "煮熟的鳕鱼", category: .proteins, safetyLevel: .safe, description: "低脂白肉鱼", notes: "去骨，无调味", nutrients: ["蛋白质", "维生素B12"]),
        BirdFood(name: "煮熟的虾", category: .proteins, safetyLevel: .caution, description: "海鲜蛋白", notes: "去壳，无调味，少量喂食，可能引起过敏", nutrients: ["蛋白质", "硒", "维生素B12"]),
        BirdFood(name: "生肉", category: .proteins, safetyLevel: .dangerous, description: "可能含有病原体", notes: "生肉可能携带沙门氏菌、大肠杆菌、弯曲杆菌等病原体，绝对不能喂食", nutrients: []),
        BirdFood(name: "生鱼", category: .proteins, safetyLevel: .dangerous, description: "可能含有寄生虫", notes: "生鱼可能含有寄生虫和细菌", nutrients: []),
        BirdFood(name: "生虾", category: .proteins, safetyLevel: .dangerous, description: "可能含有病原体", notes: "必须煮熟", nutrients: []),
        
        // ========== 昆虫蛋白 ==========
        BirdFood(name: "面包虫/黄粉虫", category: .proteins, safetyLevel: .safe, description: "活体蛋白，鸟儿喜爱", notes: "购买专门饲养的，活的或干燥的都可以，是繁殖期的优质蛋白来源", nutrients: ["蛋白质", "脂肪", "钙", "磷"]),
        BirdFood(name: "大麦虫", category: .proteins, safetyLevel: .safe, description: "比面包虫更大", notes: "专门饲养的", nutrients: ["蛋白质", "脂肪"]),
        BirdFood(name: "蟋蟀", category: .proteins, safetyLevel: .safe, description: "优质昆虫蛋白", notes: "专门饲养的食用蟋蟀", nutrients: ["蛋白质", "钙", "铁", "锌"]),
        BirdFood(name: "蚕蛹", category: .proteins, safetyLevel: .safe, description: "高蛋白昆虫", notes: "煮熟或干燥的", nutrients: ["蛋白质", "脂肪", "维生素B2"]),
        BirdFood(name: "蚂蚱/蝗虫", category: .proteins, safetyLevel: .safe, description: "昆虫蛋白", notes: "专门饲养的", nutrients: ["蛋白质", "钙"]),
        BirdFood(name: "蜡虫", category: .proteins, safetyLevel: .safe, description: "高脂肪昆虫", notes: "脂肪含量高，作为零食少量喂食", nutrients: ["蛋白质", "脂肪"]),
        BirdFood(name: "蚯蚓", category: .proteins, safetyLevel: .caution, description: "野生可能有寄生虫", notes: "只能喂食专门养殖的红蚯蚓，野生的可能携带寄生虫和重金属", nutrients: ["蛋白质", "钙"]),
        BirdFood(name: "蚂蚁卵", category: .proteins, safetyLevel: .safe, description: "高蛋白", notes: "专门饲养的", nutrients: ["蛋白质"]),
        BirdFood(name: "蝇蛆", category: .proteins, safetyLevel: .safe, description: "高蛋白昆虫", notes: "专门饲养的，清洁的", nutrients: ["蛋白质", "脂肪"]),
        BirdFood(name: "黑水虻幼虫", category: .proteins, safetyLevel: .safe, description: "新型昆虫蛋白", notes: "专门饲养的，钙含量高", nutrients: ["蛋白质", "钙", "脂肪"]),
        
        // ========== 植物蛋白 ==========
        BirdFood(name: "豆腐", category: .proteins, safetyLevel: .safe, description: "植物蛋白", notes: "原味豆腐，切小块，不要油炸的", nutrients: ["蛋白质", "钙", "铁", "异黄酮"]),
        BirdFood(name: "豆浆", category: .proteins, safetyLevel: .caution, description: "大豆饮品", notes: "无糖的，少量，可能引起胀气", nutrients: ["蛋白质", "钙"]),
        BirdFood(name: "纳豆", category: .proteins, safetyLevel: .caution, description: "发酵大豆", notes: "少量尝试，气味特殊", nutrients: ["蛋白质", "维生素K2", "纳豆激酶"]),
        BirdFood(name: "豆腐皮/腐竹", category: .proteins, safetyLevel: .safe, description: "大豆制品", notes: "无调味的，泡软后喂食", nutrients: ["蛋白质", "钙"]),
        BirdFood(name: "素肉/植物肉", category: .proteins, safetyLevel: .dangerous, description: "加工食品", notes: "含大量添加剂和调味料，不适合鸟类", nutrients: []),
        
        // ========== 危险蛋白质 ==========
        BirdFood(name: "香肠", category: .proteins, safetyLevel: .dangerous, description: "加工肉类", notes: "含亚硝酸盐、大量盐分和添加剂，对鸟有毒", nutrients: []),
        BirdFood(name: "火腿", category: .proteins, safetyLevel: .dangerous, description: "加工肉类", notes: "含亚硝酸盐和大量盐分", nutrients: []),
        BirdFood(name: "培根", category: .proteins, safetyLevel: .dangerous, description: "高盐加工肉", notes: "盐分和脂肪含量过高，含亚硝酸盐", nutrients: []),
        BirdFood(name: "腊肉", category: .proteins, safetyLevel: .dangerous, description: "腌制肉类", notes: "盐分极高", nutrients: []),
        BirdFood(name: "咸鱼", category: .proteins, safetyLevel: .dangerous, description: "腌制鱼类", notes: "盐分极高", nutrients: []),
        BirdFood(name: "罐头肉", category: .proteins, safetyLevel: .dangerous, description: "加工食品", notes: "含盐和添加剂", nutrients: []),
        BirdFood(name: "午餐肉", category: .proteins, safetyLevel: .dangerous, description: "加工肉类", notes: "含大量盐和添加剂", nutrients: []),
        BirdFood(name: "肉松", category: .proteins, safetyLevel: .dangerous, description: "加工肉类", notes: "含盐和糖", nutrients: []),
    ]
}
