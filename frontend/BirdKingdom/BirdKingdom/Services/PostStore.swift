import Foundation
import Combine

// MARK: - Fix B1: 使用 actor 保证原子性
// 帖子状态全局 Store（Single Source of Truth）
// 解决列表页与详情页状态不一致的问题

// 内部使用 actor 保证原子性
actor PostStoreActor {
    private(set) var likeCounts: [Int64: Int] = [:]
    private(set) var commentCounts: [Int64: Int] = [:]
    private(set) var favoriteCounts: [Int64: Int] = [:]
    
    func getLikeCount(postId: Int64) -> Int {
        likeCounts[postId] ?? 0
    }
    
    func getCommentCount(postId: Int64) -> Int {
        commentCounts[postId] ?? 0
    }
    
    func getFavoriteCount(postId: Int64) -> Int {
        favoriteCounts[postId] ?? 0
    }
    
    func setLikeCount(postId: Int64, count: Int) {
        likeCounts[postId] = count
    }
    
    func updateLikeCount(postId: Int64, delta: Int) -> Int {
        let current = likeCounts[postId] ?? 0
        let newValue = max(0, current + delta)
        likeCounts[postId] = newValue
        return newValue
    }
    
    func setCommentCount(postId: Int64, count: Int) {
        commentCounts[postId] = count
    }
    
    func updateCommentCount(postId: Int64, delta: Int) {
        let current = commentCounts[postId] ?? 0
        commentCounts[postId] = max(0, current + delta)
    }
    
    func updateFavoriteCount(postId: Int64, delta: Int) {
        let current = favoriteCounts[postId] ?? 0
        favoriteCounts[postId] = max(0, current + delta)
    }
    
    func syncFromPosts(_ posts: [(id: Int64, likeCount: Int, commentCount: Int, favoriteCount: Int)]) {
        for post in posts {
            likeCounts[post.id] = post.likeCount
            commentCounts[post.id] = post.commentCount
            favoriteCounts[post.id] = post.favoriteCount
        }
    }
    
    func removePost(postId: Int64) {
        likeCounts.removeValue(forKey: postId)
        commentCounts.removeValue(forKey: postId)
        favoriteCounts.removeValue(forKey: postId)
    }
    
    func clearAll() {
        likeCounts.removeAll()
        commentCounts.removeAll()
        favoriteCounts.removeAll()
    }
}

// 对外暴露的 ObservableObject 包装器（用于 SwiftUI 绑定）
@MainActor
class PostStore: ObservableObject {
    static let shared = PostStore()
    
    private let actor = PostStoreActor()
    
    // 用于 UI 绑定的发布属性
    @Published private(set) var likeCounts: [Int64: Int] = [:]
    @Published private(set) var commentCounts: [Int64: Int] = [:]
    @Published private(set) var favoriteCounts: [Int64: Int] = [:]
    
    private init() {}
    
    // MARK: - 同步读取（UI 使用）
    
    func getLikeCount(postId: Int64) -> Int {
        likeCounts[postId] ?? 0
    }
    
    func getCommentCount(postId: Int64) -> Int {
        commentCounts[postId] ?? 0
    }
    
    func getFavoriteCount(postId: Int64) -> Int {
        favoriteCounts[postId] ?? 0
    }
    
    // MARK: - 原子性更新操作
    
    func setLikeCount(postId: Int64, count: Int) {
        likeCounts[postId] = count
        Task {
            await actor.setLikeCount(postId: postId, count: count)
        }
    }
    
    func updateLikeCount(postId: Int64, delta: Int) {
        // 先乐观更新 UI
        let current = likeCounts[postId] ?? 0
        let newValue = max(0, current + delta)
        likeCounts[postId] = newValue
        
        // 同步到 actor
        Task {
            _ = await actor.updateLikeCount(postId: postId, delta: delta)
        }
        
        // 发送通知
        NotificationCenter.default.post(
            name: NSNotification.Name("PostLikeCountChanged"),
            object: nil,
            userInfo: ["postId": postId, "likeCount": newValue]
        )
    }
    
    func setCommentCount(postId: Int64, count: Int) {
        commentCounts[postId] = count
        Task {
            await actor.setCommentCount(postId: postId, count: count)
        }
    }
    
    func updateCommentCount(postId: Int64, delta: Int) {
        let current = commentCounts[postId] ?? 0
        commentCounts[postId] = max(0, current + delta)
        Task {
            await actor.updateCommentCount(postId: postId, delta: delta)
        }
    }
    
    func updateFavoriteCount(postId: Int64, delta: Int) {
        let current = favoriteCounts[postId] ?? 0
        favoriteCounts[postId] = max(0, current + delta)
        Task {
            await actor.updateFavoriteCount(postId: postId, delta: delta)
        }
    }
    
    // MARK: - 批量同步
    
    func syncFromPosts(_ posts: [ForumPost]) {
        for post in posts {
            likeCounts[post.id] = post.likeCount
            commentCounts[post.id] = post.commentCount
            favoriteCounts[post.id] = post.favoriteCount
        }
        Task {
            await actor.syncFromPosts(posts.map { ($0.id, $0.likeCount, $0.commentCount, $0.favoriteCount) })
        }
    }
    
    func syncFromDTOs(_ dtos: [ForumPostDTO]) {
        for dto in dtos {
            likeCounts[dto.id] = dto.likeCount ?? 0
            commentCounts[dto.id] = dto.commentCount ?? 0
        }
        Task {
            await actor.syncFromPosts(dtos.map { ($0.id, $0.likeCount ?? 0, $0.commentCount ?? 0, 0) })
        }
    }
    
    // MARK: - 清理
    
    func removePost(postId: Int64) {
        likeCounts.removeValue(forKey: postId)
        commentCounts.removeValue(forKey: postId)
        favoriteCounts.removeValue(forKey: postId)
        Task {
            await actor.removePost(postId: postId)
        }
    }
    
    func clearAll() {
        likeCounts.removeAll()
        commentCounts.removeAll()
        favoriteCounts.removeAll()
        Task {
            await actor.clearAll()
        }
    }
}
