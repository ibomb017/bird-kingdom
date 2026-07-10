import Vapor

/// 注册所有路由
func routes(_ app: Application) throws {
    // 健康检查
    app.get("health") { req async -> String in
        "OK"
    }
    
    // API 版本信息
    app.get("api") { req async -> [String: String] in
        [
            "name": "Bird Kingdom API",
            "version": "1.0.0",
            "framework": "Vapor (Swift)"
        ]
    }
    
    // MARK: - 非 API 路由（直接挂在根路径）
    
    // 分享页面（/share/post/:id）
    try app.register(collection: SharePageController())
    
    // 静态页面（/privacy, /terms）
    try app.register(collection: StaticPageController())
    
    // Well-Known 文件（Universal Links）
    try app.register(collection: WellKnownController())
    
    // MARK: - API 路由组
    let api = app.grouped("api")
    
    // 认证相关路由
    try api.register(collection: AuthController())
    
    // 用户相关路由
    try api.register(collection: UserController())
    
    // 论坛/广场相关路由
    try api.register(collection: ForumController())
    
    // 鸟儿相关路由
    try api.register(collection: BirdController())
    
    // 日志相关路由
    try api.register(collection: BirdLogController())
    
    // 记录相关路由（产蛋/洗澡）
    try api.register(collection: BirdRecordController())
    
    // 支出相关路由
    try api.register(collection: ExpenseController())
    
    // 提醒相关路由
    try api.register(collection: ReminderController())
    
    // 通知相关路由
    try api.register(collection: NotificationController())
    
    // 百科相关路由（食物、鸟类、症状）
    try api.register(collection: EncyclopediaController())
    
    // 开屏展示系统路由
    try api.register(collection: SplashController())
    
    // 反馈相关路由
    try api.register(collection: FeedbackController())
    
    // 共享邀请相关路由
    try api.register(collection: InvitationController())
    
    // 品种相关路由
    try api.register(collection: ParrotSpeciesController())
    
    // AI 代理路由
    try api.register(collection: AIProxyController())
    
    // Apple 通知路由
    try api.register(collection: AppleNotificationController())
    
    // 上传相关路由
    try api.register(collection: UploadController())
    
    // 举报和拉黑相关路由
    try api.register(collection: ReportBlockController())
    
    // 统计相关路由
    try api.register(collection: StatsController())
    
    // 系统配置相关路由
    try api.register(collection: SystemController())
    
    // MARK: - 内部 API（不需要认证）
    
    // 短信代理（内部使用）
    try app.register(collection: SmsProxyController())
}

