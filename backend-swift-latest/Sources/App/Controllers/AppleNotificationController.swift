import Vapor
import Fluent

/// 苹果服务器通知接收接口
/// 用于接收App Store Server Notifications V2
struct AppleNotificationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let apple = routes.grouped("apple")
        
        // 接收苹果服务器通知
        apple.post("notifications", use: receiveNotification)
        
        // 测试接口
        apple.post("notifications", "test", use: testNotification)
    }
    
    // MARK: - 接收苹果服务器通知
    @Sendable
    func receiveNotification(req: Request) async throws -> HTTPStatus {
        struct NotificationPayload: Content {
            let signedPayload: String?
        }
        
        do {
            let payload = try req.content.decode(NotificationPayload.self)
            
            guard let signedPayload = payload.signedPayload, !signedPayload.isEmpty else {
                req.logger.warning("⚠️ 苹果通知：signedPayload为空")
                return .badRequest
            }
            
            // 处理通知
            try await processNotification(signedPayload: signedPayload, db: req.db, logger: req.logger)
            
            return .ok
        } catch {
            req.logger.error("❌ 处理苹果通知失败: \(error.localizedDescription)")
            // 即使处理失败也返回200，避免苹果重复发送
            return .ok
        }
    }
    
    // MARK: - 测试接口
    @Sendable
    func testNotification(req: Request) async throws -> AppleNotificationResponse {
        struct TestPayload: Content {
            let transactionId: String?
            let notificationType: String?
        }
        
        let payload = try req.content.decode(TestPayload.self)
        
        guard let transactionId = payload.transactionId else {
            return AppleNotificationResponse(success: false, message: "缺少 transactionId")
        }
        
        if payload.notificationType == "REFUND" {
            // 处理退款
            try await processRefund(transactionId: transactionId, db: req.db, logger: req.logger)
            return AppleNotificationResponse(success: true, message: "退款处理成功")
        }
        
        return AppleNotificationResponse(success: false, message: "未知通知类型")
    }
    
    // MARK: - 处理通知
    private func processNotification(signedPayload: String, db: Database, logger: Logger) async throws {
        // 解析 JWS 格式的 payload
        logger.info("📱 收到苹果通知: \(signedPayload.prefix(50))...")
    }
    
    // MARK: - 处理退款
    private func processRefund(transactionId: String, db: Database, logger: Logger) async throws {
        logger.info("💰 处理退款: \(transactionId)")
    }
}

// MARK: - DTO
struct AppleNotificationResponse: Content {
    let success: Bool
    let message: String
}

// MARK: - 苹果购买记录模型
final class ApplePurchaseRecord: Model, Content, @unchecked Sendable {
    static let schema = "apple_purchase_records"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "original_transaction_id")
    var originalTransactionId: String
    
    @Field(key: "product_id")
    var productId: String
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Field(key: "phone")
    var phone: String
    
    @Field(key: "purchase_date")
    var purchaseDate: Date
    
    @Field(key: "expire_date")
    var expireDate: Date
    
    @Field(key: "order_status")
    var orderStatus: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, originalTransactionId: String, productId: String, 
         userId: Int64, phone: String, purchaseDate: Date, expireDate: Date, 
         orderStatus: String = "VALID") {
        self.id = id
        self.originalTransactionId = originalTransactionId
        self.productId = productId
        self.userId = userId
        self.phone = phone
        self.purchaseDate = purchaseDate
        self.expireDate = expireDate
        self.orderStatus = orderStatus
    }
}

