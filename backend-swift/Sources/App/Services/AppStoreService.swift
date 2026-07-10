import Vapor
import Foundation

/// Apple App Store 服务
/// 用于验证 iOS 应用内购买收据
actor AppStoreService {
    static let shared = AppStoreService()
    
    private init() {}
    
    // MARK: - 配置
    
    /// App Store Connect API 密钥 ID
    private var keyId: String {
        Environment.get("APPLE_API_KEY_ID") ?? ""
    }
    
    /// App Store Connect API 发行者 ID
    private var issuerId: String {
        Environment.get("APPLE_API_ISSUER_ID") ?? ""
    }
    
    /// Bundle ID
    private var bundleId: String {
        Environment.get("APPLE_BUNDLE_ID") ?? "com.birdkingdom.app"
    }
    
    /// 是否使用沙箱环境
    private var useSandbox: Bool {
        Environment.get("APPLE_USE_SANDBOX") == "true"
    }
    
    // MARK: - 验证交易
    
    /// 验证 App Store 交易
    /// - Parameters:
    ///   - originalTransactionId: 原始交易ID
    ///   - productId: 产品ID
    ///   - client: HTTP 客户端
    /// - Returns: 验证结果
    func verifyTransaction(
        originalTransactionId: String,
        productId: String,
        client: Client,
        logger: Logger
    ) async -> TransactionVerificationResult {
        logger.info("🍎 开始验证 Apple 交易: \(originalTransactionId)")
        
        // 检查是否配置了 Apple API
        guard !keyId.isEmpty, !issuerId.isEmpty else {
            logger.warning("⚠️ Apple API 未配置，跳过验证")
            // 未配置时返回"通过"以便开发测试
            return TransactionVerificationResult(
                isValid: true,
                originalTransactionId: originalTransactionId,
                productId: productId,
                purchaseDate: Date(),
                expiresDate: nil,
                status: .verified,
                message: "验证跳过（开发模式）"
            )
        }
        
        // 验证产品 ID 是否匹配已知的订阅产品
        let validProductIds = [
            "com.birdkingdom.vip.monthly",
            "com.birdkingdom.vip.yearly",
            "com.birdkingdom.vip.lifetime"
        ]
        
        guard validProductIds.contains(productId) || productId.hasPrefix("com.birdkingdom.") else {
            logger.warning("⚠️ 无效的产品 ID: \(productId)")
            return TransactionVerificationResult(
                isValid: false,
                originalTransactionId: originalTransactionId,
                productId: productId,
                purchaseDate: nil,
                expiresDate: nil,
                status: .invalidProductId,
                message: "无效的产品 ID"
            )
        }
        
        // 在生产环境中，这里应该调用 App Store Server API
        // 使用 App Store Server API 的 Get Transaction History 或 Look Up Order ID
        // 由于需要配置 JWT 签名等复杂逻辑，这里提供一个简化版本
        
        // 生产环境需接入 App Store Server API，当前为简化开发模式
        // 信任客户端传递的信息
        logger.info("✅ 交易验证通过（简化模式）: \(originalTransactionId)")
        
        return TransactionVerificationResult(
            isValid: true,
            originalTransactionId: originalTransactionId,
            productId: productId,
            purchaseDate: Date(),
            expiresDate: calculateExpireDate(productId: productId),
            status: .verified,
            message: "验证成功"
        )
    }
    
    /// 验证恢复购买的交易
    /// - Parameters:
    ///   - transactions: 客户端传递的交易信息数组
    ///   - client: HTTP 客户端
    /// - Returns: 验证结果列表
    func verifyRestoredTransactions(
        transactions: [[String: Any]],
        client: Client,
        logger: Logger
    ) async -> [TransactionVerificationResult] {
        var results: [TransactionVerificationResult] = []
        
        for transaction in transactions {
            guard let originalTransactionId = transaction["originalTransactionId"] as? String,
                  let productId = transaction["productId"] as? String else {
                continue
            }
            
            let result = await verifyTransaction(
                originalTransactionId: originalTransactionId,
                productId: productId,
                client: client,
                logger: logger
            )
            results.append(result)
        }
        
        return results
    }
    
    // MARK: - 辅助方法
    
    /// 根据产品 ID 计算过期时间
    private func calculateExpireDate(productId: String) -> Date? {
        let now = Date()
        let calendar = Calendar.current
        
        if productId.contains("monthly") {
            return calendar.date(byAdding: .month, value: 1, to: now)
        } else if productId.contains("yearly") {
            return calendar.date(byAdding: .year, value: 1, to: now)
        } else if productId.contains("lifetime") {
            // 终身会员，设置为 100 年后
            return calendar.date(byAdding: .year, value: 100, to: now)
        }
        
        // 默认 1 个月
        return calendar.date(byAdding: .month, value: 1, to: now)
    }
}

// MARK: - 交易验证结果
struct TransactionVerificationResult {
    let isValid: Bool
    let originalTransactionId: String
    let productId: String
    let purchaseDate: Date?
    let expiresDate: Date?
    let status: TransactionStatus
    let message: String
}

enum TransactionStatus {
    case verified
    case expired
    case refunded
    case invalidProductId
    case invalidReceipt
    case networkError
    case unknown
}
