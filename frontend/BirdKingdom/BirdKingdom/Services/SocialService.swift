import Foundation
import Combine

// MARK: - 社交服务
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
    
    // 关注/粉丝列表
    @Published var followingUsers: [UserProfile] = []
    @Published var followerUsers: [UserProfile] = []
    
    // 我的帖子和收藏
    @Published var myPosts: [ForumPostDTO] = []
    @Published var myFavorites: [ForumPostDTO] = []
    
    private init() {}
    
    // MARK: - 点赞功能 (调用后端API)
    func toggleLike(postId: Int64) {
        Task {
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
    }
    
    // 本地检查是否点赞（用于UI显示）
    func isLiked(postId: Int64) -> Bool {
        likedPostIds.contains(postId)
    }
    
    // MARK: - 评论点赞功能
    func toggleCommentLike(commentId: Int64) {
        Task {
            do {
                let result = try await ApiService.shared.toggleCommentLike(commentId: commentId)
                await MainActor.run {
                    if result["isLiked"] == true {
                        likedCommentIds.insert(commentId)
                    } else {
                        likedCommentIds.remove(commentId)
                    }
                }
            } catch {
                print("评论点赞失败: \(error)")
            }
        }
    }
    
    func isCommentLiked(commentId: Int64) -> Bool {
        likedCommentIds.contains(commentId)
    }
    
    // MARK: - 收藏功能
    func toggleFavorite(postId: Int64) {
        Task {
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
                
                // 立即重新加载收藏列表
                await loadMyFavorites()
            } catch {
                print("收藏失败: \(error)")
            }
        }
    }
    
    func isFavorited(postId: Int64) -> Bool {
        favoritePostIds.contains(postId)
    }
    
    // MARK: - 关注功能
    func toggleFollow(userId: Int64, currentUserId: Int64? = nil) {
        Task {
            do {
                let result = try await ApiService.shared.toggleFollow(userId: userId)
                let isFollowing = result["isFollowing"] == true
                
                await MainActor.run {
                    if isFollowing {
                        followingUserIds.insert(userId)
                        followingCount += 1
                    } else {
                        followingUserIds.remove(userId)
                        followingCount = max(0, followingCount - 1)
                    }
                }
                
                // 立即重新加载关注列表
                if let uid = currentUserId {
                    await loadFollowingUsers(userId: uid)
                }
            } catch {
                print("关注失败: \(error)")
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
    func loadMyPosts(userId: Int64) async {
        do {
            let page = try await ApiService.shared.getUserPosts(userId: userId)
            await MainActor.run {
                myPosts = page.content
            }
        } catch {
            print("加载我的帖子失败: \(error)")
        }
    }
    
    // MARK: - 加载我的收藏
    func loadMyFavorites() async {
        do {
            let page = try await ApiService.shared.getFavorites()
            await MainActor.run {
                myFavorites = page.content
                favoritePostIds = Set(page.content.map { $0.id })
            }
        } catch {
            print("加载我的收藏失败: \(error)")
        }
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
}

// MARK: - 用户简介模型
struct UserProfile: Identifiable {
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
