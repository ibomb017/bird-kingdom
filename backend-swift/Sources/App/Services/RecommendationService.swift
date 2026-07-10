import Vapor
import Fluent

/// 推荐服务
/// 实现个性化推荐算法
struct RecommendationService {
    let db: Database
    
    init(db: Database) {
        self.db = db
    }
    
    // MARK: - 获取个性化推荐帖子
    
    /// 获取个性化推荐的帖子ID列表及其得分
    /// - Parameters:
    ///   - userId: 用户ID（nil表示匿名用户）
    ///   - page: 页码
    ///   - size: 每页数量
    ///   - postType: 帖子类型筛选
    /// - Returns: 帖子列表（已按推荐分数排序）
    func getPersonalizedPosts(
        userId: Int64?,
        page: Int,
        size: Int,
        postType: String? = nil
    ) async throws -> (posts: [ForumPost], total: Int) {
        // 获取所有候选帖子
        var query = ForumPost.query(on: db)
        
        if let type = postType, !type.isEmpty {
            query = query.filter(\.$postType == type)
        }
        
        let allPosts = try await query.all()
        
        // 如果没有登录用户，使用热度排序
        guard let userId = userId else {
            return await rankByHotness(posts: allPosts, page: page, size: size)
        }
        
        // 获取用户兴趣画像
        let interests = try await UserInterest.query(on: db)
            .filter(\.$userId == userId)
            .all()
        
        // 构建兴趣映射
        var speciesInterests: [String: Double] = [:]
        var postTypeInterests: [String: Double] = [:]
        var authorInterests: [Int64: Double] = [:]
        
        for interest in interests {
            switch interest.interestType {
            case "bird_species":
                speciesInterests[interest.interestValue] = interest.score
            case "post_type":
                postTypeInterests[interest.interestValue] = interest.score
            case "author":
                if let authorId = Int64(interest.interestValue) {
                    authorInterests[authorId] = interest.score
                }
            default:
                break
            }
        }
        
        // 获取用户关注列表
        let followingIds = try await UserFollow.query(on: db)
            .filter(\.$followerId == userId)
            .all()
            .map { $0.followingId }
        
        let followingSet = Set(followingIds)
        
        // 获取用户已浏览过的帖子（最近7天，用于去重/降权）
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let viewedPostIds = try await UserBehavior.query(on: db)
            .filter(\.$userId == userId)
            .filter(\.$behaviorType == UserBehaviorType.view.rawValue)
            .filter(\.$createdAt >= sevenDaysAgo)
            .all()
            .compactMap { $0.targetId }
        
        let viewedSet = Set(viewedPostIds)
        
        // 计算每个帖子的推荐分数
        var scoredPosts: [(post: ForumPost, score: Double)] = []
        
        for post in allPosts {
            var score: Double = 0
            
            // 1. 基础热度分（40%权重）
            let hotnessScore = calculateHotnessScore(post: post)
            score += hotnessScore * 0.4
            
            // 2. 用户兴趣匹配分（35%权重）
            var interestScore: Double = 0
            
            // 品种匹配
            if let species = post.birdSpecies, let speciesScore = speciesInterests[species] {
                interestScore += speciesScore * 0.5
            }
            
            // 帖子类型匹配
            if let type = post.postType, let typeScore = postTypeInterests[type] {
                interestScore += typeScore * 0.3
            }
            
            // 作者偏好匹配
            if let authorScore = authorInterests[post.authorId] {
                interestScore += authorScore * 0.2
            }
            
            score += interestScore * 0.35
            
            // 3. 社交关系分（15%权重）
            if followingSet.contains(post.authorId) {
                score += 100 * 0.15  // 关注的人发的帖子加权
            }
            
            // 4. 新鲜度分（10%权重）
            let freshnessScore = calculateFreshnessScore(post: post)
            score += freshnessScore * 0.1
            
            // 5. 已浏览降权
            if let postId = post.id, viewedSet.contains(postId) {
                score *= 0.5  // 已浏览过的帖子降权50%
            }
            
            // 6. 内容质量加权
            if post.mediaType == "VIDEO" {
                score *= 1.2  // 视频内容加权
            }
            
            scoredPosts.append((post, score))
        }
        
        // 按分数排序
        scoredPosts.sort { $0.score > $1.score }
        
        // 分页
        let total = scoredPosts.count
        let startIndex = page * size
        let endIndex = min(startIndex + size, total)
        
        let pagedPosts = startIndex < total ? Array(scoredPosts[startIndex..<endIndex].map { $0.post }) : []
        
        return (pagedPosts, total)
    }
    
    // MARK: - 热度排序（匿名用户/冷启动）
    
    private func rankByHotness(posts: [ForumPost], page: Int, size: Int) async -> (posts: [ForumPost], total: Int) {
        var scoredPosts: [(post: ForumPost, score: Double)] = []
        
        for post in posts {
            let score = calculateHotnessScore(post: post) + calculateFreshnessScore(post: post)
            scoredPosts.append((post, score))
        }
        
        scoredPosts.sort { $0.score > $1.score }
        
        let total = scoredPosts.count
        let startIndex = page * size
        let endIndex = min(startIndex + size, total)
        
        let pagedPosts = startIndex < total ? Array(scoredPosts[startIndex..<endIndex].map { $0.post }) : []
        
        return (pagedPosts, total)
    }
    
    // MARK: - 热度分数计算
    
    /// 计算帖子的热度分数（0-100）
    private func calculateHotnessScore(post: ForumPost) -> Double {
        // 互动分：点赞×3 + 评论×4 + 浏览×0.1
        let interactionScore = Double(post.likeCount) * 3.0 +
                              Double(post.commentCount) * 4.0 +
                              Double(post.viewCount) * 0.1
        
        // 归一化到0-100（假设最热的帖子有1000互动分）
        return min(interactionScore / 10.0, 100.0)
    }
    
    // MARK: - 新鲜度分数计算
    
    /// 计算帖子的新鲜度分数（0-100）
    private func calculateFreshnessScore(post: ForumPost) -> Double {
        guard let createdAt = post.createdAt else { return 0 }
        
        let hoursSinceCreation = Date().timeIntervalSince(createdAt) / 3600
        
        // 24小时内: 100分
        // 7天内: 70分
        // 30天内: 40分
        // 更早: 20分
        if hoursSinceCreation <= 24 {
            return 100 - (hoursSinceCreation / 24 * 30)  // 24小时内: 100 -> 70
        } else if hoursSinceCreation <= 24 * 7 {
            let daysSinceCreation = hoursSinceCreation / 24
            return 70 - ((daysSinceCreation - 1) / 6 * 30)  // 7天内: 70 -> 40
        } else if hoursSinceCreation <= 24 * 30 {
            let daysSinceCreation = hoursSinceCreation / 24
            return 40 - ((daysSinceCreation - 7) / 23 * 20)  // 30天内: 40 -> 20
        } else {
            return 20
        }
    }
    
    // MARK: - 附近推荐
    
    /// 获取附近的帖子
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - radiusKm: 搜索半径（公里）
    ///   - page: 页码
    ///   - size: 每页数量
    ///   - postType: 帖子类型筛选
    /// - Returns: 按距离排序的帖子列表
    func getNearbyPosts(
        latitude: Double,
        longitude: Double,
        radiusKm: Double,
        page: Int,
        size: Int,
        postType: String? = nil
    ) async throws -> (posts: [ForumPost], total: Int, distances: [Int64: Double]) {
        // 查询有位置信息的帖子
        var query = ForumPost.query(on: db)
            .filter(\.$latitude != nil)
            .filter(\.$longitude != nil)
        
        if let type = postType, !type.isEmpty {
            query = query.filter(\.$postType == type)
        }
        
        let allPosts = try await query.all()
        
        // 计算距离并筛选
        var postsWithDistance: [(post: ForumPost, distance: Double)] = []
        
        for post in allPosts {
            guard let postLat = post.latitude, let postLon = post.longitude else { continue }
            
            let distance = calculateDistance(
                lat1: latitude, lon1: longitude,
                lat2: postLat, lon2: postLon
            )
            
            if distance <= radiusKm {
                postsWithDistance.append((post, distance))
            }
        }
        
        // 综合排序：距离 + 热度
        // 距离权重70%，热度权重30%
        let maxDistance = radiusKm
        
        postsWithDistance.sort { item1, item2 in
            let distanceScore1 = (1 - item1.distance / maxDistance) * 70
            let hotnessScore1 = calculateHotnessScore(post: item1.post) * 0.3
            let score1 = distanceScore1 + hotnessScore1
            
            let distanceScore2 = (1 - item2.distance / maxDistance) * 70
            let hotnessScore2 = calculateHotnessScore(post: item2.post) * 0.3
            let score2 = distanceScore2 + hotnessScore2
            
            return score1 > score2
        }
        
        // 构建距离映射
        var distances: [Int64: Double] = [:]
        for (post, distance) in postsWithDistance {
            if let postId = post.id {
                distances[postId] = distance
            }
        }
        
        // 分页
        let total = postsWithDistance.count
        let startIndex = page * size
        let endIndex = min(startIndex + size, total)
        
        let pagedPosts = startIndex < total ? Array(postsWithDistance[startIndex..<endIndex].map { $0.post }) : []
        
        return (pagedPosts, total, distances)
    }
    
    // MARK: - 距离计算（Haversine公式）
    
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371.0  // km
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
    
    // MARK: - 相似帖子推荐
    
    /// 获取与指定帖子相似的帖子
    func getSimilarPosts(postId: Int64, limit: Int = 6) async throws -> [ForumPost] {
        guard let post = try await ForumPost.find(postId, on: db) else {
            return []
        }
        
        // 获取候选帖子（排除自身）
        var query = ForumPost.query(on: db)
            .filter(\.$id != postId)
        
        // 优先筛选相同品种
        if let species = post.birdSpecies, !species.isEmpty {
            // 先获取同品种的帖子
            let sameSpeciesPosts = try await ForumPost.query(on: db)
                .filter(\.$id != postId)
                .filter(\.$birdSpecies == species)
                .sort(\.$likeCount, .descending)
                .limit(limit)
                .all()
            
            if sameSpeciesPosts.count >= limit {
                return sameSpeciesPosts
            }
            
            // 不足则补充同类型帖子
            let remaining = limit - sameSpeciesPosts.count
            let sameTypePosts = try await ForumPost.query(on: db)
                .filter(\.$id != postId)
                .filter(\.$postType == (post.postType ?? "NORMAL"))
                .filter(\.$birdSpecies != species)  // 排除已获取的
                .sort(\.$likeCount, .descending)
                .limit(remaining)
                .all()
            
            return sameSpeciesPosts + sameTypePosts
        }
        
        // 没有品种信息，按类型筛选
        let candidates = try await query
            .filter(\.$postType == (post.postType ?? "NORMAL"))
            .sort(\.$likeCount, .descending)
            .limit(limit)
            .all()
        
        return candidates
    }
}

// MARK: - Request 扩展
extension Request {
    var recommendationService: RecommendationService {
        RecommendationService(db: self.db)
    }
}
