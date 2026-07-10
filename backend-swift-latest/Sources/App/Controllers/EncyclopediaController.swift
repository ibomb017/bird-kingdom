import Vapor
import Fluent

/// 百科控制器
struct EncyclopediaController: RouteCollection {
    /// 同义词库组（相互关联的匹配词）
    private static let synonymGroups = [
        // 症状同义词
        ["拉稀", "拉肚子", "腹泻", "稀便", "水便", "便稀", "拉水", "不成形", "绿便", "血便", "便血", "拉血", "稀"],
        ["不吃", "拒食", "吃不下", "厌食", "挑食", "不开食", "不进食", "食欲不振", "食欲下降", "不肯吃", "不吃食", "吃不下饭"],
        ["喘气", "张嘴喘", "呼吸急促", "喘粗气", "呼吸困难", "憋气", "不通气", "张嘴呼吸", "喘"],
        ["炸毛", "没精神", "打蔫", "不爱动", "缩成一团", "发抖", "虚弱", "精神差", "萎靡", "蓬毛", "松毛"],
        ["眼红", "眼肿", "流眼泪", "流泪", "眼屎", "睁不开", "眼炎", "结膜炎", "红眼"],
        ["感冒", "受凉", "着凉", "受寒", "流鼻涕", "打喷嚏", "流气"],
        ["吐食", "呕吐", "甩头吐", "反胃", "吐了", "甩食", "干呕"],
        ["掉毛", "脱毛", "啄羽", "咬毛", "拔毛", "自残", "秃了", "啄毛", "羽毛脱落"],
        ["流血", "受伤", "出血", "骨折", "外伤", "磕破", "伤口"],
        ["难产", "下不出蛋", "卡蛋", "蛋阻留", "生不出"],
        
        // 食物同义词
        ["板栗", "栗子", "甘栗", "毛栗"],
        ["土豆", "马铃薯", "洋芋"],
        ["西红柿", "番茄", "洋柿子"],
        ["玉米", "苞谷", "包谷", "棒子", "玉蜀黍"],
        ["红薯", "番薯", "地瓜", "山芋", "红苕"],
        ["花生", "落花生", "长生果", "地豆"],
        ["西兰花", "绿花菜", "青花菜", "花椰菜"],
        ["白菜", "大白菜", "黄芽白", "结球白菜"],
        ["卷心菜", "圆白菜", "洋白菜", "包菜", "莲花白"],
        ["苹果", "蛇果", "沙果"],
        ["哈密瓜", "哈蜜瓜", "网纹瓜", "甜瓜"],
        ["胡萝卜", "红萝卜", "胡萝卜"],
        ["猕猴桃", "奇异果", "毛梨"],
        ["南瓜", "麦瓜", "倭瓜", "金瓜"],
        ["黄瓜", "青瓜", "胡瓜"],
        ["辣椒", "秦椒", "海椒", "甜椒", "彩椒"],
        ["燕麦", "莜麦", "麦片"],
        ["油菜", "青菜", "油白菜", "上海青", "小白菜"],
        ["空心菜", "通菜", "蕹菜", "无心菜"],
        ["菠菜", "波斯草", "红根菜", "飞龙菜"],
        ["生菜", "莴苣", "叶用莴苣"],
        ["蒲公英", "婆婆丁", "黄花地丁"],
        ["车前草", "车轮菜", "猪耳草"],
        ["面包虫", "黄粉虫"],
        ["大麦虫", "超级面包虫"]
    ]

    /// 智能扩展关键词为同义词候选列表
    private func expandKeywords(from query: String) -> [String] {
        let rawKeywords = query
            .components(separatedBy: CharacterSet(charactersIn: " ,，;；.。"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var expanded: [String] = []
        
        for kw in rawKeywords {
            expanded.append(kw)
            for group in Self.synonymGroups {
                var isMatched = false
                for word in group {
                    if kw.contains(word) || word.contains(kw) {
                        isMatched = true
                        break
                    }
                }
                if isMatched {
                    for word in group {
                        if !expanded.contains(word) {
                            expanded.append(word)
                        }
                    }
                }
            }
        }
        return expanded
    }

    func boot(routes: RoutesBuilder) throws {
        let encyclopedia = routes.grouped("encyclopedia")
        
        // ==================== 食物百科 ====================
        encyclopedia.get("foods", use: getAllFoods)
        encyclopedia.get("foods", ":foodId", use: getFoodById)
        encyclopedia.get("foods", "search", use: searchFoods)
        encyclopedia.get("foods", "categories", use: getAllFoodCategories)
        encyclopedia.get("foods", "category", ":category", use: getFoodsByCategory)
        encyclopedia.get("foods", "safety", ":safetyLevel", use: getFoodsBySafetyLevel)
        encyclopedia.get("foods", "filter", use: filterFoods)
        
        // ==================== 鸟类百科 ====================
        encyclopedia.get("birds", use: getAllBirds)
        encyclopedia.get("birds", ":birdId", use: getBirdById)
        encyclopedia.get("birds", "search", use: searchBirds)
        encyclopedia.get("birds", "categories", use: getAllBirdCategories)
        encyclopedia.get("birds", "category", ":category", use: getBirdsByCategory)
        
        // ==================== 症状速查 ====================
        encyclopedia.get("symptoms", use: getAllSymptoms)
        encyclopedia.get("symptoms", ":symptomId", use: getSymptomById)
        encyclopedia.get("symptoms", "search", use: searchSymptoms)
        encyclopedia.get("symptoms", "severity", ":severity", use: getSymptomsBySeverity)
        encyclopedia.get("symptoms", "category", ":category", use: getSymptomsByCategory)
        encyclopedia.get("symptoms", "filter", use: filterSymptoms)
        
        // ==================== 管理端兼容别名 (Admin Web) ====================
        encyclopedia.get("species", use: getAllBirds)
    }

    // ==================== 食物百科 ====================
    
    @Sendable
    func getAllFoods(req: Request) async throws -> [FoodEncyclopediaDTO] {
        let foods = try await BirdFood.query(on: req.db)
            .sort(\.$foodName, .ascending)
            .all()
        return foods.map { FoodEncyclopediaDTO.from($0) }
    }
    
    @Sendable
    func getFoodById(req: Request) async throws -> FoodEncyclopediaDTO {
        guard let foodIdStr = req.parameters.get("foodId"),
              let foodId = Int64(foodIdStr) else {
            throw Abort(.badRequest, reason: "无效的食物ID")
        }
        
        guard let food = try await BirdFood.find(foodId, on: req.db) else {
            throw Abort(.notFound, reason: "食物不存在")
        }
        
        return FoodEncyclopediaDTO.from(food)
    }
    
    @Sendable
    func searchFoods(req: Request) async throws -> [FoodEncyclopediaDTO] {
        let keyword = req.query[String.self, at: "keyword"] ?? ""
        
        if keyword.isEmpty {
            return try await getAllFoods(req: req)
        }
        
        let expanded = expandKeywords(from: keyword)
        
        // 广泛模糊搜索：匹配食物名、分类、别名、简介 + 单字拆分
        let foods = try await BirdFood.query(on: req.db)
            .group(.or) { group in
                for kw in expanded {
                    group.filter(\.$foodName ~~ kw)
                    group.filter(\.$category ~~ kw)
                    group.filter(\.$aliases ~~ kw)
                    group.filter(\.$intro ~~ kw)
                }
                // 单字拆分匹配：对2字以上关键词，逐字匹配食物名和别名
                if keyword.count >= 2 {
                    for char in keyword {
                        let charStr = String(char)
                        group.filter(\.$foodName ~~ charStr)
                        group.filter(\.$aliases ~~ charStr)
                    }
                }
            }
            .all()
        
        // 去重
        var seen = Set<Int64>()
        var uniqueFoods: [BirdFood] = []
        for food in foods {
            if let id = food.id, !seen.contains(id) {
                seen.insert(id)
                uniqueFoods.append(food)
            }
        }
        
        // 智能相关性评分排序
        let sorted = uniqueFoods.sorted { a, b in
            return foodSearchScoreSmart(food: a, query: keyword, expanded: expanded) > foodSearchScoreSmart(food: b, query: keyword, expanded: expanded)
        }
        
        return sorted.map { FoodEncyclopediaDTO.from($0) }
    }
    
    /// 计算食物智能搜索相关性评分
    private func foodSearchScoreSmart(food: BirdFood, query: String, expanded: [String]) -> Int {
        var score = 0
        
        // 1. 完全匹配原始查询词 (最高权重)
        if food.foodName == query {
            score += 500
        } else if food.foodName.contains(query) {
            score += 300
        }
        
        // 2. 别名完全匹配原始查询词
        if let aliases = food.aliases {
            let list = aliases.components(separatedBy: ",")
            if list.contains(query) {
                score += 400
            } else if aliases.contains(query) {
                score += 250
            }
        }
        
        // 3. 匹配扩展的同义词 (同义词匹配权重)
        for kw in expanded {
            if food.foodName == kw { score += 200 }
            else if food.foodName.contains(kw) { score += 150 }
            
            if let aliases = food.aliases {
                let list = aliases.components(separatedBy: ",")
                if list.contains(kw) { score += 180 }
                else if aliases.contains(kw) { score += 120 }
            }
            
            if food.intro.contains(kw) { score += 50 }
            if food.category.contains(kw) { score += 80 }
        }
        
        // 4. 单字拆分匹配度
        for char in query {
            if food.foodName.contains(char) { score += 10 }
            if let aliases = food.aliases, aliases.contains(char) { score += 8 }
        }
        return score
    }
    
    @Sendable
    func getAllFoodCategories(req: Request) async throws -> [String] {
        let foods = try await BirdFood.query(on: req.db).all()
        let categories = Set(foods.map { $0.category })
        return Array(categories).sorted()
    }
    
    @Sendable
    func getFoodsByCategory(req: Request) async throws -> [FoodEncyclopediaDTO] {
        guard let category = req.parameters.get("category") else {
            throw Abort(.badRequest, reason: "缺少分类参数")
        }
        
        let foods = try await BirdFood.query(on: req.db)
            .filter(\.$category == category)
            .all()
        
        return foods.map { FoodEncyclopediaDTO.from($0) }
    }
    
    @Sendable
    func getFoodsBySafetyLevel(req: Request) async throws -> [FoodEncyclopediaDTO] {
        guard let safetyLevel = req.parameters.get("safetyLevel") else {
            throw Abort(.badRequest, reason: "缺少安全等级参数")
        }
        
        let foods = try await BirdFood.query(on: req.db)
            .filter(\.$safetyLevel == safetyLevel)
            .all()
        
        return foods.map { FoodEncyclopediaDTO.from($0) }
    }
    
    @Sendable
    func filterFoods(req: Request) async throws -> [FoodEncyclopediaDTO] {
        let category = req.query[String.self, at: "category"]
        let safetyLevel = req.query[String.self, at: "safetyLevel"]
        
        var query = BirdFood.query(on: req.db)
        
        if let category = category, !category.isEmpty {
            query = query.filter(\.$category == category)
        }
        if let safetyLevel = safetyLevel, !safetyLevel.isEmpty {
            query = query.filter(\.$safetyLevel == safetyLevel)
        }
        
        let foods = try await query.all()
        return foods.map { FoodEncyclopediaDTO.from($0) }
    }
    
    // ==================== 鸟类百科 ====================
    
    @Sendable
    func getAllBirds(req: Request) async throws -> [BirdEncyclopediaDTO] {
        let birds = try await BirdEncyclopedia.query(on: req.db)
            .sort(\.$name, .ascending)
            .all()
        return birds.map { BirdEncyclopediaDTO.from($0) }
    }
    
    @Sendable
    func getBirdById(req: Request) async throws -> BirdEncyclopediaDTO {
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟类ID")
        }
        
        guard let bird = try await BirdEncyclopedia.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟类不存在")
        }
        
        return BirdEncyclopediaDTO.from(bird)
    }
    
    @Sendable
    func searchBirds(req: Request) async throws -> [BirdEncyclopediaDTO] {
        let keyword = req.query[String.self, at: "keyword"] ?? ""
        
        if keyword.isEmpty {
            return try await getAllBirds(req: req)
        }
        
        let expanded = expandKeywords(from: keyword)
        
        // 广泛模糊搜索
        let birds = try await BirdEncyclopedia.query(on: req.db)
            .group(.or) { group in
                for kw in expanded {
                    group.filter(\.$name ~~ kw)
                    group.filter(\.$category ~~ kw)
                    group.filter(\.$aliases ~~ kw)
                    group.filter(\.$description ~~ kw)
                    group.filter(\.$tags ~~ kw)
                }
                // 单字拆分匹配
                if keyword.count >= 2 {
                    for char in keyword {
                        let charStr = String(char)
                        group.filter(\.$name ~~ charStr)
                        group.filter(\.$aliases ~~ charStr)
                    }
                }
            }
            .all()
        
        // 去重 + 相关性排序
        var seen = Set<Int64>()
        var uniqueBirds: [BirdEncyclopedia] = []
        for bird in birds {
            if let id = bird.id, !seen.contains(id) {
                seen.insert(id)
                uniqueBirds.append(bird)
            }
        }
        
        let sorted = uniqueBirds.sorted { a, b in
            return birdSearchScoreSmart(bird: a, query: keyword, expanded: expanded) > birdSearchScoreSmart(bird: b, query: keyword, expanded: expanded)
        }
        
        return sorted.map { BirdEncyclopediaDTO.from($0) }
    }
    
    /// 计算鸟类智能搜索相关性评分
    private func birdSearchScoreSmart(bird: BirdEncyclopedia, query: String, expanded: [String]) -> Int {
        var score = 0
        if bird.name == query { score += 500 }
        else if bird.name.contains(query) { score += 300 }
        
        if let aliases = bird.aliases {
            let list = aliases.components(separatedBy: ",")
            if list.contains(query) { score += 400 }
            else if aliases.contains(query) { score += 250 }
        }
        
        for kw in expanded {
            if bird.name == kw { score += 200 }
            else if bird.name.contains(kw) { score += 150 }
            
            if let aliases = bird.aliases {
                let list = aliases.components(separatedBy: ",")
                if list.contains(kw) { score += 180 }
                else if aliases.contains(kw) { score += 120 }
            }
            
            if let category = bird.category, category.contains(kw) { score += 80 }
            if let desc = bird.description, desc.contains(kw) { score += 50 }
        }
        
        for char in query {
            if bird.name.contains(char) { score += 10 }
            if let aliases = bird.aliases, aliases.contains(char) { score += 8 }
        }
        return score
    }
    
    @Sendable
    func getAllBirdCategories(req: Request) async throws -> [String] {
        let birds = try await BirdEncyclopedia.query(on: req.db).all()
        let categories = Set(birds.compactMap { $0.category })
        return Array(categories).sorted()
    }
    
    @Sendable
    func getBirdsByCategory(req: Request) async throws -> [BirdEncyclopediaDTO] {
        guard let category = req.parameters.get("category") else {
            throw Abort(.badRequest, reason: "缺少分类参数")
        }
        
        let birds = try await BirdEncyclopedia.query(on: req.db)
            .filter(\.$category == category)
            .all()
        
        return birds.map { BirdEncyclopediaDTO.from($0) }
    }
    
    // ==================== 症状速查 ====================
    
    @Sendable
    func getAllSymptoms(req: Request) async throws -> [SymptomDTO] {
        let symptoms = try await Symptom.query(on: req.db)
            .sort(\.$name, .ascending)
            .all()
        return symptoms.map { SymptomDTO.from($0) }
    }
    
    @Sendable
    func getSymptomById(req: Request) async throws -> SymptomDTO {
        guard let symptomIdStr = req.parameters.get("symptomId"),
              let symptomId = Int64(symptomIdStr) else {
            throw Abort(.badRequest, reason: "无效的症状ID")
        }
        
        guard let symptom = try await Symptom.find(symptomId, on: req.db) else {
            throw Abort(.notFound, reason: "症状不存在")
        }
        
        return SymptomDTO.from(symptom)
    }
    
    @Sendable
    func searchSymptoms(req: Request) async throws -> [SymptomDTO] {
        let keyword = req.query[String.self, at: "keyword"] ?? ""
        
        if keyword.isEmpty {
            return try await getAllSymptoms(req: req)
        }
        
        let expanded = expandKeywords(from: keyword)
        
        // 广泛模糊搜索：名称、别名（口语化关键词）、描述、可能原因、建议
        let symptoms = try await Symptom.query(on: req.db)
            .group(.or) { group in
                for kw in expanded {
                    group.filter(\.$name ~~ kw)
                    group.filter(\.$aliases ~~ kw)
                    group.filter(\.$description ~~ kw)
                    group.filter(\.$possibleCauses ~~ kw)
                    group.filter(\.$suggestions ~~ kw)
                    group.filter(\.$category ~~ kw)
                }
                // 单字拆分匹配
                if keyword.count >= 2 {
                    for char in keyword {
                        let charStr = String(char)
                        group.filter(\.$name ~~ charStr)
                        group.filter(\.$aliases ~~ charStr)
                    }
                }
            }
            .all()
        
        // 去重 + 相关性排序
        var seen = Set<Int64>()
        var uniqueSymptoms: [Symptom] = []
        for symptom in symptoms {
            if let id = symptom.id, !seen.contains(id) {
                seen.insert(id)
                uniqueSymptoms.append(symptom)
            }
        }
        
        let sorted = uniqueSymptoms.sorted { a, b in
            return symptomSearchScoreSmart(symptom: a, query: keyword, expanded: expanded) > symptomSearchScoreSmart(symptom: b, query: keyword, expanded: expanded)
        }
        
        return sorted.map { SymptomDTO.from($0) }
    }
    
    /// 计算症状智能搜索相关性评分
    private func symptomSearchScoreSmart(symptom: Symptom, query: String, expanded: [String]) -> Int {
        var score = 0
        // 1. 完全匹配原始查询词
        if symptom.name == query { score += 500 }
        else if symptom.name.contains(query) { score += 300 }
        
        // 2. 别名（口语化）完全匹配原始查询词
        if let aliases = symptom.aliases {
            let list = aliases.components(separatedBy: ",")
            if list.contains(query) { score += 450 }
            else if aliases.contains(query) { score += 280 }
        }
        
        // 3. 匹配扩展的同义词
        for kw in expanded {
            if symptom.name == kw { score += 200 }
            else if symptom.name.contains(kw) { score += 150 }
            
            if let aliases = symptom.aliases {
                let list = aliases.components(separatedBy: ",")
                if list.contains(kw) { score += 180 }
                else if aliases.contains(kw) { score += 120 }
            }
            
            if let category = symptom.category, category.contains(kw) { score += 80 }
            if let desc = symptom.description, desc.contains(kw) { score += 50 }
            if let causes = symptom.possibleCauses, causes.contains(kw) { score += 30 }
        }
        
        // 4. 单字匹配
        for char in query {
            if symptom.name.contains(char) { score += 10 }
            if let aliases = symptom.aliases, aliases.contains(char) { score += 8 }
        }
        return score
    }
    
    @Sendable
    func getSymptomsBySeverity(req: Request) async throws -> [SymptomDTO] {
        guard let severity = req.parameters.get("severity") else {
            throw Abort(.badRequest, reason: "缺少严重程度参数")
        }
        
        let symptoms = try await Symptom.query(on: req.db)
            .filter(\.$severity == severity)
            .all()
        
        return symptoms.map { SymptomDTO.from($0) }
    }
    
    @Sendable
    func getSymptomsByCategory(req: Request) async throws -> [SymptomDTO] {
        guard let category = req.parameters.get("category") else {
            throw Abort(.badRequest, reason: "缺少分类参数")
        }
        
        let symptoms = try await Symptom.query(on: req.db)
            .filter(\.$category == category)
            .all()
        
        return symptoms.map { SymptomDTO.from($0) }
    }
    
    @Sendable
    func filterSymptoms(req: Request) async throws -> [SymptomDTO] {
        let category = req.query[String.self, at: "category"]
        let severity = req.query[String.self, at: "severity"]
        
        var query = Symptom.query(on: req.db)
        
        if let category = category, !category.isEmpty {
            query = query.filter(\.$category == category)
        }
        if let severity = severity, !severity.isEmpty {
            query = query.filter(\.$severity == severity)
        }
        
        let symptoms = try await query.all()
        return symptoms.map { SymptomDTO.from($0) }
    }
}

// MARK: - 食物百科模型
final class BirdFood: Model, Content, @unchecked Sendable {
    static let schema = "bird_foods"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "category")
    var category: String
    
    @Field(key: "food_name")
    var foodName: String
    
    @Field(key: "intro")
    var intro: String
    
    @Field(key: "nutrition")
    var nutrition: String
    
    @Field(key: "precautions")
    var precautions: String
    
    @Field(key: "safety_level")
    var safetyLevel: String
    
    @OptionalField(key: "source")
    var source: String?
    
    @OptionalField(key: "status")
    var status: Int?
    
    @OptionalField(key: "aliases")
    var aliases: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    // 兼容旧代码的 name 属性
    var name: String { foodName }
}

// MARK: - 鸟类百科模型
final class BirdEncyclopedia: Model, Content, @unchecked Sendable {
    static let schema = "bird_encyclopedia"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "name")
    var name: String
    
    @OptionalField(key: "scientific_name")
    var scientificName: String?
    
    @OptionalField(key: "category")
    var category: String?
    
    @OptionalField(key: "tags")
    var tags: String?
    
    @OptionalField(key: "description")
    var description: String?
    
    @OptionalField(key: "feeding_tips")
    var feedingTips: String?
    
    @OptionalField(key: "habitat")
    var habitat: String?
    
    @OptionalField(key: "lifespan")
    var lifespan: Int?
    
    @OptionalField(key: "color_hex")
    var colorHex: String?
    
    @OptionalField(key: "image_url")
    var imageUrl: String?
    
    @OptionalField(key: "weight_min")
    var weightMin: Double?
    
    @OptionalField(key: "weight_max")
    var weightMax: Double?
    
    @OptionalField(key: "price_min")
    var priceMin: Int?
    
    @OptionalField(key: "price_max")
    var priceMax: Int?
    
    @OptionalField(key: "aliases")
    var aliases: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
}

// MARK: - 症状模型
final class Symptom: Model, Content, @unchecked Sendable {
    static let schema = "symptoms"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "name")
    var name: String
    
    @OptionalField(key: "description")
    var description: String?
    
    @OptionalField(key: "possible_causes")
    var possibleCauses: String?
    
    @OptionalField(key: "suggestions")
    var suggestions: String?
    
    @OptionalField(key: "when_to_see_vet")
    var whenToSeeVet: String?
    
    @OptionalField(key: "prevention")
    var prevention: String?
    
    @OptionalField(key: "severity")
    var severity: String?
    
    @OptionalField(key: "category")
    var category: String?
    
    @OptionalField(key: "icon")
    var icon: String?
    
    @OptionalField(key: "aliases")
    var aliases: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
}

// MARK: - DTOs
struct FoodEncyclopediaDTO: Content {
    let id: Int64
    let foodName: String  // 修复：前端期望 foodName 而不是 name
    let category: String
    let safetyLevel: String
    let intro: String
    let nutrition: [String]  // 修复：前端期望数组
    let precautions: String
    let source: String?
    let status: Int?
    
    static func from(_ food: BirdFood) -> FoodEncyclopediaDTO {
        // 解析 nutrition 字符串为数组（支持 JSON 数组格式或逗号分隔）
        var nutritionArray: [String] = []
        if !food.nutrition.isEmpty {
            // 尝试解析为 JSON 数组
            if let data = food.nutrition.data(using: .utf8),
               let parsed = try? JSONDecoder().decode([String].self, from: data) {
                nutritionArray = parsed
            } else {
                // 回退：按逗号或换行分隔
                nutritionArray = food.nutrition
                    .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
        
        return FoodEncyclopediaDTO(
            id: food.id ?? 0,
            foodName: food.foodName,  // 修复：使用 foodName
            category: food.category,
            safetyLevel: food.safetyLevel,
            intro: food.intro,
            nutrition: nutritionArray,
            precautions: food.precautions,
            source: food.source,
            status: food.status
        )
    }
}

struct BirdEncyclopediaDTO: Content {
    let id: Int64
    let name: String
    let scientificName: String?
    let category: String?
    let tags: [String]?  // 修复：前端期望数组
    let description: String?
    let feedingTips: String?
    let habitat: String?
    let lifespan: Int?
    let colorHex: String?
    let imageUrl: String?
    let priceMin: Int?
    let priceMax: Int?
    
    static func from(_ bird: BirdEncyclopedia) -> BirdEncyclopediaDTO {
        // 解析 tags 字符串为数组
        var tagsArray: [String]? = nil
        if let tagsStr = bird.tags, !tagsStr.isEmpty {
            // 尝试解析为 JSON 数组
            if let data = tagsStr.data(using: .utf8),
               let parsed = try? JSONDecoder().decode([String].self, from: data) {
                tagsArray = parsed
            } else {
                // 回退：按逗号分隔
                tagsArray = tagsStr
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
        
        return BirdEncyclopediaDTO(
            id: bird.id ?? 0,
            name: bird.name,
            scientificName: bird.scientificName,
            category: bird.category,
            tags: tagsArray,
            description: bird.description,
            feedingTips: bird.feedingTips,
            habitat: bird.habitat,
            lifespan: bird.lifespan,
            colorHex: bird.colorHex,
            imageUrl: bird.imageUrl,
            priceMin: bird.priceMin,
            priceMax: bird.priceMax
        )
    }
}

struct SymptomDTO: Content {
    let id: Int64
    let name: String
    let category: String?
    let description: String?
    let severity: String?
    let possibleCauses: [String]?  // 修复：前端期望数组
    let suggestions: [String]?      // 修复：前端期望数组
    let whenToSeeVet: [String]?     // 修复：前端期望数组
    let prevention: [String]?       // 修复：前端期望数组
    let icon: String?
    
    /// 辅助函数：解析字符串为数组
    private static func parseStringToArray(_ str: String?) -> [String]? {
        guard let str = str, !str.isEmpty else { return nil }
        
        // 尝试解析为 JSON 数组
        if let data = str.data(using: .utf8),
           let parsed = try? JSONDecoder().decode([String].self, from: data) {
            return parsed
        }
        
        // 回退：按逗号或换行分隔
        let result = str
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return result.isEmpty ? nil : result
    }
    
    static func from(_ symptom: Symptom) -> SymptomDTO {
        SymptomDTO(
            id: symptom.id ?? 0,
            name: symptom.name,
            category: symptom.category,
            description: symptom.description,
            severity: symptom.severity,
            possibleCauses: parseStringToArray(symptom.possibleCauses),
            suggestions: parseStringToArray(symptom.suggestions),
            whenToSeeVet: parseStringToArray(symptom.whenToSeeVet),
            prevention: parseStringToArray(symptom.prevention),
            icon: symptom.icon
        )
    }
}

