import Vapor
import Foundation
import Crypto

/// 阿里云内容审核 (Green API V3)
actor AliyunGreenService {
    static let shared = AliyunGreenService()
    
    private init() {}
    
    private var accessKeyId: String {
        Environment.get("ALIYUN_GREEN_ACCESS_KEY_ID") ?? Environment.get("ALIYUN_OSS_ACCESS_KEY_ID") ?? ""
    }
    
    private var accessKeySecret: String {
        Environment.get("ALIYUN_GREEN_ACCESS_KEY_SECRET") ?? Environment.get("ALIYUN_OSS_ACCESS_KEY_SECRET") ?? ""
    }
    
    private let endpoint = "green-cip.cn-shanghai.aliyuncs.com"
    private let version = "2022-03-02"
    
    /// 审核文本内容 (返回 true 表示通过，false 表示违规)
    func moderateText(_ text: String, client: Client) async throws -> Bool {
        guard !accessKeyId.isEmpty, !accessKeySecret.isEmpty else {
            return true // 未配置AK时默认放行
        }
        
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        let action = "TextModeration"
        let date = getISO8601Date()
        let nonce = UUID().uuidString
        
        let payload: [String: Any] = [
            "Service": "chat_detection",
            "ServiceParameters": [
                "content": text
            ]
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            return true
        }
        
        let response = try await sendRequest(action: action, date: date, nonce: nonce, bodyData: bodyData, client: client)
        
        struct GreenResponse: Content {
            let Code: Int?
            let Message: String?
            let Data: GreenData?
        }
        
        struct GreenData: Content {
            let reason: String?
            let labels: String?
        }
        
        if let res = try? response.content.decode(GreenResponse.self) {
            if res.Code == 200 {
                // 如果 labels 是空或者是 "nonLabel" 表示没有检测到违规
                if let labels = res.Data?.labels, !labels.isEmpty, labels != "nonLabel" {
                    return false // 发现违规标签
                }
                return true
            }
        }
        
        return true // 接口调用失败时默认放行，避免阻断业务
    }
    
    /// 审核图片内容 (返回 true 表示通过，false 表示违规)
    func moderateImage(_ imageUrl: String, client: Client) async throws -> Bool {
        guard !accessKeyId.isEmpty, !accessKeySecret.isEmpty else {
            return true
        }
        
        let action = "ImageModeration"
        let date = getISO8601Date()
        let nonce = UUID().uuidString
        
        let payload: [String: Any] = [
            "Service": "baselineCheck", // 通用基线检测（包含涉黄、暴恐、不良内容等）
            "ServiceParameters": [
                "imageUrl": imageUrl
            ]
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            return true
        }
        
        let response = try await sendRequest(action: action, date: date, nonce: nonce, bodyData: bodyData, client: client)
        
        struct GreenResponse: Content {
            let Code: Int?
            let Data: GreenImageData?
        }
        
        struct GreenImageData: Content {
            let Result: [ImageResultItem]?
        }
        
        struct ImageResultItem: Content {
            let Label: String?
        }
        
        if let res = try? response.content.decode(GreenResponse.self) {
            if res.Code == 200 {
                if let results = res.Data?.Result {
                    for item in results {
                        if let label = item.Label, label != "nonLabel" {
                            return false // 发现违规
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    private func sendRequest(action: String, date: String, nonce: String, bodyData: Data, client: Client) async throws -> ClientResponse {
        let signature = generateSignature(
            method: "POST",
            action: action,
            version: version,
            date: date,
            nonce: nonce,
            payload: bodyData
        )
        
        let authHeader = "ACS3-HMAC-SHA256 Credential=\(accessKeyId),SignedHeaders=host;x-acs-action;x-acs-date;x-acs-signature-nonce;x-acs-version,Signature=\(signature)"
        
        let url = URI(string: "https://\(endpoint)/")
        return try await client.post(url) { req in
            req.headers.add(name: "Accept", value: "application/json")
            req.headers.add(name: "Content-Type", value: "application/json;charset=utf-8")
            req.headers.add(name: "x-acs-action", value: action)
            req.headers.add(name: "x-acs-version", value: version)
            req.headers.add(name: "x-acs-date", value: date)
            req.headers.add(name: "x-acs-signature-nonce", value: nonce)
            req.headers.add(name: "host", value: endpoint)
            req.headers.add(name: "Authorization", value: authHeader)
            req.body = .init(data: bodyData)
        }
    }
    
    private func generateSignature(
        method: String,
        action: String,
        version: String,
        date: String,
        nonce: String,
        payload: Data
    ) -> String {
        let payloadHash = SHA256.hash(data: payload).compactMap { String(format: "%02x", $0) }.joined()
        
        let canonicalHeaders = "host:\(endpoint)\nx-acs-action:\(action)\nx-acs-date:\(date)\nx-acs-signature-nonce:\(nonce)\nx-acs-version:\(version)\n"
        let signedHeaders = "host;x-acs-action;x-acs-date;x-acs-signature-nonce;x-acs-version"
        
        let canonicalRequest = "\(method)\n/\n\n\(canonicalHeaders)\n\(signedHeaders)\n\(payloadHash)"
        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        
        let stringToSign = "ACS3-HMAC-SHA256\n\(canonicalRequestHash)"
        
        let key = SymmetricKey(data: Data(accessKeySecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key)
        return signature.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func getISO8601Date() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter.string(from: Date())
    }
}
