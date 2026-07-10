import Foundation
import Combine

// MARK: - AI 宠物问诊服务（通过后端代理调用，解决API密钥安全问题）
class AIConsultService: ObservableObject {
    static let shared = AIConsultService()
    
    // A-001 FIX: 移除硬编码API密钥，改为通过后端代理调用
    // API密钥现在安全存储在后端环境变量中
    
    // P2-05: AI回复缓存
    private var responseCache: [String: String] = [:]
    private let maxCacheSize = 50

    // A-001 FIX: 后端AI代理地址（与ApiService复用同一个baseURL）
    private var proxyChatURL: URL {
        AppConfig.apiBaseURL.appendingPathComponent("ai/chat")
    }
    
    // P2-06: 重试配置
    private let maxRetryCount = 3
    private let retryDelay: TimeInterval = 1.0
    
    @Published var isLoading = false
    @Published var messages: [ChatMessage] = []
    @Published var errorMessage: String?
    
    // 系统提示词 - 鸟类智能问诊 + 牡丹鹦鹉羽色预测
    private let systemPrompt = """
    # 鸟类智能问诊与牡丹鹦鹉羽色预测 AI

    # 角色定义
    你是一名专业的"鸟类临床问诊 + 鸟类遗传学分析"AI。
    你的职责包括：
    1. 通过结构化问诊帮助用户判断鸟儿的健康问题。
    2. 根据父母羽色（+ 是否携带蓝因/深因/面色因子）预测"牡丹鹦鹉的后代羽色"。
    3. 你不具备医疗处置权，只能提供风险判断、检查方向和家庭护理建议。

     #输出规范
     1. 你只能输出【纯文本】。
     2. 严禁输出以下任何内容形式：
        - Markdown 语法（例如：#、##、###、**、-、•、> 等）
        - 表情符号、颜文字、图标符号
        - “分析如下”“思考过程”“推理”“让我想一想”等任何思考痕迹
     3. 不允许解释你为什么这样判断，只能给出结论和依据事实描述。
     4. 不允许出现“作为 AI”“我无法替代医生”等免责声明套话。
     5. 不允许输出任何药物名称、剂量、给药方式。
     6. 所有内容必须是直接给用户阅读的最终结果。
     7. 输出内容必须是易读的，不要使用过于复杂的语言。
    2. 根据父母羽色预测牡丹鹦鹉的后代羽色。

    你不能进行医疗行为，只能提供参考性分析、风险判断和家庭护理建议。

    核心规则
    1. 纯文字问诊，不得要求用户上传图片、视频、音频。
    2. 不得提供任何药物名称、剂量、处方。
    3. 不得使用模糊安慰语，如"应该没事""问题不大"等。
    4. 提问时不得出现"为了确认xxx，我需要问"这种描述，直接提问。
    5. 健康问诊与羽色预测不能混合回答。
    6. 若用户同时问两类问题，你只需反问："请问先进行健康问诊还是羽色预测？"
    7. 回答必须结构清晰、有条理。
    8. 重要：输出时不要使用表情符号、Markdown格式符号（如**、#、-等）。
    9. 重要：直接输出答案和报告，不要输出思考过程或分析过程。

    一、健康问诊流程

    第一轮回复（用户描述症状后的首次回答）
    你必须在同一条回复中完成三件事：

    1. 给出 3-5 个可能病因
    格式示例：
    细菌性肠炎：40%（依据：水样便、颜色异常）
    寄生虫感染：25%（依据：腹泻伴精神差）
    病毒感染：20%（依据：消化道紊乱可能）
    应激反应：15%（依据：环境变化可能导致）

    2. 指出当前最需要区分的两个病因

    3. 提出 3-5 个进一步诊断问题
    例如：
    1. 粪便是否带黏液或血丝？
    2. 最近是否出现拒食或明显食欲下降？
    3. 是否经历温度变化、惊吓或搬家？
    4. 是否做过驱虫？
    5. 是否有呼吸急促或张嘴喘气？

    第二轮回复（用户回答你的问题后）
    根据用户补充的信息更新每个病因的概率
    若某病因达到70%以上则进入最终诊断报告
    若仍无法确定则再提出2-4个关键追问

    最终诊断报告（当某病因达到70%时）
    必须包含以下结构：

    诊断报告

    诊断倾向：XXX（75%）

    依据：列出2-3个关键症状依据

    风险等级：Critical / High / Medium / Low

    推荐检查：如粪便涂片、影像学检查、寄生虫检测等

    家庭护理建议：
    温度保持在28-30℃
    提供干净饮水
    暂停水果、种子等刺激性食物
    注意：不得提供药物信息

    危险信号（需立即就医）：
    持续拒食超过12小时
    站立困难或明显萎靡
    张嘴呼吸或呼吸困难
    粪便带血

    二、牡丹鹦鹉羽色预测流程

    当用户询问配色、繁殖会出什么颜色、子代羽色概率等问题时，进入羽色预测模式。

    羽色预测规则
    1. 输出按概率排序的子代羽色列表
    2. 若某羽色需特定基因组合需明确说明
    3. 若用户提供性别则说明某些羽色是否偏雄性或雌性出现
    4. 若信息不足则必须主动提出基因补全问题
    5. 概率用区间表示，如：20-40%
    6. 所有结论需严谨，不能编造不存在的羽色

    羽色预测输出格式：

    根据您提供的羽色组合，预测后代可能出现的羽色如下：

    可能羽色（按概率从高到低）：
    XXX：40-60%（依据：父母均携带蓝因）
    XXX：20-40%（依据：其中一方为深因）
    XXX：10-25%（依据：双亲均可能携带基因组合）

    影响羽色的关键因素：
    蓝因（Blue Factor）
    深因（Dark Factor）
    面色因子（黄面/白面）
    是否双因子（DF）或单因子（SF）

    若需更精准预测，请补充以下信息：
    1. 父母是否携带蓝因？
    2. 是否存在深因？
    3. 面色基因是否为显性？
    4. 亲代是否为双因子？

    风险等级标准
    Critical：立即就医
    High：当天就医
    Medium：24小时内就医
    Low：可观察24-48小时
    """
    
    // P3-02: 对话历史持久化
    private let historyKey = "ai_consult_history"
    private let maxHistoryCount = 50

    // MARK: - 后端AI代理请求/响应模型
    private struct ProxyChatRequest: Codable {
        let messages: [ProxyMessage]
    }

    private struct ProxyMessage: Codable {
        let role: String
        let content: String
    }

    private struct ProxyChatResponse: Codable {
        let success: Bool
        let content: String?
        let error: String?
    }
    
    private init() {
        // P3-02: 加载历史对话
        loadChatHistory()
        
        // 如果没有历史，添加欢迎消息
        if messages.isEmpty {
            messages.append(ChatMessage(
                role: .assistant,
                content: "你好，我是荷荷，你的鸟类智能问诊AI\n我可以帮助你:\n·健康问诊\n描述鸟儿的症状，我将进行病因分析和风险评估\n·羽色预测\n告诉我父母的羽色，我可以预测牡丹鹦鹉后代的羽色概率\n请直接描述你的问题，我会自动识别并提供帮助!"
            ))
        }
    }

    // MARK: - A-002: 保存对话历史（加密存储）
    private func saveChatHistory() {
        let encoder = JSONEncoder()
        // 只保留最近的对话
        let recentMessages = Array(messages.suffix(maxHistoryCount))
        if let data = try? encoder.encode(recentMessages) {
            // A-002: 使用Keychain加密存储
            KeychainService.shared.save(data, forKey: historyKey)
        }
    }
    
    // MARK: - A-002: 加载对话历史（从keycain加密存储读取）
    private func loadChatHistory() {
        // A-002: 优先从Keychain读取，兼容旧版UserDefaults
        if let data = KeychainService.shared.load(forKey: historyKey) {
            let decoder = JSONDecoder()
            if let savedMessages = try? decoder.decode([ChatMessage].self, from: data) {
                messages = savedMessages
                return
            }
        }
        // 兼容旧版：UserDefaults迁移到Keychain
        if let data = UserDefaults.standard.data(forKey: historyKey) {
            let decoder = JSONDecoder()
            if let savedMessages = try? decoder.decode([ChatMessage].self, from: data) {
                messages = savedMessages
                // 迁移到Keychain并清除UserDefaults
                KeychainService.shared.save(data, forKey: historyKey)
                UserDefaults.standard.removeObject(forKey: historyKey)
            }
        }
    }
    
    // MARK: - A-002: 清除对话历史
    func clearHistory() {
        messages.removeAll()
        messages.append(ChatMessage(
            role: .assistant,
            content: "你好，我是荷荷，你的鸟类智能问诊AI\n我可以帮助你:\n·健康问诊\n描述鸟儿的症状，我将进行病因分析和风险评估\n·羽色预测\n告诉我父母的羽色，我可以预测牡丹鹦鹉后代的羽色概率\n请直接描述你的问题，我会自动识别并提供帮助!"
        ))
        // A-002: Keychain和UserDefaults都清除
        KeychainService.shared.delete(key: historyKey)
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
    
    // MARK: - 发送消息（P2-05: 缓存支持，P2-06: 自动重试）
    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 添加用户消息
        let userMessage = ChatMessage(role: .user, content: content)
        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
            errorMessage = nil
        }
        
        // P2-05: 检查缓存（仅对简单问题有效）
        let cacheKey = generateCacheKey(content)
        if let cachedResponse = responseCache[cacheKey] {
            await MainActor.run {
                messages.append(ChatMessage(role: .assistant, content: cachedResponse))
                isLoading = false
            }
            return
        }
        
        // P2-06: 带重试的API调用
        var lastError: Error?
        for attempt in 1...maxRetryCount {
            do {
                let response = try await callDoubaoAPI(userMessage: content)
                
                // A-003: 内容过滤（安全处理敏感医疗信息）
                let filteredResponse = filterAIResponse(response)
                
                // P2-05: 缓存响应
                cacheResponse(key: cacheKey, response: filteredResponse)
                
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, content: filteredResponse))
                    isLoading = false
                    // P3-02: 保存对话历史
                    saveChatHistory()
                }
                return
            } catch {
                lastError = error
                if attempt < maxRetryCount {
                    // 指数退避重试
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000))
                }
            }
        }
        
        // 所有重试都失败
        await MainActor.run {
            errorMessage = "API调用失败: \(lastError?.localizedDescription ?? "未知错误")"
            isLoading = false
            messages.append(ChatMessage(
                role: .assistant,
                content: "抱歉，我暂时无法回复。已重试\(maxRetryCount)次，请检查网络连接后重试。🙏"
            ))
        }
    }
    
    // MARK: - P2-05: 缓存相关方法
    private func generateCacheKey(_ content: String) -> String {
        // 只缓存简单的快捷问题
        return content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func cacheResponse(key: String, response: String) {
        // 限制缓存大小
        if responseCache.count >= maxCacheSize {
            responseCache.removeAll()
        }
        responseCache[key] = response
    }
    
    // MARK: - A-003: AI响应内容过滤（过滤敏感医疗信息）
    private func filterAIResponse(_ content: String) -> String {
        // 需要过滤的敏感关键词（药物/剂量相关）
        let sensitivePatterns = [
            // 剂量单位
            "mg/kg", "毫克/公斤", "ml/kg", "毫升/公斤",
            // 具体药物名称（常见兽医用药）
            "阿莫西林", "头孢", "恩诺沙星", "甲硝唑", "氟康唑",
            "伊维菌素", "吡虫啉", "阿维菌素", "左旋咪唑",
            // 处方相关
            "处方药", "每日剂量", "注射剂量", "口服剂量"
        ]
        
        var filtered = content
        for pattern in sensitivePatterns {
            if filtered.contains(pattern) {
                filtered = filtered.replacingOccurrences(
                    of: pattern,
                    with: "[请咨询兽医]"
                )
            }
        }
        
        // 过滤具体数字剂量（如"5mg"、"0.1ml"）
        let doseRegex = try? NSRegularExpression(pattern: "\\d+(\\.\\d+)?\\s*(mg|ml|毫克|毫升)", options: .caseInsensitive)
        if let regex = doseRegex {
            let range = NSRange(filtered.startIndex..<filtered.endIndex, in: filtered)
            filtered = regex.stringByReplacingMatches(in: filtered, options: [], range: range, withTemplate: "[剂量请咨询兽医]")
        }
        
        return filtered
    }
    
    // MARK: - 调用后端AI代理（不直连第三方，避免前端持有API Key）
    private func callDoubaoAPI(userMessage: String) async throws -> String {
        var request = URLRequest(url: proxyChatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Fix for #401: 添加认证 Token
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.timeoutInterval = 60

        // 后端会统一注入系统提示词；前端只发送对话历史（user/assistant）+ 当前消息。
        // 保留最近20条以控制payload大小。
        var proxyMessages: [ProxyMessage] = []

        let recentMessages = messages.suffix(20)
        for msg in recentMessages {
            proxyMessages.append(ProxyMessage(
                role: msg.role == .user ? "user" : "assistant",
                content: msg.content
            ))
        }
        proxyMessages.append(ProxyMessage(role: "user", content: userMessage))

        let body = ProxyChatRequest(messages: proxyMessages)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIError.httpError(httpResponse.statusCode)
        }

        let proxyResponse: ProxyChatResponse
        do {
            proxyResponse = try JSONDecoder().decode(ProxyChatResponse.self, from: data)
        } catch {
            throw AIError.parseError
        }

        if proxyResponse.success, let content = proxyResponse.content {
            return content
        }

        throw AIError.apiError(proxyResponse.error ?? "AI服务暂时不可用")
    }
    
    // MARK: - 清空对话
    func clearMessages() {
        messages.removeAll()
        // 重新添加欢迎消息
        messages.append(ChatMessage(
            role: .assistant,
            content: "你好，我是荷荷，你的鸟类智能问诊AI\n我可以帮助你:\n·健康问诊\n描述鸟儿的症状，我将进行病因分析和风险评估\n·羽色预测\n告诉我父母的羽色，我可以预测牡丹鹦鹉后代的羽色概率\n请直接描述你的问题，我会自动识别并提供帮助!"
        ))
    }
    
    // MARK: - 快捷问题（健康问诊 + 羽色预测）
    static let quickQuestions = [
        "我的鸟儿不吃东西，精神萎靡",
        "鸟儿拉稀，粪便呈绿色水样",
        "鸟儿呼吸急促，张嘴呼吸",
        "绿桃配蓝桃会出什么颜色？",
        "紫罗兰和蓝桃配对后代羽色",
    ]
}

// MARK: - 聊天消息模型
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    enum MessageRole: String, Codable {
        case user
        case assistant
    }
    
    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - AI 错误类型
enum AIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API 地址"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .apiError(let message):
            return message
        case .parseError:
            return "解析响应失败"
        }
    }
}
