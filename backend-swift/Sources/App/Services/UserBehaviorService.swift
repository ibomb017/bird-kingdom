import Vapor
import Fluent

/// 用户行为服务
/// 负责记录用户行为并生成用户画像
struct UserBehaviorService {
    let db: Database
    
    init(db: Database) {
        self.db = db
    }
    
    // MARK: - 记录用户行为
    
    /// 记录用户浏览帖子行为
    func recordView(userId: Int64, postId: Int64, post: ForumPost, duration: Int? = nil, appVersion: String? = nil) async {
        let behavior = UserBehavior(
            userId: userId,
            behaviorType: .view,
            targetType: "POST",
            targetId: postId,
            duration: duration,
            birdSpecies: post.birdSpecies,
            postType: post.postType,
            appVersion: appVersion
        )
        
        do {
            try await behavior.save(on: db)
        } catch {
            // 静默失败，不影响主流程
            print("Failed to record view behavior: \(error)")
        }
    }
    
    /// 记录用户点赞行为
    func recordLike(userId: Int64, postId: Int64, post: ForumPost, isLike: Bool) async {
        let behavior = UserBehavior(
            userId: userId,
            behaviorType: isLike ? .like : .unlike,
            targetType: "POST",
            targetId: postId,
            birdSpecies: post.birdSpecies,
            postType: post.postType
        )
        
        do {
            try await behavior.save(on: db)
        } catch {
            print("Failed to record like behavior: \(error)")
        }
    }
    
    /// 记录用户收藏行为
    func recordFavorite(userId: Int64, postId: Int64, post: ForumPost, isFavorite: Bool) async {
        let behavior = UserBehavior(
            userId: userId,
            behaviorType: isFavorite ? .favorite : .unfavorite,
            targetType: "POST",
            targetId: postId,
            birdSpecies: post.birdSpecies,
            postType: post.postType
        )
        
        do {
            try await behavior.save(on: db)
        } catch {
            print("Failed to record favorite behavior: \(error)")
        }
    }
    
    /// 记录用户评论行为
    func recordComment(userId: Int64, postId: Int64, post: ForumPost, commentContent: String) async {
        let behavior = UserBehavior(
            userId: userId,
            behaviorType: .comment,
            targetType: "POST",
            targetId: postId,
            content: commentContent,
            birdSpecies: post.birdSpecies,
            postType: post.postType
        )
        
        do {
            try await behavior.save(on: db)
        } catch {
            print("Failed to record comment behavior: \(error)")
        }
    }
    
    /// 记录用户关注行为
    func recordFollow(userId: Int64, targetUserId: Int64, isFollow: Bool) async {
        let behavior = UserBehavior(
            userId: userId,
            behaviorType: isFollow ? .follow : .unfollow,
            targetType: "USER",
            targetId: targetUserId
        )
        
        do {
            try await behavior.save(on: db)
        } catch {
            print("Failed to record follow behavior: \(error)")
        }
    }
    
    /// 记录用户搜索行为
    func recordSearch(userId: Int64?, keyword: String, resultCount: Int, scene: String? = nil, ipAddress: String? = nil) async {
        // 记录到 UserBehavior 表（如果已登录）
        if let userId = userId {
            let behavior = UserBehavior(
                userId: userId,
                behaviorType: .search,
                targetType: "KEYWORD",
                content: keyword
            )
            do {
                try await behavior.save(on: db)
            } catch {
                print("Failed to record search behavior: \(error)")
            }
        }
        
        // 同时记录到 SearchLog 表（用于热搜统计）
        let searchLog = SearchLog(
            userId: userId,
            keyword: keyword,
            resultCount: resultCount,
            scene: scene,
            ipAddress: ipAddress
        )
        do {
            try await searchLog.save(on: db)
        } catch {
            print("Failed to record search log: \(error)")
        }
    }
    
    /// 记录用户发帖行为
    func recordCreate(userId: Int64, postId: Int64, post: ForumPost) async {
        let behavior = UserBehavior(
            userId: userId,
            behaviorType: .create,
            targetType: "POST",
            targetId: postId,
            birdSpecies: post.birdSpecies,
            postType: post.postType
        )
        
        do {
            try await behavior.save(on: db)
        } catch {
            print("Failed to record create behavior: \(error)")
        }
    }
    
    // MARK: - 用户兴趣分析
    
    /// 获取用户的兴趣画像
    func getUserInterests(userId: Int64) async throws -> [UserInterest] {
        return try await UserInterest.query(on: db)
            .filter(\.$userId == userId)
            .sort(\.$score, .descending)
            .all()
    }
    
    /// 更新用户兴趣画像（基于最近30天的行为）
    func updateUserInterests(userId: Int64) async throws {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        // 获取用户最近30天的行为
        let behaviors = try await UserBehavior.query(on: db)
            .filter(\.$userId == userId)
            .filter(\.$createdAt >= thirtyDaysAgo)
            .all()
        
        // 统计鸟品种偏好
        var speciesScores: [String: Double] = [:]
        // 统计帖子类型偏好
        var postTypeScores: [String: Double] = [:]
        // 统计关注的作者
        var authorScores: [Int64: Double] = [:]
        
        for behavior in behaviors {
            // 不同行为的权重
            let weight: Double
            switch behavior.behaviorType {
            case UserBehaviorType.like.rawValue:
                weight = 3.0
            case UserBehaviorType.favorite.rawValue:
                weight = 5.0
            case UserBehaviorType.comment.rawValue:
                weight = 4.0
            case UserBehaviorType.view.rawValue:
                // 浏览时长加权
                let duration = behavior.duration ?? 5
                weight = min(Double(duration) / 10.0, 2.0)
            case UserBehaviorType.follow.rawValue:
                weight = 10.0
            default:
                weight = 1.0
            }
            
            // 累积品种分数
            if let species = behavior.birdSpecies, !species.isEmpty {
                speciesScores[species, default: 0] += weight
            }
            
            // 累积帖子类型分数
            if let postType = behavior.postType, !postType.isEmpty {
                postTypeScores[postType, default: 0] += weight
            }
            
            // 累积作者偏好分数
            if behavior.targetType == "USER", let targetId = behavior.targetId {
                authorScores[targetId, default: 0] += weight
            }
        }
        
        // 归一化并保存兴趣
        try await saveNormalizedInterests(userId: userId, type: "bird_species", scores: speciesScores)
        try await saveNormalizedInterests(userId: userId, type: "post_type", scores: postTypeScores)
        try await saveNormalizedInterestsInt(userId: userId, type: "author", scores: authorScores)
    }
    
    private func saveNormalizedInterests(userId: Int64, type: String, scores: [String: Double]) async throws {
        let maxScore = scores.values.max() ?? 1.0
        
        for (value, score) in scores {
            let normalizedScore = (score / maxScore) * 100
            
            // 使用 upsert 逻辑
            if let existing = try await UserInterest.query(on: db)
                .filter(\.$userId == userId)
                .filter(\.$interestType == type)
                .filter(\.$interestValue == value)
                .first() {
                existing.score = normalizedScore
                try await existing.save(on: db)
            } else {
                let interest = UserInterest(
                    userId: userId,
                    interestType: type,
                    interestValue: value,
                    score: normalizedScore
                )
                try await interest.save(on: db)
            }
        }
    }
    
    private func saveNormalizedInterestsInt(userId: Int64, type: String, scores: [Int64: Double]) async throws {
        let maxScore = scores.values.max() ?? 1.0
        
        for (key, score) in scores {
            let value = String(key)
            let normalizedScore = (score / maxScore) * 100
            
            if let existing = try await UserInterest.query(on: db)
                .filter(\.$userId == userId)
                .filter(\.$interestType == type)
                .filter(\.$interestValue == value)
                .first() {
                existing.score = normalizedScore
                try await existing.save(on: db)
            } else {
                let interest = UserInterest(
                    userId: userId,
                    interestType: type,
                    interestValue: value,
                    score: normalizedScore
                )
                try await interest.save(on: db)
            }
        }
    }
    
    // MARK: - 热门搜索
    
    /// 获取热门搜索词（最近7天）
    func getHotSearchKeywords(limit: Int = 10) async throws -> [String] {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        // 获取所有搜索日志
        let searchLogs = try await SearchLog.query(on: db)
            .filter(\.$createdAt >= sevenDaysAgo)
            .all()
        
        // 统计关键词频率
        var keywordCounts: [String: Int] = [:]
        for log in searchLogs {
            let keyword = log.keyword.lowercased().trimmingCharacters(in: .whitespaces)
            if !keyword.isEmpty {
                keywordCounts[keyword, default: 0] += 1
            }
        }
        
        // 排序并返回前N个
        let sorted = keywordCounts.sorted { $0.value > $1.value }
        return Array(sorted.prefix(limit).map { $0.key })
    }
}

// MARK: - Request 扩展
extension Request {
    var behaviorService: UserBehaviorService {
        UserBehaviorService(db: self.db)
    }
}
