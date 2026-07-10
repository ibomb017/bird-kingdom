import Fluent
import Vapor

/// 帖子图片模型
final class PostImage: Model, Content, @unchecked Sendable {
    static let schema = "post_images"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "post_id")
    var postId: Int64
    
    @Field(key: "image_url")
    var imageUrl: String
    
    @OptionalField(key: "sort_order")
    var sortOrder: Int?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, postId: Int64, imageUrl: String, sortOrder: Int? = 0) {
        self.id = id
        self.postId = postId
        self.imageUrl = imageUrl
        self.sortOrder = sortOrder
    }
}

// MARK: - 数据库迁移
struct CreatePostImage: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(PostImage.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("post_id", .int64, .required, .references(ForumPost.schema, "id", onDelete: .cascade))
            .field("image_url", .string, .required)
            .field("sort_order", .int, .required, .sql(.default(0)))
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(PostImage.schema).delete()
    }
}
