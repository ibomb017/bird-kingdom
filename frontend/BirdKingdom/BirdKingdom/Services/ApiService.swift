import Foundation
import UIKit

enum ApiError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case networkError(Error)
    case httpError(statusCode: Int)
    case unauthorized  // Fix #25: Token 过期或无效
    case forbidden     // Fix #25: 权限不足
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP错误: \(statusCode)"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .forbidden:
            return "权限不足"
        }
    }
}

// 情侣绑定响应
struct CoupleBindResponse: Codable {
    let success: Bool
    let message: String
}


final class ApiService {
    static let shared = ApiService()
    private init() {}

    // 使用配置文件管理API地址
    private let baseURL = AppConfig.apiBaseURL

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // 使用 ISO 8601 日期解码策略，与 Swift 后端保持一致
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    /// 自定义 URLSession，带 30 秒超时配置
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30  // 请求超时 30 秒
        config.timeoutIntervalForResource = 60 // 资源超时 60 秒
        config.waitsForConnectivity = true     // 等待网络连接
        return URLSession(configuration: config)
    }()
    

    // MARK: - 鸟档案

    func getBirds() async throws -> [Bird] {
        let url = baseURL.appendingPathComponent("birds")
        var request = URLRequest(url: url)
        
        // 添加Authorization头，获取当前用户的鸟
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Bird].self, from: data)
    }
    
    /// 获取我的鸟儿列表（别名）
    func getMyBirds() async throws -> [Bird] {
        return try await getBirds()
    }
    
    /// 更新鸟儿丢失状态
    func updateBirdLostStatus(birdId: Int64, isLost: Bool, lostDate: String? = nil, lostLocation: String? = nil) async throws {
        let url = baseURL.appendingPathComponent("birds/\(birdId)/lost-status")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = ["isLost": isLost]
        if let lostDate = lostDate {
            body["lostDate"] = lostDate
        }
        if let lostLocation = lostLocation {
            body["lostLocation"] = lostLocation
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }

    func getBird(id: Int) async throws -> Bird {
        let url = baseURL.appendingPathComponent("birds/\(id)")
        var request = URLRequest(url: url)
        
        // Fix: getBird required auth token
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Bird.self, from: data)
    }

    // #7 FIX: 添加幂等性保护，防止重复创建
    func createBird(_ bird: Bird) async throws -> Bird {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加Authorization头，绑定鸟到当前用户
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // #7 FIX: 添加幂等性 key
        let idempotencyKey = request.setNewIdempotencyKey(for: "createBird")
        guard IdempotencyHelper.shared.markRequestStarted(idempotencyKey) else {
            throw ApiError.serverError("请勿重复提交")
        }
        
        request.httpBody = try jsonEncoder.encode(bird)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response: response)
            let result = try jsonDecoder.decode(Bird.self, from: data)
            IdempotencyHelper.shared.markRequestCompleted(idempotencyKey, success: true)
            return result
        } catch {
            IdempotencyHelper.shared.markRequestCompleted(idempotencyKey, success: false)
            throw error
        }
    }

    func updateBird(id: Int64, nickname: String, species: String, gender: String?, hatchDate: Date?, adoptionDate: Date?, birthdayType: String?, featherColor: String?, source: String?, avatarUrl: String?, notes: String?, deathDate: Date? = nil, fatherInfo: String? = nil, motherInfo: String? = nil, legRingId: String? = nil, medicalHistory: String? = nil) async throws -> Bird {
        let url = baseURL.appendingPathComponent("birds/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        // P0 修复：所有可选字段必须始终发送（包括 null），否则后端无法清空已有值
        var body: [String: Any] = [
            "nickname": nickname,
            "species": species,
            "gender": gender as Any? ?? NSNull(),
            "featherColor": featherColor as Any? ?? NSNull(),
            "source": source as Any? ?? NSNull(),
            "avatarUrl": avatarUrl as Any? ?? NSNull(),
            "notes": notes as Any? ?? NSNull(),
            "birthdayType": birthdayType as Any? ?? NSNull(),
            "fatherInfo": fatherInfo as Any? ?? NSNull(),
            "motherInfo": motherInfo as Any? ?? NSNull(),
            "legRingId": legRingId as Any? ?? NSNull(),
            "medicalHistory": medicalHistory as Any? ?? NSNull()
        ]
        
        // 日期字段：有值时格式化，无值时发送 null（允许清空）
        body["hatchDate"] = hatchDate.map { DateFormatters.toAPIDateTime($0) } ?? NSNull()
        body["adoptionDate"] = adoptionDate.map { DateFormatters.toAPIDateTime($0) } ?? NSNull()
        body["deathDate"] = deathDate.map { DateFormatters.toAPIDateTime($0) } ?? NSNull()
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        // 调试日志
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 updateBird 请求体: \(jsonString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 调试响应
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 updateBird 响应: \(responseString)")
        }
        
        try Self.validate(response: response)
        return try jsonDecoder.decode(Bird.self, from: data)
    }

    func deleteBird(id: Int64) async throws {
        let url = baseURL.appendingPathComponent("birds/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    func restoreBird(id: Int64) async throws -> Bird {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(id)/restore"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Bird.self, from: data)
    }
    
    /// 永久删除鸟儿（从回收站彻底删除）
    func permanentDeleteBird(id: Int64) async throws {
        let url = baseURL.appendingPathComponent("birds/\(id)/permanent")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    func getDeletedBirds(userId: Int64) async throws -> [Bird] {
        let url = baseURL.appendingPathComponent("birds/deleted").appending(queryItems: [URLQueryItem(name: "userId", value: String(userId))])
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Bird].self, from: data)
    }
    
    func getActiveBirds(userId: Int64) async throws -> [Bird] {
        let url = baseURL.appendingPathComponent("birds/active").appending(queryItems: [URLQueryItem(name: "userId", value: String(userId))])
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Bird].self, from: data)
    }

    // MARK: - 鸟类品种
    
    /// 品种分类排序优先级（按养鸟人常见顺序）
    private static let categoryOrder: [String: Int] = [
        "小型鹦鹉": 1,
        "中大型鹦鹉": 2,
        "凤头鹦鹉": 3,
        "金刚鹦鹉": 4,
        "亚马逊鹦鹉": 5,
        "雀类": 6
    ]
    
    /// 获取所有品种（按分类分组，按养鸟人常见顺序排序）
    func getSpecies() async throws -> [SpeciesCategory] {
        let url = baseURL.appendingPathComponent("species")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        
        // API 返回 { "分类名": [品种列表] } 格式
        let grouped = try JSONDecoder().decode([String: [BirdSpecies]].self, from: data)
        
        // 转换为 SpeciesCategory 数组，按自定义顺序排序（小型鹦鹉最常见，放第一位）
        return grouped.map { SpeciesCategory(name: $0.key, species: $0.value) }
            .sorted { 
                let order1 = Self.categoryOrder[$0.name] ?? 99
                let order2 = Self.categoryOrder[$1.name] ?? 99
                return order1 < order2
            }
    }
    
    /// 根据品种名查找体重范围
    func getSpeciesByName(_ name: String) async throws -> BirdSpecies? {
        let url = baseURL.appendingPathComponent("species/by-name")
            .appending(queryItems: [URLQueryItem(name: "name", value: name)])
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            return nil
        }
        
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdSpecies.self, from: data)
    }

    // MARK: - 生理周期
    
    /// 获取某鸟所有周期记录
    func getCycles(birdId: Int64) async throws -> [BirdCycleRecord] {
        let url = baseURL.appendingPathComponent("birds/\(birdId)/cycles")
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdCycleRecord].self, from: data)
    }
    
    /// 获取某鸟正在进行中的周期
    func getActiveCycles(birdId: Int64) async throws -> [BirdCycleRecord] {
        let url = baseURL.appendingPathComponent("birds/\(birdId)/cycles/active")
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdCycleRecord].self, from: data)
    }
    
    /// 开始新周期
    /// P1 N2-01 修复：添加幂等性保护
    func createCycle(birdId: Int64, request: CreateCycleRequest) async throws -> BirdCycleRecord {
        let url = baseURL.appendingPathComponent("birds/\(birdId)/cycles")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // P1 N2-01 修复：添加幂等性 key
        let idempotencyKey = IdempotencyHelper.shared.generateKey(
            operation: "createCycle",
            params: ["birdId": birdId, "cycleType": request.cycleType.rawValue, "startDate": request.startDate]
        )
        urlRequest.setIdempotencyKey(idempotencyKey)
        guard IdempotencyHelper.shared.markRequestStarted(idempotencyKey) else {
            throw ApiError.serverError("请勿重复提交")
        }
        
        urlRequest.httpBody = try jsonEncoder.encode(request)
        
        // 调试日志
        if let bodyString = String(data: urlRequest.httpBody!, encoding: .utf8) {
            print("📤 createCycle 请求: \(url.absoluteString)")
            print("📤 createCycle 请求体: \(bodyString)")
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            // 调试响应
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 createCycle 响应: \(responseString)")
            }
            
            try Self.validate(response: response)
            let result = try jsonDecoder.decode(BirdCycleRecord.self, from: data)
            IdempotencyHelper.shared.markRequestCompleted(idempotencyKey, success: true)
            return result
        } catch {
            print("❌ createCycle 错误: \(error)")
            IdempotencyHelper.shared.markRequestCompleted(idempotencyKey, success: false)
            throw error
        }
    }
    
    /// 结束周期
    func endCycle(cycleId: Int64, endDate: Date, notes: String? = nil, eggCount: Int? = nil, hatchedCount: Int? = nil) async throws -> BirdCycleRecord {
        let url = baseURL.appendingPathComponent("cycles/\(cycleId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        var updateRequest = UpdateCycleRequest()
        updateRequest.endDate = DateFormatters.toAPIDateTime(endDate)
        updateRequest.notes = notes
        updateRequest.eggCount = eggCount
        updateRequest.hatchedCount = hatchedCount
        
        request.httpBody = try jsonEncoder.encode(updateRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdCycleRecord.self, from: data)
    }
    
    /// 更新周期记录（不强制结束周期）
    func updateCycle(cycleId: Int64, endDate: Date? = nil, notes: String? = nil, eggCount: Int? = nil, hatchedCount: Int? = nil) async throws -> BirdCycleRecord {
        let url = baseURL.appendingPathComponent("cycles/\(cycleId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        var updateRequest = UpdateCycleRequest()
        if let endDate = endDate {
            updateRequest.endDate = DateFormatters.toAPIDateTime(endDate)
        }
        updateRequest.notes = notes
        updateRequest.eggCount = eggCount
        updateRequest.hatchedCount = hatchedCount
        
        request.httpBody = try jsonEncoder.encode(updateRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdCycleRecord.self, from: data)
    }
    
    /// 删除周期记录
    func deleteCycle(cycleId: Int64) async throws {
        let url = baseURL.appendingPathComponent("cycles/\(cycleId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }

    // MARK: - 日志

    func getLogs() async throws -> [BirdLog] {
        let url = baseURL.appendingPathComponent("logs")
        var request = URLRequest(url: url)
        
        // 添加Authorization头，获取当前用户的日志
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdLog].self, from: data)
    }

    func getLogs(byBird birdId: Int) async throws -> [BirdLog] {
        let url = baseURL.appendingPathComponent("logs/bird/\(birdId)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdLog].self, from: data)
    }

    /// 创建日志（可带体重和图片），用于"写新日志"页面
    /// #7 FIX: 添加幂等性保护
    func createLog(birdId: Int64, date: Date, weight: Double?, notes: String, imageUrls: [String] = []) async throws -> BirdLog {
        var request = URLRequest(url: baseURL.appendingPathComponent("logs"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // #7 FIX: 添加幂等性 key
        let idempotencyKey = request.setNewIdempotencyKey(for: "createLog")
        guard IdempotencyHelper.shared.markRequestStarted(idempotencyKey) else {
            throw ApiError.serverError("请勿重复提交")
        }

        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        var body: [String: Any] = [
            "birdId": birdId,
            "logDate": DateFormatters.toAPIDateTime(date),
            "notes": notes
        ]

        if let weight = weight {
            body["weight"] = weight
        }
        
        if !imageUrls.isEmpty {
            body["imageUrls"] = imageUrls
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response: response)
            let result = try jsonDecoder.decode(BirdLog.self, from: data)
            IdempotencyHelper.shared.markRequestCompleted(idempotencyKey, success: true)
            return result
        } catch {
            IdempotencyHelper.shared.markRequestCompleted(idempotencyKey, success: false)
            throw error
        }
    }
    
    /// 删除日志
    func deleteLog(id: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("logs/\(id)"))
        request.httpMethod = "DELETE"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 获取单个日志
    func getLog(id: Int64) async throws -> BirdLog {
        let url = baseURL.appendingPathComponent("logs/\(id)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdLog.self, from: data)
    }
    
    /// 更新日志
    func updateLog(id: Int64, date: Date, weight: Double?, notes: String) async throws -> BirdLog {
        var request = URLRequest(url: baseURL.appendingPathComponent("logs/\(id)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        var body: [String: Any] = [
            "logDate": DateFormatters.toAPIDateTime(date),
            "notes": notes
        ]
        if let weight = weight {
            body["weight"] = weight
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdLog.self, from: data)
    }
    
    /// PATCH更新日志（部分更新，支持右滑编辑）
    func patchLog(
        id: Int64,
        logDate: Date? = nil,
        weight: Double? = nil,
        mood: String? = nil,
        behavior: String? = nil,
        notes: String? = nil,
        healthScore: Int? = nil,
        imageUrls: [String]? = nil
    ) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("logs/\(id)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        

        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        var body: [String: Any] = [:]
        
        if let logDate = logDate {
            body["logDate"] = DateFormatters.toAPIDateTime(logDate)
        }
        if let weight = weight {
            body["weight"] = weight
        }
        if let mood = mood {
            body["mood"] = mood
        }
        if let behavior = behavior {
            body["behavior"] = behavior
        }
        if let notes = notes {
            body["notes"] = notes
        }
        if let healthScore = healthScore {
            body["healthScore"] = healthScore
        }
        if let imageUrls = imageUrls {
            body["imageUrls"] = imageUrls
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 获取体重趋势
    func getWeightTrend(birdId: Int64? = nil, range: String = "month") async throws -> [WeightTrendDTO] {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("logs/weight-trend"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "range", value: range)]
        if let birdId = birdId {
            queryItems.append(URLQueryItem(name: "birdId", value: String(birdId)))
        }
        urlComponents.queryItems = queryItems
        
        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)
        try Self.validate(response: response)
        return try jsonDecoder.decode([WeightTrendDTO].self, from: data)
    }

    // MARK: - 提醒

    func getReminders() async throws -> [Reminder] {
        let url = baseURL.appendingPathComponent("reminders")
        var request = URLRequest(url: url)
        
        // 添加Authorization头，获取当前用户的提醒
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Reminder].self, from: data)
    }
    
    func createReminder(title: String, timeDescription: String, reminderType: String?, enabled: Bool) async throws -> Reminder {
        var request = URLRequest(url: baseURL.appendingPathComponent("reminders"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "title": title,
            "timeDescription": timeDescription,
            "enabled": enabled
        ]
        if let reminderType = reminderType {
            body["reminderType"] = reminderType
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Reminder.self, from: data)
    }
    
    func updateReminder(id: Int64, title: String, timeDescription: String, reminderType: String?, enabled: Bool) async throws -> Reminder {
        var request = URLRequest(url: baseURL.appendingPathComponent("reminders/\(id)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "title": title,
            "timeDescription": timeDescription,
            "enabled": enabled
        ]
        if let reminderType = reminderType {
            body["reminderType"] = reminderType
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Reminder.self, from: data)
    }
    
    func toggleReminder(id: Int64) async throws -> Reminder {
        var request = URLRequest(url: baseURL.appendingPathComponent("reminders/\(id)/toggle"))
        request.httpMethod = "PATCH"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Reminder.self, from: data)
    }
    
    func deleteReminder(id: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("reminders/\(id)"))
        request.httpMethod = "DELETE"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }


    // MARK: - 鸟类共享功能
    
    /// 发送共享邀请
    func shareBird(birdId: Int64, targetPhone: String, role: ShareRole) async throws -> ShareResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/share"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证 Token
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "targetPhone": targetPhone,
            "role": role.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ShareResponse.self, from: data)
    }
    
    /// 获取待处理的共享邀请
    func getPendingInvitations() async throws -> [ShareInvitation] {
        let url = baseURL.appendingPathComponent("share/invitations/pending")
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([ShareInvitation].self, from: data)
    }
    
    /// 接受共享邀请
    func acceptInvitation(invitationId: Int64) async throws -> ShareResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("share/invitations/\(invitationId)/accept"))
        request.httpMethod = "POST"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ShareResponse.self, from: data)
    }
    
    /// 拒绝共享邀请
    func rejectInvitation(invitationId: Int64) async throws -> ShareResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("share/invitations/\(invitationId)/reject"))
        request.httpMethod = "POST"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ShareResponse.self, from: data)
    }
    
    /// 获取鸟的共享用户列表
    func getBirdSharedUsers(birdId: Int64) async throws -> [BirdCoOwner] {
        let url = baseURL.appendingPathComponent("birds/\(birdId)/shared-users")
        var request = URLRequest(url: url)
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdCoOwner].self, from: data)
    }
    
    /// 移除共享用户
    func removeSharedUser(birdId: Int64, userId: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/shared-users/\(userId)"))
        request.httpMethod = "DELETE"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    /// 更新共享用户角色
    func updateSharedUserRole(birdId: Int64, userId: Int64, newRole: ShareRole) async throws -> BirdCoOwner {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/shared-users/\(userId)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = ["role": newRole.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdCoOwner.self, from: data)
    }
    
    /// 退出共享（被共享者主动退出）
    func leaveSharedBird(birdId: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/leave"))
        request.httpMethod = "POST"
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    // MARK: - 论坛帖子
    
    /// 获取帖子列表
    /// - Parameters:
    ///   - sort: recommended-推荐(默认), latest-最新, likes-最多点赞, comments-最多评论
    func getPosts(page: Int = 0, size: Int = 20, sort: String = "recommended") async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/posts")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "sort", value: sort)
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 获取关注用户的帖子
    func getFollowingPosts(page: Int = 0, size: Int = 20) async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/posts/following")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        print("📱 获取关注帖子: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("📱 Token已设置")
        } else {
            print("⚠️ 未登录，无Token")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 打印响应
        if let httpResponse = response as? HTTPURLResponse {
            print("📱 关注帖子响应状态: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ 错误响应: \(errorString)")
                }
            }
        }
        
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 创建帖子
    func createPost(content: String, postType: String = "NORMAL", images: [String] = [], mediaType: String = "IMAGE", videoUrl: String? = nil, videoCover: String? = nil, videoDuration: Int? = nil, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil, birdId: Int64? = nil, birdIds: [Int64]? = nil, birdName: String? = nil, birdSpecies: String? = nil, lostLocation: String? = nil, contactPhone: String? = nil, reward: String? = nil) async throws -> ForumPostDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "content": content,
            "postType": postType,
            "images": images,
            "mediaType": mediaType
        ]
        // 视频相关字段
        if let videoUrl = videoUrl { body["videoUrl"] = videoUrl }
        if let videoCover = videoCover { body["videoCover"] = videoCover }
        if let videoDuration = videoDuration { body["videoDuration"] = videoDuration }
        // 位置相关字段
        if let lat = latitude { body["latitude"] = lat }
        if let lng = longitude { body["longitude"] = lng }
        if let loc = locationName { body["locationName"] = loc }
        // 多选鸟儿支持
        if let ids = birdIds, !ids.isEmpty {
            body["birdIds"] = ids
        } else if let bid = birdId {
            body["birdId"] = bid
        }
        // 寻鸟帖子专用字段
        if let name = birdName { body["birdName"] = name }
        if let species = birdSpecies { body["birdSpecies"] = species }
        if let lost = lostLocation { body["lostLocation"] = lost }
        if let phone = contactPhone { body["contactPhone"] = phone }
        if let rew = reward { body["reward"] = rew }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostDTO.self, from: data)
    }
    
    /// 搜索帖子
    func searchPosts(keyword: String, page: Int = 0, size: Int = 20) async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/posts/search")
        url.append(queryItems: [
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 获取热门搜索关键词（基于最近7天的搜索统计）
    func getHotSearchKeywords(limit: Int = 10) async throws -> [String] {
        var url = baseURL.appendingPathComponent("forum/posts/hot-keywords")
        url.append(queryItems: [
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
        
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String].self, from: data)
    }
    
    /// 获取我的帖子
    func getMyPosts(page: Int = 0, size: Int = 20) async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/posts/mine")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 获取单个帖子详情
    func getPost(postId: Int64) async throws -> ForumPostDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)"))
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostDTO.self, from: data)
    }
    
    /// 删除帖子
    func deletePost(postId: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)"))
        request.httpMethod = "DELETE"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 点赞/取消点赞
    func togglePostLike(postId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)/like"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        struct UserAction: Codable {
            let likeCount: Int
            let isLiked: Bool
        }
        
        do {
            let userAction = try jsonDecoder.decode(UserAction.self, from: data)
            var result = [String : Bool]()
            result["isLiked"] = userAction.isLiked
            return  result
        } catch {
            print("错误: \(error)")
            return [:]
        }
    }
    
    /// 收藏/取消收藏
    func togglePostFavorite(postId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)/favorite"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Bool].self, from: data)
    }
    
    /// 获取用户收藏的帖子
    func getFavorites(page: Int = 0, size: Int = 20) async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/favorites")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 获取用户的帖子
    func getUserPosts(userId: Int64, page: Int = 0, size: Int = 20) async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/posts/user/\(userId)")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 获取帖子评论
    func getComments(postId: Int64, page: Int = 0, size: Int = 20) async throws -> CommentPage {
        var url = baseURL.appendingPathComponent("forum/posts/\(postId)/comments")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(CommentPage.self, from: data)
    }
    
    /// 添加评论
    func addComment(postId: Int64, content: String, parentId: Int64? = nil) async throws -> CommentDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)/comments"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = ["content": content]
        if let parentId = parentId { body["parentId"] = parentId }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(CommentDTO.self, from: data)
    }
    
    /// 评论点赞/取消点赞
    func toggleCommentLike(commentId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/comments/\(commentId)/like"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Bool].self, from: data)
    }
    
    /// 删除评论
    func deleteComment(commentId: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/comments/\(commentId)"))
        request.httpMethod = "DELETE"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    // MARK: - 用户关注
    
    /// 检查是否关注了某用户
    func isFollowing(userId: Int64) async throws -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("users/\(userId)/is-following"))
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        let result = try jsonDecoder.decode([String: Bool].self, from: data)
        return result["following"] ?? false
    }
    
    /// 获取用户信息
    func getUser(userId: Int64) async throws -> UserDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent("users/\(userId)"))
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(UserDTO.self, from: data)
    }
    
    /// 关注/取消关注用户
    func toggleFollow(userId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("users/\(userId)/follow"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Bool].self, from: data)
    }
    
    /// 获取用户的关注列表
    func getFollowing(userId: Int64, page: Int = 0, size: Int = 20) async throws -> UserPage {
        var url = baseURL.appendingPathComponent("users/\(userId)/following")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(UserPage.self, from: data)
    }
    
    /// 获取用户的粉丝列表
    func getFollowers(userId: Int64, page: Int = 0, size: Int = 20) async throws -> UserPage {
        var url = baseURL.appendingPathComponent("users/\(userId)/followers")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(UserPage.self, from: data)
    }
    
    /// 获取关注统计
    func getFollowStats(userId: Int64) async throws -> [String: Int] {
        let url = baseURL.appendingPathComponent("users/\(userId)/follow-stats")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Int].self, from: data)
    }
    
    /// 获取用户完整统计信息（鸟数量、帖子数量、粉丝数、关注数）
    func getUserFullStats(userId: Int64) async throws -> UserFullStats {
        let url = baseURL.appendingPathComponent("users/\(userId)/full-stats")
        print("📊 API调用: \(url.absoluteString)")
        var request = URLRequest(url: url)
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 打印原始响应数据
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📊 API响应: \(jsonString)")
        }
        
        try Self.validate(response: response)
        return try jsonDecoder.decode(UserFullStats.self, from: data)
    }
    
    /// 获取其他用户的鸟儿列表
    func getUserBirds(userId: Int64) async throws -> [Bird] {
        let url = baseURL.appendingPathComponent("users/\(userId)/birds")
        var request = URLRequest(url: url)
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Bird].self, from: data)
    }
    
    // MARK: - P2-04: 寻鸟帖标记已找到
    
    /// 标记寻鸟帖已找到
    func markPostAsFound(postId: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)/mark-found"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    // MARK: - P2-05: 重复发布检查
    
    /// 检查是否重复发布
    func checkDuplicatePost(content: String) async throws -> Bool {
        var url = baseURL.appendingPathComponent("forum/posts/check-duplicate")
        url.append(queryItems: [URLQueryItem(name: "content", value: content)])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        let result = try jsonDecoder.decode([String: Bool].self, from: data)
        return result["isDuplicate"] ?? false
    }
    
    /// 获取用户的粉丝列表（返回 UserProfile 数组）
    func getUserFollowers(userId: Int64) async throws -> [UserProfile] {
        let page = try await getFollowers(userId: userId, page: 0, size: 100)
        return page.content.map { dto in
            UserProfile(
                id: dto.id ?? 0,
                nickname: dto.nickname ?? "用户",
                avatar: dto.avatarUrl,
                bio: dto.bio,
                birdCount: dto.birdCount ?? 0,
                postCount: dto.postCount ?? 0,
                followerCount: dto.followerCount ?? 0,
                followingCount: dto.followingCount ?? 0
            )
        }
    }
    
    /// 获取用户的关注列表（返回 UserProfile 数组）
    func getUserFollowing(userId: Int64) async throws -> [UserProfile] {
        let page = try await getFollowing(userId: userId, page: 0, size: 100)
        return page.content.map { dto in
            UserProfile(
                id: dto.id ?? 0,
                nickname: dto.nickname ?? "用户",
                avatar: dto.avatarUrl,
                bio: dto.bio,
                birdCount: dto.birdCount ?? 0,
                postCount: dto.postCount ?? 0,
                followerCount: dto.followerCount ?? 0,
                followingCount: dto.followingCount ?? 0
            )
        }
    }
    
    // MARK: - 举报和拉黑API
    
    /// 举报帖子
    /// - Parameters:
    ///   - postId: 帖子ID
    ///   - type: 举报类型（SPAM/INAPPROPRIATE/HARASSMENT/FRAUD/VIOLENCE/COPYRIGHT/OTHER）
    ///   - reason: 举报原因
    ///   - description: 详细描述（可选）
    func reportPost(postId: Int64, type: String, reason: String, description: String? = nil) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)/report"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "type": type,
            "reason": reason
        ]
        if let desc = description, !desc.isEmpty {
            body["description"] = desc
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        // 后端返回 { success: Bool, message: String }，提取 success 字段
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            return ["success": success]
        }
        return ["success": true]
    }
    
    /// 拉黑/取消拉黑用户
    func blockUser(userId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("users/\(userId)/block"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Bool].self, from: data)
    }
    
    /// 获取拉黑列表
    func getBlockedUsers() async throws -> [Int64] {
        var request = URLRequest(url: baseURL.appendingPathComponent("users/blocked"))
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Int64].self, from: data)
    }
    
    /// 注销账号（需要验证码二次确认）
    func deleteAccount(code: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/delete-account"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // P1 安全修复：发送验证码用于二次确认
        let body = ["code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 发送验证码
    func sendVerificationCode(phone: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/send-code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone": phone]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 验证验证码（用于验证当前手机号）
    func verifyCode(phone: String, code: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/verify-code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone": phone, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode([String: Bool].self, from: data)
        if result["valid"] != true {
            throw ApiError.serverError("验证码错误")
        }
    }
    
    /// 修改手机号
    func changePhone(newPhone: String, code: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/change-phone"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["newPhone": newPhone, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode([String: Bool].self, from: data)
        if result["success"] != true {
            throw ApiError.serverError("修改手机号失败")
        }
    }
    
    /// 设置密码（首次设置）
    func setPassword(password: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/set-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 修改密码（需要验证旧密码）
    func changePassword(oldPassword: String, newPassword: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/change-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["oldPassword": oldPassword, "newPassword": newPassword]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode(LoginResponse.self, from: data)
        if result.success != true {
            throw ApiError.serverError(result.message)
        }
    }
    
    /// 重置密码（通过验证码，用于忘记密码）
    func resetPassword(phone: String, code: String, newPassword: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/reset-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone": phone, "code": code, "newPassword": newPassword]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode(LoginResponse.self, from: data)
        if result.success != true {
            throw ApiError.serverError(result.message)
        }
    }
    

    
    /// 密码登录
    func loginWithPassword(phone: String, password: String) async throws -> (token: String, user: User) {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/login-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone": phone, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        guard result.success, let token = result.token, let user = result.user else {
            throw ApiError.serverError(result.message)
        }
        
        return (token, user)
    }
    
    /// 绑定情侣伴侣
    /// #7 FIX: 添加幂等性保护，防止重复绑定
    /// #12 FIX: 关键操作，需要确保原子性
    func bindCouplePartner(partnerPhone: String) async throws -> CoupleBindResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/bind"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // #7 FIX: 添加幂等性 key（使用伴侣手机号作为参数确保唯一性）
        let idempotencyKey = IdempotencyHelper.shared.generateKey(
            operation: "bindCouplePartner",
            params: ["partnerPhone": partnerPhone]
        )
        request.setIdempotencyKey(idempotencyKey)
        guard IdempotencyHelper.shared.markRequestStarted(idempotencyKey) else {
            throw ApiError.serverError("请勿重复提交绑定请求")
        }
        
        let body = ["partnerPhone": partnerPhone]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response: response)
            let result = try JSONDecoder().decode(CoupleBindResponse.self, from: data)
            IdempotencyHelper.shared.markRequestCompleted(idempotencyKey, success: result.success)
            return result
        } catch {
            IdempotencyHelper.shared.markRequestCompleted(idempotencyKey, success: false)
            throw error
        }
    }
    
    /// 解绑情侣伴侣
    func unbindCouplePartner() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/unbind"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 取消预留情侣绑定
    func cancelPendingCoupleBinding() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/cancel-pending"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 修改预留情侣绑定手机号
    func updatePendingCoupleBinding(newPartnerPhone: String) async throws -> CoupleBindResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/update-pending"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["partnerPhone": newPartnerPhone]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        return try JSONDecoder().decode(CoupleBindResponse.self, from: data)
    }
    
    // MARK: - P0 修复：情侣邀请确认流程
    
    /// 获取待处理的情侣邀请
    func getCoupleInvitation() async throws -> CoupleInvitationResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/invitation"))
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        // 直接解码后端响应
        return try jsonDecoder.decode(CoupleInvitationResponse.self, from: data)
    }
    
    /// 接受情侣邀请
    func acceptCoupleInvitation() async throws -> CoupleActionResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/invitation/accept"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        return try JSONDecoder().decode(CoupleActionResponse.self, from: data)
    }
    
    /// 拒绝情侣邀请
    func rejectCoupleInvitation() async throws -> CoupleActionResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/invitation/reject"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        return try JSONDecoder().decode(CoupleActionResponse.self, from: data)
    }

    
    /// 购买/续费VIP（首次购买时绑定Apple订单到手机号）
    func purchaseVip(vipType: String, duration: Int?, transactionInfo: (originalTransactionId: String, productId: String, purchaseDate: Int64)? = nil) async throws -> VipPurchaseResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/vip/purchase"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = ["vipType": vipType]
        if let duration = duration {
            body["duration"] = duration
        }
        // 首次购买时传递交易信息用于绑定订单
        if let txInfo = transactionInfo {
            body["originalTransactionId"] = txInfo.originalTransactionId
            body["productId"] = txInfo.productId
            body["purchaseDate"] = txInfo.purchaseDate
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode(VipPurchaseResponse.self, from: data)
        return result
    }
    
    // VIP购买响应
    struct VipPurchaseResponse: Codable {
        let success: Bool
        let message: String
        let vipType: String?
        let expireDate: String?
        let remainingDays: Int?
    }
    
    /// 恢复购买 - 将Apple交易信息发送到后端验证并恢复VIP状态
    /// 包含交易ID绑定验证，防止同一笔购买被恢复到多个账号
    func restoreVipPurchase(transactions: [[String: Any]]) async throws -> VipPurchaseResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/vip/restore"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = ["transactions": transactions]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        return try JSONDecoder().decode(VipPurchaseResponse.self, from: data)
    }
    
    // MARK: - 用户反馈
    
    /// 提交用户反馈
    /// - Parameters:
    ///   - type: 反馈类型 (bug, suggestion, other)
    ///   - content: 反馈内容
    ///   - contactInfo: 可选的联系方式
    /// - Returns: 是否提交成功
    func submitFeedback(type: String, content: String, contactInfo: String?) async throws -> Bool {
        let url = baseURL.appendingPathComponent("feedback")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 可选：添加 Token（支持匿名反馈）
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 获取设备信息
        let device = UIDevice.current
        let deviceInfo = "\(device.model), \(device.systemName) \(device.systemVersion)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        var body: [String: Any] = [
            "type": type,
            "content": content,
            "deviceInfo": deviceInfo,
            "appVersion": appVersion
        ]
        
        if let contact = contactInfo, !contact.isEmpty {
            body["contactInfo"] = contact
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            return success
        }
        
        return true
    }
    
    // MARK: - 文件上传
    
    /// 上传鸟儿头像
    func uploadBirdAvatar(image: UIImage) async throws -> String {
        // 1. 先调整图片尺寸（最大1024x1024）
        let resizedImage = resizeImage(image: image, maxSize: 1024)
        
        // 2. 压缩图片
        guard var imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw ApiError.invalidResponse
        }
        
        // 3. 如果文件仍然大于3MB，继续压缩
        var quality: CGFloat = 0.6
        while imageData.count > 3_000_000 && quality > 0.1 {
            quality -= 0.1
            if let compressed = resizedImage.jpegData(compressionQuality: quality) {
                imageData = compressed
            }
        }
        
        let sizeInMB = Double(imageData.count) / 1_000_000.0
        print("📤 开始上传头像")
        print("📦 原始尺寸: \(image.size.width)x\(image.size.height)")
        print("📦 调整后尺寸: \(resizedImage.size.width)x\(resizedImage.size.height)")
        print("📦 压缩质量: \(String(format: "%.1f", quality * 100))%")
        print("📦 文件大小: \(String(format: "%.2f", sizeInMB)) MB (\(imageData.count) bytes)")
        
        // 检查文件大小
        if imageData.count > 8_000_000 {
            print("⚠️ 警告：文件仍然较大，可能上传失败")
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("upload/bird-avatar"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 响应状态码: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ 错误信息: \(errorString)")
                }
            }
        }
        
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode([String: String].self, from: data)
        guard let url = result["url"] else {
            throw ApiError.invalidResponse
        }
        
        print("✅ 上传成功: \(url)")
        
        // 后端返回的已经是完整的OSS URL
        return url
    }
    
    /// 上传用户头像
    func uploadUserAvatar(image: UIImage) async throws -> String {
        return try await uploadBirdAvatar(image: image)
    }
    
    /// 上传帖子图片
    func uploadPostImage(image: UIImage) async throws -> String {
        print("📷 开始上传图片, 原始尺寸: \(image.size)")
        
        // 调整图片尺寸（最大1920x1920）
        let resizedImage = resizeImage(image: image, maxSize: 1920)
        print("📷 调整后尺寸: \(resizedImage.size)")
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            print("❌ 图片压缩失败")
            throw NSError(domain: "ApiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片压缩失败"])
        }
        print("📷 图片数据大小: \(imageData.count) bytes")
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: baseURL.appendingPathComponent("upload/post-image"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"post_image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📷 发送上传请求到: \(request.url?.absoluteString ?? "")")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📷 上传响应状态码: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ 上传失败响应: \(responseString)")
                }
            }
        }
        
        try Self.validate(response: response)
        
        let result = try jsonDecoder.decode([String: String].self, from: data)
        guard let url = result["url"] else {
            print("❌ 上传成功但未返回URL, 响应: \(String(data: data, encoding: .utf8) ?? "")")
            throw NSError(domain: "ApiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "上传成功但未返回URL"])
        }
        print("✅ 图片上传成功: \(url)")
        return url
    }
    
    /// 上传帖子视频
    func uploadPostVideo(videoURL: URL) async throws -> String {
        let videoData = try Data(contentsOf: videoURL)
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: baseURL.appendingPathComponent("upload/post-video"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try jsonDecoder.decode([String: String].self, from: data)
        guard let url = result["url"] else {
            throw NSError(domain: "ApiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "上传成功但未返回URL"])
        }
        return url
    }
    
    /// 调整图片大小
    private func resizeImage(image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        
        // 如果图片已经小于最大尺寸，直接返回
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        // 计算缩放比例
        let widthRatio = maxSize / size.width
        let heightRatio = maxSize / size.height
        let ratio = min(widthRatio, heightRatio)
        
        // 计算新尺寸
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // 创建新图片
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }

    // MARK: - Helpers

    private static func validate(response: URLResponse, expectedStatusCode: Int = 200) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }
        
        // P0 修复：401 只抛出错误，不自动触发登出
        // Token 真正过期只在 App 启动时由 auth/validate 接口检测
        if httpResponse.statusCode == 401 {
            throw ApiError.unauthorized
        }
        
        // 403 Forbidden - 权限不足
        if httpResponse.statusCode == 403 {
            throw ApiError.forbidden
        }
        
        // 允许 200, 201, 204 和 expectedStatusCode
        let validCodes = [200, 201, 204, expectedStatusCode]
        guard validCodes.contains(httpResponse.statusCode) else {
            throw ApiError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - 论坛帖子 DTO

// Fix #11: 使用自定义解码器处理 null 值
struct ForumPostDTO: Codable {
    let id: Int64
    let authorId: Int64?
    let authorName: String?
    let authorAvatar: String?
    let content: String  // 保持非可选，在解码时提供默认值
    let postType: String?
    let mediaType: String?
    let images: [String]?
    let videoUrl: String?
    let videoCover: String?
    let videoDuration: Int?
    let likeCount: Int?
    let commentCount: Int?
    let favoriteCount: Int?
    let viewCount: Int?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let distance: Double?
    let birdId: Int64?
    let birdName: String?
    let birdSpecies: String?
    let birdAvatar: String?
    let birdsInfo: String?  // 多个鸟儿信息JSON数组
    let lostLocation: String?
    let contactPhone: String?
    let reward: String?
    let isFound: Bool?
    let isLiked: Bool?
    let isFavorited: Bool?
    let isFollowing: Bool?
    let createdAt: String?
    let timeAgo: String?
    
    // Fix #11: 自定义解码器处理 null 值
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        authorId = try container.decodeIfPresent(Int64.self, forKey: .authorId)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        authorAvatar = try container.decodeIfPresent(String.self, forKey: .authorAvatar)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""  // 默认空字符串
        postType = try container.decodeIfPresent(String.self, forKey: .postType)
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
        images = try container.decodeIfPresent([String].self, forKey: .images)
        videoUrl = try container.decodeIfPresent(String.self, forKey: .videoUrl)
        videoCover = try container.decodeIfPresent(String.self, forKey: .videoCover)
        videoDuration = try container.decodeIfPresent(Int.self, forKey: .videoDuration)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
        favoriteCount = try container.decodeIfPresent(Int.self, forKey: .favoriteCount)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        birdId = try container.decodeIfPresent(Int64.self, forKey: .birdId)
        birdName = try container.decodeIfPresent(String.self, forKey: .birdName)
        birdSpecies = try container.decodeIfPresent(String.self, forKey: .birdSpecies)
        birdAvatar = try container.decodeIfPresent(String.self, forKey: .birdAvatar)
        birdsInfo = try container.decodeIfPresent(String.self, forKey: .birdsInfo)
        lostLocation = try container.decodeIfPresent(String.self, forKey: .lostLocation)
        contactPhone = try container.decodeIfPresent(String.self, forKey: .contactPhone)
        reward = try container.decodeIfPresent(String.self, forKey: .reward)
        isFound = try container.decodeIfPresent(Bool.self, forKey: .isFound)
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked)
        isFavorited = try container.decodeIfPresent(Bool.self, forKey: .isFavorited)
        isFollowing = try container.decodeIfPresent(Bool.self, forKey: .isFollowing)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        timeAgo = try container.decodeIfPresent(String.self, forKey: .timeAgo)
    }
    
    // 保留默认初始化器用于编码和手动创建
    init(id: Int64, authorId: Int64?, authorName: String?, authorAvatar: String?, content: String, postType: String?, mediaType: String?, images: [String]?, videoUrl: String?, videoCover: String?, videoDuration: Int?, likeCount: Int?, commentCount: Int?, favoriteCount: Int?, viewCount: Int?, latitude: Double?, longitude: Double?, locationName: String?, distance: Double?, birdId: Int64?, birdName: String?, birdSpecies: String?, birdAvatar: String?, birdsInfo: String?, lostLocation: String?, contactPhone: String?, reward: String?, isFound: Bool?, isLiked: Bool?, isFavorited: Bool?, isFollowing: Bool?, createdAt: String?, timeAgo: String?) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.content = content
        self.postType = postType
        self.mediaType = mediaType
        self.images = images
        self.videoUrl = videoUrl
        self.videoCover = videoCover
        self.videoDuration = videoDuration
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.favoriteCount = favoriteCount
        self.viewCount = viewCount
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.distance = distance
        self.birdId = birdId
        self.birdName = birdName
        self.birdSpecies = birdSpecies
        self.birdAvatar = birdAvatar
        self.birdsInfo = birdsInfo
        self.lostLocation = lostLocation
        self.contactPhone = contactPhone
        self.reward = reward
        self.isFound = isFound
        self.isLiked = isLiked
        self.isFavorited = isFavorited
        self.isFollowing = isFollowing
        self.createdAt = createdAt
        self.timeAgo = timeAgo
    }
}

struct ForumPostPage: Codable {
    let content: [ForumPostDTO]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let first: Bool
    let last: Bool
}

// MARK: - 评论 DTO

struct CommentDTO: Codable {
    let id: Int64
    let postId: Int64?
    let authorId: Int64?
    let authorName: String?
    let authorAvatar: String?
    let content: String
    let likeCount: Int?
    let parentId: Int64?
    let parentAuthorName: String?  // 父评论作者名（用于@显示）
    let replies: [CommentDTO]?
    let isLiked: Bool?
    let createdAt: String?
    let timeAgo: String?
    
    // VIP Related Fields
    let authorIsVip: Bool?
    let authorVipType: String?
    let authorIsCoupleVip: Bool?
    let authorCouplePartnerId: Int64?
}

struct CommentPage: Codable {
    let content: [CommentDTO]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let first: Bool
    let last: Bool
}

// MARK: - 用户 DTO

struct UserDTO: Codable {
    let id: Int64
    let phone: String?
    let nickname: String?
    let avatarUrl: String?
    let bio: String?
    let isVip: Bool?
    let vipType: String?
    let vipExpireDate: String?
    let createdAt: String?
    let birdCount: Int?
    let postCount: Int?
    let followerCount: Int?
    let followingCount: Int?
}

struct UserPage: Codable {
    let content: [UserDTO]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let first: Bool
    let last: Bool
}

// MARK: - 离线同步回调版本API

extension ApiService {
    
    /// 创建鸟儿（回调版本，用于离线同步）
    /// 重举修复 #3: 携带 idempotencyKey 用于幂等性保护
    func createBird(_ dto: BirdDTO, completion: @escaping (Result<BirdDTO, Error>) -> Void) {
        Task {
            do {
                var request = URLRequest(url: baseURL.appendingPathComponent("birds"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = AuthService.shared.getToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime]
                
                // P0 修复：与 async 版本保持一致，使用 NSNull() 而非 compactMapValues
                var body: [String: Any] = [
                    "nickname": dto.nickname as Any? ?? NSNull(),
                    "species": dto.species as Any? ?? NSNull(),
                    "gender": dto.gender as Any? ?? NSNull(),
                    "featherColor": dto.featherColor as Any? ?? NSNull(),
                    "source": dto.source as Any? ?? NSNull(),
                    "fatherInfo": dto.fatherInfo as Any? ?? NSNull(),
                    "motherInfo": dto.motherInfo as Any? ?? NSNull(),
                    "legRingId": dto.legRingId as Any? ?? NSNull(),
                    "avatarUrl": dto.avatarUrl as Any? ?? NSNull(),
                    "notes": dto.notes as Any? ?? NSNull(),
                    "medicalHistory": dto.medicalHistory as Any? ?? NSNull(),
                    "birthdayType": dto.birthdayType as Any? ?? NSNull()
                ]
                
                // 幂等键（仅创建时使用）
                if let key = dto.idempotencyKey {
                    body["idempotencyKey"] = key
                }
                
                // 日期字段
                body["hatchDate"] = dto.hatchDate.map { isoFormatter.string(from: $0) } ?? NSNull()
                body["adoptionDate"] = dto.adoptionDate.map { isoFormatter.string(from: $0) } ?? NSNull()
                body["deathDate"] = dto.deathDate.map { isoFormatter.string(from: $0) } ?? NSNull()
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response: response)
                let result = try jsonDecoder.decode(BirdDTO.self, from: data)
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// 更新鸟儿（回调版本，用于离线同步）
    func updateBird(id: Int, _ dto: BirdDTO, completion: @escaping (Result<BirdDTO, Error>) -> Void) {
        Task {
            do {
                var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(id)"))
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = AuthService.shared.getToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime]
                
                // P0 修复：补全所有字段（之前只发送了5个字段，离线编辑的其他字段全部丢失）
                var body: [String: Any] = [
                    "nickname": dto.nickname as Any? ?? NSNull(),
                    "species": dto.species as Any? ?? NSNull(),
                    "gender": dto.gender as Any? ?? NSNull(),
                    "featherColor": dto.featherColor as Any? ?? NSNull(),
                    "source": dto.source as Any? ?? NSNull(),
                    "avatarUrl": dto.avatarUrl as Any? ?? NSNull(),
                    "notes": dto.notes as Any? ?? NSNull(),
                    "birthdayType": dto.birthdayType as Any? ?? NSNull(),
                    "fatherInfo": dto.fatherInfo as Any? ?? NSNull(),
                    "motherInfo": dto.motherInfo as Any? ?? NSNull(),
                    "legRingId": dto.legRingId as Any? ?? NSNull(),
                    "medicalHistory": dto.medicalHistory as Any? ?? NSNull(),
                    "version": dto.version as Any? ?? NSNull()
                ]
                
                // 日期字段
                body["hatchDate"] = dto.hatchDate.map { isoFormatter.string(from: $0) } ?? NSNull()
                body["adoptionDate"] = dto.adoptionDate.map { isoFormatter.string(from: $0) } ?? NSNull()
                body["deathDate"] = dto.deathDate.map { isoFormatter.string(from: $0) } ?? NSNull()
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response: response)
                let result = try jsonDecoder.decode(BirdDTO.self, from: data)
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// 删除鸟儿（回调版本，用于离线同步）
    func deleteBird(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(id)"))
                request.httpMethod = "DELETE"
                if let token = AuthService.shared.getToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let (_, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response: response, expectedStatusCode: 204)
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// 添加鸟儿日志（回调版本，用于离线同步）
    /// P0 修复：端点从 /birds/{birdId}/logs 改为 /logs，birdId 在请求体中传递
    func addBirdLog(birdId: Int, data: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        Task {
            do {
                // P0 修复：后端日志端点是 POST /api/logs，不是 /api/birds/{birdId}/logs
                var request = URLRequest(url: baseURL.appendingPathComponent("logs"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = AuthService.shared.getToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                // P0 修复：确保 birdId 在请求体中传递
                var requestData = data
                requestData["birdId"] = birdId
                
                request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
                
                let (responseData, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response: response)
                let result = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] ?? [:]
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// 添加鸟儿日志（async 版本，用于同步写入服务器）
    func createBirdLogAsync(birdId: Int, data: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: baseURL.appendingPathComponent("logs"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 确保 birdId 在请求体中传递
        var requestData = data
        requestData["birdId"] = birdId
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try JSONSerialization.jsonObject(with: responseData) as? [String: Any] ?? [:]
    }
    
    /// 获取鸟儿日志
    func getBirdLogs(birdId: Int, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        Task {
            do {
                var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/logs"))
                if let token = AuthService.shared.getToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response: response)
                let result = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// 添加鸟儿体重记录（回调版本，用于离线同步）
    func addBirdWeight(birdId: Int, data: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        Task {
            do {
                var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/weights"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token = AuthService.shared.getToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                request.httpBody = try JSONSerialization.data(withJSONObject: data)
                
                let (responseData, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response: response)
                let result = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] ?? [:]
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// 获取鸟儿体重记录
    func getBirdWeights(birdId: Int, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        Task {
            do {
                var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/weights"))
                if let token = AuthService.shared.getToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                try Self.validate(response: response)
                let result = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// 删除鸟儿体重记录
    func deleteBirdWeight(birdId: Int64, weightId: Int64) async throws {
        let url = baseURL.appendingPathComponent("birds/\(birdId)/weights/\(weightId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    /// 删除鸟儿日志
    func deleteBirdLog(birdId: Int64, logId: Int64) async throws {
        let url = baseURL.appendingPathComponent("birds/\(birdId)/logs/\(logId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    // MARK: - 百科 Encyclopedia
    
    /// 获取所有百科鸟类
    func getEncyclopediaBirds() async throws -> [BirdEncyclopediaDTO] {
        let url = baseURL.appendingPathComponent("encyclopedia/birds")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdEncyclopediaDTO].self, from: data)
    }
    
    /// 根据ID获取百科鸟类详情
    func getEncyclopediaBird(id: Int64) async throws -> BirdEncyclopediaDTO {
        let url = baseURL.appendingPathComponent("encyclopedia/birds/\(id)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdEncyclopediaDTO.self, from: data)
    }
    
    /// 搜索百科鸟类
    func searchEncyclopediaBirds(keyword: String) async throws -> [BirdEncyclopediaDTO] {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("encyclopedia/birds/search"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        
        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdEncyclopediaDTO].self, from: data)
    }
    
    /// 获取所有百科分类
    func getEncyclopediaCategories() async throws -> [String] {
        let url = baseURL.appendingPathComponent("encyclopedia/birds/categories")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String].self, from: data)
    }
    
    /// 根据分类获取百科鸟类
    func getEncyclopediaBirdsByCategory(category: String) async throws -> [BirdEncyclopediaDTO] {
        let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category
        let url = baseURL.appendingPathComponent("encyclopedia/birds/category/\(encodedCategory)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdEncyclopediaDTO].self, from: data)
    }
    
    // MARK: - 食物百科 Food Encyclopedia
    
    /// 获取所有食物
    func getAllFoods() async throws -> [FoodEncyclopediaDTO] {
        let url = baseURL.appendingPathComponent("encyclopedia/foods")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([FoodEncyclopediaDTO].self, from: data)
    }
    
    /// 根据ID获取食物详情
    func getFoodById(id: Int64) async throws -> FoodEncyclopediaDTO {
        let url = baseURL.appendingPathComponent("encyclopedia/foods/\(id)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(FoodEncyclopediaDTO.self, from: data)
    }
    
    /// 搜索食物
    func searchFoods(keyword: String) async throws -> [FoodEncyclopediaDTO] {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("encyclopedia/foods/search"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        
        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)
        try Self.validate(response: response)
        return try jsonDecoder.decode([FoodEncyclopediaDTO].self, from: data)
    }
    
    /// 获取所有食物分类
    func getFoodCategories() async throws -> [String] {
        let url = baseURL.appendingPathComponent("encyclopedia/foods/categories")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String].self, from: data)
    }
    
    /// 根据分类获取食物
    func getFoodsByCategory(category: String) async throws -> [FoodEncyclopediaDTO] {
        let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category
        let url = baseURL.appendingPathComponent("encyclopedia/foods/category/\(encodedCategory)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([FoodEncyclopediaDTO].self, from: data)
    }
    
    /// 根据安全等级获取食物
    func getFoodsBySafetyLevel(safetyLevel: String) async throws -> [FoodEncyclopediaDTO] {
        let url = baseURL.appendingPathComponent("encyclopedia/foods/safety/\(safetyLevel)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([FoodEncyclopediaDTO].self, from: data)
    }
    
    // MARK: - 症状百科 Symptom Encyclopedia
    
    /// 获取所有症状
    func getAllSymptoms() async throws -> [SymptomDTO] {
        let url = baseURL.appendingPathComponent("encyclopedia/symptoms")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([SymptomDTO].self, from: data)
    }
    
    /// 根据ID获取症状详情
    func getSymptomById(id: Int64) async throws -> SymptomDTO {
        let url = baseURL.appendingPathComponent("encyclopedia/symptoms/\(id)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(SymptomDTO.self, from: data)
    }
    
    /// 搜索症状
    func searchSymptoms(keyword: String) async throws -> [SymptomDTO] {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("encyclopedia/symptoms/search"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        
        let (data, response) = try await URLSession.shared.data(from: urlComponents.url!)
        try Self.validate(response: response)
        return try jsonDecoder.decode([SymptomDTO].self, from: data)
    }
    
    /// 根据严重程度获取症状
    func getSymptomsBySeverity(severity: String) async throws -> [SymptomDTO] {
        let url = baseURL.appendingPathComponent("encyclopedia/symptoms/severity/\(severity)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([SymptomDTO].self, from: data)
    }
}


// MARK: - 百科数据模型
struct BirdEncyclopediaDTO: Codable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let scientificName: String?
    let category: String?
    let tags: [String]?
    let description: String?
    let feedingTips: String?
    let habitat: String?
    let lifespan: Int?
    let colorHex: String?
    let imageUrl: String?
    let priceMin: Int?  // 最低价格（元）
    let priceMax: Int?  // 最高价格（元）
    
    // 价格范围文字
    var priceRangeText: String? {
        guard let min = priceMin, let max = priceMax else { return nil }
        if min == max {
            return "¥\(min)"
        }
        return "¥\(min) - ¥\(max)"
    }
}

// MARK: - 食物百科数据模型
struct FoodEncyclopediaDTO: Codable, Identifiable, Hashable {
    let id: Int64
    let category: String
    let foodName: String
    let intro: String
    let nutrition: [String]
    let precautions: String
    let safetyLevel: String
    let source: String?
    let status: Int?
    
    // 转换为前端BirdFood模型
    func toBirdFood() -> BirdFood {
        let foodCategory = FoodCategory.fromString(category)
        let safety = FoodSafetyLevel.fromString(safetyLevel)
        
        return BirdFood(
            name: foodName,
            category: foodCategory,
            safetyLevel: safety,
            description: intro,
            notes: precautions,
            nutrients: nutrition,
            birdPreferences: [:],
            sources: source != nil ? [source!] : []
        )
    }
}

// 扩展FoodCategory支持从字符串转换
extension FoodCategory {
    static func fromString(_ string: String) -> FoodCategory {
        switch string {
        case "水果": return .fruits
        case "蔬菜": return .vegetables
        case "谷物种子", "谷物": return .grains
        case "蛋白质": return .proteins
        case "坚果": return .nuts
        case "草本植物", "香草": return .herbs
        case "人类食品", "人类食物": return .humanFood
        case "饮品", "饮料": return .drinks
        case "调味品", "调味料": return .seasonings
        case "零食甜点", "零食": return .snacks
        case "其他": return .others
        default: return .others
        }
    }
}


// 扩展FoodSafetyLevel支持从字符串转换
extension FoodSafetyLevel {
    static func fromString(_ string: String) -> FoodSafetyLevel {
        switch string {
        case "safe": return .safe
        case "limited": return .caution
        case "dangerous": return .dangerous
        default: return .caution
        }
    }
}

// MARK: - 症状百科数据模型
struct SymptomDTO: Codable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let description: String?
    let possibleCauses: [String]?
    let suggestions: [String]?
    let whenToSeeVet: [String]?
    let prevention: [String]?
    let severity: String?
    let category: String?
    let icon: String?
    
    // 转换为前端BirdSymptom模型
    func toBirdSymptom() -> BirdSymptom {
        let severityEnum: BirdSymptom.Severity
        switch severity {
        case "high": severityEnum = .high
        case "low": severityEnum = .low
        default: severityEnum = .medium
        }
        
        return BirdSymptom(
            name: name,
            description: description ?? "",
            icon: icon ?? "exclamationmark.triangle",
            severity: severityEnum,
            category: category ?? "综合症状",
            possibleCauses: possibleCauses ?? [],
            suggestions: suggestions ?? [],
            whenToSeeVet: whenToSeeVet ?? [],
            prevention: prevention ?? []
        )
    }
}

// MARK: - BirdDTO for offline sync

struct BirdDTO: Codable {
    var id: Int?
    var userId: Int?
    var nickname: String?
    var species: String?
    var gender: String?
    var hatchDate: Date?
    var adoptionDate: Date?
    var birthdayType: String?
    var deathDate: Date?                     // P0-01: 忌日
    var featherColor: String?
    var source: String?
    var avatarUrl: String?
    var notes: String?
    var medicalHistory: String?              // 医疗史
    var fatherInfo: String?                  // 父亲信息
    var motherInfo: String?                  // 母亲信息
    var legRingId: String?                   // 脚环ID
    var isLost: Bool?
    var lostDate: Date?
    var lostLocation: String?
    var lostPostId: Int64?                   // 关联的寻鸟帖子ID
    var isDeleted: Bool?                     // P0-02: 是否已删除
    var deletedAt: Date?                     // P0-02: 删除时间
    var version: Int64?                      // P0: 版本号（乐观锁）
    var createdAt: Date?
    var updatedAt: Date?
    
    // 重举修复 #3: 幂等键，用于防止网络超时时重复创建
    var idempotencyKey: String?
    
    init() {}
}

// MARK: - Data Extension
extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
