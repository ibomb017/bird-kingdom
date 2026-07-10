import Foundation

/// #7 FIX: 幂等性辅助工具
/// 用于生成和管理 POST 请求的幂等性 key，防止重复提交
///
/// 使用方法：
/// 1. 在发起 POST 请求前生成 idempotency key
/// 2. 将 key 添加到 HTTP Header: "X-Idempotency-Key"
/// 3. 后端需要实现幂等性检查逻辑
///
/// 关键场景：
/// - 支付操作
/// - 资源创建（如发帖、添加鸟档案）
/// - 状态变更操作
class IdempotencyHelper {
    static let shared = IdempotencyHelper()
    
    /// HTTP Header 名称（业界标准）
    static let headerName = "X-Idempotency-Key"
    
    /// 存储进行中的请求 key，防止重复发送
    private var pendingKeys: Set<String> = []
    private let lock = NSLock()
    
    /// 已完成请求的缓存（用于检测重复）
    /// key: idempotencyKey, value: 完成时间戳
    private var completedKeys: [String: Date] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1小时后过期
    
    private init() {}
    
    // MARK: - 生成幂等性 Key
    
    /// 生成基于操作类型和参数的幂等性 key
    /// - Parameters:
    ///   - operation: 操作类型（如 "createBird", "purchaseVip"）
    ///   - params: 操作参数，用于生成唯一标识
    /// - Returns: 唯一的幂等性 key
    func generateKey(operation: String, params: [String: Any] = [:]) -> String {
        let uuid = UUID().uuidString
        
        // 将参数序列化为字符串（用于调试追踪）
        var paramString = ""
        if !params.isEmpty {
            let sortedKeys = params.keys.sorted()
            paramString = sortedKeys.map { "\($0)=\(params[$0] ?? "")" }.joined(separator: "&")
        }
        
        // 使用操作名 + UUID 作为 key，简单且保证唯一
        // 参数信息可用于日志追踪
        if !paramString.isEmpty {
            print("🔑 生成幂等性 key: \(operation) 参数: \(paramString)")
        }
        return "\(operation)_\(uuid)"
    }
    
    /// 生成简单的 UUID 幂等性 key
    func generateSimpleKey() -> String {
        return UUID().uuidString
    }
    
    // MARK: - 请求状态管理
    
    /// 标记请求开始（添加到进行中列表）
    /// - Parameter key: 幂等性 key
    /// - Returns: 如果 key 已存在（重复请求），返回 false
    func markRequestStarted(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // 检查是否已完成过（且未过期）
        if let completedTime = completedKeys[key] {
            if Date().timeIntervalSince(completedTime) < cacheExpiration {
                print("⚠️ 幂等性检查: 请求已完成，拒绝重复 (\(key))")
                return false
            } else {
                // 过期了，清理
                completedKeys.removeValue(forKey: key)
            }
        }
        
        // 检查是否正在进行
        if pendingKeys.contains(key) {
            print("⚠️ 幂等性检查: 请求进行中，拒绝重复 (\(key))")
            return false
        }
        
        pendingKeys.insert(key)
        print("✅ 幂等性请求开始: \(key)")
        return true
    }
    
    /// 标记请求完成
    /// - Parameters:
    ///   - key: 幂等性 key
    ///   - success: 是否成功完成
    func markRequestCompleted(_ key: String, success: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        pendingKeys.remove(key)
        
        if success {
            completedKeys[key] = Date()
            print("✅ 幂等性请求完成: \(key)")
        } else {
            // 失败的请求允许重试
            print("⚠️ 幂等性请求失败，允许重试: \(key)")
        }
        
        // 清理过期的已完成请求
        cleanupExpiredKeys()
    }
    
    /// 取消请求（允许重试）
    func cancelRequest(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        pendingKeys.remove(key)
        print("🚫 幂等性请求取消: \(key)")
    }
    
    /// 检查请求是否正在进行
    func isRequestPending(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingKeys.contains(key)
    }
    
    // MARK: - Private
    
    private func cleanupExpiredKeys() {
        let now = Date()
        completedKeys = completedKeys.filter { key, time in
            now.timeIntervalSince(time) < cacheExpiration
        }
    }
    
    /// 清除所有缓存（用于退出登录时）
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        pendingKeys.removeAll()
        completedKeys.removeAll()
        print("🗑️ 幂等性缓存已清除")
    }
}

// MARK: - URLRequest 扩展
extension URLRequest {
    /// 添加幂等性 key 到请求头
    /// - Parameter key: 幂等性 key
    mutating func setIdempotencyKey(_ key: String) {
        setValue(key, forHTTPHeaderField: IdempotencyHelper.headerName)
    }
    
    /// 生成并设置幂等性 key
    /// - Parameter operation: 操作名称
    /// - Returns: 生成的幂等性 key
    @discardableResult
    mutating func setNewIdempotencyKey(for operation: String) -> String {
        let key = IdempotencyHelper.shared.generateKey(operation: operation)
        setIdempotencyKey(key)
        return key
    }
}
