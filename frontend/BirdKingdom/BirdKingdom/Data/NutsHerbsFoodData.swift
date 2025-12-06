import Foundation

// MARK: - 坚果类食物数据 (30+种)
extension BirdFood {
    static let nutsFoods: [BirdFood] = [
        // ========== 安全坚果 ==========
        BirdFood(name: "杏仁(甜杏仁)", category: .nuts, safetyLevel: .safe, description: "营养丰富的坚果", notes: "无盐无调味，切碎喂食。只能是甜杏仁！", nutrients: ["维生素E", "镁", "蛋白质", "纤维素"]),
        BirdFood(name: "核桃", category: .nuts, safetyLevel: .safe, description: "富含Omega-3", notes: "去壳，切碎，适量喂食", nutrients: ["Omega-3", "蛋白质", "维生素E", "锰"]),
        BirdFood(name: "腰果", category: .nuts, safetyLevel: .safe, description: "美味坚果", notes: "无盐烘烤的，少量喂食。生腰果外壳含漆酚有毒，但市售腰果都是处理过的", nutrients: ["铜", "镁", "蛋白质", "锌"]),
        BirdFood(name: "榛子", category: .nuts, safetyLevel: .safe, description: "欧洲常见坚果", notes: "去壳切碎", nutrients: ["维生素E", "锰", "健康脂肪"]),
        BirdFood(name: "开心果", category: .nuts, safetyLevel: .safe, description: "绿色坚果", notes: "无盐去壳，少量喂食", nutrients: ["维生素B6", "蛋白质", "纤维素", "钾"]),
        BirdFood(name: "松子", category: .nuts, safetyLevel: .safe, description: "小巧美味", notes: "无盐的，适量喂食", nutrients: ["维生素E", "锌", "蛋白质", "镁"]),
        BirdFood(name: "碧根果/美国山核桃", category: .nuts, safetyLevel: .safe, description: "美洲坚果", notes: "去壳切碎", nutrients: ["健康脂肪", "锰", "铜"]),
        BirdFood(name: "山核桃", category: .nuts, safetyLevel: .safe, description: "中国坚果", notes: "去壳切碎", nutrients: ["Omega-3", "蛋白质"]),
        BirdFood(name: "栗子", category: .nuts, safetyLevel: .safe, description: "低脂坚果", notes: "煮熟后喂食，生栗子难消化", nutrients: ["碳水化合物", "维生素C", "钾"]),
        BirdFood(name: "白果/银杏果", category: .nuts, safetyLevel: .caution, description: "含微量毒素", notes: "必须煮熟，少量喂食。含银杏酸，过量可能中毒", nutrients: ["蛋白质", "维生素C"]),
        BirdFood(name: "莲子", category: .nuts, safetyLevel: .safe, description: "水生坚果", notes: "煮熟后喂食", nutrients: ["蛋白质", "钾", "镁"]),
        BirdFood(name: "芡实", category: .nuts, safetyLevel: .safe, description: "水生坚果", notes: "煮熟后喂食", nutrients: ["碳水化合物", "蛋白质"]),
        
        // ========== 需注意的坚果 ==========
        BirdFood(name: "花生", category: .nuts, safetyLevel: .caution, description: "可能含有黄曲霉毒素", notes: "只能喂新鲜无霉变的，无盐烘烤。花生容易发霉产生黄曲霉毒素(致癌物)，必须检查无霉变", nutrients: ["蛋白质", "维生素E", "烟酸", "叶酸"]),
        BirdFood(name: "花生米", category: .nuts, safetyLevel: .caution, description: "去壳花生", notes: "同花生，注意霉变", nutrients: ["蛋白质", "维生素E"]),
        BirdFood(name: "巴西坚果", category: .nuts, safetyLevel: .caution, description: "硒含量极高", notes: "每次只能喂一小块！硒过量有毒(硒中毒)，一颗巴西坚果含约70-90微克硒", nutrients: ["硒", "镁", "蛋白质"]),
        BirdFood(name: "夏威夷果", category: .nuts, safetyLevel: .caution, description: "脂肪含量很高", notes: "少量喂食，脂肪含量约75%", nutrients: ["健康脂肪", "锰", "维生素B1"]),
        BirdFood(name: "杏仁(苦杏仁)", category: .nuts, safetyLevel: .dangerous, description: "含氰苷剧毒！", notes: "苦杏仁含苦杏仁苷(amygdalin)，在体内转化为氰化物。3-4颗苦杏仁可致人死亡，对鸟更危险！绝对不能喂食", nutrients: []),
        BirdFood(name: "盐焗坚果", category: .nuts, safetyLevel: .dangerous, description: "含盐量高", notes: "任何加盐调味的坚果都不能喂食", nutrients: []),
        BirdFood(name: "蜜汁坚果", category: .nuts, safetyLevel: .dangerous, description: "含糖量高", notes: "加糖的坚果不适合鸟类", nutrients: []),
        BirdFood(name: "五香坚果", category: .nuts, safetyLevel: .dangerous, description: "含调味料", notes: "调味料可能对鸟有害", nutrients: []),
    ]
    
    // ========== 草本植物类食物数据 (30+种) ==========
    static let herbsFoods: [BirdFood] = [
        // ========== 安全草本 ==========
        BirdFood(name: "香菜/芫荽", category: .herbs, safetyLevel: .safe, description: "芳香草本", notes: "新鲜叶子，少量喂食", nutrients: ["维生素K", "维生素C", "维生素A"]),
        BirdFood(name: "罗勒/九层塔", category: .herbs, safetyLevel: .safe, description: "芳香草本", notes: "新鲜叶子", nutrients: ["维生素K", "铁", "钙"]),
        BirdFood(name: "薄荷", category: .herbs, safetyLevel: .safe, description: "清凉草本", notes: "少量新鲜叶子", nutrients: ["维生素A", "铁", "锰"]),
        BirdFood(name: "欧芹/荷兰芹", category: .herbs, safetyLevel: .safe, description: "营养丰富的香草", notes: "新鲜叶子，适量喂食", nutrients: ["维生素K", "维生素C", "维生素A"]),
        BirdFood(name: "莳萝", category: .herbs, safetyLevel: .safe, description: "芳香草本", notes: "新鲜的少量喂食", nutrients: ["维生素C", "锰", "维生素A"]),
        BirdFood(name: "蒲公英叶", category: .herbs, safetyLevel: .safe, description: "野生可食用植物", notes: "确保无农药污染，是很好的绿叶菜", nutrients: ["维生素A", "维生素C", "钙", "铁"]),
        BirdFood(name: "蒲公英花", category: .herbs, safetyLevel: .safe, description: "可食用花", notes: "确保无污染", nutrients: ["维生素A", "维生素C"]),
        BirdFood(name: "车前草", category: .herbs, safetyLevel: .safe, description: "常见野草", notes: "确保无污染", nutrients: ["维生素C", "钙", "钾"]),
        BirdFood(name: "紫花苜蓿芽", category: .herbs, safetyLevel: .safe, description: "营养丰富的芽菜", notes: "新鲜的", nutrients: ["维生素K", "维生素C", "蛋白质"]),
        BirdFood(name: "小麦草", category: .herbs, safetyLevel: .safe, description: "嫩麦苗", notes: "新鲜的，可以自己种植", nutrients: ["叶绿素", "维生素A", "维生素C"]),
        BirdFood(name: "猫草/燕麦草", category: .herbs, safetyLevel: .safe, description: "嫩草", notes: "可以自己种植", nutrients: ["纤维素", "叶绿素"]),
        BirdFood(name: "鸡毛菜苗", category: .herbs, safetyLevel: .safe, description: "嫩苗", notes: "新鲜的", nutrients: ["维生素C", "维生素A"]),
        BirdFood(name: "豌豆苗", category: .herbs, safetyLevel: .safe, description: "豌豆的嫩芽", notes: "新鲜的，营养丰富", nutrients: ["维生素C", "维生素A", "叶酸"]),
        BirdFood(name: "葵花苗", category: .herbs, safetyLevel: .safe, description: "葵花籽的嫩芽", notes: "新鲜的", nutrients: ["维生素E", "蛋白质"]),
        BirdFood(name: "萝卜苗", category: .herbs, safetyLevel: .safe, description: "萝卜的嫩芽", notes: "新鲜的", nutrients: ["维生素C", "维生素E"]),
        BirdFood(name: "牛至/奥勒冈", category: .herbs, safetyLevel: .safe, description: "芳香草本", notes: "少量新鲜叶子", nutrients: ["维生素K", "铁", "锰"]),
        BirdFood(name: "百里香", category: .herbs, safetyLevel: .safe, description: "芳香草本", notes: "少量", nutrients: ["维生素C", "铁"]),
        BirdFood(name: "迷迭香", category: .herbs, safetyLevel: .caution, description: "芳香草本", notes: "极少量，气味浓烈", nutrients: ["铁", "钙"]),
        BirdFood(name: "鼠尾草", category: .herbs, safetyLevel: .caution, description: "芳香草本", notes: "极少量", nutrients: ["维生素K"]),
        BirdFood(name: "马齿苋", category: .herbs, safetyLevel: .safe, description: "野生可食用", notes: "确保无污染", nutrients: ["Omega-3", "维生素A", "维生素C"]),
        BirdFood(name: "紫苏叶", category: .herbs, safetyLevel: .safe, description: "芳香草本", notes: "新鲜叶子", nutrients: ["维生素A", "钙", "铁"]),
        BirdFood(name: "艾草", category: .herbs, safetyLevel: .caution, description: "药用草本", notes: "极少量，有些品种有毒", nutrients: []),
        BirdFood(name: "薰衣草", category: .herbs, safetyLevel: .caution, description: "芳香草本", notes: "极少量，主要用于环境", nutrients: []),
        
        // ========== 危险草本 ==========
        BirdFood(name: "芦荟", category: .herbs, safetyLevel: .dangerous, description: "含皂苷", notes: "芦荟含皂苷和蒽醌类化合物，可导致腹泻和消化道刺激", nutrients: []),
        BirdFood(name: "夹竹桃", category: .herbs, safetyLevel: .dangerous, description: "剧毒植物", notes: "全株有毒，含强心苷，可致死", nutrients: []),
        BirdFood(name: "水仙", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "全株有毒，特别是球茎", nutrients: []),
        BirdFood(name: "风信子", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "全株有毒", nutrients: []),
        BirdFood(name: "郁金香", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "全株有毒，特别是球茎", nutrients: []),
        BirdFood(name: "百合", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "对鸟有毒", nutrients: []),
        BirdFood(name: "杜鹃花", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "含木藜芦毒素，全株有毒", nutrients: []),
        BirdFood(name: "绣球花", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "含氰苷", nutrients: []),
        BirdFood(name: "一品红", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "汁液有毒", nutrients: []),
        BirdFood(name: "常春藤", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "全株有毒", nutrients: []),
        BirdFood(name: "万年青", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "含草酸钙针晶", nutrients: []),
        BirdFood(name: "滴水观音", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "含草酸钙针晶，汁液剧毒", nutrients: []),
        BirdFood(name: "龟背竹", category: .herbs, safetyLevel: .dangerous, description: "有毒植物", notes: "含草酸钙针晶", nutrients: []),
    ]
}
