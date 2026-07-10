import Vapor
import Fluent

/// AI代理控制器
struct AIProxyController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let ai = routes.grouped("ai")
        let protected = ai.grouped(JWTAuthMiddleware())
        
        protected.post("chat", use: chat)
    }
    
    @Sendable
    func chat(req: Request) async throws -> AIChatResponse {
        let input = try req.content.decode(AIChatRequest.self)
        let response = generateAIResponse(messages: input.messages)
        return AIChatResponse(success: true, content: response, error: nil)
    }
    
    private func generateAIResponse(messages: [AIChatRequest.MessageItem]) -> String {
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            return "您好！我是鸟鸟王国的AI助手，有什么可以帮助您的吗？"
        }
        
        let content = lastUserMessage.content.lowercased()
        
        if content.contains("羽毛") || content.contains("掉毛") {
            return "关于鸟儿掉毛的情况，可能有以下几种原因：正常换羽期、营养不良、环境应激、疾病因素等。建议观察是否是换羽期，检查饮食是否均衡，保持环境稳定。如持续异常，建议就医检查。"
        } else if content.contains("食物") || content.contains("吃") || content.contains("喂") {
            return "关于鸟儿的饮食：可以吃专业鸟粮、新鲜蔬菜、适量水果等；不能吃巧克力、牛油果、咖啡因饮品、酒精、高盐高油食物等。请根据您鸟儿的品种选择合适的食物配比。"
        } else {
            return "感谢您的提问！作为鸟鸟王国的AI助手，我可以为您提供鸟儿健康咨询、饮食建议、日常护理指导、行为分析等帮助。请详细描述您的问题，如果是紧急情况，建议及时就医。"
        }
    }
}

struct AIChatRequest: Content {
    struct MessageItem: Content {
        let role: String
        let content: String
    }
    let messages: [MessageItem]
}

struct AIChatResponse: Content {
    let success: Bool
    let content: String?
    let error: String?
}
