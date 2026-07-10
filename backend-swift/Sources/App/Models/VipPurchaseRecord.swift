import Vapor
import Fluent

/// VIP 购买记录
/// 用于防止同一笔 Apple 交易被恢复到多个账号
final class VipPurchaseRecord: Model, Content, @unchecked Sendable {
    static let schema = "vip_purchase_record"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Field(key: "original_transaction_id")
    var originalTransactionId: String
    
    @Field(key: "product_id")
    var productId: String
    
    @Field(key: "purchase_date")
    var purchaseDate: Date
    
    @OptionalField(key: "expires_date")
    var expiresDate: Date?
    
    @OptionalField(key: "verification_status")
    var verificationStatus: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(
        id: Int64? = nil,
        userId: Int64,
        originalTransactionId: String,
        productId: String,
        purchaseDate: Date,
        expiresDate: Date? = nil,
        verificationStatus: String? = "verified"
    ) {
        self.id = id
        self.userId = userId
        self.originalTransactionId = originalTransactionId
        self.productId = productId
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.verificationStatus = verificationStatus
    }
}
