import Vapor
import Foundation
import Crypto

/// 阿里云 OSS 服务
/// 使用 REST API 直接上传，无需额外 SDK
actor OSSService {
    static let shared = OSSService()
    
    private init() {}
    
    // MARK: - 配置
    private var accessKeyId: String {
        Environment.get("ALIYUN_OSS_ACCESS_KEY_ID") ?? ""
    }
    
    private var accessKeySecret: String {
        Environment.get("ALIYUN_OSS_ACCESS_KEY_SECRET") ?? ""
    }
    
    private var endpoint: String {
        Environment.get("ALIYUN_OSS_ENDPOINT") ?? "oss-cn-shanghai.aliyuncs.com"
    }
    
    private var bucket: String {
        Environment.get("ALIYUN_OSS_BUCKET") ?? "birdkingdom"
    }
    
    /// 公开访问的 URL 基础路径
    var publicBaseURL: String {
        "https://\(bucket).\(endpoint)"
    }
    
    // MARK: - 上传文件
    
    /// 上传文件到 OSS
    /// - Parameters:
    ///   - data: 文件数据
    ///   - key: OSS 对象键（路径）
    ///   - contentType: MIME 类型
    ///   - client: HTTP 客户端
    /// - Returns: 公开访问 URL
    func uploadFile(
        data: Data,
        key: String,
        contentType: String,
        client: Client
    ) async throws -> String {
        // 检查配置
        guard !accessKeyId.isEmpty, !accessKeySecret.isEmpty else {
            throw OSSError.missingCredentials
        }
        
        let date = formatRFC2822Date()
        let resource = "/\(bucket)/\(key)"
        
        // 构建签名
        let stringToSign = "PUT\n\n\(contentType)\n\(date)\n\(resource)"
        let signature = hmacSHA1(stringToSign: stringToSign, secret: accessKeySecret)
        let authorization = "OSS \(accessKeyId):\(signature)"
        
        // 构建请求
        let url = URI(string: "https://\(bucket).\(endpoint)/\(key)")
        
        let response = try await client.put(url) { req in
            req.headers.add(name: "Date", value: date)
            req.headers.add(name: "Content-Type", value: contentType)
            req.headers.add(name: "Authorization", value: authorization)
            req.headers.add(name: "Content-Length", value: String(data.count))
            req.body = .init(data: data)
        }
        
        guard response.status == .ok else {
            // 尝试解析错误信息
            if let body = response.body {
                let errorBody = String(buffer: body)
                throw OSSError.uploadFailed("OSS 上传失败: \(response.status), \(errorBody)")
            }
            throw OSSError.uploadFailed("OSS 上传失败: \(response.status)")
        }
        
        return "\(publicBaseURL)/\(key)"
    }
    
    /// 生成预签名上传 URL（用于客户端直传）
    /// - Parameters:
    ///   - key: OSS 对象键
    ///   - expires: 过期时间（秒）
    /// - Returns: 预签名 URL
    func generatePresignedURL(key: String, expires: Int = 3600) -> String {
        let expireTime = Int(Date().timeIntervalSince1970) + expires
        let resource = "/\(bucket)/\(key)"
        let stringToSign = "PUT\n\n\n\(expireTime)\n\(resource)"
        let signature = hmacSHA1(stringToSign: stringToSign, secret: accessKeySecret)
        let encodedSignature = signature.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? signature
        
        return "https://\(bucket).\(endpoint)/\(key)?OSSAccessKeyId=\(accessKeyId)&Expires=\(expireTime)&Signature=\(encodedSignature)"
    }
    
    // MARK: - 辅助方法
    
    /// 格式化 RFC2822 日期
    private func formatRFC2822Date() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone(identifier: "GMT")
        return formatter.string(from: Date())
    }
    
    /// 计算 HMAC-SHA1 签名
    private func hmacSHA1(stringToSign: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: key
        )
        return Data(signature).base64EncodedString()
    }
    
    // MARK: - 生成上传路径
    
    /// 生成图片上传路径
    func generateImageKey(userId: Int64, filename: String) -> String {
        let uuid = UUID().uuidString.lowercased()
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        let validExt = ["jpg", "jpeg", "png", "gif", "webp"].contains(ext) ? ext : "jpg"
        return "uploads/images/\(userId)/\(uuid).\(validExt)"
    }
    
    /// 生成视频上传路径
    func generateVideoKey(userId: Int64, filename: String) -> String {
        let uuid = UUID().uuidString.lowercased()
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        let validExt = ["mp4", "mov", "m4v"].contains(ext) ? ext : "mp4"
        return "uploads/videos/\(userId)/\(uuid).\(validExt)"
    }
    
    /// 生成头像上传路径
    func generateAvatarKey(userId: Int64, filename: String) -> String {
        let uuid = UUID().uuidString.lowercased()
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        let validExt = ["jpg", "jpeg", "png", "webp"].contains(ext) ? ext : "jpg"
        return "uploads/avatars/\(userId)/\(uuid).\(validExt)"
    }
}

// MARK: - 错误类型
enum OSSError: Error, LocalizedError {
    case missingCredentials
    case uploadFailed(String)
    case invalidFile
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "OSS 配置缺失，请检查环境变量"
        case .uploadFailed(let message):
            return message
        case .invalidFile:
            return "无效的文件"
        }
    }
}
