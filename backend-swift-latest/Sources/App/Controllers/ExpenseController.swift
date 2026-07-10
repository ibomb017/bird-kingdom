import Vapor
import Fluent

/// 支出控制器
struct ExpenseController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let expenses = routes.grouped("expenses")
        
        // 需要认证的路由
        let protected = expenses.grouped(JWTAuthMiddleware())
        
        // 获取支出列表
        protected.get(use: getExpenses)
        
        // 获取支出统计
        protected.get("stats", use: getExpenseStats)
        
        // 添加支出
        protected.post(use: addExpense)
        
        // 更新支出
        protected.put(":expenseId", use: updateExpense)
        
        // 删除支出
        protected.delete(":expenseId", use: deleteExpense)
    }
    
    // MARK: - 获取支出列表
    @Sendable
    func getExpenses(req: Request) async throws -> [ExpenseDTO] {
        let userId = try req.auth.require(AuthPayload.self).userId
        let category = req.query[String.self, at: "category"]
        let birdId = req.query[Int64.self, at: "birdId"]
        let page = req.query[Int.self, at: "page"] ?? 0
        let size = req.query[Int.self, at: "size"] ?? 50
        
        // 获取伴侣用户ID（如果有）
        let user = try await User.find(userId, on: req.db)
        let partnerUserId = user?.couplePartnerId
        
        // 构建查询 - 包含自己和伴侣的支出
        var userIds = [userId]
        if let partnerId = partnerUserId {
            userIds.append(partnerId)
        }
        
        var query = Expense.query(on: req.db)
            .filter(\.$userId ~~ userIds)
        
        if let category = category, !category.isEmpty {
            query = query.filter(\.$category == category)
        }
        
        if let birdId = birdId {
            query = query.filter(\.$birdId == birdId)
        }
        
        let expenses = try await query
            .sort(\.$expenseDate, .descending)
            .range(page * size..<(page + 1) * size)
            .all()
        
        return expenses.map { ExpenseDTO.from($0) }
    }
    
    // MARK: - 获取支出统计
    @Sendable
    func getExpenseStats(req: Request) async throws -> ExpenseStatsDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        // 获取伴侣用户ID
        let user = try await User.find(userId, on: req.db)
        let partnerUserId = user?.couplePartnerId
        
        var userIds = [userId]
        if let partnerId = partnerUserId {
            userIds.append(partnerId)
        }
        
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$userId ~~ userIds)
            .all()
        
        // 计算总金额
        let totalAmount = expenses.reduce(0.0) { $0 + $1.amount }
        
        // 本月支出
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthlyExpenses = expenses.filter { $0.expenseDate >= startOfMonth }
        let monthlyAmount = monthlyExpenses.reduce(0.0) { $0 + $1.amount }
        
        // 按分类统计
        var categoryStats: [String: Double] = [:]
        for expense in expenses {
            let category = expense.category ?? "其他"
            categoryStats[category, default: 0] += expense.amount
        }
        
        return ExpenseStatsDTO(
            totalExpense: totalAmount,
            monthlyExpense: monthlyAmount,
            expenseByCategory: categoryStats,
            monthlyStats: nil
        )
    }
    
    // MARK: - 添加支出
    @Sendable
    func addExpense(req: Request) async throws -> ExpenseDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct CreateExpenseRequest: Content {
            let title: String?
            let amount: Double
            let category: String?
            let note: String?
            let birdId: Int64?
            let birdName: String?
            let expenseDate: Date?
        }
        
        let input = try req.content.decode(CreateExpenseRequest.self)
        
        let expense = Expense(
            userId: userId,
            title: input.title ?? "",
            amount: input.amount,
            category: input.category,
            note: input.note,
            birdId: input.birdId,
            birdName: input.birdName,
            expenseDate: input.expenseDate ?? Date()
        )
        
        try await expense.save(on: req.db)
        
        return ExpenseDTO.from(expense)
    }
    
    // MARK: - 更新支出
    @Sendable
    func updateExpense(req: Request) async throws -> ExpenseDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let expenseIdStr = req.parameters.get("expenseId"),
              let expenseId = Int64(expenseIdStr) else {
            throw Abort(.badRequest, reason: "无效的支出ID")
        }
        
        struct UpdateExpenseRequest: Content {
            let title: String?
            let amount: Double?
            let category: String?
            let note: String?
            let birdId: Int64?
            let birdName: String?
            let expenseDate: Date?
        }
        
        let input = try req.content.decode(UpdateExpenseRequest.self)
        
        guard let expense = try await Expense.find(expenseId, on: req.db) else {
            throw Abort(.notFound, reason: "支出记录不存在")
        }
        
        // 验证权限 - 允许伴侣修改
        let user = try await User.find(userId, on: req.db)
        let partnerUserId = user?.couplePartnerId
        
        if expense.userId != userId && expense.userId != partnerUserId {
            throw Abort(.forbidden, reason: "无权修改该支出记录")
        }
        
        if let title = input.title {
            expense.title = title
        }
        if let amount = input.amount {
            expense.amount = amount
        }
        if let category = input.category {
            expense.category = category
        }
        if let note = input.note {
            expense.note = note
        }
        if let birdName = input.birdName {
            expense.birdName = birdName
        }
        if let birdId = input.birdId {
            expense.birdId = birdId
        }
        if let expenseDate = input.expenseDate {
            expense.expenseDate = expenseDate
        }
        
        try await expense.save(on: req.db)
        
        return ExpenseDTO.from(expense)
    }
    
    // MARK: - 删除支出
    @Sendable
    func deleteExpense(req: Request) async throws -> [String: String] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let expenseIdStr = req.parameters.get("expenseId"),
              let expenseId = Int64(expenseIdStr) else {
            throw Abort(.badRequest, reason: "无效的支出ID")
        }
        
        guard let expense = try await Expense.find(expenseId, on: req.db) else {
            throw Abort(.notFound, reason: "支出记录不存在")
        }
        
        // 验证权限 - 允许伴侣删除
        let user = try await User.find(userId, on: req.db)
        let partnerUserId = user?.couplePartnerId
        
        if expense.userId != userId && expense.userId != partnerUserId {
            throw Abort(.forbidden, reason: "无权删除该支出记录")
        }
        
        try await expense.delete(on: req.db)
        
        return ["message": "删除成功"]
    }
}

// MARK: - 支出模型
final class Expense: Model, Content, @unchecked Sendable {
    static let schema = "expenses"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "amount")
    var amount: Double
    
    @OptionalField(key: "category")
    var category: String?
    
    @Field(key: "expense_date")
    var expenseDate: Date
    
    @OptionalField(key: "bird_id")
    var birdId: Int64?
    
    @OptionalField(key: "bird_name")
    var birdName: String?
    
    @OptionalField(key: "note")
    var note: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, userId: Int64, title: String = "", amount: Double, category: String? = nil, 
         note: String? = nil, birdId: Int64? = nil, birdName: String? = nil, expenseDate: Date = Date()) {
        self.id = id
        self.userId = userId
        self.title = title
        self.amount = amount
        self.category = category
        self.note = note
        self.birdId = birdId
        self.birdName = birdName
        self.expenseDate = expenseDate
    }
}

// MARK: - DTOs
struct ExpenseDTO: Content {
    let id: Int64
    let userId: Int64
    let title: String
    let amount: Double
    let category: String?
    let note: String?
    let birdId: Int64?
    let birdName: String?
    let expenseDate: String  // 改为 String 匹配前端
    let createdAt: String?   // 改为 String 匹配前端
    let updatedAt: String?   // 改为 String 匹配前端
    let creatorName: String? // 添加：创建者昵称
    
    static func from(_ expense: Expense, creatorName: String? = nil) -> ExpenseDTO {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        
        return ExpenseDTO(
            id: expense.id ?? 0,
            userId: expense.userId,
            title: expense.title,
            amount: expense.amount,
            category: expense.category,
            note: expense.note,
            birdId: expense.birdId,
            birdName: expense.birdName,
            expenseDate: dateFormatter.string(from: expense.expenseDate),
            createdAt: expense.createdAt.map { iso8601Formatter.string(from: $0) },
            updatedAt: expense.updatedAt.map { iso8601Formatter.string(from: $0) },
            creatorName: creatorName
        )
    }
}

struct ExpenseStatsDTO: Content {
    let totalExpense: Double
    let monthlyExpense: Double
    let expenseByCategory: [String: Double]
    let monthlyStats: [MonthlyExpenseStat]?
}

struct MonthlyExpenseStat: Content {
    let month: String
    let amount: Double
}
