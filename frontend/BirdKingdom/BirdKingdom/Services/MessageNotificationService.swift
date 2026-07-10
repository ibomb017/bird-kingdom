//
//  MessageNotificationService.swift
//  BirdKingdom
//
//  用户消息通知服务（点赞、收藏、评论等）
//

import Foundation
import SwiftUI
import Combine

/// 用户消息通知服务
class MessageNotificationService: ObservableObject {
    static let shared = MessageNotificationService()
    
    @Published var notifications: [MessageNotificationItem] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    
    private var currentPage = 0
    private var hasMore = true
    
    // P1 修复：请求锁防止并发
    private var isFetching = false
    
    // P1 修复：去重集合防止重复数据
    private var seenIds: Set<Int64> = []
    
    private var baseURL: URL { AppConfig.apiBaseURL }
    
    private init() {}
    
    // MARK: - 获取通知列表
    
    func fetchNotifications(refresh: Bool = false) async throws {
        // P1 修复：防止并发请求
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        
        if refresh {
            currentPage = 0
            hasMore = true
            seenIds.removeAll()
        }
        
        guard hasMore else { return }
        
        await MainActor.run { isLoading = true }
        
        defer {
            Task { @MainActor in isLoading = false }
        }
        
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("notifications"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: String(currentPage)),
            URLQueryItem(name: "size", value: "20")
        ]
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取通知失败"])
        }
        
        let result = try JSONDecoder().decode(MessageNotificationsResponse.self, from: data)
        
        if result.code == 0 {
            // P1 修复：使用去重集合过滤重复数据
            let newItems = (result.data ?? []).filter { item in
                if seenIds.contains(item.id) {
                    return false
                }
                seenIds.insert(item.id)
                return true
            }
            
            await MainActor.run {
                if refresh {
                    self.notifications = newItems
                } else {
                    self.notifications.append(contentsOf: newItems)
                }
                // P1 修复：从通知列表计算未读数，保持一致性
                self.unreadCount = self.notifications.filter { !$0.isRead }.count
                self.hasMore = (result.data?.count ?? 0) >= 20
                self.currentPage += 1
                
                // 内存优化：如果 seenIds 过大，清理并在最近的 notification 中重建，防止无限制增长
                if self.seenIds.count > 1000 {
                    let keepCount = 500
                    let recentItems = self.notifications.suffix(keepCount)
                    self.seenIds = Set(recentItems.map { $0.id })
                }
            }
        }
    }
    
    // MARK: - 获取未读数量
    
    func fetchUnreadCount() async {
        do {
            let url = baseURL.appendingPathComponent("notifications/unread-count")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            if let token = AuthService.shared.getToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }
            
            let result = try JSONDecoder().decode(MessageUnreadCountResponse.self, from: data)
            
            if result.code == 0 {
                await MainActor.run {
                    self.unreadCount = result.data?.count ?? 0
                }
            }
        } catch {
            print("获取未读通知数量失败: \(error)")
        }
    }
    
    // MARK: - 标记全部已读
    
    func markAllAsRead() async throws {
        let url = baseURL.appendingPathComponent("notifications/mark-all-read")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "标记已读失败"])
        }
        
        await MainActor.run {
            self.unreadCount = 0
            for i in self.notifications.indices {
                self.notifications[i].isRead = true
            }
        }
    }
    
    // MARK: - 标记单条已读
    
    func markAsRead(_ notificationId: Int64) async {
        do {
            let url = baseURL.appendingPathComponent("notifications/\(notificationId)/read")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            if let token = AuthService.shared.getToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            // P1 修复：先验证后端响应成功
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("标记已读失败: 服务器返回错误")
                return
            }
            
            // 成功后再更新本地状态
            await MainActor.run {
                if let index = self.notifications.firstIndex(where: { $0.id == notificationId }) {
                    if !self.notifications[index].isRead {
                        self.notifications[index].isRead = true
                        self.unreadCount = max(0, self.unreadCount - 1)
                    }
                }
            }
        } catch {
            print("标记已读失败: \(error)")
        }
    }
}

// MARK: - 数据模型

struct MessageNotificationItem: Codable, Identifiable {
    let id: Int64
    let type: String
    let senderId: Int64?
    let senderNickname: String?
    let senderAvatar: String?
    let postId: Int64?
    let postTitle: String?
    let postImage: String?
    let commentId: Int64?
    let content: String?
    var isRead: Bool
    let createdAt: String?
    
    /// 通知类型描述
    var typeDescription: String {
        switch type {
        case "POST_LIKE": return "赞了你的帖子"
        case "POST_FAVORITE": return "收藏了你的帖子"
        case "POST_COMMENT": return "评论了你的帖子"
        case "COMMENT_REPLY": return "回复了你的评论"
        case "COMMENT_LIKE": return "赞了你的评论"
        case "NEW_FOLLOWER": return "关注了你"
        default: return "发来消息"
        }
    }
    
    /// 通知图标
    var icon: String {
        switch type {
        case "POST_LIKE": return "heart.fill"
        case "POST_FAVORITE": return "bookmark.fill"
        case "POST_COMMENT": return "bubble.left.fill"
        case "COMMENT_REPLY": return "arrowshape.turn.up.left.fill"
        case "COMMENT_LIKE": return "hand.thumbsup.fill"
        case "NEW_FOLLOWER": return "person.badge.plus"
        default: return "bell.fill"
        }
    }
    
    /// 图标颜色
    var iconColor: Color {
        switch type {
        case "POST_LIKE": return .red
        case "POST_FAVORITE": return .orange
        case "POST_COMMENT", "COMMENT_REPLY": return .blue
        case "COMMENT_LIKE": return .purple
        case "NEW_FOLLOWER": return .green
        default: return .gray
        }
    }
    
    /// 格式化时间
    var formattedTime: String {
        guard let createdAt = createdAt else { return "" }
        // 尝试多种日期格式
        let formatters: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            
            return [f1, f2]
        }()
        
        var date: Date?
        for formatter in formatters {
            if let d = formatter.date(from: createdAt) {
                date = d
                break
            }
        }
        
        guard let parsedDate = date else { return "" }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: parsedDate, to: now)
        
        if let day = components.day, day > 0 {
            if day == 1 { return "昨天" }
            if day < 7 { return "\(day)天前" }
            let df = DateFormatter()
            df.dateFormat = "MM-dd"
            return df.string(from: parsedDate)
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        } else {
            return "刚刚"
        }
    }
}

struct MessageNotificationsResponse: Codable {
    let code: Int
    let data: [MessageNotificationItem]?
    let message: String?
}

struct MessageUnreadCountData: Codable {
    let count: Int
}

struct MessageUnreadCountResponse: Codable {
    let code: Int
    let data: MessageUnreadCountData?
}
