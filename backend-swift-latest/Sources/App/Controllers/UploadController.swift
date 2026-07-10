import Vapor

/// 文件上传控制器
struct UploadController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let upload = routes.grouped("upload")
        
        // 需要认证的路由
        let protected = upload.grouped(JWTAuthMiddleware())
        
        // 上传图片 (兼容多个路径)
        protected.on(.POST, "image", body: .collect(maxSize: "50mb"), use: uploadImage)
        protected.on(.POST, "post-image", body: .collect(maxSize: "50mb"), use: uploadImage)  // 前端调用路径
        
        // 上传视频 (兼容多个路径)
        protected.on(.POST, "video", body: .collect(maxSize: "200mb"), use: uploadVideo)
        protected.on(.POST, "post-video", body: .collect(maxSize: "200mb"), use: uploadVideo)  // 前端调用路径
        
        // 上传头像 (兼容多个路径)
        protected.on(.POST, "avatar", body: .collect(maxSize: "10mb"), use: uploadAvatar)
        protected.on(.POST, "bird-avatar", body: .collect(maxSize: "10mb"), use: uploadAvatar)  // 前端调用路径
    }
    
    // MARK: - 上传图片
    @Sendable
    func uploadImage(req: Request) async throws -> UploadResponse {
        guard let file = try? req.content.decode(FileUpload.self) else {
            throw Abort(.badRequest, reason: "请选择文件")
        }
        
        // TODO: 集成阿里云 OSS 上传
        // 暂时返回模拟 URL
        let fileName = "\(UUID().uuidString).\(file.file.extension ?? "jpg")"
        let url = "https://birdkingdom.oss-cn-shanghai.aliyuncs.com/uploads/images/\(fileName)"
        
        req.logger.info("📷 上传图片: \(fileName)")
        
        return UploadResponse(url: url, fileName: fileName)
    }
    
    // MARK: - 上传视频
    @Sendable
    func uploadVideo(req: Request) async throws -> UploadResponse {
        guard let file = try? req.content.decode(FileUpload.self) else {
            throw Abort(.badRequest, reason: "请选择文件")
        }
        
        // TODO: 集成阿里云 OSS 上传
        let fileName = "\(UUID().uuidString).\(file.file.extension ?? "mp4")"
        let url = "https://birdkingdom.oss-cn-shanghai.aliyuncs.com/uploads/videos/\(fileName)"
        
        req.logger.info("🎬 上传视频: \(fileName)")
        
        return UploadResponse(url: url, fileName: fileName)
    }
    
    // MARK: - 上传头像
    @Sendable
    func uploadAvatar(req: Request) async throws -> UploadResponse {
        guard let file = try? req.content.decode(FileUpload.self) else {
            throw Abort(.badRequest, reason: "请选择文件")
        }
        
        // TODO: 集成阿里云 OSS 上传
        let fileName = "\(UUID().uuidString).\(file.file.extension ?? "jpg")"
        let url = "https://birdkingdom.oss-cn-shanghai.aliyuncs.com/uploads/avatars/\(fileName)"
        
        req.logger.info("👤 上传头像: \(fileName)")
        
        return UploadResponse(url: url, fileName: fileName)
    }
}

// MARK: - 文件上传请求
struct FileUpload: Content {
    let file: File
}

// MARK: - 上传响应
struct UploadResponse: Content {
    let url: String
    let fileName: String
}
