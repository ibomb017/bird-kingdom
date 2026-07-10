import Vapor
import Fluent

/// 短信代理控制器
/// 在本地作为"短信网关服务器"使用
struct SmsProxyController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // 内部接口，不需要认证
        let sms = routes.grouped("internal", "sms")
        
        // 发送短信
        sms.post("send", use: sendSms)
    }
    
    // MARK: - 发送短信
    @Sendable
    func sendSms(req: Request) async throws -> SmsResponse {
        struct SendSmsRequest: Content {
            let phone: String?
            let code: String?
        }
        
        let input = try req.content.decode(SendSmsRequest.self)
        
        guard let phone = input.phone, let code = input.code else {
            return SmsResponse(success: false, message: "phone 或 code 不能为空")
        }
        
        // 调用阿里云短信服务
        let success = try await sendAliyunSms(phone: phone, code: code, logger: req.logger, req: req)
        
        return SmsResponse(success: success, message: success ? "发送成功" : "发送失败")
    }
    
    // MARK: - 阿里云短信发送
    private func sendAliyunSms(phone: String, code: String, logger: Logger, req: Request) async throws -> Bool {
        // Java SMS Proxy 地址 (默认本地 8081)
        let proxyUrl = Environment.get("SMS_PROXY_URL") ?? "http://127.0.0.1:8082/internal/sms/send"
        let apiKey = Environment.get("SMS_PROXY_API_KEY") ?? "dev-api-key-change-in-production"
        
        do {
            let response = try await req.client.post(URI(string: proxyUrl)) { req in
                req.headers.add(name: "X-API-Key", value: apiKey)
                try req.content.encode(["phone": phone, "code": code])
            }
            
            struct ProxyResponse: Decodable {
                let success: Bool
                let message: String?
            }
            
            guard response.status == .ok else {
                logger.error("❌ SMS Proxy 请求失败: Status \(response.status)")
                return false
            }
            
            let result = try response.content.decode(ProxyResponse.self)
            if result.success {
                logger.info("✅ SMS Proxy 发送成功: \(phone)")
                return true
            } else {
                logger.error("❌ SMS Proxy 发送失败: \(result.message ?? "未知错误")")
                return false
            }
        } catch {
            logger.error("❌ SMS Proxy 连接异常: \(error)")
            return false
        }
    }
}

// MARK: - DTO
struct SmsResponse: Content {
    let success: Bool
    let message: String?
}
