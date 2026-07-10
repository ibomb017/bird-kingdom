import Fluent
import Vapor

/// 用户行为类型枚举
enum UserBehaviorType: String, Codable {
    case view = "VIEW"           // 浏览帖子
    case like = "LIKE"           // 点赞
    case unlike = "UNLIKE"       // 取消点赞
    case favorite = "FAVORITE"   // 收藏
    case unfavorite = "UNFAVORITE" // 取消收藏
    case comment = "COMMENT"     // 评论
    case share = "SHARE"         // 分享
    case search = "SEARCH"       // 搜索
    case follow = "FOLLOW"       // 关注用户
    case unfollow = "UNFOLLOW"   // 取消关注
    case create = "CREATE"       // 发布内容
}

/// 用户行为记录模型
/// 用于记录用户在平台上的所有互动行为，支撑个性化推荐
final class UserBehavior: Model, Content, @unchecked Sendable {
    static let schema = "user_behaviors"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    /// 用户ID
    @Field(key: "user_id")
    var userId: Int64
    
    /// 行为类型
    @Field(key: "behavior_type")
    var behaviorType: String
    
    /// 目标类型（POST, USER, COMMENT 等）
    @OptionalField(key: "target_type")
    var targetType: String?
    
    /// 目标ID（帖子ID、用户ID等）
    @OptionalField(key: "target_id")
    var targetId: Int64?
    
    /// 相关内容（搜索关键词、评论内容等）
    @OptionalField(key: "content")
    var content: String?
    
    /// 相关元数据（JSON格式，存储额外信息）
    @OptionalField(key: "metadata")
    var metadata: String?
    
    /// 浏览时长（秒）- 针对 VIEW 行为
    @OptionalField(key: "duration")
    var duration: Int?
    
    /// 鸟品种（用于兴趣分析）
    @OptionalField(key: "bird_species")
    var birdSpecies: String?
    
    /// 帖子类型（用于内容偏好分析）
    @OptionalField(key: "post_type")
    var postType: String?
    
    /// 位置信息
    @OptionalField(key: "latitude")
    var latitude: Double?
    
    @OptionalField(key: "longitude")
    var longitude: Double?
    
    /// 设备信息
    @OptionalField(key: "device_type")
    var deviceType: String?
    
    /// 客户端版本
    @OptionalField(key: "app_version")
    var appVersion: String?
    
    /// 创建时间
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(
        id: Int64? = nil,
        userId: Int64,
        behaviorType: UserBehaviorType,
        targetType: String? = nil,
        targetId: Int64? = nil,
        content: String? = nil,
        metadata: String? = nil,
        duration: Int? = nil,
        birdSpecies: String? = nil,
        postType: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        deviceType: String? = nil,
        appVersion: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.behaviorType = behaviorType.rawValue
        self.targetType = targetType
        self.targetId = targetId
        self.content = content
        self.metadata = metadata
        self.duration = duration
        self.birdSpecies = birdSpecies
        self.postType = postType
        self.latitude = latitude
        self.longitude = longitude
        self.deviceType = deviceType
        self.appVersion = appVersion
    }
}

// MARK: - 数据库迁移
struct CreateUserBehavior: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(UserBehavior.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("user_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("behavior_type", .string, .required)
            .field("target_type", .string)
            .field("target_id", .int64)
            .field("content", .sql(raw: "TEXT"))
            .field("metadata", .sql(raw: "TEXT"))
            .field("duration", .int)
            .field("bird_species", .string)
            .field("post_type", .string)
            .field("latitude", .double)
            .field("longitude", .double)
            .field("device_type", .string)
            .field("app_version", .string)
            .field("created_at", .datetime)
            // 索引优化查询性能
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(UserBehavior.schema).delete()
    }
}

// MARK: - 搜索日志模型
/// 搜索日志，用于分析热门搜索和改进搜索质量
final class SearchLog: Model, Content, @unchecked Sendable {
    static let schema = "search_logs"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    /// 用户ID（匿名搜索时可为空）
    @OptionalField(key: "user_id")
    var userId: Int64?
    
    /// 搜索关键词
    @Field(key: "keyword")
    var keyword: String
    
    /// 搜索结果数量
    @OptionalField(key: "result_count")
    var resultCount: Int?
    
    /// 用户是否点击了结果
    @OptionalField(key: "has_clicked")
    var hasClicked: Bool?
    
    /// 点击的帖子ID
    @OptionalField(key: "clicked_post_id")
    var clickedPostId: Int64?
    
    /// 搜索场景（home, explore, profile等）
    @OptionalField(key: "scene")
    var scene: String?
    
    /// 搜索耗时（毫秒）
    @OptionalField(key: "search_duration_ms")
    var searchDurationMs: Int?
    
    /// IP地址（用于地域分析）
    @OptionalField(key: "ip_address")
    var ipAddress: String?
    
    /// 创建时间
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(
        id: Int64? = nil,
        userId: Int64? = nil,
        keyword: String,
        resultCount: Int? = nil,
        hasClicked: Bool? = nil,
        clickedPostId: Int64? = nil,
        scene: String? = nil,
        searchDurationMs: Int? = nil,
        ipAddress: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.keyword = keyword
        self.resultCount = resultCount
        self.hasClicked = hasClicked
        self.clickedPostId = clickedPostId
        self.scene = scene
        self.searchDurationMs = searchDurationMs
        self.ipAddress = ipAddress
    }
}

// MARK: - 搜索日志迁移
struct CreateSearchLog: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(SearchLog.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("user_id", .int64)
            .field("keyword", .string, .required)
            .field("result_count", .int)
            .field("has_clicked", .bool)
            .field("clicked_post_id", .int64)
            .field("scene", .string)
            .field("search_duration_ms", .int)
            .field("ip_address", .string)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(SearchLog.schema).delete()
    }
}

// MARK: - 用户兴趣画像
/// 用户兴趣画像（定期聚合计算）
final class UserInterest: Model, Content, @unchecked Sendable {
    static let schema = "user_interests"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    /// 用户ID
    @Field(key: "user_id")
    var userId: Int64
    
    /// 兴趣类型（bird_species, post_type, author等）
    @Field(key: "interest_type")
    var interestType: String
    
    /// 兴趣值（具体的品种名、帖子类型等）
    @Field(key: "interest_value")
    var interestValue: String
    
    /// 兴趣分数（0-100）
    @Field(key: "score")
    var score: Double
    
    /// 最近更新时间
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    /// 创建时间
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(
        id: Int64? = nil,
        userId: Int64,
        interestType: String,
        interestValue: String,
        score: Double
    ) {
        self.id = id
        self.userId = userId
        self.interestType = interestType
        self.interestValue = interestValue
        self.score = score
    }
}

// MARK: - 用户兴趣迁移
struct CreateUserInterest: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(UserInterest.schema)
            .field("id", .int64, .identifier(auto: true))
            .field("user_id", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
            .field("interest_type", .string, .required)
            .field("interest_value", .string, .required)
            .field("score", .double, .required)
            .field("updated_at", .datetime)
            .field("created_at", .datetime)
            // 唯一约束：每个用户每种兴趣类型+值只有一条记录
            .unique(on: "user_id", "interest_type", "interest_value")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema(UserInterest.schema).delete()
    }
}
