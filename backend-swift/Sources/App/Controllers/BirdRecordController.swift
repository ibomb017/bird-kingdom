import Vapor
import Fluent

/// 鸟儿记录控制器（产蛋/洗澡）
struct BirdRecordController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // 鸟的记录路由
        let birdRecords = routes.grouped("birds", ":birdId", "cycles")
        let protectedBird = birdRecords.grouped(JWTAuthMiddleware())
        
        // 获取某鸟所有记录
        protectedBird.get(use: getRecords)
        
        // 获取某鸟正在进行中的周期
        protectedBird.get("active", use: getActiveRecords)
        
        // 新增记录
        protectedBird.post(use: createRecord)
        
        // 记录的单独操作路由
        let records = routes.grouped("cycles")
        let protectedRecords = records.grouped(JWTAuthMiddleware())
        
        // 更新记录（结束周期等）
        protectedRecords.put(":cycleId", use: updateRecord)
        
        // 删除记录
        protectedRecords.delete(":cycleId", use: deleteRecord)
    }
    
    // MARK: - 获取某鸟所有记录
    @Sendable
    func getRecords(req: Request) async throws -> [BirdRecordDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟ID")
        }
        
        // 验证鸟的权限
        guard try await checkBirdAccess(birdId: birdId, userId: userId, db: req.db) else {
            throw Abort(.forbidden, reason: "无权限访问该鸟的数据")
        }
        
        let records = try await BirdRecord.query(on: req.db)
            .filter(\.$birdId == birdId)
            .sort(\.$recordDate, .descending)
            .all()
        
        return records.map { BirdRecordDTO.from($0) }
    }
    
    // MARK: - 获取某鸟正在进行中的周期（endDate 为空的记录）
    @Sendable
    func getActiveRecords(req: Request) async throws -> [BirdRecordDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟ID")
        }
        
        // 验证鸟的权限
        guard try await checkBirdAccess(birdId: birdId, userId: userId, db: req.db) else {
            throw Abort(.forbidden, reason: "无权限访问该鸟的数据")
        }
        
        // 查询 endDate 为空的记录（正在进行中）
        let records = try await BirdRecord.query(on: req.db)
            .filter(\.$birdId == birdId)
            .filter(\.$endDate == nil)
            .sort(\.$recordDate, .descending)
            .all()
        
        return records.map { BirdRecordDTO.from($0) }
    }
    
    // MARK: - 新增记录
    @Sendable
    func createRecord(req: Request) async throws -> BirdRecordDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let birdIdStr = req.parameters.get("birdId"),
              let birdId = Int64(birdIdStr) else {
            throw Abort(.badRequest, reason: "无效的鸟ID")
        }
        
        struct CreateRecordRequest: Content {
            let cycleType: String   // 兼容前端字段名
            let startDate: String   // 改为 String，手动解析支持多种格式
            let notes: String?
            let eggCount: Int?      // 产蛋数量
            let hatchedCount: Int?  // 孵化数量
        }
        
        let input = try req.content.decode(CreateRecordRequest.self)
        
        // 解析日期，支持多种格式
        let parsedDate = try parseDate(input.startDate, req: req)
        
        req.logger.info("[DateDebug] Saving recordDate: \(parsedDate) for bird \(birdId)")
        
        // 验证记录类型
        let recordType = input.cycleType.uppercased()
        guard recordType == "EGG_LAYING" || recordType == "BATHING" else {
            throw Abort(.badRequest, reason: "无效的记录类型，只支持 EGG_LAYING 和 BATHING")
        }
        
        // 验证鸟的权限
        guard let bird = try await Bird.find(birdId, on: req.db) else {
            throw Abort(.notFound, reason: "鸟儿不存在")
        }
        
        let hasAccess = try await checkBirdAccess(birdId: birdId, userId: userId, db: req.db, requireEditPermission: true)
        if !hasAccess {
            throw Abort(.forbidden, reason: "无权限操作该鸟")
        }
        
        // 产蛋记录性别校验
        if recordType == "EGG_LAYING" && bird.gender != "FEMALE" {
            throw Abort(.badRequest, reason: "仅母鸟可添加产蛋记录")
        }
        
        // P3: 移除未来日期检查，因为我们标准化到 UTC 00:00 (CST 08:00)，如果在 CST 00:00-08:00 操作，会被误判为未来
        
        let record = BirdRecord(
            birdId: birdId,
            recordType: recordType,
            recordDate: parsedDate,
            notes: input.notes,
            eggCount: input.eggCount,
            hatchedCount: input.hatchedCount
        )
        
        try await record.save(on: req.db)
        req.logger.info("[DateDebug] Record saved successfully with ID: \(record.id ?? 0)")
        
        return BirdRecordDTO.from(record)
    }
    
    // MARK: - 更新记录（支持结束周期）
    @Sendable
    func updateRecord(req: Request) async throws -> BirdRecordDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let recordIdStr = req.parameters.get("cycleId"),
              let recordId = Int64(recordIdStr) else {
            throw Abort(.badRequest, reason: "无效的记录ID")
        }
        
        guard let record = try await BirdRecord.find(recordId, on: req.db) else {
            throw Abort(.notFound, reason: "记录不存在")
        }
        
        // 验证权限
        guard try await checkBirdAccess(birdId: record.birdId, userId: userId, db: req.db, requireEditPermission: true) else {
            throw Abort(.forbidden, reason: "无权限更新该记录")
        }
        
        struct UpdateRecordRequest: Content {
            let endDate: String?      // 结束日期
            let notes: String?
            let eggCount: Int?
            let hatchedCount: Int?
        }
        
        let input = try req.content.decode(UpdateRecordRequest.self)
        
        // 更新字段
        if let endDateStr = input.endDate {
            record.endDate = try parseDate(endDateStr, req: req)
        }
        if let notes = input.notes {
            record.notes = notes
        }
        if let eggCount = input.eggCount {
            record.eggCount = eggCount
        }
        if let hatchedCount = input.hatchedCount {
            record.hatchedCount = hatchedCount
        }
        
        try await record.save(on: req.db)
        
        return BirdRecordDTO.from(record)
    }
    
    // MARK: - 删除记录
    @Sendable
    func deleteRecord(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let recordIdStr = req.parameters.get("cycleId"),
              let recordId = Int64(recordIdStr) else {
            throw Abort(.badRequest, reason: "无效的记录ID")
        }
        
        guard let record = try await BirdRecord.find(recordId, on: req.db) else {
            throw Abort(.notFound, reason: "记录不存在")
        }
        
        // 验证权限
        guard try await checkBirdAccess(birdId: record.birdId, userId: userId, db: req.db) else {
            throw Abort(.forbidden, reason: "无权限删除该记录")
        }
        
        try await record.delete(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 辅助方法
    
    // MARK: - 辅助方法
    
    // MARK: - 辅助方法
    
    /// 解析日期字符串
    /// P3 最终修复：Fluent 时区适配
    /// 问题根源：Fluent 默认使用 UTC 去序列化 Date 到 MySQL 的 DATE 字段。
    /// 现象：北京时间 2026-02-02 00:00:00 的 UTC 时间是 2026-02-01 16:00:00。
    /// 结果：Fluent 截取 UTC 日期写入数据库，导致日期变成 "2026-02-01" (前一天)。
    /// 解决方案：构造一个在 UTC 时区下也是 "2026-02-02" 的 Date 对象 (即 UTC 00:00:00)。
    private func parseDate(_ dateStr: String, req: Request) throws -> Date {
        req.logger.info("[DateDebug] Parsing input: \(dateStr)")
        
        var components: DateComponents? = nil
        
        // 1. 优先尝试纯日期格式（yyyy-MM-dd）
        let dateOnlyScanner = Scanner(string: dateStr)
        // 手动提取，避免中间环节的时区干扰
        if dateStr.count >= 10 {
            let yStr = dateStr.prefix(4)
            let mStr = dateStr.dropFirst(5).prefix(2)
            let dStr = dateStr.dropFirst(8).prefix(2)
            
            if let y = Int(yStr), let m = Int(mStr), let d = Int(dStr) {
                 var comp = DateComponents()
                 comp.year = y
                 comp.month = m
                 comp.day = d
                 components = comp
            }
        }
        
        // 2. 备用：ISO8601
        if components == nil {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateStr) {
                 // 使用北京时区提取年月日
                 var calendar = Calendar(identifier: .gregorian)
                 calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
                 components = calendar.dateComponents([.year, .month, .day], from: date)
            }
        }
        
        guard let comps = components, let y = comps.year, let m = comps.month, let d = comps.day else {
            req.logger.error("[DateDebug] Invalid format")
            throw Abort(.badRequest, reason: "无效的日期格式")
        }
        
        // 3. 构造 标准 UTC 午夜时间
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)! // 显式使用 UTC
        
        guard let utcDate = utcCalendar.date(from: DateComponents(year: y, month: m, day: d)) else {
             throw Abort(.badRequest, reason: "日期构造失败")
        }
        
        req.logger.info("[DateDebug] Parsed Result: \(utcDate) (UTC Expected: \(y)-\(m)-\(d))")
        return utcDate
    }
    
    /// 检查用户是否有权访问某只鸟
    private func checkBirdAccess(birdId: Int64, userId: Int64, db: Database, requireEditPermission: Bool = false) async throws -> Bool {
        guard let bird = try await Bird.find(birdId, on: db) else {
            return false
        }
        
        // 鸟主人
        if bird.userId == userId {
            return true
        }
        
        // 检查是否是情侣伴侣
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
                return share.role == "EDIT" || share.role == "ADMIN" || share.role == "OWNER"
            }
            return true
        }
        
        return false
    }
}

// MARK: - 记录模型
final class BirdRecord: Model, Content, @unchecked Sendable {
    static let schema = "bird_record"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "bird_id")
    var birdId: Int64
    
    @Field(key: "record_type")
    var recordType: String
    
    @Field(key: "record_date")
    var recordDate: Date
    
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
    
    init(id: Int64? = nil, birdId: Int64, recordType: String, recordDate: Date, endDate: Date? = nil, notes: String? = nil, eggCount: Int? = nil, hatchedCount: Int? = nil) {
        self.id = id
        self.birdId = birdId
        self.recordType = recordType
        self.recordDate = recordDate
        self.endDate = endDate
        self.notes = notes
        self.eggCount = eggCount
        self.hatchedCount = hatchedCount
    }
}

// MARK: - DTO（兼容前端字段名）
struct BirdRecordDTO: Content {
    let id: Int64
    let birdId: Int64
    let cycleType: String       // 兼容前端
    let startDate: String       // P3 修复：改为 String，使用北京时区格式化
    let endDate: String?        // P3 修复：改为 String
    let notes: String?
    let eggCount: Int?          // 产蛋数量
    let hatchedCount: Int?      // 孵化数量
    let createdAt: Date?
    
    /// P3 修复 Ver.3：
    /// 写入时我们构造了 UTC 00:00 (CST 08:00)，确保写入正确。
    /// 读取时，如果服务器是 CST，Fluent 可能会读成 CST 00:00 (UTC 16:00 前一天)。
    /// 所以格式化时必须用 CST (服务器本地时区) 来还原日期，否则用 UTC 格式化会变成前一天。
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static func from(_ record: BirdRecord) -> BirdRecordDTO {
        BirdRecordDTO(
            id: record.id ?? 0,
            birdId: record.birdId,
            cycleType: record.recordType,
            startDate: dateFormatter.string(from: record.recordDate),
            endDate: record.endDate.map { dateFormatter.string(from: $0) },
            notes: record.notes,
            eggCount: record.eggCount,
            hatchedCount: record.hatchedCount,
            createdAt: record.createdAt
        )
    }
}

