import Vapor
import Fluent

/// 通知控制器
struct NotificationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let notifications = routes.grouped("notifications")
        let protected = notifications.grouped(JWTAuthMiddleware())
        
        protected.get(use: getNotifications)
        protected.get("unread-count", use: getUnreadCount)
        protected.post("mark-all-read", use: markAllAsRead)
        protected.post(":notificationId", "read", use: markAsRead)
    }
    
    @Sendable
    func getNotifications(req: Request) async throws -> NotificationListResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        let page = req.query[Int.self, at: "page"] ?? 0
        let size = req.query[Int.self, at: "size"] ?? 20
        
        let notifications = try await UserNotification.query(on: req.db)
            .filter(\.$receiverId == userId)
            .sort(\.$createdAt, .descending)
            .range(page * size..<(page + 1) * size)
            .all()
        
        // 收集所有需要查询的 senderId 和 postId
        let senderIds = Set(notifications.map { $0.senderId })
        let postIds = Set(notifications.compactMap { $0.postId })
        
        // 批量查询发送者信息
        let senders = try await User.query(on: req.db)
            .filter(\.$id ~~ senderIds)
            .all()
        var senderMap: [Int64: User] = [:]
        for sender in senders {
            if let id = sender.id {
                senderMap[id] = sender
            }
        }
        
        // 批量查询帖子信息
        var postMap: [Int64: ForumPost] = [:]
        var postImageMap: [Int64: String] = [:]
        if !postIds.isEmpty {
            let posts = try await ForumPost.query(on: req.db)
                .filter(\.$id ~~ postIds)
                .all()
            for post in posts {
                if let id = post.id {
                    postMap[id] = post
                }
            }
            
            // 获取帖子的第一张图片
            let postImages = try await PostImage.query(on: req.db)
                .filter(\.$postId ~~ postIds)
                .sort(\.$sortOrder, .ascending)
                .all()
            for image in postImages {
                if postImageMap[image.postId] == nil {
                    postImageMap[image.postId] = image.imageUrl
                }
            }
        }
        
        // 构建 DTO
        let items = notifications.map { notification in
            let sender = senderMap[notification.senderId]
            let post = notification.postId.flatMap { postMap[$0] }
            let postImage = notification.postId.flatMap { postImageMap[$0] }
            
            return NotificationItemDTO.from(
                notification,
                senderNickname: sender?.nickname,
                senderAvatar: sender?.avatarUrl,
                postTitle: post?.content,
                postImage: postImage
            )
        }
        
        return NotificationListResponse(code: 0, data: items)
    }
    
    @Sendable
    func getUnreadCount(req: Request) async throws -> NotificationUnreadResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let count = try await UserNotification.query(on: req.db)
            .filter(\.$receiverId == userId)
            .filter(\.$isRead == false)
            .count()
        
        return NotificationUnreadResponse(code: 0, data: NotificationCountDTO(count: count))
    }
    
    @Sendable
    func markAllAsRead(req: Request) async throws -> NotificationActionResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        try await UserNotification.query(on: req.db)
            .filter(\.$receiverId == userId)
            .filter(\.$isRead == false)
            .set(\.$isRead, to: true)
            .update()
        
        return NotificationActionResponse(code: 0, message: "success")
    }
    
    @Sendable
    func markAsRead(req: Request) async throws -> NotificationActionResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let notificationIdStr = req.parameters.get("notificationId"),
              let notificationId = Int64(notificationIdStr) else {
            throw Abort(.badRequest, reason: "无效的通知ID")
        }
        
        guard let notification = try await UserNotification.find(notificationId, on: req.db) else {
            return NotificationActionResponse(code: 404, message: "通知不存在或无权操作")
        }
        
        if notification.receiverId != userId {
            return NotificationActionResponse(code: 404, message: "通知不存在或无权操作")
        }
        
        notification.isRead = true
        try await notification.save(on: req.db)
        
        return NotificationActionResponse(code: 0, message: "success")
    }
}

// MARK: - Model
final class UserNotification: Model, Content, @unchecked Sendable {
    static let schema = "user_notification"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "receiver_id")
    var receiverId: Int64
    
    @Field(key: "sender_id")
    var senderId: Int64
    
    @Field(key: "notification_type")
    var notificationType: String
    
    @OptionalField(key: "content")
    var content: String?
    
    @OptionalField(key: "post_id")
    var postId: Int64?
    
    @OptionalField(key: "comment_id")
    var commentId: Int64?
    
    @Field(key: "is_read")
    var isRead: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, receiverId: Int64, senderId: Int64, notificationType: String,
         content: String? = nil, postId: Int64? = nil, commentId: Int64? = nil) {
        self.id = id
        self.receiverId = receiverId
        self.senderId = senderId
        self.notificationType = notificationType
        self.content = content
        self.postId = postId
        self.commentId = commentId
        self.isRead = false
    }
}

// MARK: - DTOs
struct NotificationItemDTO: Content {
    let id: Int64
    let type: String
    let senderId: Int64
    let senderNickname: String?  // 添加：发送者昵称
    let senderAvatar: String?     // 添加：发送者头像
    let postId: Int64?
    let postTitle: String?        // 添加：帖子标题（用 content 代替）
    let postImage: String?        // 添加：帖子图片
    let commentId: Int64?
    let content: String?
    var isRead: Bool
    let createdAt: Date?
    
    static func from(
        _ notification: UserNotification,
        senderNickname: String? = nil,
        senderAvatar: String? = nil,
        postTitle: String? = nil,
        postImage: String? = nil
    ) -> NotificationItemDTO {
        NotificationItemDTO(
            id: notification.id ?? 0,
            type: notification.notificationType,
            senderId: notification.senderId,
            senderNickname: senderNickname,
            senderAvatar: senderAvatar,
            postId: notification.postId,
            postTitle: postTitle ?? notification.content,
            postImage: postImage,
            commentId: notification.commentId,
            content: notification.content,
            isRead: notification.isRead,
            createdAt: notification.createdAt
        )
    }
}

struct NotificationListResponse: Content {
    let code: Int
    let data: [NotificationItemDTO]
}

struct NotificationCountDTO: Content {
    let count: Int
}

struct NotificationUnreadResponse: Content {
    let code: Int
    let data: NotificationCountDTO
}

struct NotificationActionResponse: Content {
    let code: Int
    let message: String
}
