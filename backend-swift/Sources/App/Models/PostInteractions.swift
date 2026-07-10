import Fluent
import Vapor

/// 帖子点赞模型
final class PostLike: Model, Content, @unchecked Sendable {
    static let schema = "post_likes"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "post_id")
    var postId: Int64
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, postId: Int64, userId: Int64) {
        self.id = id
        self.postId = postId
        self.userId = userId
    }
}

// MARK: - 数据库迁移
struct CreatePostLike: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(PostLike.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("post_id", .int64, .required, .references(ForumPost.schema, "id", onDelete: .cascade))
            .field("user_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "post_id", "user_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(PostLike.schema).delete()
    }
}

/// 帖子收藏模型
final class PostFavorite: Model, Content, @unchecked Sendable {
    static let schema = "post_favorites"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "post_id")
    var postId: Int64
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, postId: Int64, userId: Int64) {
        self.id = id
        self.postId = postId
        self.userId = userId
    }
}

// MARK: - 数据库迁移
struct CreatePostFavorite: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(PostFavorite.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("post_id", .int64, .required, .references(ForumPost.schema, "id", onDelete: .cascade))
            .field("user_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "post_id", "user_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(PostFavorite.schema).delete()
    }
}

/// 帖子举报模型
final class PostReport: Model, Content, @unchecked Sendable {
    static let schema = "post_reports"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "post_id")
    var postId: Int64
    
    @Field(key: "reporter_id")
    var reporterId: Int64
    
    @Field(key: "report_type")
    var reportType: String
    
    @Field(key: "reason")
    var reason: String
    
    @Field(key: "description")
    var description: String?
    
    @Field(key: "status")
    var status: String
    
    @Field(key: "review_note")
    var reviewNote: String?
    
    @Field(key: "reviewer_id")
    var reviewerId: Int64?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Field(key: "reviewed_at")
    var reviewedAt: Date?
    
    init() {
        self.reportType = "OTHER"
        self.status = "PENDING"
    }
    
    init(
        id: Int64? = nil,
        postId: Int64,
        reporterId: Int64,
        reportType: String = "OTHER",
        reason: String,
        description: String? = nil
    ) {
        self.id = id
        self.postId = postId
        self.reporterId = reporterId
        self.reportType = reportType
        self.reason = reason
        self.description = description
        self.status = "PENDING"
    }
}

// MARK: - 数据库迁移
struct CreatePostReport: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(PostReport.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("post_id", .int64, .required, .references(ForumPost.schema, "id", onDelete: .cascade))
            .field("reporter_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("report_type", .string, .required, .sql(.default("OTHER")))
            .field("reason", .string, .required)
            .field("description", .string)
            .field("status", .string, .required, .sql(.default("PENDING")))
            .field("review_note", .string)
            .field("reviewer_id", .int64)
            .field("created_at", .datetime)
            .field("reviewed_at", .datetime)
            .unique(on: "post_id", "reporter_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(PostReport.schema).delete()
    }
}

/// 评论点赞模型
final class CommentLike: Model, Content, @unchecked Sendable {
    static let schema = "comment_likes"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "comment_id")
    var commentId: Int64
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, commentId: Int64, userId: Int64) {
        self.id = id
        self.commentId = commentId
        self.userId = userId
    }
}

