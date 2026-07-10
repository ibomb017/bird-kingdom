//
//  AppConfig.swift
//  BirdKingdom
//
//  应用配置文件 - 管理API地址等配置
//

import Foundation

/// 应用配置
struct AppConfig {
    
    // MARK: - 环境配置
    
    /// 当前环境
    enum Environment {
        case development  // 开发环境
        case production   // 生产环境
    }
    
    /// 当前运行环境
    /// 测试远程服务器时改为 .production
    /// 测试本地后端时改为 .development
    static let currentEnvironment: Environment = .production
    
    // MARK: - API配置
    
    // MARK: - 服务器地址配置
    
    /// Mac电脑的局域网IP（用于真机测试连接本地后端）
    /// 获取方式：在Mac终端执行 ipconfig getifaddr en0
    private static let localNetworkIP = "192.168.0.28"
    
    /// 生产服务器地址（正式域名）
    private static let productionServer = "api.birdkingdom.xyz"
    
    /// API基础地址
    static var apiBaseURL: URL {
        switch currentEnvironment {
        case .development:
            // 开发环境 - 连接Mac本地后端
            // 模拟器用 127.0.0.1，真机用局域网IP
            #if targetEnvironment(simulator)
            return URL(string: "http://127.0.0.1:8080/api")!
            #else
            return URL(string: "http://\(localNetworkIP):8080/api")!
            #endif
        case .production:
            // 生产环境 - 阿里云服务器（HTTPS）
            return URL(string: "https://\(productionServer)/api")!
        }
    }
    
    /// 文件上传地址
    static var uploadBaseURL: URL {
        switch currentEnvironment {
        case .development:
            #if targetEnvironment(simulator)
            return URL(string: "http://127.0.0.1:8080/api/upload")!
            #else
            return URL(string: "http://\(localNetworkIP):8080/api/upload")!
            #endif
        case .production:
            return URL(string: "https://\(productionServer)/api/upload")!
        }
    }
    
    // MARK: - OSS配置
    
    /// OSS图片访问基础地址
    static var ossImageBaseURL: String {
        return "https://birdkingdom.oss-cn-shanghai.aliyuncs.com"
    }
    
    // MARK: - 其他配置
    
    /// 是否启用调试日志
    static var enableDebugLog: Bool {
        return currentEnvironment == .development
    }
    
    /// 网络请求超时时间（秒）
    static let networkTimeout: TimeInterval = 30
    
    /// 图片缓存最大容量（MB）
    static let imageCacheMaxSize: Int = 100
    
    /// Token过期提前刷新时间（秒）
    static let tokenRefreshThreshold: TimeInterval = 3600
}

// MARK: - 便捷方法

extension AppConfig {
    /// 打印调试日志
    static func debugLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        if enableDebugLog {
            let fileName = (file as NSString).lastPathComponent
            print("[\(fileName):\(line)] \(function) - \(message)")
        }
    }
    
    /// 将普通图片 URL 转为 CDN 或经过处理的 URL（如需要）
    static func applyCDN(to urlString: String) -> String {
        // 如果原本就能生成有效 URL，说明已经是合法/编码过的了
        if URL(string: urlString) != nil {
            return urlString
        }
        
        // 处理含有中文或空格的 URL，生成合法链接
        if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return encoded
        }
        return urlString
    }
}
