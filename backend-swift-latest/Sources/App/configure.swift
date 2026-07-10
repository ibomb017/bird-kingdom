import Fluent
import FluentMySQLDriver
import Vapor
import JWT

/// 配置 Vapor 应用
func configure(_ app: Application) async throws {
    // MARK: - JSON 日期格式配置（使用 ISO 8601，iOS 原生支持）
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)
    
    // 设置日志级别
    app.logger.logLevel = .info
    
    // MARK: - 服务器配置
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "0.0.0.0"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080
    
    // MARK: - 文件上传配置
    // 最大请求体大小 200MB
    app.routes.defaultMaxBodySize = "200mb"
    
    // MARK: - 数据库配置
    let dbHost = Environment.get("DB_HOST") ?? "localhost"
    let dbPort = Environment.get("DB_PORT").flatMap(Int.init) ?? 3306
    let dbUsername = Environment.get("DB_USERNAME") ?? "root"
    let dbPassword = Environment.get("DB_PASSWORD") ?? ""
    let dbName = Environment.get("DB_NAME") ?? "bird_kingdom"
    
    var tlsConfig: TLSConfiguration? = nil
    if Environment.get("DB_USE_SSL") == "true" {
        tlsConfig = .makeClientConfiguration()
    }
    
    app.databases.use(
        .mysql(
            hostname: dbHost,
            port: dbPort,
            username: dbUsername,
            password: dbPassword,
            database: dbName,
            tlsConfiguration: tlsConfig
        ),
        as: .mysql
    )
    
    // MARK: - JWT 配置
    let jwtSecret = Environment.get("JWT_SECRET") ?? "your-super-secret-key-change-in-production"
    app.jwt.signers.use(.hs256(key: jwtSecret))
    
    // MARK: - 中间件配置
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )))
    
    // MARK: - 数据库迁移
    // 注意：数据库表已由 Java 后端创建，跳过迁移
    // 如果是全新数据库，取消下面两行的注释
    // try await configureMigrations(app)
    // try await app.autoMigrate()
    
    // MARK: - 路由配置
    try routes(app)
    
    app.logger.info("🐦 Bird Kingdom Swift Server started on \(app.http.server.configuration.hostname):\(app.http.server.configuration.port)")
}

/// 配置数据库迁移
func configureMigrations(_ app: Application) async throws {
    // 按依赖顺序添加迁移
    app.migrations.add(CreateUser())
    app.migrations.add(CreateBird())
    app.migrations.add(CreateForumPost())
    app.migrations.add(CreatePostImage())
    app.migrations.add(CreatePostComment())
    app.migrations.add(CreatePostLike())
    app.migrations.add(CreatePostFavorite())
    app.migrations.add(CreatePostReport())
    app.migrations.add(CreateUserFollow())
    app.migrations.add(CreateUserBlock())
    app.migrations.add(CreateVerificationCode())
    
    // 用户行为分析相关表
    app.migrations.add(CreateUserBehavior())
    app.migrations.add(CreateSearchLog())
    app.migrations.add(CreateUserInterest())
}
