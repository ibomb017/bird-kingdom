import Vapor
import Fluent

/// 论坛控制器
struct ForumController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let forum = routes.grouped("forum")
        
        // 公开路由 - 注意：更具体的路由必须放在前面
        forum.get("posts", "search", use: searchPosts)
        forum.get("posts", "hot-keywords", use: getHotKeywords)
        forum.get("posts", ":postId", "similar", use: getSimilarPosts)
        forum.get("posts", use: getPosts)
        forum.get("posts", ":postId", use: getPost)
        forum.get("posts", ":postId", "comments", use: getComments)
        
        // 需要认证的路由
        let protected = forum.grouped(JWTAuthMiddleware())
        
        // 关注用户的帖子
        protected.get("posts", "following", use: getFollowingPosts)
        
        // 我的帖子 - 前端调的是 /posts/mine
        protected.get("posts", "mine", use: getMyPosts)
        
        // 某用户的帖子
        protected.get("posts", "user", ":userId", use: getUserPosts)
        
        // 检查重复
        protected.get("posts", "check-duplicate", use: checkDuplicate)
        
        // 发帖
        protected.post("posts", use: createPost)
        
        // 删除帖子
        protected.delete("posts", ":postId", use: deletePost)
        
        // 点赞/取消点赞
        protected.post("posts", ":postId", "like", use: toggleLike)
        
        // 收藏/取消收藏
        protected.post("posts", ":postId", "favorite", use: toggleFavorite)
        
        // 发评论
        protected.post("posts", ":postId", "comments", use: createComment)
        
        // 删除评论
        protected.delete("comments", ":commentId", use: deleteComment)
        
        // 评论点赞
        protected.post("comments", ":commentId", "like", use: toggleCommentLike)
        
        // 我的帖子（兼容旧接口）
        protected.get("my-posts", use: getMyPosts)
        
        // 我的收藏
        protected.get("favorites", use: getFavorites)
        
        // 举报帖子（在 ForumController 添加兼容路由）
        protected.post("posts", ":postId", "report", use: reportPost)
        
        // 标记帖子已找回（针对丢失帖）
        protected.post("posts", ":postId", "mark-found", use: markPostFound)
    }
    
    // MARK: - 获取帖子列表（统一接口，支持多种场景）
    // scene 参数：recommend（推荐流）、follow（关注流）、nearby（附近流）
    @Sendable
    func getPosts(req: Request) async throws -> PageResponse<ForumPostDTO> {
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        let postType = try? req.query.get(String.self, at: "postType")
        let scene = (try? req.query.get(String.self, at: "scene")) ?? "recommend"
        let sort = (try? req.query.get(String.self, at: "sort")) ?? "hot"
        
        // 附近流参数
        let userLat = try? req.query.get(Double.self, at: "latitude")
        let userLon = try? req.query.get(Double.self, at: "longitude")
        let distance = (try? req.query.get(Double.self, at: "distance")) ?? 10.0  // 默认10km
        
        let currentUserId = req.auth.get(AuthPayload.self)?.userId
        
        var posts: [ForumPost]
        var total: Int
        
        switch scene {
        case "follow":
            // 关注流：只返回当前用户关注的作者的帖子
            guard let userId = currentUserId else {
                return PageResponse(content: [], page: page, size: size, total: 0)
            }
            
            let followingIds = try await UserFollow.query(on: req.db)
                .filter(\.$followerId == userId)
                .all()
                .map { $0.followingId }
            
            if followingIds.isEmpty {
                return PageResponse(content: [], page: page, size: size, total: 0)
            }
            
            var query = ForumPost.query(on: req.db)
                .filter(\.$authorId ~~ followingIds)
            
            if let type = postType, !type.isEmpty {
                query = query.filter(\.$postType == type)
            }
            
            total = try await query.count()
            
            // 关注流默认按时间倒序
            posts = try await query
                .sort(\.$createdAt, .descending)
                .range((page * size)..<((page + 1) * size))
                .all()
                
        case "nearby":
            // 附近流：按地理位置返回附近的帖子
            var query = ForumPost.query(on: req.db)
                .filter(\.$latitude != nil)
                .filter(\.$longitude != nil)
            
            if let type = postType, !type.isEmpty {
                query = query.filter(\.$postType == type)
            }
            
            // 获取所有有位置的帖子，然后在内存中计算距离
            let allPosts = try await query.all()
            
            // 如果用户提供了位置，按距离筛选
            if let lat = userLat, let lon = userLon {
                posts = allPosts.filter { post in
                    guard let postLat = post.latitude, let postLon = post.longitude else { return false }
                    let dist = Self.calculateDistance(lat1: lat, lon1: lon, lat2: postLat, lon2: postLon)
                    return dist <= distance
                }
                // 按距离排序（近到远）
                posts.sort { post1, post2 in
                    guard let lat1 = post1.latitude, let lon1 = post1.longitude,
                          let lat2 = post2.latitude, let lon2 = post2.longitude else { return false }
                    let dist1 = Self.calculateDistance(lat1: lat, lon1: lon, lat2: lat1, lon2: lon1)
                    let dist2 = Self.calculateDistance(lat1: lat, lon1: lon, lat2: lat2, lon2: lon2)
                    return dist1 < dist2
                }
            } else {
                posts = allPosts
            }
            
            total = posts.count
            let startIndex = page * size
            let endIndex = min(startIndex + size, total)
            posts = startIndex < total ? Array(posts[startIndex..<endIndex]) : []
            
        default:  // "recommend" - 推荐流
            // 推荐流：个性化推荐（基于用户兴趣画像）或热度排序
            if sort == "new" {
                // 最新排序（不使用个性化）
                var query = ForumPost.query(on: req.db)
                
                if let type = postType, !type.isEmpty {
                    query = query.filter(\.$postType == type)
                }
                
                total = try await query.count()
                posts = try await query
                    .sort(\.$createdAt, .descending)
                    .range((page * size)..<((page + 1) * size))
                    .all()
            } else {
                // 个性化推荐（使用推荐服务）
                let result = try await req.recommendationService.getPersonalizedPosts(
                    userId: currentUserId,
                    page: page,
                    size: size,
                    postType: postType
                )
                posts = result.posts
                total = result.total
            }
        }
        
        // 构建 DTO 响应 - 批量查询优化（消除 N+1 查询）
        let postIds = posts.compactMap { $0.id }
        let authorIds = Array(Set(posts.map { $0.authorId }))
        
        // 批量查询：所有作者（1次查询）
        let authors = try await User.query(on: req.db)
            .filter(\.$id ~~ authorIds)
            .all()
        let authorMap = Dictionary(uniqueKeysWithValues: authors.compactMap { user -> (Int64, User)? in
            guard let id = user.id else { return nil }
            return (id, user)
        })
        
        // 批量查询：所有帖子图片（1次查询）
        let allImages = try await PostImage.query(on: req.db)
            .filter(\.$postId ~~ postIds)
            .all()
        let imageMap = Dictionary(grouping: allImages, by: { $0.postId })
        
        // 批量查询：所有帖子收藏数（1次查询，使用分组计数）
        let allFavorites = try await PostFavorite.query(on: req.db)
            .filter(\.$postId ~~ postIds)
            .all()
        let favoriteCountMap = Dictionary(grouping: allFavorites, by: { $0.postId }).mapValues { $0.count }
        
        // 当前用户相关的批量查询
        var likedPostIdSet: Set<Int64> = []
        var favoritedPostIdSet: Set<Int64> = []
        var followingAuthorIdSet: Set<Int64> = []
        
        if let userId = currentUserId {
            // 批量查询：当前用户点赞的帖子（1次查询）
            let likedPosts = try await PostLike.query(on: req.db)
                .filter(\.$postId ~~ postIds)
                .filter(\.$userId == userId)
                .all()
            likedPostIdSet = Set(likedPosts.map { $0.postId })
            
            // 批量查询：当前用户收藏的帖子（1次查询）
            let favoritedPosts = try await PostFavorite.query(on: req.db)
                .filter(\.$postId ~~ postIds)
                .filter(\.$userId == userId)
                .all()
            favoritedPostIdSet = Set(favoritedPosts.map { $0.postId })
            
            // 批量查询：当前用户关注的作者（1次查询）
            let follows = try await UserFollow.query(on: req.db)
                .filter(\.$followerId == userId)
                .filter(\.$followingId ~~ authorIds)
                .all()
            followingAuthorIdSet = Set(follows.map { $0.followingId })
        }
        
        // 在内存中组装 DTO（无额外数据库查询）
        var postDTOs: [ForumPostDTO] = []
        for post in posts {
            let postId = post.id!
            let author = authorMap[post.authorId]
            let images = imageMap[postId] ?? []
            let favoriteCount = favoriteCountMap[postId] ?? 0
            let isLiked = likedPostIdSet.contains(postId)
            let isFavorited = favoritedPostIdSet.contains(postId)
            let isFollowing = followingAuthorIdSet.contains(post.authorId)
            
            // 计算距离（附近流时使用）
            var distanceValue: Double? = nil
            if let lat = userLat, let lon = userLon,
               let postLat = post.latitude, let postLon = post.longitude {
                distanceValue = Self.calculateDistance(lat1: lat, lon1: lon, lat2: postLat, lon2: postLon)
            }
            
            postDTOs.append(ForumPostDTO.from(
                post,
                author: author,
                images: images,
                isLiked: isLiked,
                isFavorited: isFavorited,
                distance: distanceValue,
                favoriteCount: favoriteCount,
                isFollowing: isFollowing
            ))
        }
        
        return PageResponse(content: postDTOs, page: page, size: size, total: total)
    }
    
    // MARK: - 计算热度分数（小红书式算法）
    private static func calculateHotScore(post: ForumPost) -> Double {
        // 基础互动分：点赞×3 + 评论×4 + 浏览×0.1
        let interactionScore = Double(post.likeCount) * 3.0 +
                              Double(post.commentCount) * 4.0 +
                              Double(post.viewCount) * 0.1
        
        // 时效衰减：7天内权重×2，30天内×1.5
        var timeWeight: Double = 1.0
        if let createdAt = post.createdAt {
            let daysSinceCreation = Date().timeIntervalSince(createdAt) / 86400
            if daysSinceCreation <= 1 {
                timeWeight = 3.0  // 24小时内
            } else if daysSinceCreation <= 7 {
                timeWeight = 2.0
            } else if daysSinceCreation <= 30 {
                timeWeight = 1.5
            }
        }
        
        // 内容质量权重：视频帖加权
        var qualityWeight: Double = 1.0
        if post.mediaType == "VIDEO" {
            qualityWeight = 1.3
        }
        
        return interactionScore * timeWeight * qualityWeight
    }
    
    // MARK: - 计算两点间距离（km）
    private static func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371.0  // km
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
    
    
    // MARK: - 获取单个帖子
    @Sendable
    func getPost(req: Request) async throws -> ForumPostDTO {
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        guard let post = try await ForumPost.find(postId, on: req.db) else {
            throw Abort(.notFound, reason: "帖子不存在")
        }
        
        // 增加浏览量
        post.viewCount += 1
        try await post.save(on: req.db)
        
        // 记录用户浏览行为（用于个性化推荐）
        if let userId = req.auth.get(AuthPayload.self)?.userId {
            await req.behaviorService.recordView(userId: userId, postId: postId, post: post)
        }
        
        let author = try await User.find(post.authorId, on: req.db)
        let images = try await PostImage.query(on: req.db)
            .filter(\.$postId == postId)
            .all()
        
        var isLiked = false
        var isFavorited = false
        var isFollowing = false
        var favoriteCount = 0
            
        favoriteCount = try await PostFavorite.query(on: req.db)
            .filter(\.$postId == postId)
            .count()
        
        if let userId = req.auth.get(AuthPayload.self)?.userId {
            isLiked = try await PostLike.query(on: req.db)
                .filter(\.$postId == postId)
                .filter(\.$userId == userId)
                .first() != nil
            
            isFavorited = try await PostFavorite.query(on: req.db)
                .filter(\.$postId == postId)
                .filter(\.$userId == userId)
                .first() != nil
                
            isFollowing = try await UserFollow.query(on: req.db)
                .filter(\.$followerId == userId)
                .filter(\.$followingId == post.authorId)
                .first() != nil
        }
        
        return ForumPostDTO.from(
            post,
            author: author,
            images: images,
            isLiked: isLiked,
            isFavorited: isFavorited,
            favoriteCount: favoriteCount,
            isFollowing: isFollowing
        )
    }
    
    // MARK: - 创建帖子
    @Sendable
    func createPost(req: Request) async throws -> ForumPostDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct CreatePostRequest: Content {
            let content: String
            let postType: String?
            let mediaType: String?
            let videoUrl: String?
            let videoCover: String?
            let videoDuration: Int?
            let latitude: Double?
            let longitude: Double?
            let locationName: String?
            let birdId: Int64?
            let birdIds: String?
            let birdsInfo: String?
            let birdName: String?
            let birdSpecies: String?
            let birdAvatar: String?
            let lostLocation: String?
            let contactPhone: String?
            let reward: String?
            let images: [String]?
        }
        
        let input = try req.content.decode(CreatePostRequest.self)
        
        // 阿里云内容审核
        let isTextValid = try await AliyunGreenService.shared.moderateText(input.content, client: req.client)
        if !isTextValid {
            throw Abort(.badRequest, reason: "内容包含违规信息，请修改后发布")
        }
        
        if let imageUrls = input.images {
            for url in imageUrls {
                let isImageValid = try await AliyunGreenService.shared.moderateImage(url, client: req.client)
                if !isImageValid {
                    throw Abort(.badRequest, reason: "图片包含违规信息，请修改后发布")
                }
            }
        }
        
        if let videoCover = input.videoCover {
            let isCoverValid = try await AliyunGreenService.shared.moderateImage(videoCover, client: req.client)
            if !isCoverValid {
                throw Abort(.badRequest, reason: "视频封面包含违规信息，请修改后发布")
            }
        }
        
        let post = ForumPost(
            authorId: userId,
            content: input.content,
            postType: input.postType ?? "NORMAL",
            mediaType: input.mediaType ?? "IMAGE",
            videoUrl: input.videoUrl,
            videoCover: input.videoCover,
            videoDuration: input.videoDuration,
            latitude: input.latitude,
            longitude: input.longitude,
            locationName: input.locationName,
            birdId: input.birdId,
            birdIds: input.birdIds,
            birdsInfo: input.birdsInfo,
            birdName: input.birdName,
            birdSpecies: input.birdSpecies,
            birdAvatar: input.birdAvatar,
            lostLocation: input.lostLocation,
            contactPhone: input.contactPhone,
            reward: input.reward
        )
        
        try await post.save(on: req.db)
        
        // 保存图片
        var savedImages: [PostImage] = []
        if let imageUrls = input.images {
            for (index, url) in imageUrls.enumerated() {
                let image = PostImage(postId: post.id!, imageUrl: url, sortOrder: index)
                try await image.save(on: req.db)
                savedImages.append(image)
            }
        }
        
        let author = try await User.find(userId, on: req.db)
        
        return ForumPostDTO.from(post, author: author, images: savedImages)
    }
    
    // MARK: - 删除帖子
    @Sendable
    func deletePost(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        guard let post = try await ForumPost.find(postId, on: req.db) else {
            throw Abort(.notFound, reason: "帖子不存在")
        }
        
        if post.authorId != userId {
            throw Abort(.forbidden, reason: "只能删除自己的帖子")
        }
        
        // 清理关联数据
        // 1. 删除帖子图片
        try await PostImage.query(on: req.db)
            .filter(\.$postId == postId)
            .delete()
        
        // 2. 删除评论的点赞
        let commentIds = try await PostComment.query(on: req.db)
            .filter(\.$postId == postId)
            .all()
            .compactMap { $0.id }
        if !commentIds.isEmpty {
            try await CommentLike.query(on: req.db)
                .filter(\.$commentId ~~ commentIds)
                .delete()
        }
        
        // 3. 删除评论
        try await PostComment.query(on: req.db)
            .filter(\.$postId == postId)
            .delete()
        
        // 4. 删除点赞记录
        try await PostLike.query(on: req.db)
            .filter(\.$postId == postId)
            .delete()
        
        // 5. 删除收藏记录
        try await PostFavorite.query(on: req.db)
            .filter(\.$postId == postId)
            .delete()
        
        // 6. 删除关联通知
        try await UserNotification.query(on: req.db)
            .filter(\.$postId == postId)
            .delete()
        
        // 7. 删除帖子
        try await post.delete(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 点赞/取消点赞
    @Sendable
    func toggleLike(req: Request) async throws -> LikeResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        guard let post = try await ForumPost.find(postId, on: req.db) else {
            throw Abort(.notFound, reason: "帖子不存在")
        }
        
        if let existingLike = try await PostLike.query(on: req.db)
            .filter(\.$postId == postId)
            .filter(\.$userId == userId)
            .first() {
            // 取消点赞
            try await existingLike.delete(on: req.db)
            post.likeCount = max(0, post.likeCount - 1)
            try await post.save(on: req.db)
            // 记录取消点赞行为
            await req.behaviorService.recordLike(userId: userId, postId: postId, post: post, isLike: false)
            return LikeResponse(isLiked: false, likeCount: post.likeCount)
        } else {
            // 点赞
            let like = PostLike(postId: postId, userId: userId)
            try await like.save(on: req.db)
            post.likeCount += 1
            try await post.save(on: req.db)
            // 记录点赞行为
            await req.behaviorService.recordLike(userId: userId, postId: postId, post: post, isLike: true)
            
            // 创建通知（不给自己发通知）
            if userId != post.authorId {
                do {
                    let notification = UserNotification(
                        receiverId: post.authorId,
                        senderId: userId,
                        notificationType: "POST_LIKE",
                        postId: postId
                    )
                    try await notification.save(on: req.db)
                } catch {
                    // 忽略通知创建错误（可能是重复通知）
                    print("创建点赞通知失败: \(error)")
                }
            }
            
            return LikeResponse(isLiked: true, likeCount: post.likeCount)
        }
    }
    
    // MARK: - 收藏/取消收藏
    @Sendable
    func toggleFavorite(req: Request) async throws -> [String: Bool] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        guard let post = try await ForumPost.find(postId, on: req.db) else {
            throw Abort(.notFound, reason: "帖子不存在")
        }
        
        if let existingFavorite = try await PostFavorite.query(on: req.db)
            .filter(\.$postId == postId)
            .filter(\.$userId == userId)
            .first() {
            // 取消收藏
            try await existingFavorite.delete(on: req.db)
            // 记录取消收藏行为
            await req.behaviorService.recordFavorite(userId: userId, postId: postId, post: post, isFavorite: false)
            return ["isFavorited": false]
        } else {
            // 收藏
            let favorite = PostFavorite(postId: postId, userId: userId)
            try await favorite.save(on: req.db)
            // 记录收藏行为
            await req.behaviorService.recordFavorite(userId: userId, postId: postId, post: post, isFavorite: true)
            
            // 创建通知（不给自己发通知）
            if userId != post.authorId {
                do {
                    let notification = UserNotification(
                        receiverId: post.authorId,
                        senderId: userId,
                        notificationType: "POST_FAVORITE",
                        postId: postId
                    )
                    try await notification.save(on: req.db)
                } catch {
                    // 忽略通知创建错误（可能是重复通知）
                    print("创建收藏通知失败: \(error)")
                }
            }
            
            return ["isFavorited": true]
        }
    }
    
    // MARK: - 获取评论
    @Sendable
    func getComments(req: Request) async throws -> PageResponse<CommentDTO> {
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        
        // 获取顶级评论
        let total = try await PostComment.query(on: req.db)
            .filter(\.$postId == postId)
            .filter(\.$parentId == nil)
            .count()
        
        let comments = try await PostComment.query(on: req.db)
            .filter(\.$postId == postId)
            .filter(\.$parentId == nil)
            .sort(\.$createdAt, .descending)
            .range((page * size)..<((page + 1) * size))
            .all()
        
        let currentUserId = req.auth.get(AuthPayload.self)?.userId
        
        var commentDTOs: [CommentDTO] = []
        for comment in comments {
            let author = try await User.find(comment.authorId, on: req.db)
            
            var isLiked = false
            if let userId = currentUserId {
                isLiked = try await CommentLike.query(on: req.db)
                    .filter(\.$commentId == comment.id!)
                    .filter(\.$userId == userId)
                    .first() != nil
            }
            
            // 获取回复
            let replies = try await PostComment.query(on: req.db)
                .filter(\.$parentId == comment.id!)
                .sort(\.$createdAt, .ascending)
                .all()
            
            var replyDTOs: [CommentDTO] = []
            for reply in replies {
                let replyAuthor = try await User.find(reply.authorId, on: req.db)
                
                var isReplyLiked = false
                if let userId = currentUserId {
                    isReplyLiked = try await CommentLike.query(on: req.db)
                        .filter(\.$commentId == reply.id!)
                        .filter(\.$userId == userId)
                        .first() != nil
                }
                
                replyDTOs.append(CommentDTO.from(reply, author: replyAuthor, isLiked: isReplyLiked))
            }
            
            commentDTOs.append(CommentDTO.from(
                comment,
                author: author,
                isLiked: isLiked,
                replies: replyDTOs.isEmpty ? nil : replyDTOs
            ))
        }
        
        return PageResponse(content: commentDTOs, page: page, size: size, total: total)
    }
    
    // MARK: - 发表评论
    @Sendable
    func createComment(req: Request) async throws -> CommentDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        struct CreateCommentRequest: Content {
            let content: String
            let parentId: Int64?
        }
        
        let input = try req.content.decode(CreateCommentRequest.self)
        
        // 阿里云内容审核
        let isTextValid = try await AliyunGreenService.shared.moderateText(input.content, client: req.client)
        if !isTextValid {
            throw Abort(.badRequest, reason: "评论包含违规信息，请修改后发布")
        }
        
        guard let post = try await ForumPost.find(postId, on: req.db) else {
            throw Abort(.notFound, reason: "帖子不存在")
        }
        
        let comment = PostComment(
            postId: postId,
            authorId: userId,
            content: input.content,
            parentId: input.parentId
        )
        try await comment.save(on: req.db)
        
        // 更新评论计数
        post.commentCount += 1
        try await post.save(on: req.db)
        
        // 记录评论行为
        await req.behaviorService.recordComment(userId: userId, postId: postId, post: post, commentContent: input.content)
        
        // 创建通知
        if let parentId = input.parentId {
            // 回复评论
            if let parentComment = try await PostComment.find(parentId, on: req.db),
               userId != parentComment.authorId {
                do {
                    let notification = UserNotification(
                        receiverId: parentComment.authorId,
                        senderId: userId,
                        notificationType: "COMMENT_REPLY",
                        content: input.content,
                        postId: postId,
                        commentId: comment.id
                    )
                    try await notification.save(on: req.db)
                } catch {
                    print("创建回复通知失败: \(error)")
                }
            }
        } else {
            // 评论帖子（不给自己发通知）
            if userId != post.authorId {
                do {
                    let notification = UserNotification(
                        receiverId: post.authorId,
                        senderId: userId,
                        notificationType: "POST_COMMENT",
                        content: input.content,
                        postId: postId,
                        commentId: comment.id
                    )
                    try await notification.save(on: req.db)
                } catch {
                    print("创建评论通知失败: \(error)")
                }
            }
        }
        
        let author = try await User.find(userId, on: req.db)
        
        return CommentDTO.from(comment, author: author)
    }
    
    // MARK: - 删除评论
    @Sendable
    func deleteComment(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let commentIdStr = req.parameters.get("commentId"),
              let commentId = Int64(commentIdStr) else {
            throw Abort(.badRequest, reason: "无效的评论ID")
        }
        
        guard let comment = try await PostComment.find(commentId, on: req.db) else {
            throw Abort(.notFound, reason: "评论不存在")
        }
        
        if comment.authorId != userId {
            throw Abort(.forbidden, reason: "只能删除自己的评论")
        }
        
        // 删除所有子回复
        let replyCount = try await PostComment.query(on: req.db)
            .filter(\.$parentId == commentId)
            .count()
        
        try await PostComment.query(on: req.db)
            .filter(\.$parentId == commentId)
            .delete()
        
        // 更新帖子评论计数（减少本评论 + 所有子回复数量）
        if let post = try await ForumPost.find(comment.postId, on: req.db) {
            post.commentCount = max(0, post.commentCount - 1 - replyCount)
            try await post.save(on: req.db)
        }
        
        try await comment.delete(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 评论点赞
    @Sendable
    func toggleCommentLike(req: Request) async throws -> CommentLikeResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let commentIdStr = req.parameters.get("commentId"),
              let commentId = Int64(commentIdStr) else {
            throw Abort(.badRequest, reason: "无效的评论ID")
        }
        
        guard let comment = try await PostComment.find(commentId, on: req.db) else {
            throw Abort(.notFound, reason: "评论不存在")
        }
        
        if let existingLike = try await CommentLike.query(on: req.db)
            .filter(\.$commentId == commentId)
            .filter(\.$userId == userId)
            .first() {
            // 取消点赞
            try await existingLike.delete(on: req.db)
            let currentCount = comment.likeCount ?? 0
            comment.likeCount = max(0, currentCount - 1)
            try await comment.save(on: req.db)
            
            return CommentLikeResponse(isLiked: false, likeCount: comment.likeCount ?? 0)
        } else {
            // 点赞
            let like = CommentLike(commentId: commentId, userId: userId)
            try await like.save(on: req.db)
            comment.likeCount = (comment.likeCount ?? 0) + 1
            try await comment.save(on: req.db)
            
            // 创建通知（不给自己发通知）
            if userId != comment.authorId {
                do {
                    let notification = UserNotification(
                        receiverId: comment.authorId,
                        senderId: userId,
                        notificationType: "COMMENT_LIKE",
                        postId: comment.postId,
                        commentId: commentId
                    )
                    try await notification.save(on: req.db)
                } catch {
                    // 忽略通知创建错误
                    req.logger.warning("创建评论点赞通知失败: \(error)")
                }
            }
            
            return CommentLikeResponse(isLiked: true, likeCount: comment.likeCount ?? 0)
        }
    }
    
    // MARK: - 我的帖子
    @Sendable
    func getMyPosts(req: Request) async throws -> PageResponse<ForumPostDTO> {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        
        let total = try await ForumPost.query(on: req.db)
            .filter(\.$authorId == userId)
            .count()
        
        let posts = try await ForumPost.query(on: req.db)
            .filter(\.$authorId == userId)
            .sort(\.$createdAt, .descending)
            .range((page * size)..<((page + 1) * size))
            .all()
        
        let author = try await User.find(userId, on: req.db)
        
        // 批量查询图片
        let postIds = posts.compactMap { $0.id }
        let allImages = try await PostImage.query(on: req.db)
            .filter(\.$postId ~~ postIds)
            .all()
        let imageMap = Dictionary(grouping: allImages, by: { $0.postId })
        
        let postDTOs: [ForumPostDTO] = posts.map { post in
            ForumPostDTO.from(post, author: author, images: imageMap[post.id!] ?? [])
        }
        
        return PageResponse(content: postDTOs, page: page, size: size, total: total)
    }
    
    // MARK: - 我的收藏
    @Sendable
    func getFavorites(req: Request) async throws -> PageResponse<ForumPostDTO> {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        
        let favorites = try await PostFavorite.query(on: req.db)
            .filter(\.$userId == userId)
            .sort(\.$createdAt, .descending)
            .range((page * size)..<((page + 1) * size))
            .all()
        
        let total = try await PostFavorite.query(on: req.db)
            .filter(\.$userId == userId)
            .count()
        
        let postIds = favorites.map { $0.postId }
        
        // 批量查询所有帖子
        let posts = try await ForumPost.query(on: req.db)
            .filter(\.$id ~~ postIds)
            .all()
        let postMap = Dictionary(uniqueKeysWithValues: posts.compactMap { p -> (Int64, ForumPost)? in
            guard let id = p.id else { return nil }
            return (id, p)
        })
        
        // 批量查询所有作者
        let authorIds = Array(Set(posts.map { $0.authorId }))
        let authors = try await User.query(on: req.db)
            .filter(\.$id ~~ authorIds)
            .all()
        let authorMap = Dictionary(uniqueKeysWithValues: authors.compactMap { u -> (Int64, User)? in
            guard let id = u.id else { return nil }
            return (id, u)
        })
        
        // 批量查询所有图片
        let allImages = try await PostImage.query(on: req.db)
            .filter(\.$postId ~~ postIds)
            .all()
        let imageMap = Dictionary(grouping: allImages, by: { $0.postId })
        
        var postDTOs: [ForumPostDTO] = []
        for favorite in favorites {
            if let post = postMap[favorite.postId] {
                postDTOs.append(ForumPostDTO.from(
                    post,
                    author: authorMap[post.authorId],
                    images: imageMap[post.id!] ?? [],
                    isFavorited: true
                ))
            }
        }
        
        return PageResponse(content: postDTOs, page: page, size: size, total: total)
    }
    
    // MARK: - 搜索帖子（小红书式全维度搜索）
    @Sendable
    func searchPosts(req: Request) async throws -> PageResponse<ForumPostDTO> {
        let keyword = (try? req.query.get(String.self, at: "keyword")) ?? ""
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        let sortBy = (try? req.query.get(String.self, at: "sort")) ?? "hot"  // hot 或 latest
        let mediaType = try? req.query.get(String.self, at: "mediaType")  // IMAGE 或 VIDEO
        
        // 1. 处理搜索关键词（忽略大小写，去除多余空格）
        let searchKeyword = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        
        // 2. 同义词扩展（鹦鹉品种常用别名）
        let synonyms = Self.getSynonyms(for: searchKeyword)
        let allKeywords = [searchKeyword] + synonyms
        
        var matchedPostIds: Set<Int64> = []
        var postScores: [Int64: Double] = [:]  // 权重分数
        
        if !searchKeyword.isEmpty {
            // 3. 全维度搜索 - 获取所有帖子进行全字段匹配
            let allPosts = try await ForumPost.query(on: req.db).all()
            
            for post in allPosts {
                guard let postId = post.id else { continue }
                var score: Double = 0
                var matched = false
                
                for kw in allKeywords {
                    // 3.1 搜索帖子内容（最高权重）
                    if post.content.lowercased().contains(kw) {
                        matched = true
                        // 计算关键词占比权重
                        let ratio = Double(kw.count) / Double(max(post.content.count, 1))
                        score += 100 * ratio + 50
                    }
                    
                    // 3.2 搜索鸟名
                    if let birdName = post.birdName, birdName.lowercased().contains(kw) {
                        matched = true
                        score += 80
                    }
                    
                    // 3.3 搜索鸟品种
                    if let birdSpecies = post.birdSpecies, birdSpecies.lowercased().contains(kw) {
                        matched = true
                        score += 80
                    }
                    
                    // 3.4 搜索位置名称
                    if let locationName = post.locationName, locationName.lowercased().contains(kw) {
                        matched = true
                        score += 40
                    }
                    
                    // 3.5 搜索丢失地点
                    if let lostLocation = post.lostLocation, lostLocation.lowercased().contains(kw) {
                        matched = true
                        score += 40
                    }
                    
                    // 3.6 搜索多鸟信息
                    if let birdsInfo = post.birdsInfo, birdsInfo.lowercased().contains(kw) {
                        matched = true
                        score += 60
                    }
                }
                
                if matched {
                    matchedPostIds.insert(postId)
                    
                    // 4. 计算综合权重分数（小红书排序规则）
                    // 4.1 互动权重（60%）：点赞 > 收藏隐式权重 > 评论 > 浏览
                    let interactionScore = Double(post.likeCount) * 3.0 +
                                          Double(post.commentCount) * 2.0 +
                                          Double(post.viewCount) * 0.1
                    
                    // 4.2 时效权重：7天内的内容加权
                    var timeWeight: Double = 1.0
                    if let createdAt = post.createdAt {
                        let daysSinceCreation = Date().timeIntervalSince(createdAt) / 86400
                        if daysSinceCreation <= 7 {
                            timeWeight = 2.0
                        } else if daysSinceCreation <= 30 {
                            timeWeight = 1.5
                        }
                    }
                    
                    // 4.3 内容质量权重：视频/有图片的帖子加权
                    var qualityWeight: Double = 1.0
                    if post.mediaType == "VIDEO" {
                        qualityWeight = 1.3
                    }
                    
                    postScores[postId] = score + interactionScore * timeWeight * qualityWeight
                }
            }
            
            // 5. 搜索作者昵称
            let matchedUsers = try await User.query(on: req.db).all().filter { user in
                let nickname = user.nickname
                guard !nickname.isEmpty else { return false }
                return allKeywords.contains { nickname.lowercased().contains($0) }
            }
            
            for user in matchedUsers {
                guard let userId = user.id else { continue }
                let userPosts = try await ForumPost.query(on: req.db)
                    .filter(\.$authorId == userId)
                    .all()
                for post in userPosts {
                    if let postId = post.id {
                        matchedPostIds.insert(postId)
                        postScores[postId, default: 0] += 70  // 作者匹配权重
                    }
                }
            }
            
            // 6. 搜索评论内容
            let matchedComments = try await PostComment.query(on: req.db).all().filter { comment in
                allKeywords.contains { comment.content.lowercased().contains($0) }
            }
            
            for comment in matchedComments {
                matchedPostIds.insert(comment.postId)
                postScores[comment.postId, default: 0] += 30  // 评论匹配权重较低
            }
        }
        
        // 7. 获取匹配的帖子
        var posts: [ForumPost]
        
        if searchKeyword.isEmpty {
            // 无关键词时返回热门内容
            posts = try await ForumPost.query(on: req.db)
                .sort(\.$likeCount, .descending)
                .sort(\.$createdAt, .descending)
                .all()
        } else if matchedPostIds.isEmpty {
            // 无结果兜底：返回相关热门内容
            posts = try await ForumPost.query(on: req.db)
                .sort(\.$likeCount, .descending)
                .limit(size)
                .all()
        } else {
            posts = try await ForumPost.query(on: req.db)
                .filter(\.$id ~~ Array(matchedPostIds))
                .all()
        }
        
        // 8. 媒体类型筛选
        if let mediaFilter = mediaType, !mediaFilter.isEmpty {
            posts = posts.filter { $0.mediaType == mediaFilter }
        }
        
        // 9. 排序
        if sortBy == "latest" {
            // 最新排序
            posts.sort { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        } else {
            // 最热排序（按权重分数）
            posts.sort { (postScores[$0.id ?? 0] ?? 0) > (postScores[$1.id ?? 0] ?? 0) }
        }
        
        // 10. 分页
        let total = posts.count
        let startIndex = page * size
        let endIndex = min(startIndex + size, total)
        let pagedPosts = startIndex < total ? Array(posts[startIndex..<endIndex]) : []
        
        // 11. 构建响应
        let currentUserId = req.auth.get(AuthPayload.self)?.userId
        
        var postDTOs: [ForumPostDTO] = []
        for post in pagedPosts {
            let author = try await User.find(post.authorId, on: req.db)
            let images = try await PostImage.query(on: req.db)
                .filter(\.$postId == post.id!)
                .all()
            
            var isLiked = false
            var isFavorited = false
            
            if let userId = currentUserId {
                isLiked = try await PostLike.query(on: req.db)
                    .filter(\.$postId == post.id!)
                    .filter(\.$userId == userId)
                    .first() != nil
                
                isFavorited = try await PostFavorite.query(on: req.db)
                    .filter(\.$postId == post.id!)
                    .filter(\.$userId == userId)
                    .first() != nil
            }
            
            postDTOs.append(ForumPostDTO.from(
                post,
                author: author,
                images: images,
                isLiked: isLiked,
                isFavorited: isFavorited
            ))
        }
        
        // 记录搜索行为日志（用于热搜统计和搜索质量分析）
        if !searchKeyword.isEmpty {
            let currentUserId = req.auth.get(AuthPayload.self)?.userId
            await req.behaviorService.recordSearch(
                userId: currentUserId,
                keyword: searchKeyword,
                resultCount: total,
                scene: "search"
            )
        }
        
        return PageResponse(content: postDTOs, page: page, size: size, total: total)
    }
    
    // MARK: - 同义词/近义词映射（鹦鹉领域）
    private static func getSynonyms(for keyword: String) -> [String] {
        let synonymMap: [String: [String]] = [
            // 品种别名
            "玄凤": ["鸡尾鹦鹉", "卡美"],
            "虎皮": ["虎皮鹦鹉", "娇凤"],
            "牡丹": ["牡丹鹦鹉", "情侣鹦鹉", "爱情鸟"],
            "金刚": ["金刚鹦鹉"],
            "灰鹦鹉": ["非洲灰鹦鹉", "灰机"],
            "小太阳": ["太阳锥尾", "金太阳", "绿颊锥尾"],
            "和尚": ["和尚鹦鹉", "贵格"],
            "凯克": ["凯克鹦鹉", "金头凯克", "黑头凯克"],
            "亚历山大": ["亚历山大鹦鹉"],
            "折衷": ["折衷鹦鹉"],
            
            // 行为/话题同义词
            "喂食": ["饲养", "投喂", "喂养", "吃"],
            "生病": ["治病", "病症", "养护", "疾病", "不舒服"],
            "掉毛": ["换毛", "脱毛", "羽毛"],
            "训练": ["驯养", "教学", "互动"],
            "笼子": ["笼具", "鸟笼", "站架"],
            "食物": ["鸟粮", "饲料", "零食", "水果"],
            "断奶": ["断奶期", "手养", "奶粉"],
            "叫声": ["鸣叫", "唱歌", "说话"],
            "繁殖": ["配对", "下蛋", "孵化", "育雏"]
        ]
        
        for (key, values) in synonymMap {
            if keyword.contains(key) {
                return values
            }
            for value in values {
                if keyword.contains(value) {
                    return [key] + values.filter { $0 != value }
                }
            }
        }
        
        return []
    }
    
    // MARK: - 获取关注用户的帖子
    @Sendable
    func getFollowingPosts(req: Request) async throws -> PageResponse<ForumPostDTO> {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        
        // 获取关注的用户ID列表
        let followingIds = try await UserFollow.query(on: req.db)
            .filter(\.$followerId == userId)
            .all()
            .map { $0.followingId }
        
        if followingIds.isEmpty {
            return PageResponse(content: [], page: page, size: size, total: 0)
        }
        
        let total = try await ForumPost.query(on: req.db)
            .filter(\.$authorId ~~ followingIds)
            .count()
        
        let posts = try await ForumPost.query(on: req.db)
            .filter(\.$authorId ~~ followingIds)
            .sort(\.$createdAt, .descending)
            .range((page * size)..<((page + 1) * size))
            .all()
        
        // 批量查询优化
        let postIds = posts.compactMap { $0.id }
        let authorIds = Array(Set(posts.map { $0.authorId }))
        
        let authors = try await User.query(on: req.db)
            .filter(\.$id ~~ authorIds)
            .all()
        let authorMap = Dictionary(uniqueKeysWithValues: authors.compactMap { u -> (Int64, User)? in
            guard let id = u.id else { return nil }
            return (id, u)
        })
        
        let allImages = try await PostImage.query(on: req.db)
            .filter(\.$postId ~~ postIds)
            .all()
        let imageMap = Dictionary(grouping: allImages, by: { $0.postId })
        
        // 当前用户的点赞/收藏状态
        let likedPosts = try await PostLike.query(on: req.db)
            .filter(\.$postId ~~ postIds)
            .filter(\.$userId == userId)
            .all()
        let likedSet = Set(likedPosts.map { $0.postId })
        
        let favoritedPosts = try await PostFavorite.query(on: req.db)
            .filter(\.$postId ~~ postIds)
            .filter(\.$userId == userId)
            .all()
        let favoritedSet = Set(favoritedPosts.map { $0.postId })
        
        let postDTOs: [ForumPostDTO] = posts.map { post in
            let postId = post.id!
            return ForumPostDTO.from(
                post,
                author: authorMap[post.authorId],
                images: imageMap[postId] ?? [],
                isLiked: likedSet.contains(postId),
                isFavorited: favoritedSet.contains(postId),
                isFollowing: true  // 关注流中的帖子作者必然已被关注
            )
        }
        
        return PageResponse(content: postDTOs, page: page, size: size, total: total)
    }
    
    // MARK: - 获取某用户的帖子
    @Sendable
    func getUserPosts(req: Request) async throws -> PageResponse<ForumPostDTO> {
        guard let userIdStr = req.parameters.get("userId"),
              let targetUserId = Int64(userIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        let page = (try? req.query.get(Int.self, at: "page")) ?? 0
        let size = (try? req.query.get(Int.self, at: "size")) ?? 20
        
        let total = try await ForumPost.query(on: req.db)
            .filter(\.$authorId == targetUserId)
            .count()
        
        let posts = try await ForumPost.query(on: req.db)
            .filter(\.$authorId == targetUserId)
            .sort(\.$createdAt, .descending)
            .range((page * size)..<((page + 1) * size))
            .all()
        
        let author = try await User.find(targetUserId, on: req.db)
        
        // 批量查询图片
        let postIds = posts.compactMap { $0.id }
        let allImages = try await PostImage.query(on: req.db)
            .filter(\.$postId ~~ postIds)
            .all()
        let imageMap = Dictionary(grouping: allImages, by: { $0.postId })
        
        let postDTOs: [ForumPostDTO] = posts.map { post in
            ForumPostDTO.from(post, author: author, images: imageMap[post.id!] ?? [])
        }
        
        return PageResponse(content: postDTOs, page: page, size: size, total: total)
    }
    
    // MARK: - 检查重复帖子
    @Sendable
    func checkDuplicate(req: Request) async throws -> [String: Bool] {
        let userId = try req.auth.require(AuthPayload.self).userId
        let content = try req.query.get(String.self, at: "content")
        
        // 检查最近5分钟内是否有相同内容的帖子
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        
        let exists = try await ForumPost.query(on: req.db)
            .filter(\.$authorId == userId)
            .filter(\.$content == content)
            .filter(\.$createdAt >= fiveMinutesAgo)
            .first() != nil
        
        return ["duplicate": exists]
    }
    
    // MARK: - 获取热搜词
    @Sendable
    func getHotKeywords(req: Request) async throws -> [String] {
        let limit = (try? req.query.get(Int.self, at: "limit")) ?? 10
        return try await req.behaviorService.getHotSearchKeywords(limit: limit)
    }
    
    // MARK: - 获取相似帖子推荐
    @Sendable
    func getSimilarPosts(req: Request) async throws -> [ForumPostDTO] {
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        let limit = (try? req.query.get(Int.self, at: "limit")) ?? 6
        
        let posts = try await req.recommendationService.getSimilarPosts(postId: postId, limit: limit)
        
        let currentUserId = req.auth.get(AuthPayload.self)?.userId
        
        var postDTOs: [ForumPostDTO] = []
        for post in posts {
            let author = try await User.find(post.authorId, on: req.db)
            let images = try await PostImage.query(on: req.db)
                .filter(\.$postId == post.id!)
                .all()
            
            var isLiked = false
            var isFavorited = false
            
            if let userId = currentUserId {
                isLiked = try await PostLike.query(on: req.db)
                    .filter(\.$postId == post.id!)
                    .filter(\.$userId == userId)
                    .first() != nil
                
                isFavorited = try await PostFavorite.query(on: req.db)
                    .filter(\.$postId == post.id!)
                    .filter(\.$userId == userId)
                    .first() != nil
            }
            
            postDTOs.append(ForumPostDTO.from(
                post,
                author: author,
                images: images,
                isLiked: isLiked,
                isFavorited: isFavorited
            ))
        }
        
        return postDTOs
    }
    
    // MARK: - 举报帖子
    @Sendable
    func reportPost(req: Request) async throws -> ReportResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        struct ReportRequest: Content {
            let reason: String?
        }
        
        let input = try req.content.decode(ReportRequest.self)
        
        // 检查帖子是否存在
        guard try await ForumPost.find(postId, on: req.db) != nil else {
            throw Abort(.notFound, reason: "帖子不存在")
        }
        
        // 检查是否已举报
        let existingReport = try await PostReport.query(on: req.db)
            .filter(\.$postId == postId)
            .filter(\.$reporterId == userId)
            .first()
        
        if existingReport != nil {
            return ReportResponse(success: true, message: "您已举报过该帖子")
        }
        
        // 创建举报记录
        let report = PostReport(
            postId: postId,
            reporterId: userId,
            reportType: "USER_REPORT",
            reason: input.reason ?? "用户举报"
        )
        try await report.save(on: req.db)
        
        return ReportResponse(success: true, message: "举报成功，我们会尽快处理")
    }
    
    // MARK: - 标记帖子已找回
    @Sendable
    func markPostFound(req: Request) async throws -> MarkFoundResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.badRequest, reason: "无效的帖子ID")
        }
        
        guard let post = try await ForumPost.find(postId, on: req.db) else {
            throw Abort(.notFound, reason: "帖子不存在")
        }
        
        // 只有作者可以标记找回
        if post.authorId != userId {
            throw Abort(.forbidden, reason: "只有帖子作者可以标记找回")
        }
        
        // 更新帖子状态
        post.isFound = true
        try await post.save(on: req.db)
        
        return MarkFoundResponse(success: true, message: "已标记为找回")
    }
}

// MARK: - 点赞响应
struct LikeResponse: Content {
    let isLiked: Bool
    let likeCount: Int
}

// MARK: - 评论点赞响应
struct CommentLikeResponse: Content {
    let isLiked: Bool
    let likeCount: Int
}

// MARK: - 举报响应
struct ReportResponse: Content {
    let success: Bool
    let message: String
}

// MARK: - 标记找回响应
struct MarkFoundResponse: Content {
    let success: Bool
    let message: String
}

// 注意: PostReport 模型定义在 Models/PostInteractions.swift 中

