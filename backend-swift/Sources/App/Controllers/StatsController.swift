import Vapor
import Fluent
import SQLKit

/// 统计数据控制器 (Real Data 版本)
struct StatsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let stats = routes.grouped("stats")
        // 只允许管理员访问
        let protected = stats.grouped(JWTAuthMiddleware(), StatsAdminMiddleware())
        
        protected.get("dashboard", use: getDashboardStats)
        protected.get("todos", use: getTodos)
        protected.get("user-trend", use: getUserTrend)
        protected.get("post-distribution", use: getPostDistribution)
        protected.get("vip-conversion", use: getVipConversion)
        protected.get("revenue-trend", use: getRevenueTrend)
    }
    
    /// 获取仪表盘核心数据 — 真实数据库查询
    func getDashboardStats(req: Request) async throws -> StatsApiResponse<DashboardStatsResponse> {
        let db = req.db
        
        let totalUsers = try await User.query(on: db).count()
        let totalBirds = try await Bird.query(on: db).count()
        let totalPosts = try await ForumPost.query(on: db).count()
        let totalComments = try await PostComment.query(on: db).count()
        
        let overview = DashboardOverviewDTO(
            totalUsers: totalUsers,
            totalBirds: totalBirds,
            totalPosts: totalPosts,
            totalComments: totalComments
        )
        
        // 今日新增用户
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let todayNewUsers = try await User.query(on: db)
            .filter(\.$createdAt >= startOfDay)
            .count()
        
        // 今日发帖
        let todayPosts = try await ForumPost.query(on: db)
            .filter(\.$createdAt >= startOfDay)
            .count()
        
        let cards = [
            DashboardCardDTO(title: "今日新增用户", value: todayNewUsers),
            DashboardCardDTO(title: "今日发帖", value: todayPosts)
        ]
        
        return StatsApiResponse(data: DashboardStatsResponse(overview: overview, cards: cards))
    }
    
    /// 获取待办事项 — 真实数据库查询
    func getTodos(req: Request) async throws -> StatsApiResponse<[TodoItem]> {
        let db = req.db
        var items: [TodoItem] = []
        
        // 查询待审核的开屏展示位
        let pendingCount = try await SplashDisplaySlot.query(on: db)
            .filter(\.$reviewStatus == "PENDING")
            .count()
        
        if pendingCount > 0 {
            items.append(TodoItem(
                id: "splash-review",
                type: "splash_review",
                title: "开屏展示位审核",
                content: "待审核: \(pendingCount) 条",
                createdAt: Date(),
                actionUrl: "/splash/review",
                path: "/splash/review",
                count: pendingCount
            ))
        }
        
        // 查询待处理的举报
        let reportCount = try await PostReport.query(on: db)
            .filter(\.$status == "PENDING")
            .count()
        
        if reportCount > 0 {
            items.append(TodoItem(
                id: "post-report",
                type: "post_report",
                title: "帖子举报处理",
                content: "待处理: \(reportCount) 条",
                createdAt: Date(),
                actionUrl: "/forum/reports",
                path: "/forum/reports",
                count: reportCount
            ))
        }
        
        return StatsApiResponse(data: items)
    }
    
    /// 获取用户趋势 — 真实数据库查询
    func getUserTrend(req: Request) async throws -> StatsApiResponse<UserTrendData> {
        let daysStr = req.query[String.self, at: "days"] ?? "7"
        let days = Int(daysStr) ?? 7
        
        var dates: [String] = []
        var newUsers: [Int] = []
        var totalUsers: [Int] = []
        var activeUsers: [Int] = []
        
        let now = Date()
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "MM-dd"
        
        let db = req.db
        
        // 获取 days 天前的累计用户数
        let baseDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))!
        var currentTotal = try await User.query(on: db)
            .filter(\.$createdAt < baseDate)
            .count()
        
        for i in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: now)!
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            dates.append(df.string(from: date))
            
            let dailyNew = try await User.query(on: db)
                .filter(\.$createdAt >= dayStart)
                .filter(\.$createdAt < dayEnd)
                .count()
            
            currentTotal += dailyNew
            
            newUsers.append(dailyNew)
            totalUsers.append(currentTotal)
            activeUsers.append(0) // 活跃用户需要登录日志表支持
        }
        
        return StatsApiResponse(data: UserTrendData(
            dates: dates,
            newUsers: newUsers,
            totalUsers: totalUsers,
            activeUsers: activeUsers
        ))
    }

    /// 获取帖子分布 — 真实数据库查询
    func getPostDistribution(req: Request) async throws -> StatsApiResponse<[PostDistItem]> {
        let db = req.db
        
        let colorMap: [String: String] = [
            "NORMAL": "#EC4899",
            "HELP": "#F59E0B",
            "SHOW": "#3B82F6",
            "FIND_BIRD": "#EF4444",
            "OTHER": "#10B981"
        ]
        
        let nameMap: [String: String] = [
            "NORMAL": "日常分享",
            "HELP": "求助问答",
            "SHOW": "鸟儿展示",
            "FIND_BIRD": "寻鸟启事",
            "OTHER": "其他"
        ]
        
        // 使用 SQLDatabase 执行原始 SQL
        guard let sqlDb = db as? SQLDatabase else {
            // Fallback: 使用 Fluent 查询所有帖子并在内存中分组
            let allPosts = try await ForumPost.query(on: db).all()
            var typeCounts: [String: Int] = [:]
            for post in allPosts {
                let postType = post.postType ?? "NORMAL"
                typeCounts[postType, default: 0] += 1
            }
            
            var dist: [PostDistItem] = []
            for (postType, count) in typeCounts {
                let name = nameMap[postType] ?? postType
                let color = colorMap[postType] ?? "#9CA3AF"
                dist.append(PostDistItem(value: count, name: name, color: color))
            }
            
            if dist.isEmpty {
                dist.append(PostDistItem(value: 0, name: "无数据", color: "#E5E7EB"))
            }
            
            return StatsApiResponse(data: dist)
        }
        
        struct PostTypeRow: Decodable {
            let post_type: String
            let cnt: Int
        }
        
        let rows = try await sqlDb.raw("SELECT post_type, COUNT(*) as cnt FROM forum_posts GROUP BY post_type")
            .all(decoding: PostTypeRow.self)
        
        var dist: [PostDistItem] = []
        for row in rows {
            let name = nameMap[row.post_type] ?? row.post_type
            let color = colorMap[row.post_type] ?? "#9CA3AF"
            dist.append(PostDistItem(value: row.cnt, name: name, color: color))
        }
        
        if dist.isEmpty {
            dist.append(PostDistItem(value: 0, name: "无数据", color: "#E5E7EB"))
        }
        
        return StatsApiResponse(data: dist)
    }

    /// 获取 VIP 转化数据 — 真实数据库查询
    @Sendable
    func getVipConversion(req: Request) async throws -> StatsApiResponse<VipConversionData> {
        let db = req.db
        
        let totalUsers = try await User.query(on: db).count()
        var vipUsers = 0
        var coupleVipUsers = 0
        
        do {
            vipUsers = try await User.query(on: db)
                .filter(\.$isVip == true)
                .count()
            coupleVipUsers = try await User.query(on: db)
                .filter(\.$isCoupleVip == true)
                .count()
        } catch {
            req.logger.warning("Failed to query VIP stats (columns may be missing): \(error)")
        }
            
        return StatsApiResponse(data: VipConversionData(
            vipUsers: vipUsers,
            coupleVipUsers: coupleVipUsers,
            totalUsers: totalUsers
        ))
    }

    /// 获取收入趋势数据 — 真实数据库查询
    @Sendable
    func getRevenueTrend(req: Request) async throws -> StatsApiResponse<RevenueTrendData> {
        let daysStr = req.query[String.self, at: "days"] ?? "7"
        let days = Int(daysStr) ?? 7
        
        var dates: [String] = []
        var vipRevenue: [Double] = []
        var splashRevenue: [Double] = []
        
        let now = Date()
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "MM-dd"
        
        let db = req.db
        
        for i in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: now)!
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            dates.append(df.string(from: date))
            
            // VIP 收入
            var dailyVip: Double = 0
            do {
                let vipRecords = try await VipPurchaseRecord.query(on: db)
                    .filter(\.$createdAt >= dayStart)
                    .filter(\.$createdAt < dayEnd)
                    .all()
                
                for record in vipRecords {
                    if record.productId.contains("month") {
                        dailyVip += 9.9
                    } else if record.productId.contains("year") {
                        dailyVip += 99.0
                    } else if record.productId.contains("permanent") {
                        dailyVip += 199.0
                    } else {
                        dailyVip += 9.9
                    }
                }
            } catch {
                // Table might not exist yet
                req.logger.warning("Failed to query VipPurchaseRecord: \(error)")
            }
            vipRevenue.append(dailyVip)
            
            // 开屏收入 SplashOrder
            var dailySplash: Double = 0
            do {
                let splashOrders = try await SplashOrder.query(on: db)
                    .filter(\.$createdAt >= dayStart)
                    .filter(\.$createdAt < dayEnd)
                    .all()
                    
                dailySplash = splashOrders.filter { $0.status == "PAID" }.reduce(0.0) { $0 + $1.amount }
            } catch {
                req.logger.warning("Failed to query SplashOrder: \(error)")
            }
            splashRevenue.append(dailySplash)
        }
        
        return StatsApiResponse(data: RevenueTrendData(
            dates: dates,
            vipRevenue: vipRevenue,
            splashRevenue: splashRevenue
        ))
    }
}

// MARK: - DTOs & Response Wrapper

struct StatsApiResponse<T: Content>: Content {
    let code: Int
    let message: String
    let data: T?
    
    init(data: T?, code: Int = 0, message: String = "success") {
        self.code = code
        self.message = message
        self.data = data
    }
}

struct DashboardOverviewDTO: Content {
    let totalUsers: Int
    let totalBirds: Int
    let totalPosts: Int
    let totalComments: Int
}

struct DashboardCardDTO: Content {
    let title: String
    let value: Int
}

struct DashboardStatsResponse: Content {
    let overview: DashboardOverviewDTO
    let cards: [DashboardCardDTO]
}

struct TodoItem: Content {
    let id: String
    let type: String 
    let title: String
    let content: String
    let createdAt: Date
    let actionUrl: String
    let path: String
    let count: Int
}

struct UserTrendData: Content {
    let dates: [String]
    let newUsers: [Int]
    let totalUsers: [Int]
    let activeUsers: [Int]
}

struct PostDistItem: Content {
    let value: Int
    let name: String
    var color: String?
}

struct VipConversionData: Content {
    let vipUsers: Int
    let coupleVipUsers: Int
    let totalUsers: Int
}

struct RevenueTrendData: Content {
    let dates: [String]
    let vipRevenue: [Double]
    let splashRevenue: [Double]
}

// StatsAdminMiddleware
struct StatsAdminMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let payload = try request.jwt.verify(as: AuthPayload.self)
        
        // 这里必须保留 DB 查询以验证权限，否则不安全
        guard let user = try await User.find(payload.userId, on: request.db) else {
            throw Abort(.unauthorized)
        }
        
        if !user.isAdmin {
             throw Abort(.forbidden, reason: "需要管理员权限")
        }
        
        return try await next.respond(to: request)
    }
}
