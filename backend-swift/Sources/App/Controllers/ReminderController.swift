import Vapor
import Fluent

/// 提醒控制器
struct ReminderController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let reminders = routes.grouped("reminders")
        
        // 需要认证的路由
        let protected = reminders.grouped(JWTAuthMiddleware())
        
        // 获取当前用户的提醒
        protected.get(use: getAllReminders)
        
        // 获取已启用的提醒
        protected.get("enabled", use: getEnabledReminders)
        
        // 获取单个提醒
        protected.get(":reminderId", use: getReminderById)
        
        // 创建提醒
        protected.post(use: createReminder)
        
        // 更新提醒
        protected.put(":reminderId", use: updateReminder)
        
        // 切换提醒启用状态
        protected.patch(":reminderId", "toggle", use: toggleReminder)
        
        // 删除提醒
        protected.delete(":reminderId", use: deleteReminder)
    }
    
    // MARK: - 获取当前用户的提醒
    @Sendable
    func getAllReminders(req: Request) async throws -> [ReminderDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let reminders = try await Reminder.query(on: req.db)
            .filter(\.$userId == userId)
            .sort(\.$createdAt, .descending)
            .all()
        
        return reminders.map { ReminderDTO.from($0) }
    }
    
    // MARK: - 获取已启用的提醒
    @Sendable
    func getEnabledReminders(req: Request) async throws -> [ReminderDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let reminders = try await Reminder.query(on: req.db)
            .filter(\.$userId == userId)
            .filter(\.$enabled == true)
            .all()
        
        return reminders.map { ReminderDTO.from($0) }
    }
    
    // MARK: - 获取单个提醒
    @Sendable
    func getReminderById(req: Request) async throws -> ReminderDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let reminderIdStr = req.parameters.get("reminderId"),
              let reminderId = Int64(reminderIdStr) else {
            throw Abort(.badRequest, reason: "无效的提醒ID")
        }
        
        guard let reminder = try await Reminder.find(reminderId, on: req.db) else {
            throw Abort(.notFound, reason: "提醒不存在")
        }
        
        // P0 安全修复：验证用户权限
        if reminder.userId != userId {
            throw Abort(.forbidden, reason: "无权查看该提醒")
        }
        
        return ReminderDTO.from(reminder)
    }
    
    // MARK: - 创建提醒
    @Sendable
    func createReminder(req: Request) async throws -> ReminderDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct CreateReminderRequest: Content {
            let title: String
            let timeDescription: String?
            let reminderType: String?
            let enabled: Bool?
        }
        
        let input = try req.content.decode(CreateReminderRequest.self)
        
        // P0 后端校验：标题必填且有长度限制
        let trimmedTitle = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            throw Abort(.badRequest, reason: "提醒内容不能为空")
        }
        if trimmedTitle.count > 100 {
            throw Abort(.badRequest, reason: "提醒内容不能超过100个字符")
        }
        
        let reminder = Reminder(
            userId: userId,
            title: trimmedTitle,
            timeDescription: input.timeDescription ?? "",
            reminderType: input.reminderType,
            enabled: input.enabled ?? true
        )
        
        try await reminder.save(on: req.db)
        
        return ReminderDTO.from(reminder)
    }
    
    // MARK: - 更新提醒
    @Sendable
    func updateReminder(req: Request) async throws -> ReminderDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let reminderIdStr = req.parameters.get("reminderId"),
              let reminderId = Int64(reminderIdStr) else {
            throw Abort(.badRequest, reason: "无效的提醒ID")
        }
        
        struct UpdateReminderRequest: Content {
            let title: String?
            let timeDescription: String?
            let reminderType: String?
            let enabled: Bool?
        }
        
        let input = try req.content.decode(UpdateReminderRequest.self)
        
        guard let reminder = try await Reminder.find(reminderId, on: req.db) else {
            throw Abort(.notFound, reason: "提醒不存在")
        }
        
        if reminder.userId != userId {
            throw Abort(.forbidden, reason: "无权修改该提醒")
        }
        
        if let title = input.title {
            reminder.title = title
        }
        if let timeDescription = input.timeDescription {
            reminder.timeDescription = timeDescription
        }
        if let reminderType = input.reminderType {
            reminder.reminderType = reminderType
        }
        if let enabled = input.enabled {
            reminder.enabled = enabled
        }
        
        try await reminder.save(on: req.db)
        
        return ReminderDTO.from(reminder)
    }
    
    // MARK: - 切换提醒启用状态
    @Sendable
    func toggleReminder(req: Request) async throws -> ReminderDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let reminderIdStr = req.parameters.get("reminderId"),
              let reminderId = Int64(reminderIdStr) else {
            throw Abort(.badRequest, reason: "无效的提醒ID")
        }
        
        guard let reminder = try await Reminder.find(reminderId, on: req.db) else {
            throw Abort(.notFound, reason: "提醒不存在")
        }
        
        if reminder.userId != userId {
            throw Abort(.forbidden, reason: "无权修改该提醒")
        }
        
        reminder.enabled = !reminder.enabled
        try await reminder.save(on: req.db)
        
        return ReminderDTO.from(reminder)
    }
    
    // MARK: - 删除提醒
    @Sendable
    func deleteReminder(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let reminderIdStr = req.parameters.get("reminderId"),
              let reminderId = Int64(reminderIdStr) else {
            throw Abort(.badRequest, reason: "无效的提醒ID")
        }
        
        guard let reminder = try await Reminder.find(reminderId, on: req.db) else {
            throw Abort(.notFound, reason: "提醒不存在")
        }
        
        if reminder.userId != userId {
            throw Abort(.forbidden, reason: "无权删除该提醒")
        }
        
        try await reminder.delete(on: req.db)
        
        return .noContent
    }
}

// MARK: - 提醒模型
final class Reminder: Model, Content, @unchecked Sendable {
    static let schema = "reminders"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "user_id")
    var userId: Int64
    
    @OptionalField(key: "bird_id")
    var birdId: Int64?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "time_description")
    var timeDescription: String
    
    @OptionalField(key: "reminder_type")
    var reminderType: String?
    
    @Field(key: "enabled")
    var enabled: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, userId: Int64, birdId: Int64? = nil, title: String, 
         timeDescription: String = "", reminderType: String? = nil, enabled: Bool = true) {
        self.id = id
        self.userId = userId
        self.birdId = birdId
        self.title = title
        self.timeDescription = timeDescription
        self.reminderType = reminderType
        self.enabled = enabled
    }
}

// MARK: - DTO
struct ReminderDTO: Content {
    let id: Int64
    let userId: Int64
    let birdId: Int64?
    let birdName: String?  // 添加：前端期望的鸟名
    let title: String
    let timeDescription: String
    let reminderType: String?
    let enabled: Bool
    let isRead: Bool       // 添加：前端期望的已读状态
    let createdAt: Date?
    let updatedAt: Date?
    
    static func from(_ reminder: Reminder, birdName: String? = nil) -> ReminderDTO {
        ReminderDTO(
            id: reminder.id ?? 0,
            userId: reminder.userId,
            birdId: reminder.birdId,
            birdName: birdName,
            title: reminder.title,
            timeDescription: reminder.timeDescription,
            reminderType: reminder.reminderType,
            enabled: reminder.enabled,
            isRead: false,  // 默认未读
            createdAt: reminder.createdAt,
            updatedAt: reminder.updatedAt
        )
    }
}
