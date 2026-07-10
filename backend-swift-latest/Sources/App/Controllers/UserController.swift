import Vapor
import Fluent

/// 用户控制器
struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        
        // 获取用户信息
        users.get(":userId", use: getUser)
        
        // 获取用户统计
        users.get(":userId", "full-stats", use: getUserFullStats)
        
        // 需要认证的路由
        let protected = users.grouped(JWTAuthMiddleware())
        
        // 关注/取消关注
        protected.post(":userId", "follow", use: toggleFollow)
        
        // 检查是否关注
        protected.get(":userId", "is-following", use: isFollowing)
        
        // 获取关注列表
        users.get(":userId", "following", use: getFollowing)
        
        // 获取粉丝列表
        users.get(":userId", "followers", use: getFollowers)
        
        // 关注统计
        users.get(":userId", "follow-stats", use: getFollowStats)
        
        // 获取用户的鸟儿
        users.get(":userId", "birds", use: getUserBirds)
    }
    
    // MARK: - 获取用户信息
    @Sendable
    func getUser(req: Request) async throws -> UserDTO {
        guard let userIdStr = req.parameters.get("userId"),
              let userId = Int64(userIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        return UserDTO.from(user)
    }
    
    // MARK: - 获取用户完整统计
    @Sendable
    func getUserFullStats(req: Request) async throws -> UserFullStatsDTO {
        guard let userIdStr = req.parameters.get("userId"),
              let userId = Int64(userIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // 统计数据
        let birdCount = try await Bird.query(on: req.db)
            .filter(\.$userId == userId)
            .filter(\.$isDeleted == false)
            .count()
        
        let postCount = try await ForumPost.query(on: req.db)
            .filter(\.$authorId == userId)
            .count()
        
        let followerCount = try await UserFollow.query(on: req.db)
            .filter(\.$followingId == userId)
            .count()
        
        let followingCount = try await UserFollow.query(on: req.db)
            .filter(\.$followerId == userId)
            .count()
        
        // 检查当前用户是否关注该用户
        var isFollowing = false
        if let authPayload = req.auth.get(AuthPayload.self) {
            let follow = try await UserFollow.query(on: req.db)
                .filter(\.$followerId == authPayload.userId)
                .filter(\.$followingId == userId)
                .first()
            isFollowing = follow != nil
        }
        
        return UserFullStatsDTO(
            id: user.id ?? 0,
            nickname: user.nickname,
            avatarUrl: user.avatarUrl,
            bio: user.bio,
            birdCount: birdCount,
            postCount: postCount,
            followerCount: followerCount,
            followingCount: followingCount,
            isFollowing: isFollowing,
            isVip: user.isVip,
            vipType: user.vipType,
            isCoupleVip: user.isCoupleVip,
            couplePartnerId: user.couplePartnerId
        )
    }
    
    // MARK: - 关注/取消关注
    @Sendable
    func toggleFollow(req: Request) async throws -> [String: Bool] {
        let currentUserId = try req.auth.require(AuthPayload.self).userId
        
        guard let targetIdStr = req.parameters.get("userId"),
              let targetId = Int64(targetIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        if currentUserId == targetId {
            throw Abort(.badRequest, reason: "不能关注自己")
        }
        
        // 检查目标用户是否存在
        guard try await User.find(targetId, on: req.db) != nil else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // 检查是否已关注
        if let existingFollow = try await UserFollow.query(on: req.db)
            .filter(\.$followerId == currentUserId)
            .filter(\.$followingId == targetId)
            .first() {
            // 已关注，取消关注
            try await existingFollow.delete(on: req.db)
            return ["isFollowing": false]
        } else {
            // 未关注，添加关注
            let follow = UserFollow(followerId: currentUserId, followingId: targetId)
            try await follow.save(on: req.db)
            
            // 创建关注通知
            do {
                let notification = UserNotification(
                    receiverId: targetId,
                    senderId: currentUserId,
                    notificationType: "NEW_FOLLOWER"
                )
                try await notification.save(on: req.db)
            } catch {
                // 忽略通知创建错误（可能是重复通知）
                print("创建关注通知失败: \(error)")
            }
            
            return ["isFollowing": true]
        }
    }
    
    // MARK: - 检查是否关注
    @Sendable
    func isFollowing(req: Request) async throws -> [String: Bool] {
        let currentUserId = try req.auth.require(AuthPayload.self).userId
        
        guard let targetIdStr = req.parameters.get("userId"),
              let targetId = Int64(targetIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        let follow = try await UserFollow.query(on: req.db)
            .filter(\.$followerId == currentUserId)
            .filter(\.$followingId == targetId)
            .first()
        
        return ["following": follow != nil]
    }
    
    // MARK: - 获取关注列表
    @Sendable
    func getFollowing(req: Request) async throws -> PageResponse<UserDTO> {
        guard let userIdStr = req.parameters.get("userId"),
              let userId = Int64(userIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        
        let follows = try await UserFollow.query(on: req.db)
            .filter(\.$followerId == userId)
            .range((page * size)..<((page + 1) * size))
            .all()
        
        let total = try await UserFollow.query(on: req.db)
            .filter(\.$followerId == userId)
            .count()
        
        var users: [UserDTO] = []
        for follow in follows {
            if let user = try await User.find(follow.followingId, on: req.db) {
                users.append(UserDTO.from(user))
            }
        }
        
        return PageResponse(content: users, page: page, size: size, total: total)
    }
    
    // MARK: - 获取粉丝列表
    @Sendable
    func getFollowers(req: Request) async throws -> PageResponse<UserDTO> {
        guard let userIdStr = req.parameters.get("userId"),
              let userId = Int64(userIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        
        let follows = try await UserFollow.query(on: req.db)
            .filter(\.$followingId == userId)
            .range((page * size)..<((page + 1) * size))
            .all()
        
        let total = try await UserFollow.query(on: req.db)
            .filter(\.$followingId == userId)
            .count()
        
        var users: [UserDTO] = []
        for follow in follows {
            if let user = try await User.find(follow.followerId, on: req.db) {
                users.append(UserDTO.from(user))
            }
        }
        
        return PageResponse(content: users, page: page, size: size, total: total)
    }
    
    // MARK: - 关注统计
    @Sendable
    func getFollowStats(req: Request) async throws -> [String: Int] {
        guard let userIdStr = req.parameters.get("userId"),
              let userId = Int64(userIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        let followerCount = try await UserFollow.query(on: req.db)
            .filter(\.$followingId == userId)
            .count()
        
        let followingCount = try await UserFollow.query(on: req.db)
            .filter(\.$followerId == userId)
            .count()
        
        return [
            "followerCount": followerCount,
            "followingCount": followingCount
        ]
    }
    
    // MARK: - 获取用户的鸟儿
    @Sendable
    func getUserBirds(req: Request) async throws -> [BirdDTO] {
        guard let userIdStr = req.parameters.get("userId"),
              let userId = Int64(userIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        let birds = try await Bird.query(on: req.db)
            .filter(\.$userId == userId)
            .filter(\.$isDeleted == false)
            .sort(\.$createdAt, .descending)
            .all()
        
        return birds.map { BirdDTO.from($0) }
    }
}

struct UserFullStatsDTO: Content {
    let id: Int64
    let nickname: String
    let avatarUrl: String?
    let bio: String?
    let birdCount: Int
    let postCount: Int
    let followerCount: Int
    let followingCount: Int
    let isFollowing: Bool
    
    // 👑 VIP Related Fields
    let isVip: Bool?
    let vipType: String?
    let isCoupleVip: Bool?
    let couplePartnerId: Int64?
}
