import Fluent
import Vapor

/// 用户模型
final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "phone")
    var phone: String
    
    @OptionalField(key: "password")
    var password: String?
    
    @Field(key: "nickname")
    var nickname: String
    
    @OptionalField(key: "avatar_url")
    var avatarUrl: String?
    
    @OptionalField(key: "bio")
    var bio: String?
    
    @OptionalField(key: "is_vip")
    var isVip: Bool?
    
    @OptionalField(key: "vip_type")
    var vipType: String?
    
    @OptionalField(key: "vip_expire_date")
    var vipExpireDate: Date?
    
    @OptionalField(key: "is_couple_vip")
    var isCoupleVip: Bool?
    
    @OptionalField(key: "couple_partner_id")
    var couplePartnerId: Int64?
    
    @OptionalField(key: "pending_couple_phone")
    var pendingCouplePhone: String?
    
    @OptionalField(key: "pending_couple_invitation_from")
    var pendingCoupleInvitationFrom: Int64?
    
    @OptionalField(key: "role")
    var role: String?
    
    @OptionalField(key: "is_disabled")
    var isDisabled: Bool?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(
        id: Int64? = nil,
        phone: String,
        password: String? = nil,
        nickname: String,
        avatarUrl: String? = nil,
        bio: String? = nil,
        isVip: Bool = false,
        vipType: String? = nil,
        vipExpireDate: Date? = nil,
        isCoupleVip: Bool = false,
        couplePartnerId: Int64? = nil,
        pendingCouplePhone: String? = nil,
        pendingCoupleInvitationFrom: Int64? = nil,
        role: String = "USER"
    ) {
        self.id = id
        self.phone = phone
        self.password = password
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.isVip = isVip
        self.vipType = vipType
        self.vipExpireDate = vipExpireDate
        self.isCoupleVip = isCoupleVip
        self.couplePartnerId = couplePartnerId
        self.pendingCouplePhone = pendingCouplePhone
        self.pendingCoupleInvitationFrom = pendingCoupleInvitationFrom
        self.role = role
    }
    
    /// 是否是管理员
    var isAdmin: Bool {
        role == "ADMIN"
    }
    
    /// 获取角色，默认为 USER
    var safeRole: String {
        role ?? "USER"
    }
}

// MARK: - 数据库迁移
struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("phone", .string, .required)
            .field("password", .string)
            .field("nickname", .string, .required)
            .field("avatar_url", .string)
            .field("bio", .string)
            .field("is_vip", .bool, .required, .sql(.default(false)))
            .field("vip_type", .string)
            .field("vip_expire_date", .datetime)
            .field("is_couple_vip", .bool, .required, .sql(.default(false)))
            .field("couple_partner_id", .int64)
            .field("pending_couple_phone", .string)
            .field("pending_couple_invitation_from", .int64)
            .field("role", .string, .required, .sql(.default("USER")))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "phone")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
}
