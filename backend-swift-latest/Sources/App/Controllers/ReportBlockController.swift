import Vapor
import Fluent

/// 举报和拉黑控制器
struct ReportBlockController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // 需要认证的路由
        let protected = routes.grouped(JWTAuthMiddleware())
        
        // 举报帖子
        protected.post("forum", "posts", ":postId", "report", use: reportPost)
        
        // 拉黑用户
        protected.post("users", ":userId", "block", use: blockUser)
        
        // 检查是否拉黑
        protected.get("users", ":userId", "is-blocked", use: isBlocked)
        
        // 获取拉黑列表
        protected.get("users", "blocked", use: getBlockedUsers)
    }
    
    // MARK: - 举报响应
    struct ReportResponse: Content {
        let success: Bool
        let reported: Bool
        let reportId: Int64
        let message: String
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
            let type: String?
            let reason: String?
            let description: String?
        }
        
        let input = try req.content.decode(ReportRequest.self)
        
        // 检查是否已举报
        let existingReport = try await PostReport.query(on: req.db)
            .filter(\.$postId == postId)
            .filter(\.$reporterId == userId)
            .first()
        
        if existingReport != nil {
            throw Abort(.conflict, reason: "您已举报过此帖子")
        }
        
        // 检查帖子是否存在
        guard let post = try await ForumPost.find(postId, on: req.db) else {
            throw Abort(.notFound, reason: "帖子不存在")
        }
        
        // 不能举报自己的帖子
        if post.authorId == userId {
            throw Abort(.badRequest, reason: "不能举报自己的帖子")
        }
        
        // 创建举报
        let report = PostReport(
            postId: postId,
            reporterId: userId,
            reportType: input.type ?? "OTHER",
            reason: input.reason ?? "用户举报",
            description: input.description
        )
        try await report.save(on: req.db)
        
        // 返回详细的举报成功信息
        return ReportResponse(
            success: true,
            reported: true,
            reportId: report.id!,
            message: "感谢您的举报，我们会在24小时内审核处理，并通过消息通知您处理结果"
        )
    }
    
    // MARK: - 拉黑/取消拉黑用户
    @Sendable
    func blockUser(req: Request) async throws -> [String: Bool] {
        let currentUserId = try req.auth.require(AuthPayload.self).userId
        
        guard let targetIdStr = req.parameters.get("userId"),
              let targetId = Int64(targetIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        if currentUserId == targetId {
            throw Abort(.badRequest, reason: "不能拉黑自己")
        }
        
        // 检查目标用户是否存在
        guard try await User.find(targetId, on: req.db) != nil else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // 检查是否已拉黑
        if let existingBlock = try await UserBlock.query(on: req.db)
            .filter(\.$blockerId == currentUserId)
            .filter(\.$blockedId == targetId)
            .first() {
            // 已拉黑，取消拉黑
            try await existingBlock.delete(on: req.db)
            return ["isBlocked": false]
        } else {
            // 未拉黑，添加拉黑
            let block = UserBlock(blockerId: currentUserId, blockedId: targetId)
            try await block.save(on: req.db)
            return ["isBlocked": true]
        }
    }
    
    // MARK: - 检查是否拉黑
    @Sendable
    func isBlocked(req: Request) async throws -> [String: Bool] {
        let currentUserId = try req.auth.require(AuthPayload.self).userId
        
        guard let targetIdStr = req.parameters.get("userId"),
              let targetId = Int64(targetIdStr) else {
            throw Abort(.badRequest, reason: "无效的用户ID")
        }
        
        let block = try await UserBlock.query(on: req.db)
            .filter(\.$blockerId == currentUserId)
            .filter(\.$blockedId == targetId)
            .first()
        
        return ["isBlocked": block != nil]
    }
    
    // MARK: - 获取拉黑列表
    @Sendable
    func getBlockedUsers(req: Request) async throws -> [Int64] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        let blocks = try await UserBlock.query(on: req.db)
            .filter(\.$blockerId == userId)
            .all()
        
        return blocks.map { $0.blockedId }
    }
}
