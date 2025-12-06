import Foundation

// MARK: - 水果类食物数据 (70+种)
extension BirdFood {
    static let fruitsFoods: [BirdFood] = [
        // ========== 蔷薇科水果 ==========
        // 注意：所有蔷薇科水果的籽/核都含氰苷(cyanogenic glycosides)，必须去除！
        BirdFood(name: "苹果", category: .fruits, safetyLevel: .safe, description: "富含维生素C和纤维，鸟儿喜爱", notes: "必须去籽！苹果籽含氰苷(amygdalin)，在体内转化为氰化氢", nutrients: ["维生素C", "纤维素", "钾", "槲皮素"]),
        BirdFood(name: "梨", category: .fruits, safetyLevel: .safe, description: "清甜多汁，易消化", notes: "必须去籽！梨籽含氰苷，与苹果籽同样危险", nutrients: ["维生素C", "纤维素", "钾", "铜"]),
        BirdFood(name: "桃子", category: .fruits, safetyLevel: .safe, description: "夏季时令水果", notes: "必须去核！桃核含氰苷，果肉安全", nutrients: ["维生素A", "维生素C", "钾", "烟酸"]),
        BirdFood(name: "油桃", category: .fruits, safetyLevel: .safe, description: "光滑皮肤的桃子变种", notes: "必须去核！核有毒", nutrients: ["维生素A", "维生素C", "钾"]),
        BirdFood(name: "李子", category: .fruits, safetyLevel: .safe, description: "多汁的核果", notes: "必须去核！李子核有毒", nutrients: ["维生素C", "维生素K", "钾", "纤维素"]),
        BirdFood(name: "杏子", category: .fruits, safetyLevel: .safe, description: "富含β-胡萝卜素", notes: "必须去核！杏核含苦杏仁苷(amygdalin)，3-4颗可致人死亡", nutrients: ["维生素A", "维生素C", "钾"]),
        BirdFood(name: "樱桃", category: .fruits, safetyLevel: .safe, description: "小巧美味的核果", notes: "必须去核！樱桃核含氰苷，即使少量也危险", nutrients: ["维生素C", "钾", "花青素", "褪黑素"]),
        BirdFood(name: "枇杷", category: .fruits, safetyLevel: .safe, description: "春季时令水果", notes: "必须去籽！枇杷籽含氰苷", nutrients: ["维生素A", "钾", "锰"]),
        BirdFood(name: "山楂", category: .fruits, safetyLevel: .safe, description: "酸甜可口", notes: "去核，少量喂食", nutrients: ["维生素C", "纤维素", "抗氧化物"]),
        BirdFood(name: "海棠果", category: .fruits, safetyLevel: .safe, description: "小型苹果类", notes: "去籽！", nutrients: ["维生素C", "纤维素"]),
        
        // ========== 浆果类 ==========
        BirdFood(name: "草莓", category: .fruits, safetyLevel: .safe, description: "维生素C含量极高", notes: "洗净后切小块，去除叶子", nutrients: ["维生素C", "锰", "叶酸", "钾"]),
        BirdFood(name: "蓝莓", category: .fruits, safetyLevel: .safe, description: "超级食物，富含花青素", notes: "可以整颗喂食，对羽毛色泽有益", nutrients: ["花青素", "维生素C", "维生素K", "锰"]),
        BirdFood(name: "覆盆子", category: .fruits, safetyLevel: .safe, description: "富含纤维和抗氧化物", notes: "新鲜或冷冻的都可以", nutrients: ["维生素C", "锰", "纤维素", "鞣花酸"]),
        BirdFood(name: "黑莓", category: .fruits, safetyLevel: .safe, description: "营养丰富的浆果", notes: "切开喂食，注意清洗", nutrients: ["维生素C", "维生素K", "锰", "纤维素"]),
        BirdFood(name: "蔓越莓", category: .fruits, safetyLevel: .safe, description: "有助于泌尿系统健康", notes: "新鲜的，非加糖干燥品", nutrients: ["维生素C", "维生素E", "原花青素"]),
        BirdFood(name: "桑葚", category: .fruits, safetyLevel: .safe, description: "深色浆果，营养丰富", notes: "成熟的黑色桑葚最佳", nutrients: ["维生素C", "铁", "花青素", "白藜芦醇"]),
        BirdFood(name: "葡萄", category: .fruits, safetyLevel: .safe, description: "多汁美味", notes: "切成小块，去皮更佳，注意农药残留", nutrients: ["维生素C", "维生素K", "白藜芦醇"]),
        BirdFood(name: "红提", category: .fruits, safetyLevel: .safe, description: "红色葡萄品种", notes: "切小块喂食", nutrients: ["维生素C", "维生素K", "花青素"]),
        BirdFood(name: "青提", category: .fruits, safetyLevel: .safe, description: "绿色葡萄品种", notes: "切小块喂食", nutrients: ["维生素C", "维生素K"]),
        BirdFood(name: "无籽葡萄", category: .fruits, safetyLevel: .safe, description: "方便喂食的葡萄", notes: "切小块", nutrients: ["维生素C", "维生素K"]),
        BirdFood(name: "黑加仑", category: .fruits, safetyLevel: .safe, description: "维生素C极高", notes: "新鲜或干燥的", nutrients: ["维生素C", "花青素", "钾"]),
        BirdFood(name: "红加仑", category: .fruits, safetyLevel: .safe, description: "酸甜浆果", notes: "新鲜的", nutrients: ["维生素C", "维生素K"]),
        BirdFood(name: "醋栗", category: .fruits, safetyLevel: .safe, description: "酸味浆果", notes: "成熟的更甜", nutrients: ["维生素C", "纤维素"]),
        BirdFood(name: "枸杞", category: .fruits, safetyLevel: .safe, description: "传统滋补品", notes: "干燥的，少量", nutrients: ["维生素A", "维生素C", "铁", "多糖"]),
        
        // ========== 瓜类 ==========
        BirdFood(name: "西瓜", category: .fruits, safetyLevel: .safe, description: "水分充足，夏季消暑", notes: "去籽，适量喂食，糖分较高", nutrients: ["水分", "维生素A", "维生素C", "番茄红素"]),
        BirdFood(name: "哈密瓜", category: .fruits, safetyLevel: .safe, description: "甜美多汁，富含β-胡萝卜素", notes: "去皮去籽后喂食", nutrients: ["维生素A", "维生素C", "钾", "叶酸"]),
        BirdFood(name: "香瓜", category: .fruits, safetyLevel: .safe, description: "清甜可口", notes: "去皮去籽，切小块", nutrients: ["维生素C", "维生素A", "钾"]),
        BirdFood(name: "蜜瓜", category: .fruits, safetyLevel: .safe, description: "白色果肉的甜瓜", notes: "去皮去籽", nutrients: ["维生素C", "钾", "维生素B6"]),
        BirdFood(name: "网纹瓜", category: .fruits, safetyLevel: .safe, description: "表皮有网纹的甜瓜", notes: "去皮去籽", nutrients: ["维生素A", "维生素C", "钾"]),
        BirdFood(name: "白兰瓜", category: .fruits, safetyLevel: .safe, description: "清甜瓜类", notes: "去皮去籽", nutrients: ["维生素C", "钾"]),
        
        // ========== 热带水果 ==========
        BirdFood(name: "香蕉", category: .fruits, safetyLevel: .safe, description: "高能量水果，富含钾", notes: "适量喂食，糖分较高，过量可能导致肥胖", nutrients: ["钾", "维生素B6", "维生素C", "镁"]),
        BirdFood(name: "芒果", category: .fruits, safetyLevel: .safe, description: "热带水果，营养丰富", notes: "去皮去核，切小块，皮可能引起过敏(与漆树同科)", nutrients: ["维生素A", "维生素C", "叶酸", "维生素B6"]),
        BirdFood(name: "木瓜", category: .fruits, safetyLevel: .safe, description: "含木瓜蛋白酶，助消化", notes: "去籽，成熟的更好，未熟含乳胶", nutrients: ["维生素C", "维生素A", "叶酸", "木瓜蛋白酶"]),
        BirdFood(name: "菠萝", category: .fruits, safetyLevel: .caution, description: "含菠萝蛋白酶", notes: "去皮去芯，少量喂食，酸性较强可能刺激口腔和嗉囊", nutrients: ["维生素C", "锰", "菠萝蛋白酶"]),
        BirdFood(name: "猕猴桃", category: .fruits, safetyLevel: .safe, description: "维生素C含量是橙子的两倍", notes: "去皮后喂食，毛皮可能刺激", nutrients: ["维生素C", "维生素K", "钾", "叶酸"]),
        BirdFood(name: "奇异果", category: .fruits, safetyLevel: .safe, description: "猕猴桃的别名", notes: "去皮后喂食", nutrients: ["维生素C", "维生素K", "钾"]),
        BirdFood(name: "火龙果", category: .fruits, safetyLevel: .safe, description: "低热量，富含纤维", notes: "去皮切块，籽可以吃", nutrients: ["纤维素", "维生素C", "镁", "铁"]),
        BirdFood(name: "红心火龙果", category: .fruits, safetyLevel: .safe, description: "花青素更丰富", notes: "去皮切块", nutrients: ["花青素", "维生素C", "镁"]),
        BirdFood(name: "百香果", category: .fruits, safetyLevel: .safe, description: "热带水果，香气浓郁", notes: "果肉和籽都可以吃", nutrients: ["维生素C", "维生素A", "纤维素", "铁"]),
        BirdFood(name: "番石榴", category: .fruits, safetyLevel: .safe, description: "维生素C含量极高", notes: "去籽更安全，果肉营养丰富", nutrients: ["维生素C", "纤维素", "叶酸", "钾"]),
        BirdFood(name: "山竹", category: .fruits, safetyLevel: .safe, description: "热带水果皇后", notes: "只吃白色果肉，外壳不可食", nutrients: ["维生素C", "叶酸", "锰"]),
        BirdFood(name: "莲雾", category: .fruits, safetyLevel: .safe, description: "清脆多汁", notes: "洗净即可喂食", nutrients: ["维生素C", "钙", "镁"]),
        BirdFood(name: "红毛丹", category: .fruits, safetyLevel: .safe, description: "与荔枝类似", notes: "去皮去籽，只吃果肉", nutrients: ["维生素C", "铁", "钙"]),
        BirdFood(name: "龙眼", category: .fruits, safetyLevel: .caution, description: "与荔枝类似", notes: "去皮去核，少量为宜，糖分高", nutrients: ["维生素C", "铁", "钾"]),
        BirdFood(name: "荔枝", category: .fruits, safetyLevel: .caution, description: "甜美但糖分极高", notes: "去皮去核，少量喂食，空腹大量可能导致低血糖(荔枝病)", nutrients: ["维生素C", "铜", "钾"]),
        BirdFood(name: "榴莲", category: .fruits, safetyLevel: .caution, description: "热量和糖分都很高", notes: "极少量尝试，气味可能让鸟不适", nutrients: ["维生素C", "钾", "纤维素"]),
        BirdFood(name: "菠萝蜜", category: .fruits, safetyLevel: .caution, description: "大型热带水果", notes: "果肉少量，乳胶可能引起过敏", nutrients: ["维生素C", "钾", "纤维素"]),
        BirdFood(name: "椰子肉", category: .fruits, safetyLevel: .safe, description: "富含健康脂肪", notes: "新鲜椰肉，少量喂食", nutrients: ["锰", "铜", "健康脂肪"]),
        BirdFood(name: "杨桃", category: .fruits, safetyLevel: .caution, description: "星形热带水果", notes: "含草酸盐，肾脏问题的鸟避免，少量喂食", nutrients: ["维生素C", "纤维素", "钾"]),
        
        // ========== 柑橘类 ==========
        BirdFood(name: "橙子", category: .fruits, safetyLevel: .safe, description: "经典维生素C来源", notes: "去皮去籽，少量喂食，酸性较强可能刺激嗉囊", nutrients: ["维生素C", "纤维素", "叶酸", "硫胺素"]),
        BirdFood(name: "柑橘", category: .fruits, safetyLevel: .safe, description: "与橙子类似", notes: "去皮去籽，少量，酸性注意", nutrients: ["维生素C", "纤维素", "钾"]),
        BirdFood(name: "蜜柑", category: .fruits, safetyLevel: .safe, description: "小型柑橘", notes: "去皮去籽", nutrients: ["维生素C", "维生素A"]),
        BirdFood(name: "砂糖橘", category: .fruits, safetyLevel: .safe, description: "甜味柑橘", notes: "去皮去籽", nutrients: ["维生素C", "维生素A"]),
        BirdFood(name: "金桔", category: .fruits, safetyLevel: .safe, description: "可连皮吃的柑橘", notes: "切开喂食，皮也有营养", nutrients: ["维生素C", "纤维素", "钙"]),
        BirdFood(name: "柚子", category: .fruits, safetyLevel: .caution, description: "大型柑橘类", notes: "酸性强，少量喂食，可能与某些药物相互作用", nutrients: ["维生素C", "维生素A", "钾"]),
        BirdFood(name: "葡萄柚", category: .fruits, safetyLevel: .caution, description: "苦味柑橘", notes: "酸性强，可能影响药物代谢", nutrients: ["维生素C", "维生素A"]),
        BirdFood(name: "柠檬", category: .fruits, safetyLevel: .caution, description: "酸性极强", notes: "极少量，高酸性可能刺激消化道和嗉囊", nutrients: ["维生素C", "柠檬酸", "钾"]),
        BirdFood(name: "青柠", category: .fruits, safetyLevel: .caution, description: "与柠檬类似", notes: "酸性强，极少量", nutrients: ["维生素C", "柠檬酸"]),
        BirdFood(name: "橘子", category: .fruits, safetyLevel: .safe, description: "常见柑橘", notes: "去皮去籽", nutrients: ["维生素C", "维生素A"]),
        
        // ========== 其他水果 ==========
        BirdFood(name: "石榴", category: .fruits, safetyLevel: .safe, description: "抗氧化能力极强", notes: "只喂果肉和籽，外皮不可食", nutrients: ["维生素C", "维生素K", "叶酸", "鞣花酸"]),
        BirdFood(name: "无花果", category: .fruits, safetyLevel: .safe, description: "天然甜味，钙含量高", notes: "新鲜或干燥的都可以，干燥的糖分更集中", nutrients: ["纤维素", "钾", "钙", "镁"]),
        BirdFood(name: "柿子", category: .fruits, safetyLevel: .caution, description: "含有鞣酸", notes: "必须完全成熟！未熟柿子含大量鞣酸可致胃柿石症", nutrients: ["维生素A", "维生素C", "锰"]),
        BirdFood(name: "人参果", category: .fruits, safetyLevel: .safe, description: "低糖水果", notes: "去皮切块", nutrients: ["维生素C", "硒", "钙"]),
        BirdFood(name: "仙人掌果", category: .fruits, safetyLevel: .safe, description: "沙漠水果", notes: "去皮去刺", nutrients: ["维生素C", "镁", "钙"]),
        BirdFood(name: "杨梅", category: .fruits, safetyLevel: .safe, description: "酸甜可口", notes: "洗净，少量", nutrients: ["维生素C", "花青素"]),
        BirdFood(name: "杨桃", category: .fruits, safetyLevel: .caution, description: "含草酸", notes: "肾脏问题避免", nutrients: ["维生素C", "钾"]),
        
        // ========== 危险水果 ==========
        BirdFood(name: "牛油果/鳄梨", category: .fruits, safetyLevel: .dangerous, description: "对鸟类剧毒！", notes: "含persin毒素，可在12-24小时内导致心肌坏死、呼吸困难和死亡。果肉、皮、核、叶子全部有毒！已有大量鸟类死亡案例报告", nutrients: []),
        BirdFood(name: "释迦/番荔枝", category: .fruits, safetyLevel: .dangerous, description: "籽剧毒", notes: "籽含番荔枝素(annonacin)，是神经毒素。果肉也有争议，建议完全避免", nutrients: []),
        BirdFood(name: "刺果番荔枝", category: .fruits, safetyLevel: .dangerous, description: "与释迦同属", notes: "含番荔枝素，有毒", nutrients: []),
        BirdFood(name: "大黄茎", category: .fruits, safetyLevel: .dangerous, description: "含草酸极高", notes: "草酸盐会导致肾衰竭，叶子毒性更强", nutrients: []),
    ]
}
