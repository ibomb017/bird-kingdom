import Vapor
import Fluent

/// 日志控制器
struct BirdLogController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let logs = routes.grouped("logs")
        
        // 需要认证的路由
        let protected = logs.grouped(JWTAuthMiddleware())
        
        // 获取当前用户的所有日志
        protected.get(use: getAllLogs)
        
        // 获取单条日志
        protected.get(":logId", use: getLogById)
        
        // 获取某只鸟的日志
        protected.get("bird", ":birdId", use: getLogsByBirdId)
        
        // 创建日志
        protected.post(use: createLog)
        
        // 更新日志（PUT完整更新）
        protected.put(":logId", use: updateLog)
        
        // 部分更新日志（PATCH，支持前端右滑编辑）
        protected.patch(":logId", use: patchLog)
        
        // 删除日志
        protected.delete(":logId", use: deleteLog)
        
        // 批量创建日志
        protected.post("batch", use: createLogsBatch)
        
        // 获取体重趋势
        protected.get("weight-trend", use: getWeightTrend)
    }
    
    // MARK: - 权限检查辅助方法
    
    /// 检查用户是否有权操作某只鸟（包括伴侣和共享用户）
    private func checkBirdEditAccess(userId: Int64, birdId: Int64, on db: Database) async throws -> Bool {
        guard let bird = try await Bird.find(birdId, on: db) else {
            return false
        }
        
        // 鸟主人 - 完全权限
        if bird.userId == userId {
            return true
        }
        
        // 检查是否是情侣伴侣 - 完全权限
        if let user = try await User.find(userId, on: db),
           let partnerId = user.couplePartnerId,
           bird.userId == partnerId {
            return true
        }
        
        // 检查共享权限（需要 EDIT 权限）
        let share = try await BirdShare.query(on: db)
            .filter(\.$birdId == birdId)
            .filter(\.$sharedUserId == userId)
            .filter(\.$status == "ACCEPTED")
            .first()
        
        if let share = share {
            return share.role == "EDIT" || share.role == "ADMIN"
        }
        
        return false
    }
    
    // MARK: - 获取当前用户的所有日志
    @Sendable
    func getAllLogs(req: Request) async throws -> [BirdLogDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        // 获取当前用户和伴侣的用户ID列表
        let user = try await User.find(userId, on: req.db)
        var userIds = [userId]
        if let partnerId = user?.couplePartnerId {
            userIds.append(partnerId)
        }
        
        // 获取用户（及伴侣）的所有鸟
        let birds = try await Bird.query(on: req.db)
            .filter(\.$userId ~~ userIds)
            .filter(\.$isDeleted == false)
            .all()
        
        let birdIds = birds.compactMap { $0.id }
        
        // 构建 birdId -> birdName 映射
        var birdNameMap: [Int64: String] = [:]
        for bird in birds {
            if let id = bird.id {
                birdNameMap[id] = bird.nickname
            }
        }
        
        // 获取这些鸟的所有日志
        let logs = try await BirdLog.query(on: req.db)
            .filter(\.$birdId ~~ birdIds)
            .sort(\.$logDate, .descending)
            .all()
        
        // FIX: 批量查询所有日志的图片
        let logIds = logs.compactMap { $0.id }
        let allImages = try await BirdLogImage.query(on: req.db)
            .filter(\.$logId ~~ logIds)
            .sort(\.$sortOrder, .ascending)
            .all()
        
        // 构建 logId -> imageUrls 映射
        var imageUrlsMap: [Int64: [String]] = [:]
        for image in allImages {
            if imageUrlsMap[image.logId] == nil {
                imageUrlsMap[image.logId] = []
            }
            imageUrlsMap[image.logId]?.append(image.imageUrl)
        }
        
        return logs.map { log in
            let birdName = birdNameMap[log.birdId] ?? "未知鸟儿"
            let imageUrls = log.id.flatMap { imageUrlsMap[$0] }
            return BirdLogDTO.from(log, birdName: birdName, imageUrls: imageUrls)
        }
    }
    
    // MARK: - 获取单条日志
    @Sendable
    func getLogById(req: Request) async throws -> BirdLogDTO {
        guard let logIdStr = req.parameters.get("logId"),
              let logId = Int64(logIdStr) else {
            throw Abort(.badRequest, reason: "无效的日志ID")
        }
        
        guard let log = try await BirdLog.find(logId, on: req.db) else {
            throw Abort(.notFound, reason: "日志不存在")
        }
        
        // 获取鸟名
        let birdName = try await Bird.find(log.birdId, on: req.db)?.nickname ?? "未知鸟儿"
        return BirdLogDTO.from(log, birdName: birdName)
    }
    
    // MARK: - 获取某只鸟的日志
    @Sendable
    func getLogsByBirdId(req: Request) async throws -> [BirdLogDTO] {
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟ID")
        }
        
        // 获取鸟名
        let birdName = try await Bird.find(birdId, on: req.db)?.nickname ?? "未知鸟儿"
        
        let logs = try await BirdLog.query(on: req.db)
            .filter(\.$birdId == birdId)
            .sort(\.$logDate, .descending)
            .all()
        
        return logs.map { BirdLogDTO.from($0, birdName: birdName) }
    }
    
    // MARK: - 创建日志
    @Sendable
    func createLog(req: Request) async throws -> BirdLogDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct CreateLogRequest: Content {
            let birdId: Int64
            let logDate: Date?
            let weight: Double?
            let notes: String?
            let imageUrls: [String]?
        }
        
        let input = try req.content.decode(CreateLogRequest.self)
        
        // 验证用户是否有权操作该鸟（包括伴侣和共享用户）
        guard let bird = try await Bird.find(input.birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdEditAccess(userId: userId, birdId: input.birdId, on: req.db)
        guard hasAccess else {
            throw Abort(.forbidden, reason: "无权操作该鸟")
        }
        
        let log = BirdLog(
            birdId: input.birdId,
            logDate: input.logDate ?? Date(),
            weight: input.weight,
            notes: input.notes ?? ""
        )
        
        try await log.save(on: req.db)
        
        // 保存日志图片
        if let imageUrls = input.imageUrls, !imageUrls.isEmpty {
            for url in imageUrls {
                let image = BirdLogImage(logId: log.id!, imageUrl: url)
                try await image.save(on: req.db)
            }
        }
        
        return BirdLogDTO.from(log, birdName: bird.nickname)
    }
    
    // MARK: - 更新日志
    @Sendable
    func updateLog(req: Request) async throws -> BirdLogDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let logIdStr = req.parameters.get("logId"),
              let logId = Int64(logIdStr) else {
            throw Abort(.badRequest, reason: "无效的日志ID")
        }
        
        struct UpdateLogRequest: Content {
            let logDate: Date?
            let weight: Double?
            let notes: String?
        }
        
        let input = try req.content.decode(UpdateLogRequest.self)
        
        guard let log = try await BirdLog.find(logId, on: req.db) else {
            throw Abort(.notFound, reason: "日志不存在")
        }
        
        // 验证用户是否有权操作该鸟（包括伴侣和共享用户）
        guard let bird = try await Bird.find(log.birdId, on: req.db) else {
            throw Abort(.notFound, reason: "关联的鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdEditAccess(userId: userId, birdId: log.birdId, on: req.db)
        guard hasAccess else {
            throw Abort(.forbidden, reason: "无权操作该日志")
        }
        
        if let logDate = input.logDate {
            log.logDate = logDate
        }
        if let weight = input.weight {
            log.weight = weight
        }
        if let notes = input.notes {
            log.notes = notes
        }
        
        try await log.save(on: req.db)
        
        return BirdLogDTO.from(log, birdName: bird.nickname)
    }
    
    // MARK: - PATCH更新日志（部分更新，支持前端右滑编辑）
    @Sendable
    func patchLog(req: Request) async throws -> BirdLogDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let logIdStr = req.parameters.get("logId"),
              let logId = Int64(logIdStr) else {
            throw Abort(.badRequest, reason: "无效的日志ID")
        }
        
        struct PatchLogRequest: Content {
            let logDate: Date?
            let weight: Double?
            let mood: String?
            let behavior: String?
            let notes: String?
            let healthScore: Int?
            let imageUrls: [String]?
        }
        
        let input = try req.content.decode(PatchLogRequest.self)
        
        guard let log = try await BirdLog.find(logId, on: req.db) else {
            throw Abort(.notFound, reason: "日志不存在")
        }
        
        // 验证用户是否有权操作该鸟（包括伴侣和共享用户）
        guard let bird = try await Bird.find(log.birdId, on: req.db) else {
            throw Abort(.notFound, reason: "关联的鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdEditAccess(userId: userId, birdId: log.birdId, on: req.db)
        guard hasAccess else {
            throw Abort(.forbidden, reason: "无权操作该日志")
        }
        
        // 部分更新：仅更新传入的非nil字段
        if let logDate = input.logDate { log.logDate = logDate }
        if let weight = input.weight { log.weight = weight }
        if let mood = input.mood { log.mood = mood }
        if let behavior = input.behavior { log.behavior = behavior }
        if let notes = input.notes { log.notes = notes }
        if let healthScore = input.healthScore { log.healthScore = healthScore }
        
        try await log.save(on: req.db)
        
        // 更新图片（如有传入）
        var updatedImageUrls: [String]? = nil
        if let imageUrls = input.imageUrls {
            // 删除旧图片
            try await BirdLogImage.query(on: req.db)
                .filter(\.$logId == logId)
                .delete()
            
            // 添加新图片
            for (index, url) in imageUrls.enumerated() {
                let image = BirdLogImage(logId: logId, imageUrl: url, sortOrder: index)
                try await image.save(on: req.db)
            }
            updatedImageUrls = imageUrls
        } else {
            // 未传入图片则查询现有图片
            let images = try await BirdLogImage.query(on: req.db)
                .filter(\.$logId == logId)
                .sort(\.$sortOrder, .ascending)
                .all()
            updatedImageUrls = images.map { $0.imageUrl }
        }
        
        return BirdLogDTO.from(log, birdName: bird.nickname, imageUrls: updatedImageUrls)
    }
    
    // MARK: - 删除日志
    @Sendable
    func deleteLog(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let logIdStr = req.parameters.get("logId"),
              let logId = Int64(logIdStr) else {
            throw Abort(.badRequest, reason: "无效的日志ID")
        }
        
        guard let log = try await BirdLog.find(logId, on: req.db) else {
            throw Abort(.notFound, reason: "日志不存在")
        }
        
        // 验证用户是否有权操作该鸟（包括伴侣和共享用户）
        let hasAccess = try await checkBirdEditAccess(userId: userId, birdId: log.birdId, on: req.db)
        guard hasAccess else {
            throw Abort(.forbidden, reason: "无权删除该日志")
        }
        
        // 删除关联的图片
        try await BirdLogImage.query(on: req.db)
            .filter(\.$logId == logId)
            .delete()
        
        try await log.delete(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 批量创建日志
    @Sendable
    func createLogsBatch(req: Request) async throws -> [BirdLogDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct CreateLogRequest: Content {
            let birdId: Int64
            let logDate: Date?
            let weight: Double?
            let notes: String?
        }
        
        let inputs = try req.content.decode([CreateLogRequest].self)
        var results: [BirdLogDTO] = []
        
        for input in inputs {
            // 验证鸟属于当前用户
            guard let bird = try await Bird.find(input.birdId, on: req.db),
                  bird.userId == userId else {
                continue
            }
            
            let log = BirdLog(
                birdId: input.birdId,
                logDate: input.logDate ?? Date(),
                weight: input.weight,
                notes: input.notes ?? ""
            )
            
            try await log.save(on: req.db)
            results.append(BirdLogDTO.from(log, birdName: bird.nickname))
        }
        
        return results
    }
    
    // MARK: - 获取体重趋势
    @Sendable
    func getWeightTrend(req: Request) async throws -> [WeightTrendDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        let birdId = req.query[Int64.self, at: "birdId"]
        let range = req.query[String.self, at: "range"] ?? "month"
        
        // 计算日期范围
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch range {
        case "week":
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case "quarter":
            startDate = calendar.date(byAdding: .month, value: -3, to: now)!
        case "year":
            startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        case "all":  // FIX: 新增全部时间范围支持
            startDate = Date(timeIntervalSince1970: 0)
        default: // month
            startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        }
        
        // 获取用户的鸟
        var birdIds: [Int64]
        if let birdId = birdId {
            birdIds = [birdId]
        } else {
            birdIds = try await Bird.query(on: req.db)
                .filter(\.$userId == userId)
                .filter(\.$isDeleted == false)
                .all()
                .compactMap { $0.id }
        }
        
        // 获取日志
        let logs = try await BirdLog.query(on: req.db)
            .filter(\.$birdId ~~ birdIds)
            .filter(\.$logDate >= startDate)
            .filter(\.$weight != nil)
            .sort(\.$logDate, .ascending)
            .all()
        
        // FIX: 每日去重 - 取同一天同一只鸟的最大ID记录
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        
        var latestByDateBird: [String: (id: Int64, date: Date, weight: Double, birdId: Int64)] = [:]
        
        for log in logs {
            guard let logId = log.id, let weight = log.weight else { continue }
            let dateKey = dateFormatter.string(from: log.logDate)
            let key = "\(log.birdId)_\(dateKey)"  // 按鸟+日期组合去重
            
            if let existing = latestByDateBird[key] {
                if logId > existing.id {
                    latestByDateBird[key] = (logId, log.logDate, weight, log.birdId)
                }
            } else {
                latestByDateBird[key] = (logId, log.logDate, weight, log.birdId)
            }
        }
        
        // 转换为DTO并按日期排序
        return latestByDateBird.values
            .sorted { $0.date < $1.date }
            .map { WeightTrendDTO(date: $0.date, weight: $0.weight, birdId: $0.birdId) }
    }
}

// MARK: - 日志模型
final class BirdLog: Model, Content, @unchecked Sendable {
    static let schema = "bird_logs"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "bird_id")
    var birdId: Int64
    
    @Field(key: "log_date")
    var logDate: Date
    
    @OptionalField(key: "weight")
    var weight: Double?
    
    @OptionalField(key: "feed_amount")
    var feedAmount: Double?
    
    @OptionalField(key: "water_amount")
    var waterAmount: Double?
    
    @OptionalField(key: "health_score")
    var healthScore: Int?
    
    @OptionalField(key: "mood")
    var mood: String?
    
    @OptionalField(key: "behavior")
    var behavior: String?
    
    @OptionalField(key: "is_molting")
    var isMolting: Bool?
    
    @OptionalField(key: "is_breeding")
    var isBreeding: Bool?
    
    @OptionalField(key: "temperature")
    var temperature: Double?
    
    @OptionalField(key: "humidity")
    var humidity: Double?
    
    @OptionalField(key: "is_cleaned")
    var isCleaned: Bool?
    
    @OptionalField(key: "notes")
    var notes: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, birdId: Int64, logDate: Date, weight: Double? = nil, notes: String? = nil) {
        self.id = id
        self.birdId = birdId
        self.logDate = logDate
        self.weight = weight
        self.notes = notes
    }
}

// MARK: - 日志图片模型
final class BirdLogImage: Model, Content, @unchecked Sendable {
    static let schema = "bird_log_images"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "log_id")
    var logId: Int64
    
    @Field(key: "image_url")
    var imageUrl: String
    
    @OptionalField(key: "sort_order")
    var sortOrder: Int?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, logId: Int64, imageUrl: String, sortOrder: Int? = 0) {
        self.id = id
        self.logId = logId
        self.imageUrl = imageUrl
        self.sortOrder = sortOrder
    }
}

// MARK: - DTOs
struct BirdLogDTO: Content {
    let id: Int64
    let birdId: Int64
    let birdName: String  // 添加：前端必需的字段
    let logDate: Date
    let weight: Double?
    let feedAmount: Double?
    let waterAmount: Double?
    let healthScore: Int?
    let mood: String?
    let behavior: String?
    let isMolting: Bool?
    let isBreeding: Bool?
    let temperature: Double?
    let humidity: Double?
    let isCleaned: Bool?
    let notes: String?
    let imageUrls: [String]?
    let createdAt: Date?
    let updatedAt: Date?
    
    static func from(_ log: BirdLog, birdName: String = "未知鸟儿", imageUrls: [String]? = nil) -> BirdLogDTO {
        BirdLogDTO(
            id: log.id ?? 0,
            birdId: log.birdId,
            birdName: birdName,
            logDate: log.logDate,
            weight: log.weight,
            feedAmount: log.feedAmount,
            waterAmount: log.waterAmount,
            healthScore: log.healthScore,
            mood: log.mood,
            behavior: log.behavior,
            isMolting: log.isMolting,
            isBreeding: log.isBreeding,
            temperature: log.temperature,
            humidity: log.humidity,
            isCleaned: log.isCleaned,
            notes: log.notes,
            imageUrls: imageUrls,  // FIX: 使用传入的imageUrls参数
            createdAt: log.createdAt,
            updatedAt: log.updatedAt
        )
    }
}

struct WeightTrendDTO: Content {
    let date: Date
    let weight: Double
    let birdId: Int64
}


