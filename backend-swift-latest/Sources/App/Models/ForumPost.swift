import Fluent
import Vapor

/// 论坛帖子模型
final class ForumPost: Model, Content, @unchecked Sendable {
    static let schema = "forum_posts"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "author_id")
    var authorId: Int64
    
    @Field(key: "content")
    var content: String
    
    @OptionalField(key: "post_type")
    var postType: String?
    
    @OptionalField(key: "media_type")
    var mediaType: String?
    
    @OptionalField(key: "video_url")
    var videoUrl: String?
    
    @OptionalField(key: "video_cover")
    var videoCover: String?
    
    @OptionalField(key: "video_duration")
    var videoDuration: Int?
    
    @Field(key: "like_count")
    var likeCount: Int
    
    @Field(key: "comment_count")
    var commentCount: Int
    
    @Field(key: "view_count")
    var viewCount: Int
    
    @OptionalField(key: "latitude")
    var latitude: Double?
    
    @OptionalField(key: "longitude")
    var longitude: Double?
    
    @OptionalField(key: "location_name")
    var locationName: String?
    
    @OptionalField(key: "bird_id")
    var birdId: Int64?
    
    @OptionalField(key: "bird_ids")
    var birdIds: String?
    
    @OptionalField(key: "birds_info")
    var birdsInfo: String?
    
    @OptionalField(key: "bird_name")
    var birdName: String?
    
    @OptionalField(key: "bird_species")
    var birdSpecies: String?
    
    @OptionalField(key: "bird_avatar")
    var birdAvatar: String?
    
    @OptionalField(key: "lost_location")
    var lostLocation: String?
    
    @OptionalField(key: "contact_phone")
    var contactPhone: String?
    
    @OptionalField(key: "reward")
    var reward: String?
    
    @OptionalField(key: "is_found")
    var isFound: Bool?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {
        self.postType = "NORMAL"
        self.mediaType = "IMAGE"
        self.likeCount = 0
        self.commentCount = 0
        self.viewCount = 0
        self.isFound = false
    }
    
    init(
        id: Int64? = nil,
        authorId: Int64,
        content: String,
        postType: String = "NORMAL",
        mediaType: String = "IMAGE",
        videoUrl: String? = nil,
        videoCover: String? = nil,
        videoDuration: Int? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        birdId: Int64? = nil,
        birdIds: String? = nil,
        birdsInfo: String? = nil,
        birdName: String? = nil,
        birdSpecies: String? = nil,
        birdAvatar: String? = nil,
        lostLocation: String? = nil,
        contactPhone: String? = nil,
        reward: String? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.content = content
        self.postType = postType
        self.mediaType = mediaType
        self.videoUrl = videoUrl
        self.videoCover = videoCover
        self.videoDuration = videoDuration
        self.likeCount = 0
        self.commentCount = 0
        self.viewCount = 0
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.birdId = birdId
        self.birdIds = birdIds
        self.birdsInfo = birdsInfo
        self.birdName = birdName
        self.birdSpecies = birdSpecies
        self.birdAvatar = birdAvatar
        self.lostLocation = lostLocation
        self.contactPhone = contactPhone
        self.reward = reward
        self.isFound = false
    }
}

// MARK: - 数据库迁移
struct CreateForumPost: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ForumPost.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("author_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("content", .sql(raw: "TEXT"), .required)
            .field("post_type", .string, .required, .sql(.default("NORMAL")))
            .field("media_type", .string, .required, .sql(.default("IMAGE")))
            .field("video_url", .string)
            .field("video_cover", .string)
            .field("video_duration", .int)
            .field("like_count", .int, .required, .sql(.default(0)))
            .field("comment_count", .int, .required, .sql(.default(0)))
            .field("view_count", .int, .required, .sql(.default(0)))
            .field("latitude", .double)
            .field("longitude", .double)
            .field("location_name", .string)
            .field("bird_id", .int64)
            .field("bird_ids", .string)
            .field("birds_info", .string)
            .field("bird_name", .string)
            .field("bird_species", .string)
            .field("bird_avatar", .string)
            .field("lost_location", .string)
            .field("contact_phone", .string)
            .field("reward", .string)
            .field("is_found", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(ForumPost.schema).delete()
    }
}
