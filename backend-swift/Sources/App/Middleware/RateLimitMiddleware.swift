import Vapor
import Foundation

/// IP 级别限流中间件
/// 防止恶意请求和 API 滥用
///
/// 限制策略:
/// - 普通 API: 60秒内最多 100 次请求
/// - 登录/注册: 60秒内最多 10 次请求
/// - 验证码发送: 60秒内最多 5 次请求
public struct RateLimitMiddleware: AsyncMiddleware {
    
    /// 限流类型
    public enum LimitType {
        case normal     // 普通 API
        case auth       // 登录/注册相关
        case sms        // 短信验证码
        
        var limit: Int {
            switch self {
            case .normal: return 100
            case .auth: return 10
            case .sms: return 5
            }
        }
        
        var windowSeconds: Int {
            return 60
        }
    }
    
    let limitType: LimitType
    
    public init(type: LimitType = .normal) {
        self.limitType = type
    }
    
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let clientIp = getClientIP(request)
        let key = "\(limitType):\(clientIp)"
        
        // 检查限流
        let result = await RateLimitStore.shared.checkAndRecord(
            key: key,
            limit: limitType.limit,
            windowSeconds: limitType.windowSeconds
        )
        
        if !result.allowed {
            request.logger.warning("🚫 Rate limit exceeded: IP=\(clientIp), type=\(limitType), count=\(result.currentCount)")
            throw Abort(.tooManyRequests, reason: "请求过于频繁，请 \(result.retryAfterSeconds) 秒后重试")
        }
        
        // 继续处理请求
        let response = try await next.respond(to: request)
        
        // 添加限流头信息
        response.headers.add(name: "X-RateLimit-Limit", value: "\(limitType.limit)")
        response.headers.add(name: "X-RateLimit-Remaining", value: "\(result.remaining)")
        response.headers.add(name: "X-RateLimit-Reset", value: "\(result.resetTime)")
        
        return response
    }
    
    /// 获取客户端真实 IP
    private func getClientIP(_ request: Request) -> String {
        // 优先级: X-Forwarded-For > X-Real-IP > 直连 IP
        if let xForwardedFor = request.headers.first(name: "X-Forwarded-For") {
            // X-Forwarded-For 可能包含多个 IP，取第一个
            let ips = xForwardedFor.split(separator: ",")
            if let firstIp = ips.first {
                return String(firstIp).trimmingCharacters(in: .whitespaces)
            }
        }
        
        if let xRealIp = request.headers.first(name: "X-Real-IP") {
            return xRealIp
        }
        
        // 使用直连 IP
        return request.remoteAddress?.ipAddress ?? "unknown"
    }
}

/// 限流存储
/// 使用内存存储，生产环境建议使用 Redis
actor RateLimitStore {
    static let shared = RateLimitStore()
    
    private struct Record {
        var count: Int
        var windowStart: Date
    }
    
    private var records: [String: Record] = [:]
    private var lastCleanup: Date = Date()
    
    struct RateLimitResult {
        let allowed: Bool
        let currentCount: Int
        let remaining: Int
        let retryAfterSeconds: Int
        let resetTime: Int
    }
    
    func checkAndRecord(key: String, limit: Int, windowSeconds: Int) -> RateLimitResult {
        let now = Date()
        let windowStart = now.addingTimeInterval(-Double(windowSeconds))
        
        // 定期清理过期记录
        if now.timeIntervalSince(lastCleanup) > 300 { // 每5分钟清理一次
            cleanup(windowSeconds: windowSeconds)
            lastCleanup = now
        }
        
        // 获取或创建记录
        var record = records[key] ?? Record(count: 0, windowStart: now)
        
        // 检查是否在当前窗口内
        if record.windowStart < windowStart {
            // 窗口已过期，重置
            record = Record(count: 0, windowStart: now)
        }
        
        // 检查是否超限
        if record.count >= limit {
            let resetTime = Int(record.windowStart.timeIntervalSince1970) + windowSeconds
            let retryAfter = max(1, resetTime - Int(now.timeIntervalSince1970))
            return RateLimitResult(
                allowed: false,
                currentCount: record.count,
                remaining: 0,
                retryAfterSeconds: retryAfter,
                resetTime: resetTime
            )
        }
        
        // 记录本次请求
        record.count += 1
        records[key] = record
        
        let resetTime = Int(record.windowStart.timeIntervalSince1970) + windowSeconds
        return RateLimitResult(
            allowed: true,
            currentCount: record.count,
            remaining: max(0, limit - record.count),
            retryAfterSeconds: 0,
            resetTime: resetTime
        )
    }
    
    private func cleanup(windowSeconds: Int) {
        let threshold = Date().addingTimeInterval(-Double(windowSeconds * 2))
        records = records.filter { $0.value.windowStart > threshold }
    }
}
