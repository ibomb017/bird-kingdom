import Fluent
import Vapor

/// 帖子评论模型
final class PostComment: Model, Content, @unchecked Sendable {
    static let schema = "post_comments"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "post_id")
    var postId: Int64
    
    @Field(key: "author_id")
    var authorId: Int64
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Field(key: "content")
    var content: String
    
    @OptionalField(key: "parent_id")
    var parentId: Int64?
    
    @OptionalField(key: "reply_to_user_id")
    var replyToUserId: Int64?
    
    @OptionalField(key: "like_count")
    var likeCount: Int?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(
        id: Int64? = nil,
        postId: Int64,
        authorId: Int64,
        content: String,
        parentId: Int64? = nil,
        replyToUserId: Int64? = nil
    ) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.userId = authorId // user_id 和 author_id 相同
        self.content = content
        self.parentId = parentId
        self.replyToUserId = replyToUserId
        self.likeCount = 0
    }
}

// MARK: - 数据库迁移
struct CreatePostComment: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(PostComment.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("post_id", .int64, .required, .references(ForumPost.schema, "id", onDelete: .cascade))
            .field("author_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("content", .sql(raw: "TEXT"), .required)
            .field("parent_id", .int64)
            .field("like_count", .int, .required, .sql(.default(0)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(PostComment.schema).delete()
    }
}
