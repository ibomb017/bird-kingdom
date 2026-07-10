import Foundation
import SwiftUI
import Combine

// MARK: - 支出分类
enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "food"
    case medical = "medical"
    case supplies = "supplies"
    case toys = "toys"
    case cage = "cage"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .food: return "食物"
        case .medical: return "医疗"
        case .supplies: return "用品"
        case .toys: return "玩具"
        case .cage: return "笼具"
        case .other: return "其他"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "leaf.fill"
        case .medical: return "cross.case.fill"
        case .supplies: return "shippingbox.fill"
        case .toys: return "gamecontroller.fill"
        case .cage: return "house.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .food: return Color.green
        case .medical: return Color.red
        case .supplies: return Color.blue
        case .toys: return Color.orange
        case .cage: return Color.purple
        case .other: return Color.gray
        }
    }
}

// MARK: - 支出记录模型（API响应）
struct Expense: Identifiable, Codable, Hashable {
    let id: Int64
    var userId: Int64?          // 创建者用户ID（用于共享账户）
    var creatorName: String?    // 创建者昵称（用于共享账户区分）
    var title: String
    var amount: Double
    var category: String
    var expenseDate: String  // yyyy-MM-dd 格式
    var birdId: Int64?
    var birdName: String?
    var note: String?
    var createdAt: String?
    var updatedAt: String?
    
    var categoryEnum: ExpenseCategory {
        ExpenseCategory(rawValue: category) ?? .other
    }
    
    var date: Date {
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        return DateFormatters.parseFromAPI(expenseDate) ?? Date()
    }
    
    /// 判断当前用户是否为创建者
    var isCreatedByCurrentUser: Bool {
        guard let userId = userId,
              let currentUserIdStr = AuthService.shared.currentUserId,
              let currentUserId = Int64(currentUserIdStr) else {
            return true // 旧数据默认为当前用户创建
        }
        return userId == currentUserId
    }
}

// MARK: - 支出统计模型
struct ExpenseStats: Codable {
    let totalExpense: Double?  // 改为可选
    let monthlyExpense: Double?  // 改为可选
    let expenseByCategory: [String: Double]?
    let monthlyStats: [MonthlyExpense]?
    
    struct MonthlyExpense: Codable {
        let month: String
        let amount: Double
    }
}

// MARK: - 创建/更新支出请求
struct ExpenseRequest: Codable {
    let title: String
    let amount: Double
    let category: String
    let expenseDate: String
    let birdId: Int64?
    let birdName: String?
    let note: String?
}

// MARK: - 支出服务
class ExpenseService: ObservableObject {
    static let shared = ExpenseService()
    
    @Published var expenses: [Expense] = []
    @Published var stats: ExpenseStats?
    @Published var isLoading = false
    @Published var localExpenses: [LocalExpense] = []  // 本地未同步支出
    @Published var statsCacheExpired = false  // P2-03: 统计缓存是否过期
    
    private let baseURL = AppConfig.apiBaseURL
    private var offlineService: OfflineDataService { OfflineDataService.shared }
    
    // P1-02/P1-03: 验证常量
    private static let minAmount = 0.01
    private static let maxTitleLength = 100
    
    private init() {}
    
    // MARK: - 计算属性
    
    var totalExpense: Double {
        stats?.totalExpense ?? expenses.reduce(0) { $0 + $1.amount }
    }
    
    var monthlyExpense: Double {
        stats?.monthlyExpense ?? 0
    }
    
    var expensesByCategory: [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        if let categoryStats = stats?.expenseByCategory {
            for (key, value) in categoryStats {
                if let category = ExpenseCategory(rawValue: key) {
                    result[category] = value
                }
            }
        }
        return result
    }
    
    /// 获取所有支出记录
    @MainActor
    func fetchExpenses() async {
        guard let token = AuthService.shared.getToken() else { return }
        
        // 如果离线，使用本地数据
        if !offlineService.isOnline {
            let allLocalExpenses = offlineService.getAllExpenses()
            // 一次性更新，避免闪烁
            (expenses, localExpenses) = ([], allLocalExpenses)
            print("📴 离线模式：加载 \(allLocalExpenses.count) 条本地支出记录")
            return
        }
        
        // 先保存当前状态，如果请求失败可以恢复
        let previousExpenses = expenses
        let previousLocalExpenses = localExpenses
        
        let url = baseURL.appendingPathComponent("expenses")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("获取支出列表失败，保持当前数据")
                // 加载本地未同步的支出作为补充
                let pending = offlineService.localExpenses.filter { $0.needsSync && !$0.isDeleted }
                localExpenses = pending
                return
            }
            let decoder = JSONDecoder()
            let fetchedExpenses = try decoder.decode([Expense].self, from: data)
            
            // 加载本地未同步的支出
            let pendingLocal = offlineService.localExpenses.filter { $0.needsSync && !$0.isDeleted }
            
            // 一次性更新所有数据，避免UI闪烁
            (expenses, localExpenses) = (fetchedExpenses, pendingLocal)
            
            print("✅ 获取 \(fetchedExpenses.count) 条支出记录，\(pendingLocal.count) 条待同步")
        } catch {
            print("获取支出列表错误: \(error)，保持当前数据")
            // 网络错误时保持现有数据，只更新本地未同步数据
            let pendingLocal = offlineService.localExpenses.filter { $0.needsSync && !$0.isDeleted }
            localExpenses = pendingLocal
        }
    }
    
    /// 获取支出统计 - P2-04: 添加离线缓存
    @MainActor
    func fetchStats() async {
        guard let token = AuthService.shared.getToken() else { return }
        
        // P2-04: 离线时从缓存读取
        if !offlineService.isOnline {
            if let (cachedStats, isExpired) = loadCachedStatsWithExpiration() {
                stats = cachedStats
                statsCacheExpired = isExpired  // P2-03: 提示缓存可能过期
                print("📴 离线模式：加载缓存的支出统计\(isExpired ? "（已过期7天）" : "")")
            }
            return
        }
        
        // 在线时重置过期标志
        statsCacheExpired = false
        
        let url = baseURL.appendingPathComponent("expenses/stats")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("获取支出统计失败")
                return
            }
            let decoder = JSONDecoder()
            stats = try decoder.decode(ExpenseStats.self, from: data)
            
            // P2-04: 缓存统计数据
            cacheStats(stats!)
        } catch {
            print("获取支出统计错误: \(error)")
            // P2-04: 失败时尝试使用缓存
            if let cachedStats = loadCachedStats() {
                stats = cachedStats
            }
        }
    }
    
    // P2-04 & #5 修复：缓存支出统计数据（带 userId 隔离）
    private func cacheStats(_ stats: ExpenseStats) {
        guard let userId = AuthService.shared.currentUserId else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(stats) {
            UserDefaults.standard.set(data, forKey: "cachedExpenseStats_\(userId)")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "cachedExpenseStatsTimestamp_\(userId)")
        }
    }
    
    // P2-04 & #5 修复：加载缓存的支出统计（带 userId 隔离）
    private func loadCachedStats() -> ExpenseStats? {
        guard let userId = AuthService.shared.currentUserId else { return nil }
        guard let data = UserDefaults.standard.data(forKey: "cachedExpenseStats_\(userId)") else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(ExpenseStats.self, from: data)
    }
    
    // P2-03 & #5 修复：加载缓存并检查是否过期（超过7天，带 userId 隔离）
    private func loadCachedStatsWithExpiration() -> (ExpenseStats, Bool)? {
        guard let userId = AuthService.shared.currentUserId else { return nil }
        guard let data = UserDefaults.standard.data(forKey: "cachedExpenseStats_\(userId)") else { return nil }
        let decoder = JSONDecoder()
        guard let stats = try? decoder.decode(ExpenseStats.self, from: data) else { return nil }
        
        let timestamp = UserDefaults.standard.double(forKey: "cachedExpenseStatsTimestamp_\(userId)")
        let cacheDate = Date(timeIntervalSince1970: timestamp)
        let daysSinceCache = Calendar.current.dateComponents([.day], from: cacheDate, to: Date()).day ?? 0
        let isExpired = daysSinceCache >= 7
        
        return (stats, isExpired)
    }
    
    /// 添加支出
    @MainActor
    func addExpense(title: String, amount: Double, category: ExpenseCategory, date: Date, birdId: Int64?, birdName: String?, note: String?) async -> Bool {
        guard let token = AuthService.shared.getToken() else { return false }
        
        // P1-02: 前端金额校验
        guard amount >= Self.minAmount else {
            await ToastManager.shared.showError("金额需大于0.01元")
            return false
        }
        
        // P1-03: 前端标题长度校验
        guard title.count <= Self.maxTitleLength else {
            await ToastManager.shared.showError("标题长度不能超过\(Self.maxTitleLength)字")
            return false
        }
        
        // P1-03: 标题非空校验
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            await ToastManager.shared.showError("标题不能为空")
            return false
        }
        
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        
        // 如果离线，保存到本地
        if !offlineService.isOnline {
            let localExpense = LocalExpense(
                title: title,
                amount: amount,
                category: category.rawValue,
                expenseDate: date,
                birdId: birdId.flatMap { Int($0) },
                birdName: birdName,
                note: note
            )
            offlineService.addExpense(localExpense)
            localExpenses = offlineService.localExpenses.filter { $0.needsSync && !$0.isDeleted }
            print("💰 离线模式：支出已保存到本地")
            return true
        }
        
        let expenseRequest = ExpenseRequest(
            title: title,
            amount: amount,
            category: category.rawValue,
            expenseDate: DateFormatters.toAPIDateOnly(date),
            birdId: birdId,
            birdName: birdName,
            note: note
        )
        
        let url = baseURL.appendingPathComponent("expenses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(expenseRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                // 网络错误时保存到本地
                let localExpense = LocalExpense(
                    title: title,
                    amount: amount,
                    category: category.rawValue,
                    expenseDate: date,
                    birdId: birdId.flatMap { Int($0) },
                    birdName: birdName,
                    note: note
                )
                offlineService.addExpense(localExpense)
                localExpenses = offlineService.localExpenses.filter { $0.needsSync && !$0.isDeleted }
                print("💰 网络错误，支出已保存到本地")
                return true
            }
            
            let decoder = JSONDecoder()
            let newExpense = try decoder.decode(Expense.self, from: data)
            expenses.insert(newExpense, at: 0)
            
            // 不保存到本地，避免重复
            
            // 刷新统计
            await fetchStats()
            return true
        } catch {
            // 网络错误时保存到本地
            let localExpense = LocalExpense(
                title: title,
                amount: amount,
                category: category.rawValue,
                expenseDate: date,
                birdId: birdId.flatMap { Int($0) },
                birdName: birdName,
                note: note
            )
            offlineService.addExpense(localExpense)
            localExpenses = offlineService.localExpenses.filter { $0.needsSync && !$0.isDeleted }
            print("添加支出错误: \(error)，已保存到本地")
            await ToastManager.shared.showWarning("已保存到本地，联网后自动同步")
            return true
        }
    }
    
    /// 更新支出
    @MainActor
    func updateExpense(id: Int64, title: String, amount: Double, category: ExpenseCategory, date: Date, birdId: Int64?, birdName: String?, note: String?) async -> Bool {
        guard let token = AuthService.shared.getToken() else { return false }
        
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        
        let expenseRequest = ExpenseRequest(
            title: title,
            amount: amount,
            category: category.rawValue,
            expenseDate: DateFormatters.toAPIDateOnly(date),
            birdId: birdId,
            birdName: birdName,
            note: note
        )
        
        let url = baseURL.appendingPathComponent("expenses/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(expenseRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("更新支出失败")
                return false
            }
            
            let decoder = JSONDecoder()
            let updatedExpense = try decoder.decode(Expense.self, from: data)
            if let index = expenses.firstIndex(where: { $0.id == id }) {
                expenses[index] = updatedExpense
            }
            
            // 刷新统计
            await fetchStats()
            return true
        } catch {
            print("更新支出错误: \(error)")
            return false
        }
    }
    
    /// 删除支出
    /// Bug #8 修复：同步删除离线缓存
    @MainActor
    func deleteExpense(id: Int64) async -> Bool {
        guard let token = AuthService.shared.getToken() else { return false }
        
        // 离线时标记删除，联网后同步
        if !offlineService.isOnline {
            expenses.removeAll { $0.id == id }
            offlineService.markExpenseDeleted(serverId: Int(id))
            localExpenses = offlineService.localExpenses.filter { $0.needsSync && !$0.isDeleted }
            await ToastManager.shared.showWarning("已标记删除，联网后自动同步")
            return true
        }
        
        let url = baseURL.appendingPathComponent("expenses/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("删除支出失败")
                return false
            }
            
            expenses.removeAll { $0.id == id }
            
            // Bug #8 修复：同步删除离线缓存中的对应记录
            offlineService.deleteExpenseByServerId(Int(id))
            localExpenses = offlineService.localExpenses.filter { $0.needsSync && !$0.isDeleted }
            
            // 刷新统计
            await fetchStats()
            return true
        } catch {
            print("删除支出错误: \(error)")
            await ToastManager.shared.showError("删除失败，请检查网络")
            return false
        }
    }
    
    /// 刷新所有数据
    @MainActor
    func refresh() async {
        // 未登录时清空数据
        guard AuthService.shared.isLoggedIn else {
            clearData()
            return
        }
        
        // 防止重复刷新
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        // fetchExpenses 已经会更新 localExpenses，无需再次更新
        await fetchExpenses()
        await fetchStats()
    }
    
    /// 清空所有数据（登出时调用）
    @MainActor
    func clearData() {
        expenses = []
        localExpenses = []
        stats = nil
    }
    
    // MARK: - 格式化
    
    static func formatAmount(_ amount: Double) -> String {
        if amount >= 10000 {
            return String(format: "%.1f万", amount / 10000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
}
