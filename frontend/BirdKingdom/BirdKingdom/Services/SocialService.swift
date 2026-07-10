import Foundation
import Combine

// MARK: - 社交服务
@MainActor  // Fix #1: 确保所有 @Published 属性和方法都在主线程执行
class SocialService: ObservableObject {
    static let shared = SocialService()
    
    // 点赞的帖子 (Int64 for backend IDs)
    @Published var likedPostIds: Set<Int64> = []
    // 收藏的帖子
    @Published var favoritePostIds: Set<Int64> = []
    // 点赞的评论
    @Published var likedCommentIds: Set<Int64> = []
    // 关注的用户
    @Published var followingUserIds: Set<Int64> = []
    
    // 统计数据
    @Published var followingCount: Int = 0
    @Published var followerCount: Int = 0
    
    // P2-07: 防抖控制 - Fix #8: 使用 Task 而非 Timer
    private var likeTasks: [Int64: Task<Void, Never>] = [:]
    private var favoriteTasks: [Int64: Task<Void, Never>] = [:]
    private var followTasks: [Int64: Task<Void, Never>] = [:] // Fix #9
    private let debounceInterval: UInt64 = 500_000_000 // 500ms in nanoseconds
    
    // #9 FIX: 操作序列号 - 用于防止竞态条件
    // 每次操作递增，只有序列号匹配的响应才会被应用
    private var likeSequence: [Int64: Int] = [:]
    private var favoriteSequence: [Int64: Int] = [:]
    private var followSequence: [Int64: Int] = [:]
    
    // 关注/粉丝列表
    @Published var followingUsers: [UserProfile] = []
    @Published var followerUsers: [UserProfile] = []
    
    // 我的帖子和收藏
    @Published var myPosts: [ForumPostDTO] = []
    @Published var myFavorites: [ForumPostDTO] = []
    
    private init() {}
    
    // MARK: - 点赞功能 (Fix #8: 使用 Task 防抖替代 Timer，避免主线程阻塞)
    // Fix #10 & #20: 同步更新 PostStore 保证状态一致性
    func toggleLike(postId: Int64) {
        // 取消之前的 Task（防抖）
        likeTasks[postId]?.cancel()
        
        // 记录原始状态用于回滚
        let wasLiked = likedPostIds.contains(postId)
        
        // 立即更新本地UI状态（Optimistic Update）
        if wasLiked {
            likedPostIds.remove(postId)
            PostStore.shared.updateLikeCount(postId: postId, delta: -1) // Fix #10
        } else {
            likedPostIds.insert(postId)
            PostStore.shared.updateLikeCount(postId: postId, delta: 1) // Fix #10
        }
        
        // 延迟发送请求（防抖）
        likeTasks[postId] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.debounceInterval ?? 500_000_000)
                guard !Task.isCancelled else { return }
                
                let result = try await ApiService.shared.togglePostLike(postId: postId)
                
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    // 同步服务器状态
                    let serverLiked = result["isLiked"] == true
                    if serverLiked {
                        self?.likedPostIds.insert(postId)
                    } else {
                        self?.likedPostIds.remove(postId)
                    }
                    self?.likeTasks.removeValue(forKey: postId)
                }
            } catch {
                if Task.isCancelled { return }
                print("点赞失败: \(error)")
                // 网络失败时回滚到原始状态
                await MainActor.run {
                    if wasLiked {
                        self?.likedPostIds.insert(postId)
                        PostStore.shared.updateLikeCount(postId: postId, delta: 1) // 回滚
                    } else {
                        self?.likedPostIds.remove(postId)
                        PostStore.shared.updateLikeCount(postId: postId, delta: -1) // 回滚
                    }
                    self?.likeTasks.removeValue(forKey: postId)
                }
            }
        }
    }
    
    // 本地检查是否点赞（用于UI显示）
    func isLiked(postId: Int64) -> Bool {
        likedPostIds.contains(postId)
    }
    
    // 异步版本的点赞（用于需要等待结果的场景）
    func toggleLikeAsync(postId: Int64) async {
        do {
            let result = try await ApiService.shared.togglePostLike(postId: postId)
            await MainActor.run {
                if result["isLiked"] == true {
                    likedPostIds.insert(postId)
                } else {
                    likedPostIds.remove(postId)
                }
            }
        } catch {
            print("点赞失败: \(error)")
        }
    }
    
    // MARK: - 评论点赞功能 - Fix A3: 添加 Optimistic Update 和回滚机制
    func toggleCommentLike(commentId: Int64) {
        // 记录原始状态用于回滚
        let wasLiked = likedCommentIds.contains(commentId)
        
        // Optimistic Update
        if wasLiked {
            likedCommentIds.remove(commentId)
        } else {
            likedCommentIds.insert(commentId)
        }
        
        Task {
            do {
                let result = try await ApiService.shared.toggleCommentLike(commentId: commentId)
                // 同步服务器状态
                if result["isLiked"] == true {
                    likedCommentIds.insert(commentId)
                } else {
                    likedCommentIds.remove(commentId)
                }
            } catch {
                print("评论点赞失败: \(error)")
                // Fix A3: 回滚到原始状态
                if wasLiked {
                    likedCommentIds.insert(commentId)
                } else {
                    likedCommentIds.remove(commentId)
                }
            }
        }
    }
    
    func isCommentLiked(commentId: Int64) -> Bool {
        likedCommentIds.contains(commentId)
    }
    
    // MARK: - 收藏功能 - Fix #2: 添加 Optimistic Update 和回滚机制
    func toggleFavorite(postId: Int64) {
        // 记录原始状态用于回滚
        let wasFavorited = favoritePostIds.contains(postId)
        // 保存被移除的帖子用于回滚
        let removedPost = myFavorites.first { $0.id == postId }
        
        // Optimistic Update - 即刻更新 UI
        if wasFavorited {
            favoritePostIds.remove(postId)
            // 即刻从收藏列表中移除
            removeFavoriteImmediately(postId: postId)
        } else {
            favoritePostIds.insert(postId)
            // 收藏时需要异步获取帖子详情后添加到列表
        }
        
        Task {
            do {
                let result = try await ApiService.shared.togglePostFavorite(postId: postId)
                let isFavorited = result["isFavorited"] == true
                
                // 同步服务器状态
                if isFavorited {
                    favoritePostIds.insert(postId)
                    // 收藏成功，获取帖子详情并添加到列表
                    let postDTO = try await ApiService.shared.getPost(postId: postId)
                    await MainActor.run {
                        addFavoriteImmediately(postDTO)
                    }
                } else {
                    favoritePostIds.remove(postId)
                    // 已在上面即刻移除，无需再次操作
                }
            } catch {
                print("收藏失败: \(error)")
                // 回滚到原始状态
                await MainActor.run {
                    if wasFavorited {
                        favoritePostIds.insert(postId)
                        // 回滚：将帖子添加回收藏列表
                        if let post = removedPost {
                            addFavoriteImmediately(post)
                        }
                    } else {
                        favoritePostIds.remove(postId)
                        // 回滚：移除刚添加的帖子
                        removeFavoriteImmediately(postId: postId)
                    }
                }
            }
        }
    }
    
    func isFavorited(postId: Int64) -> Bool {
        favoritePostIds.contains(postId)
    }
    
    // 异步版本的收藏（用于需要等待结果的场景）
    func toggleFavoriteAsync(postId: Int64) async {
        do {
            let result = try await ApiService.shared.togglePostFavorite(postId: postId)
            let isFavorited = result["isFavorited"] == true
            
            await MainActor.run {
                if isFavorited {
                    favoritePostIds.insert(postId)
                } else {
                    favoritePostIds.remove(postId)
                }
            }
            
            // 重新加载收藏列表
            await loadMyFavorites()
        } catch {
            print("收藏失败: \(error)")
        }
    }
    
    // MARK: - 关注功能 (Fix #9: 添加 Optimistic Update、回滚机制和序列号保护)
    func toggleFollow(userId: Int64, currentUserId: Int64? = nil) {
        // 取消之前的 Task
        followTasks[userId]?.cancel()
        
        // #9 FIX: 递增序列号，标记此次操作
        let currentSequence = (followSequence[userId] ?? 0) + 1
        followSequence[userId] = currentSequence
        
        // 记录原始状态用于回滚
        let wasFollowing = followingUserIds.contains(userId)
        let originalFollowingCount = followingCount
        
        // Fix #9: Optimistic Update - 立即更新UI
        if wasFollowing {
            followingUserIds.remove(userId)
            followingCount = max(0, followingCount - 1)
        } else {
            followingUserIds.insert(userId)
            followingCount += 1
        }
        
        followTasks[userId] = Task { [weak self] in
            do {
                let result = try await ApiService.shared.toggleFollow(userId: userId)
                let isFollowing = result["isFollowing"] == true
                
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    // #9 FIX: 只有序列号匹配时才应用服务器响应
                    guard self?.followSequence[userId] == currentSequence else {
                        print("⚠️ 忽略过时的关注响应 (seq: \(currentSequence))")
                        return
                    }
                    
                    // 同步服务器状态
                    if isFollowing {
                        self?.followingUserIds.insert(userId)
                    } else {
                        self?.followingUserIds.remove(userId)
                    }
                    self?.followTasks.removeValue(forKey: userId)
                }
                
                // 立即重新加载关注列表
                if let uid = currentUserId {
                    await self?.loadFollowingUsers(userId: uid)
                }
            } catch {
                if Task.isCancelled { return }
                print("关注失败: \(error)")
                
                // #9 FIX: 只有序列号匹配时才回滚
                await MainActor.run {
                    guard self?.followSequence[userId] == currentSequence else {
                        print("⚠️ 忽略过时的关注回滚 (seq: \(currentSequence))")
                        return
                    }
                    
                    if wasFollowing {
                        self?.followingUserIds.insert(userId)
                    } else {
                        self?.followingUserIds.remove(userId)
                    }
                    self?.followingCount = originalFollowingCount
                    self?.followTasks.removeValue(forKey: userId)
                }
            }
        }
    }
    
    func isFollowing(userId: Int64) -> Bool {
        followingUserIds.contains(userId)
    }
    
    // MARK: - 加载关注/粉丝列表
    func loadFollowingUsers(userId: Int64) async {
        do {
            let page = try await ApiService.shared.getFollowing(userId: userId)
            let users = page.content.map { dto in
                UserProfile(
                    id: dto.id,
                    nickname: dto.nickname ?? "用户",
                    avatar: dto.avatarUrl,
                    bio: dto.bio,
                    birdCount: dto.birdCount ?? 0,
                    postCount: dto.postCount ?? 0,
                    followerCount: dto.followerCount ?? 0,
                    followingCount: dto.followingCount ?? 0
                )
            }
            await MainActor.run {
                followingUsers = users
                followingCount = page.totalElements
            }
        } catch {
            print("加载关注列表失败: \(error)")
        }
    }
    
    func loadFollowerUsers(userId: Int64) async {
        do {
            let page = try await ApiService.shared.getFollowers(userId: userId)
            let users = page.content.map { dto in
                UserProfile(
                    id: dto.id,
                    nickname: dto.nickname ?? "用户",
                    avatar: dto.avatarUrl,
                    bio: dto.bio,
                    birdCount: dto.birdCount ?? 0,
                    postCount: dto.postCount ?? 0,
                    followerCount: dto.followerCount ?? 0,
                    followingCount: dto.followingCount ?? 0
                )
            }
            await MainActor.run {
                followerUsers = users
                followerCount = page.totalElements
            }
        } catch {
            print("加载粉丝列表失败: \(error)")
        }
    }
    
    // MARK: - 加载我的帖子
    func loadMyPosts() async {
        do {
            print("📤 加载我的帖子...")
            let page = try await ApiService.shared.getMyPosts()
            await MainActor.run {
                myPosts = page.content
                print("✅ 我的帖子加载完成: \(page.content.count) 条")
            }
        } catch {
            print("❌ 加载我的帖子失败: \(error)")
        }
    }
    
    // MARK: - 插入新帖子到我的帖子列表
    /// 发帖成功后调用此方法，将新帖子插入到 myPosts 列表开头
    func insertNewPost(_ postDTO: ForumPostDTO) {
        myPosts.insert(postDTO, at: 0)
        print("✅ 新帖子已插入到我的帖子列表，当前共 \(myPosts.count) 条")
    }
    
    // MARK: - 加载我的收藏
    func loadMyFavorites() async {
        do {
            print("📤 加载我的收藏...")
            let page = try await ApiService.shared.getFavorites()
            await MainActor.run {
                myFavorites = page.content
                favoritePostIds = Set(page.content.map { $0.id })
                print("✅ 我的收藏加载完成: \(page.content.count) 条")
            }
        } catch {
            print("❌ 加载我的收藏失败: \(error)")
        }
    }
    
    // MARK: - 即刻更新收藏列表（Optimistic Update）
    /// 从收藏列表中移除指定帖子（取消收藏时调用）
    func removeFavoriteImmediately(postId: Int64) {
        myFavorites.removeAll { $0.id == postId }
        print("✅ 已从收藏列表中移除帖子 \(postId)，当前共 \(myFavorites.count) 条")
    }
    
    /// 添加帖子到收藏列表（收藏时调用，需要帖子 DTO）
    func addFavoriteImmediately(_ postDTO: ForumPostDTO) {
        // 避免重复添加
        guard !myFavorites.contains(where: { $0.id == postDTO.id }) else { return }
        myFavorites.insert(postDTO, at: 0)
        print("✅ 已添加帖子到收藏列表，当前共 \(myFavorites.count) 条")
    }
    
    // MARK: - 即刻更新我的帖子列表
    /// 从我的帖子列表中删除指定帖子（删除帖子时调用）
    func removeMyPostImmediately(postId: Int64) {
        myPosts.removeAll { $0.id == postId }
        print("✅ 已从我的帖子列表中移除帖子 \(postId)，当前共 \(myPosts.count) 条")
    }
    
    // MARK: - 加载关注统计
    func loadFollowStats(userId: Int64) async {
        do {
            let stats = try await ApiService.shared.getFollowStats(userId: userId)
            await MainActor.run {
                followingCount = stats["followingCount"] ?? 0
                followerCount = stats["followerCount"] ?? 0
            }
        } catch {
            print("加载关注统计失败: \(error)")
        }
    }
    
    // MARK: - 清除所有数据（退出登录时调用）
    // Fix E2: 先取消所有进行中的 Task，再清理数据
    func clearAllData() {
        // 取消所有进行中的点赞/收藏/关注 Task
        likeTasks.values.forEach { $0.cancel() }
        likeTasks.removeAll()
        favoriteTasks.values.forEach { $0.cancel() }
        favoriteTasks.removeAll()
        followTasks.values.forEach { $0.cancel() }
        followTasks.removeAll()
        
        // #9 FIX: 清除序列号映射
        likeSequence.removeAll()
        favoriteSequence.removeAll()
        followSequence.removeAll()
        
        // 清除数据
        likedPostIds.removeAll()
        favoritePostIds.removeAll()
        likedCommentIds.removeAll()
        followingUserIds.removeAll()
        followingCount = 0
        followerCount = 0
        followingUsers.removeAll()
        followerUsers.removeAll()
        myPosts.removeAll()
        myFavorites.removeAll()
        print("🗑️ 已清除社交数据（含取消进行中的 Task 和序列号）")
    }
    // MARK: - 举报和拉黑功能 (UGC合规) - S-03/S-04已实现后端API
    
    // 举报帖子
    func reportPost(postId: Int64, type: String = "OTHER", reason: String, description: String? = nil) {
        Task {
            do {
                // S-03: 调用后端举报API
                let result = try await ApiService.shared.reportPost(postId: postId, type: type, reason: reason, description: description)
                print("✅ 已举报帖子: \(postId), 类型: \(type), 原因: \(reason), 结果: \(result)")
            } catch {
                print("举报失败: \(error)")
            }
        }
    }
    
    // 拉黑用户
    @Published var blockedUserIds: Set<Int64> = []
    
    func blockUser(userId: Int64) {
        Task {
            do {
                // S-04: 调用后端拉黑API
                let result = try await ApiService.shared.blockUser(userId: userId)
                let isBlocked = result["isBlocked"] ?? false
                
                await MainActor.run {
                    if isBlocked {
                        blockedUserIds.insert(userId)
                        // 移除该用户的帖子
                        myPosts.removeAll { $0.authorId == userId }
                        print("🚫 已拉黑用户: \(userId)")
                    } else {
                        blockedUserIds.remove(userId)
                        print("✅ 已取消拉黑用户: \(userId)")
                    }
                }
            } catch {
                print("拉黑操作失败: \(error)")
            }
        }
    }
    
    func isBlocked(userId: Int64) -> Bool {
        blockedUserIds.contains(userId)
    }
    
    // 加载拉黑列表
    func loadBlockedUsers() async {
        do {
            let blockedIds = try await ApiService.shared.getBlockedUsers()
            await MainActor.run {
                blockedUserIds = Set(blockedIds)
            }
        } catch {
            print("加载拉黑列表失败: \(error)")
        }
    }
}

// MARK: - 用户简介模型
struct UserProfile: Identifiable, Hashable {
    let id: Int64
    let nickname: String
    let avatar: String?
    let bio: String?
    let birdCount: Int
    let postCount: Int
    let followerCount: Int
    let followingCount: Int
    
    // 空数据占位
    static let empty: [UserProfile] = []
}

// MARK: - 用户完整统计信息模型（从API获取）
struct UserFullStats: Codable {
    let id: Int64
    let nickname: String?
    let avatarUrl: String?
    let bio: String?
    let birdCount: Int
    let postCount: Int
    let followerCount: Int
    let followingCount: Int
    let isFollowing: Bool
    
    // VIP Related Fields
    let isVip: Bool?
    let vipType: String?
    let isCoupleVip: Bool?
    let couplePartnerId: Int64?
    
    // 转换为UserProfile
    func toUserProfile() -> UserProfile {
        UserProfile(
            id: id,
            nickname: nickname ?? "用户",
            avatar: avatarUrl,
            bio: bio,
            birdCount: birdCount,
            postCount: postCount,
            followerCount: followerCount,
            followingCount: followingCount
        )
    }
}
