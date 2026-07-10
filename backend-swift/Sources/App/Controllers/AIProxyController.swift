import Vapor
import Fluent

/// AI代理控制器 - 调用豆包 API
struct AIProxyController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let ai = routes.grouped("ai")
        let protected = ai.grouped(JWTAuthMiddleware())
        
        protected.post("chat", use: chat)
    }
    
    // 豆包 API 配置
    private var doubaoAPIKey: String {
        Environment.get("DOUBAO_API_KEY") ?? "d9deb736-13ff-493d-9d35-3db193f2e00b"
    }
    
    private var doubaoEndpoint: String {
        Environment.get("DOUBAO_ENDPOINT") ?? "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    }
    
    private var doubaoModel: String {
        Environment.get("DOUBAO_MODEL") ?? "ep-20250105220313-9z7gs"
    }
    
    // 系统提示词
    private let systemPrompt = """
    # 鸟类智能问诊与牡丹鹦鹉羽色预测 AI

    # 角色定义
    你是一名专业的"鸟类临床问诊 + 鸟类遗传学分析"AI。
    你的职责包括：
    1. 通过结构化问诊帮助用户判断鸟儿的健康问题。
    2. 根据父母羽色预测"牡丹鹦鹉的后代羽色"。
    3. 你不具备医疗处置权，只能提供风险判断、检查方向和家庭护理建议。

    #输出规范
    1. 你只能输出【纯文本】。
    2. 严禁输出Markdown语法、表情符号。
    3. 不允许出现"作为 AI"等免责声明。
    4. 不允许输出任何药物名称、剂量、给药方式。
    5. 所有内容必须是易读的。

    核心规则
    1. 纯文字问诊，不得要求用户上传图片。
    2. 不得提供任何药物名称、剂量、处方。
    3. 回答必须结构清晰、有条理。
    4. 每次回答的最后，必须换行并附加以下免责声明：
    
    (本功能仅供参考，不能替代专业兽医诊断。如鸟儿出现紧急症状，请立即就医。)
    """
    
    @Sendable
    func chat(req: Request) async throws -> AIChatResponse {
        let input = try req.content.decode(AIChatRequest.self)
        
        // 如果没有配置 API Key，返回降级响应
        guard !doubaoAPIKey.isEmpty else {
            req.logger.warning("豆包 API Key 未配置，使用降级响应")
            let response = generateFallbackResponse(messages: input.messages)
            return AIChatResponse(success: true, content: response, error: nil)
        }
        
        // 调用豆包 API
        do {
            let response = try await callDoubaoAPI(messages: input.messages, req: req)
            return AIChatResponse(success: true, content: response, error: nil)
        } catch {
            req.logger.error("豆包 API 调用失败: \(error)")
            // API 调用失败时使用降级响应
            let fallback = generateFallbackResponse(messages: input.messages)
            return AIChatResponse(success: true, content: fallback, error: nil)
        }
    }
    
    // MARK: - 调用豆包 API
    private func callDoubaoAPI(messages: [AIChatRequest.MessageItem], req: Request) async throws -> String {
        // 构建请求体
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        // 添加对话历史（最近20条）
        let recentMessages = messages.suffix(20)
        for msg in recentMessages {
            apiMessages.append([
                "role": msg.role,
                "content": msg.content
            ])
        }
        
        let requestBody: [String: Any] = [
            "model": doubaoModel,
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // 发送请求
        let response = try await req.client.post(URI(string: doubaoEndpoint)) { clientReq in
            clientReq.headers.add(name: .contentType, value: "application/json")
            clientReq.headers.add(name: .authorization, value: "Bearer \(doubaoAPIKey)")
            clientReq.body = .init(data: jsonData)
        }
        
        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "豆包 API 返回错误: \(response.status)")
        }
        
        guard let body = response.body else {
            throw Abort(.badGateway, reason: "豆包 API 返回空响应")
        }
        
        // 解析响应
        let data = Data(buffer: body)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw Abort(.badGateway, reason: "豆包 API 响应格式错误")
        }
        
        return content
    }
    
    // MARK: - 降级响应（API Key 未配置或调用失败时使用）
    private func generateFallbackResponse(messages: [AIChatRequest.MessageItem]) -> String {
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            return "您好！我是鸟鸟王国的AI助手，有什么可以帮助您的吗？"
        }
        
        let content = lastUserMessage.content.lowercased()
        
        // 健康问诊相关
        if content.contains("拉稀") || content.contains("腹泻") || content.contains("粪便") {
            return """
            根据您描述的症状，鸟儿可能存在消化系统问题。

            可能的原因：
            1. 细菌性肠炎（40%）- 水样便、颜色异常
            2. 寄生虫感染（25%）- 腹泻伴精神差
            3. 饮食不当（20%）- 食物变质或不耐受
            4. 应激反应（15%）- 环境变化导致

            请回答以下问题以便进一步分析：
            1. 粪便是否带黏液或血丝？
            2. 最近是否有食欲下降？
            3. 鸟儿精神状态如何？
            4. 最近是否更换过食物或环境？

            如症状持续或加重，建议尽快就医。
            """
        } else if content.contains("不吃") || content.contains("拒食") || content.contains("食欲") {
            return """
            鸟儿食欲下降需要重视。

            可能的原因：
            1. 疾病导致 - 消化道或其他系统问题
            2. 环境应激 - 温度、光照、噪音变化
            3. 食物问题 - 食物变质或不喜欢
            4. 换羽期 - 正常生理现象

            请观察以下方面：
            1. 是否有其他症状（如羽毛蓬松、精神差）？
            2. 体重是否明显下降？
            3. 是否愿意喝水？

            如拒食超过12小时，建议立即就医。
            """
        } else if content.contains("羽毛") || content.contains("掉毛") || content.contains("换羽") {
            return """
            关于鸟儿的羽毛问题：

            正常换羽期特征：
            - 均匀脱落，新羽生长
            - 精神食欲正常
            - 通常每年1-2次

            异常脱毛需警惕：
            - 局部大面积脱落
            - 皮肤红肿或有皮屑
            - 伴随精神萎靡

            建议：
            1. 保持环境温度稳定（25-28℃）
            2. 提供充足营养
            3. 减少应激因素

            如脱毛严重或伴随其他症状，建议就医检查。
            """
        } else if content.contains("呼吸") || content.contains("喘气") || content.contains("张嘴") {
            return """
            呼吸问题需要紧急关注！

            危险信号：
            - 张嘴呼吸
            - 呼吸急促
            - 尾巴随呼吸上下摆动
            - 发出异常声音

            可能原因：
            1. 呼吸道感染
            2. 环境温度过高
            3. 心脏问题
            4. 中毒

            紧急建议：
            1. 保持环境通风
            2. 避免惊吓
            3. 立即就医！

            呼吸系统问题可能危及生命，请尽快带鸟儿就医！
            """
        }
        // 羽色预测相关
        else if content.contains("配") || content.contains("繁殖") || content.contains("后代") || content.contains("颜色") {
            return """
            关于牡丹鹦鹉羽色预测：

            为了准确预测后代羽色，请提供以下信息：
            1. 父母双方的羽色（如绿桃、蓝桃、紫罗兰等）
            2. 是否知道父母携带的隐性基因
            3. 父母是否为双因子(DF)或单因子(SF)

            常见配对结果参考：
            - 绿桃 × 绿桃 = 绿桃
            - 绿桃(携蓝因) × 蓝桃 = 绿桃(携蓝因) + 蓝桃
            - 蓝桃 × 蓝桃 = 蓝桃

            请告诉我具体的父母羽色信息，我会为您分析可能的后代颜色。
            """
        } else {
            return """
            您好！我是鸟类智能问诊AI。

            我可以帮助您：

            健康问诊
            描述鸟儿的症状，我将进行病因分析和风险评估

            羽色预测
            告诉我父母的羽色，我可以预测牡丹鹦鹉后代的羽色概率

            请详细描述您的问题，我会尽力为您提供帮助。

            注意：我的建议仅供参考，如遇紧急情况请及时就医。
            """
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
