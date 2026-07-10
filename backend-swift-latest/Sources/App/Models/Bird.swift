import Fluent
import Vapor

/// 鸟儿模型
final class Bird: Model, Content, @unchecked Sendable {
    static let schema = "birds"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "nickname")
    var nickname: String
    
    @Field(key: "species")
    var species: String
    
    @OptionalField(key: "gender")
    var gender: String?
    
    @OptionalField(key: "hatch_date")
    var hatchDate: Date?
    
    @OptionalField(key: "adoption_date")
    var adoptionDate: Date?
    
    @OptionalField(key: "birthday_type")
    var birthdayType: String?
    
    @OptionalField(key: "death_date")
    var deathDate: Date?
    
    @OptionalField(key: "feather_color")
    var featherColor: String?
    
    @OptionalField(key: "avatar_url")
    var avatarUrl: String?
    
    @OptionalField(key: "source")
    var source: String?
    
    @OptionalField(key: "father_info")
    var fatherInfo: String?
    
    @OptionalField(key: "mother_info")
    var motherInfo: String?
    
    @OptionalField(key: "leg_ring_id")
    var legRingId: String?
    
    @OptionalField(key: "notes")
    var notes: String?
    
    @OptionalField(key: "medical_history")
    var medicalHistory: String?
    
    @Field(key: "is_deleted")
    var isDeleted: Bool
    
    @OptionalField(key: "deleted_at")
    var deletedAt: Date?
    
    @Field(key: "is_lost")
    var isLost: Bool
    
    @OptionalField(key: "lost_date")
    var lostDate: Date?
    
    @OptionalField(key: "lost_location")
    var lostLocation: String?
    
    @OptionalField(key: "lost_post_id")
    var lostPostId: Int64?
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Field(key: "version")
    var version: Int64
    
    init() {
        self.isDeleted = false
        self.isLost = false
        self.version = 0
    }
    
    init(
        id: Int64? = nil,
        nickname: String,
        species: String,
        gender: String? = nil,
        hatchDate: Date? = nil,
        adoptionDate: Date? = nil,
        birthdayType: String? = nil,
        featherColor: String? = nil,
        source: String? = nil,
        fatherInfo: String? = nil,
        motherInfo: String? = nil,
        legRingId: String? = nil,
        avatarUrl: String? = nil,
        notes: String? = nil,
        medicalHistory: String? = nil,
        userId: Int64
    ) {
        self.id = id
        self.nickname = nickname
        self.species = species
        self.gender = gender
        self.hatchDate = hatchDate
        self.adoptionDate = adoptionDate
        self.birthdayType = birthdayType
        self.featherColor = featherColor
        self.source = source
        self.fatherInfo = fatherInfo
        self.motherInfo = motherInfo
        self.legRingId = legRingId
        self.avatarUrl = avatarUrl
        self.notes = notes
        self.medicalHistory = medicalHistory
        self.userId = userId
        self.isDeleted = false
        self.isLost = false
        self.version = 0
    }
}

// MARK: - 数据库迁移
struct CreateBird: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Bird.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("nickname", .string, .required)
            .field("species", .string, .required)
            .field("gender", .string)
            .field("hatch_date", .date)
            .field("adoption_date", .date)
            .field("birthday_type", .string)
            .field("feather_color", .string)
            .field("source", .string)
            .field("father_info", .string)
            .field("mother_info", .string)
            .field("leg_ring_id", .string)
            .field("avatar_url", .string)
            .field("notes", .sql(raw: "TEXT"))
            .field("medical_history", .sql(raw: "TEXT"))
            .field("death_date", .date)
            .field("is_deleted", .bool, .required, .sql(.default(false)))
            .field("deleted_at", .datetime)
            .field("is_lost", .bool, .required, .sql(.default(false)))
            .field("lost_date", .date)
            .field("lost_location", .string)
            .field("lost_post_id", .int64)
            .field("user_id", .int64)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("version", .int64, .required, .sql(.default(0)))
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(Bird.schema).delete()
    }
}
