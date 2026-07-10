import Vapor
import Fluent

/// 反馈控制器
struct FeedbackController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let feedback = routes.grouped("feedback")
        
        // 提交反馈（支持未登录）
        feedback.post(use: submitFeedback)
    }
    
    // MARK: - 提交反馈
    @Sendable
    func submitFeedback(req: Request) async throws -> FeedbackResponse {
        struct FeedbackRequest: Content {
            let type: String?
            let content: String
            let contactInfo: String?
        }
        
        let input = try req.content.decode(FeedbackRequest.self)
        
        // 尝试获取用户信息
        let userId: Int64? = req.auth.get(AuthPayload.self)?.userId
        
        // 保存反馈到数据库
        let feedback = UserFeedback(
            userId: userId,
            type: input.type ?? "general",
            content: input.content,
            contactInfo: input.contactInfo
        )
        try await feedback.save(on: req.db)
        
        // 异步发送邮件通知（不阻塞响应）
        // 捕获所有需要的值以避免并发问题
        let feedbackType = input.type ?? "general"
        let feedbackContent = input.content
        let feedbackContact = input.contactInfo
        let feedbackUserId = userId
        Task {
            await sendFeedbackEmail(
                req: req,
                type: feedbackType,
                content: feedbackContent,
                contactInfo: feedbackContact,
                userId: feedbackUserId
            )
        }
        
        return FeedbackResponse(
            success: true,
            message: "感谢您的反馈！我们会认真阅读并尽快处理。"
        )
    }
    
    // MARK: - 发送反馈邮件
    private func sendFeedbackEmail(req: Request, type: String, content: String, contactInfo: String?, userId: Int64?) async {
        // 调用 sms-proxy 服务发送邮件
        // sms-proxy 运行在国内服务器(8082端口)
        let smsProxyHost = Environment.get("SMS_PROXY_HOST") ?? "47.84.177.155"
        let smsProxyPort = Environment.get("SMS_PROXY_PORT") ?? "8082"
        let apiKey = Environment.get("SMS_PROXY_API_KEY") ?? "birdkingdom-sms-proxy-2026-production-key"
        
        let urlString = "http://\(smsProxyHost):\(smsProxyPort)/internal/email/feedback"
        
        struct EmailRequest: Content {
            let type: String
            let content: String
            let contactInfo: String?
            let userId: Int64?
        }
        
        do {
            let response = try await req.client.post(URI(string: urlString)) { clientReq in
                clientReq.headers.add(name: "Content-Type", value: "application/json")
                clientReq.headers.add(name: "X-API-Key", value: apiKey)
                try clientReq.content.encode(EmailRequest(
                    type: type,
                    content: content,
                    contactInfo: contactInfo,
                    userId: userId
                ))
            }
            
            if response.status == .ok {
                req.logger.info("📧 反馈邮件发送成功")
            } else {
                req.logger.warning("📧 反馈邮件发送失败: \(response.status)")
            }
        } catch {
            req.logger.error("📧 发送反馈邮件出错: \(error)")
        }
    }
}

// MARK: - 反馈模型
final class UserFeedback: Model, Content, @unchecked Sendable {
    static let schema = "user_feedback"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "user_id")
    var userId: Int64?
    
    @Field(key: "type")
    var type: String
    
    @Field(key: "content")
    var content: String
    
    @Field(key: "contact_info")
    var contactInfo: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: Int64? = nil, userId: Int64? = nil, type: String, content: String, contactInfo: String? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.content = content
        self.contactInfo = contactInfo
    }
}

// MARK: - DTO
struct FeedbackResponse: Content {
    let success: Bool
    let message: String
}

