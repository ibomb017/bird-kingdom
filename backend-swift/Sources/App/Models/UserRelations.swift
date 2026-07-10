import Fluent
import Vapor

/// 用户关注模型
final class UserFollow: Model, Content, @unchecked Sendable {
    static let schema = "user_follows"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "follower_id")
    var followerId: Int64
    
    @Field(key: "following_id")
    var followingId: Int64
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, followerId: Int64, followingId: Int64) {
        self.id = id
        self.followerId = followerId
        self.followingId = followingId
    }
}

// MARK: - 数据库迁移
struct CreateUserFollow: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(UserFollow.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("follower_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("following_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "follower_id", "following_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(UserFollow.schema).delete()
    }
}

/// 用户拉黑模型
final class UserBlock: Model, Content, @unchecked Sendable {
    static let schema = "user_blocks"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "blocker_id")
    var blockerId: Int64
    
    @Field(key: "blocked_id")
    var blockedId: Int64
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, blockerId: Int64, blockedId: Int64) {
        self.id = id
        self.blockerId = blockerId
        self.blockedId = blockedId
    }
}

// MARK: - 数据库迁移
struct CreateUserBlock: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(UserBlock.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("blocker_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("blocked_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "blocker_id", "blocked_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(UserBlock.schema).delete()
    }
}

/// 验证码模型
final class VerificationCode: Model, Content, @unchecked Sendable {
    static let schema = "verification_codes"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "phone")
    var phone: String
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "expire_at")
    var expireAt: Date
    
    @Field(key: "used")
    var used: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {
        self.used = false
    }
    
    init(id: Int64? = nil, phone: String, code: String, expireAt: Date) {
        self.id = id
        self.phone = phone
        self.code = code
        self.expireAt = expireAt
        self.used = false
    }
    
    /// 验证码是否有效
    var isValid: Bool {
        !used && expireAt > Date()
    }
}

// MARK: - 数据库迁移
struct CreateVerificationCode: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(VerificationCode.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("phone", .string, .required)
            .field("code", .string, .required)
            .field("expire_at", .datetime, .required)
            .field("used", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(VerificationCode.schema).delete()
    }
}
