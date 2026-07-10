import Vapor
import Fluent

/// 生理周期控制器
struct BirdCycleController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // 鸟的周期路由
        let birdCycles = routes.grouped("birds", ":birdId", "cycles")
        let protectedBird = birdCycles.grouped(JWTAuthMiddleware())
        
        // 获取某鸟所有周期记录
        protectedBird.get(use: getCycles)
        
        // 获取某鸟某类型的周期记录
        protectedBird.get(":type", use: getCyclesByType)
        
        // 获取某鸟正在进行中的周期
        protectedBird.get("active", use: getActiveCycles)
        
        // 新增周期记录
        protectedBird.post(use: createCycle)
        
        // 周期的更新和删除路由
        let cycles = routes.grouped("cycles")
        let protectedCycles = cycles.grouped(JWTAuthMiddleware())
        
        // 更新周期记录
        protectedCycles.put(":cycleId", use: updateCycle)
        
        // 删除周期记录
        protectedCycles.delete(":cycleId", use: deleteCycle)
    }
    
    // MARK: - 获取某鸟所有周期记录
    @Sendable
    func getCycles(req: Request) async throws -> [BirdCycleRecordDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟ID")
        }
        
        // 验证鸟的权限
        guard try await isBirdOwnedByUser(birdId: birdId, userId: userId, db: req.db) else {
            throw Abort(.forbidden, reason: "无权限访问该鸟的数据")
        }
        
        let cycles = try await BirdCycleRecord.query(on: req.db)
            .filter(\.$birdId == birdId)
            .sort(\.$startDate, .descending)
            .all()
        
        return cycles.map { BirdCycleRecordDTO.from($0) }
    }
    
    // MARK: - 获取某鸟某类型的周期记录
    @Sendable
    func getCyclesByType(req: Request) async throws -> [BirdCycleRecordDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr),
              let typeStr = req.parameters.get("type") else {
            throw Abort(.badRequest, reason: "无效的参数")
        }
        
        guard try await isBirdOwnedByUser(birdId: birdId, userId: userId, db: req.db) else {
            throw Abort(.forbidden, reason: "无权限访问该鸟的数据")
        }
        
        let cycleType = typeStr.uppercased()
        
        let cycles = try await BirdCycleRecord.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$cycleType == cycleType)
            .sort(\.$startDate, .descending)
            .all()
        
        return cycles.map { BirdCycleRecordDTO.from($0) }
    }
    
    // MARK: - 获取某鸟正在进行中的周期
    @Sendable
    func getActiveCycles(req: Request) async throws -> [BirdCycleRecordDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟ID")
        }
        
        guard try await isBirdOwnedByUser(birdId: birdId, userId: userId, db: req.db) else {
            throw Abort(.forbidden, reason: "无权限访问该鸟的数据")
        }
        
        let cycles = try await BirdCycleRecord.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$endDate == nil)
            .all()
        
        return cycles.map { BirdCycleRecordDTO.from($0) }
    }
    
    // MARK: - 新增周期记录
    @Sendable
    func createCycle(req: Request) async throws -> BirdCycleRecordDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟ID")
        }
        
        struct CreateCycleRequest: Content {
            let cycleType: String
            let startDate: Date
            let endDate: Date?
            let notes: String?
            let eggCount: Int?
            let hatchedCount: Int?
        }
        
        let input = try req.content.decode(CreateCycleRequest.self)
        
        // 验证鸟的权限 - FIX: 使用 checkBirdAccess 支持伴侣和共享用户
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdAccess(birdId: birdId, userId: userId, db: req.db, requireEditPermission: true)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权限操作该鸟")
        }
        
        // 产蛋期性别校验
        if input.cycleType.uppercased() == "EGG_LAYING" && bird.gender != "FEMALE" {
            throw Abort(.badRequest, reason: "仅母鸟可添加产蛋期记录")
        }
        
        // 开始日期不能在未来
        if input.startDate > Date() {
            throw Abort(.badRequest, reason: "开始日期不能在未来")
        }
        
        // 结束日期不能早于开始日期
        if let endDate = input.endDate, endDate < input.startDate {
            throw Abort(.badRequest, reason: "结束日期不能早于开始日期")
        }
        
        // 检查是否已有该类型的进行中周期
        let existingCycle = try await BirdCycleRecord.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$cycleType == input.cycleType.uppercased())
            .filter(\.$endDate == nil)
            .first()
        
        if existingCycle != nil {
            let typeName = getCycleTypeName(input.cycleType)
            throw Abort(.badRequest, reason: "已有进行中的\(typeName)，请先结束当前周期")
        }
        
        let cycle = BirdCycleRecord(
            birdId: birdId,
            cycleType: input.cycleType.uppercased(),
            startDate: input.startDate,
            endDate: input.endDate,
            notes: input.notes,
            eggCount: input.eggCount,
            hatchedCount: input.hatchedCount
        )
        
        try await cycle.save(on: req.db)
        
        return BirdCycleRecordDTO.from(cycle)
    }
    
    // MARK: - 更新周期记录
    @Sendable
    func updateCycle(req: Request) async throws -> BirdCycleRecordDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let cycleIdStr = req.parameters.get("cycleId"),
              let cycleId = Int64(cycleIdStr) else {
            throw Abort(.badRequest, reason: "无效的周期ID")
        }
        
        struct UpdateCycleRequest: Content {
            let endDate: Date?
            let notes: String?
            let eggCount: Int?
            let hatchedCount: Int?
        }
        
        let input = try req.content.decode(UpdateCycleRequest.self)
        
        guard let cycle = try await BirdCycleRecord.find(cycleId, on: req.db) else {
            throw Abort(.notFound, reason: "周期记录不存在")
        }
        
        // 验证权限
        guard try await isBirdOwnedByUser(birdId: cycle.birdId, userId: userId, db: req.db) else {
            throw Abort(.forbidden, reason: "无权限操作该记录")
        }
        
        if let endDate = input.endDate {
            cycle.endDate = endDate
        }
        if let notes = input.notes {
            cycle.notes = notes
        }
        if let eggCount = input.eggCount {
            cycle.eggCount = eggCount
        }
        if let hatchedCount = input.hatchedCount {
            cycle.hatchedCount = hatchedCount
        }
        
        try await cycle.save(on: req.db)
        
        return BirdCycleRecordDTO.from(cycle)
    }
    
    // MARK: - 删除周期记录
    @Sendable
    func deleteCycle(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let cycleIdStr = req.parameters.get("cycleId"),
              let cycleId = Int64(cycleIdStr) else {
            throw Abort(.badRequest, reason: "无效的周期ID")
        }
        
        guard let cycle = try await BirdCycleRecord.find(cycleId, on: req.db) else {
            throw Abort(.notFound, reason: "周期记录不存在")
        }
        
        // 验证权限
        guard try await isBirdOwnedByUser(birdId: cycle.birdId, userId: userId, db: req.db) else {
            throw Abort(.forbidden, reason: "无权限删除该记录")
        }
        
        try await cycle.delete(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 辅助方法
    
    /// 检查用户是否有权访问某只鸟（包括伴侣和共享用户）
    private func checkBirdAccess(birdId: Int64, userId: Int64, db: Database, requireEditPermission: Bool = false) async throws -> Bool {
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
        
        // 检查共享权限
        let share = try await BirdShare.query(on: db)
            .filter(\.$birdId == birdId)
            .filter(\.$sharedUserId == userId)
            .filter(\.$status == "ACCEPTED")
            .first()
        
        if let share = share {
            if requireEditPermission {
                return share.role == "EDIT" || share.role == "ADMIN"
            }
            return true
        }
        
        return false
    }
    
    /// 兼容旧接口
    private func isBirdOwnedByUser(birdId: Int64, userId: Int64, db: Database) async throws -> Bool {
        return try await checkBirdAccess(birdId: birdId, userId: userId, db: db)
    }
    
    private func getCycleTypeName(_ type: String) -> String {
        switch type.uppercased() {
        case "MOLTING": return "换羽期"
        case "EGG_LAYING": return "产蛋期"
        case "BREEDING": return "发情期"
        default: return type
        }
    }
}

// MARK: - 生理周期模型
final class BirdCycleRecord: Model, Content, @unchecked Sendable {
    static let schema = "bird_cycle_record"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "bird_id")
    var birdId: Int64
    
    @Field(key: "cycle_type")
    var cycleType: String
    
    @Field(key: "start_date")
    var startDate: Date
    
    @OptionalField(key: "end_date")
    var endDate: Date?
    
    @OptionalField(key: "notes")
    var notes: String?
    
    @OptionalField(key: "egg_count")
    var eggCount: Int?
    
    @OptionalField(key: "hatched_count")
    var hatchedCount: Int?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, birdId: Int64, cycleType: String, startDate: Date,
         endDate: Date? = nil, notes: String? = nil, eggCount: Int? = nil, hatchedCount: Int? = nil) {
        self.id = id
        self.birdId = birdId
        self.cycleType = cycleType
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.eggCount = eggCount
        self.hatchedCount = hatchedCount
    }
}

// MARK: - DTO
struct BirdCycleRecordDTO: Content {
    let id: Int64
    let birdId: Int64
    let cycleType: String
    let startDate: Date
    let endDate: Date?
    let notes: String?
    let eggCount: Int?
    let hatchedCount: Int?
    let createdAt: Date?
    let updatedAt: Date?
    
    static func from(_ record: BirdCycleRecord) -> BirdCycleRecordDTO {
        BirdCycleRecordDTO(
            id: record.id ?? 0,
            birdId: record.birdId,
            cycleType: record.cycleType,
            startDate: record.startDate,
            endDate: record.endDate,
            notes: record.notes,
            eggCount: record.eggCount,
            hatchedCount: record.hatchedCount,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}
