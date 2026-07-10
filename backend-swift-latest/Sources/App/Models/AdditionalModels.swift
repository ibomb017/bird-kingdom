import Fluent
import Vapor

// MARK: - 鸟儿分享模型
final class BirdShare: Model, Content, @unchecked Sendable {
    static let schema = "bird_shares"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "bird_id")
    var birdId: Int64
    
    @Field(key: "owner_id")
    var ownerId: Int64
    
    @Field(key: "shared_user_id")
    var sharedUserId: Int64
    
    @OptionalField(key: "role")
    var role: String?
    
    @OptionalField(key: "status")
    var status: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, birdId: Int64, ownerId: Int64, sharedUserId: Int64, 
         role: String? = "VIEWER", status: String? = "PENDING") {
        self.id = id
        self.birdId = birdId
        self.ownerId = ownerId
        self.sharedUserId = sharedUserId
        self.role = role
        self.status = status
    }
}

// MARK: - 颜色基因模型
final class ColorGene: Model, Content, @unchecked Sendable {
    static let schema = "color_genes"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "name")
    var name: String
    
    @OptionalField(key: "code")
    var code: String?
    
    @OptionalField(key: "display_color")
    var displayColor: String?
    
    @OptionalField(key: "is_dominant")
    var isDominant: Bool?
    
    @OptionalField(key: "description")
    var description: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, name: String, code: String? = nil, 
         displayColor: String? = nil, isDominant: Bool? = false, description: String? = nil) {
        self.id = id
        self.name = name
        self.code = code
        self.displayColor = displayColor
        self.isDominant = isDominant
        self.description = description
    }
}

// MARK: - 幂等键模型（用于防止重复请求）
final class IdempotencyKey: Model, Content, @unchecked Sendable {
    static let schema = "idempotency_keys"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "key")
    var key: String
    
    @OptionalField(key: "response")
    var response: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "expires_at", on: .none)
    var expiresAt: Date?
    
    init() {}
}
