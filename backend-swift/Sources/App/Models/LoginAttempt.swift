import Fluent
import Vapor

/// 登录尝试记录 - 用于防止暴力破解
final class LoginAttempt: Model, Content, @unchecked Sendable {
    static let schema = "login_attempts"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    /// 尝试登录的手机号
    @Field(key: "phone")
    var phone: String
    
    /// 客户端IP地址
    @Field(key: "ip_address")
    var ipAddress: String
    
    /// 是否成功
    @Field(key: "success")
    var success: Bool
    
    /// 尝试时间
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(phone: String, ipAddress: String, success: Bool) {
        self.phone = phone
        self.ipAddress = ipAddress
        self.success = success
    }
}

/// 登录限制服务
struct LoginRateLimiter {
    /// 每个手机号在指定时间窗口内最多允许的失败次数
    static let maxFailedAttempts = 5
    /// 时间窗口（分钟）
    static let windowMinutes = 15
    /// 锁定时间（分钟）
    static let lockoutMinutes = 30
    
    /// 检查是否被锁定
    static func isLocked(phone: String, req: Request) async throws -> Bool {
        let windowStart = Date().addingTimeInterval(-Double(lockoutMinutes * 60))
        
        let failedCount = try await LoginAttempt.query(on: req.db)
            .filter(\.$phone == phone)
            .filter(\.$success == false)
            .filter(\.$createdAt >= windowStart)
            .count()
        
        return failedCount >= maxFailedAttempts
    }
    
    /// 记录登录尝试
    static func recordAttempt(phone: String, ipAddress: String, success: Bool, req: Request) async throws {
        let attempt = LoginAttempt(phone: phone, ipAddress: ipAddress, success: success)
        try await attempt.save(on: req.db)
        
        // 如果登录成功，清理该手机号的失败记录（可选，减少数据库压力）
        if success {
            try await LoginAttempt.query(on: req.db)
                .filter(\.$phone == phone)
                .filter(\.$success == false)
                .delete()
        }
    }
    
    /// 获取剩余锁定时间（秒）
    static func getRemainingLockTime(phone: String, req: Request) async throws -> Int? {
        let windowStart = Date().addingTimeInterval(-Double(lockoutMinutes * 60))
        
        // 获取最近的失败尝试
        guard let lastFailedAttempt = try await LoginAttempt.query(on: req.db)
            .filter(\.$phone == phone)
            .filter(\.$success == false)
            .filter(\.$createdAt >= windowStart)
            .sort(\.$createdAt, .descending)
            .first(),
            let createdAt = lastFailedAttempt.createdAt else {
            return nil
        }
        
        let failedCount = try await LoginAttempt.query(on: req.db)
            .filter(\.$phone == phone)
            .filter(\.$success == false)
            .filter(\.$createdAt >= windowStart)
            .count()
        
        if failedCount >= maxFailedAttempts {
            let unlockTime = createdAt.addingTimeInterval(Double(lockoutMinutes * 60))
            let remainingSeconds = Int(unlockTime.timeIntervalSince(Date()))
            return max(0, remainingSeconds)
        }
        
        return nil
    }
    
    /// 获取客户端IP地址
    static func getClientIP(req: Request) -> String {
        // 优先从 X-Forwarded-For 获取（适用于反向代理）
        if let forwardedFor = req.headers.first(name: "X-Forwarded-For") {
            return forwardedFor.split(separator: ",").first.map(String.init) ?? "unknown"
        }
        // 从 X-Real-IP 获取
        if let realIP = req.headers.first(name: "X-Real-IP") {
            return realIP
        }
        // 直接从连接获取
        return req.remoteAddress?.ipAddress ?? "unknown"
    }
}
