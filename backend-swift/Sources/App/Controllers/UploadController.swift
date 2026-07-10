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
        
        // 获取预签名上传 URL（用于客户端直传）
        protected.post("presign", use: getPresignedURL)
    }
    
    // MARK: - 上传图片
    @Sendable
    func uploadImage(req: Request) async throws -> UploadResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let file = try? req.content.decode(FileUpload.self) else {
            throw Abort(.badRequest, reason: "请选择文件")
        }
        
        // 验证文件类型
        guard let contentType = file.file.contentType,
              ["image/jpeg", "image/png", "image/gif", "image/webp"].contains(contentType.description) else {
            throw Abort(.badRequest, reason: "不支持的图片格式，请上传 JPG/PNG/GIF/WebP")
        }
        
        // 获取文件数据
        guard let data = file.file.data.getData(at: 0, length: file.file.data.readableBytes) else {
            throw Abort(.badRequest, reason: "文件数据读取失败")
        }
        
        let fileName = file.file.filename.isEmpty ? "image.jpg" : file.file.filename
        let ossKey = await OSSService.shared.generateImageKey(userId: userId, filename: fileName)
        
        req.logger.info("📷 开始上传图片: \(ossKey), 大小: \(data.count) bytes")
        
        // 检查是否配置了 OSS
        let ossConfigured = Environment.get("ALIYUN_OSS_ACCESS_KEY_ID")?.isEmpty == false
        
        if ossConfigured {
            // 使用真正的 OSS 上传
            let url = try await OSSService.shared.uploadFile(
                data: data,
                key: ossKey,
                contentType: contentType.description,
                client: req.client
            )
            
            req.logger.info("✅ 图片上传成功: \(url)")
            return UploadResponse(url: url, fileName: fileName)
        } else {
            // 本地存储模式
            let url = try await saveLocally(req: req, data: data, key: ossKey)
            req.logger.info("✅ 图片已保存到本地: \(url)")
            return UploadResponse(url: url, fileName: fileName)
        }
    }
    
    // MARK: - 上传视频
    @Sendable
    func uploadVideo(req: Request) async throws -> UploadResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let file = try? req.content.decode(FileUpload.self) else {
            throw Abort(.badRequest, reason: "请选择文件")
        }
        
        // 验证文件类型
        guard let contentType = file.file.contentType,
              ["video/mp4", "video/quicktime", "video/x-m4v"].contains(contentType.description) else {
            throw Abort(.badRequest, reason: "不支持的视频格式，请上传 MP4/MOV/M4V")
        }
        
        guard let data = file.file.data.getData(at: 0, length: file.file.data.readableBytes) else {
            throw Abort(.badRequest, reason: "文件数据读取失败")
        }
        
        let fileName = file.file.filename.isEmpty ? "video.mp4" : file.file.filename
        let ossKey = await OSSService.shared.generateVideoKey(userId: userId, filename: fileName)
        
        req.logger.info("🎬 开始上传视频: \(ossKey), 大小: \(data.count) bytes")
        
        let ossConfigured = Environment.get("ALIYUN_OSS_ACCESS_KEY_ID")?.isEmpty == false
        
        if ossConfigured {
            let url = try await OSSService.shared.uploadFile(
                data: data,
                key: ossKey,
                contentType: contentType.description,
                client: req.client
            )
            
            req.logger.info("✅ 视频上传成功: \(url)")
            return UploadResponse(url: url, fileName: fileName)
        } else {
            // 本地存储模式
            let url = try await saveLocally(req: req, data: data, key: ossKey)
            req.logger.info("✅ 视频已保存到本地: \(url)")
            return UploadResponse(url: url, fileName: fileName)
        }
    }
    
    // MARK: - 上传头像
    @Sendable
    func uploadAvatar(req: Request) async throws -> UploadResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let file = try? req.content.decode(FileUpload.self) else {
            throw Abort(.badRequest, reason: "请选择文件")
        }
        
        // 验证文件类型
        guard let contentType = file.file.contentType,
              ["image/jpeg", "image/png", "image/webp"].contains(contentType.description) else {
            throw Abort(.badRequest, reason: "不支持的图片格式，请上传 JPG/PNG/WebP")
        }
        
        guard let data = file.file.data.getData(at: 0, length: file.file.data.readableBytes) else {
            throw Abort(.badRequest, reason: "文件数据读取失败")
        }
        
        let fileName = file.file.filename.isEmpty ? "avatar.jpg" : file.file.filename
        let ossKey = await OSSService.shared.generateAvatarKey(userId: userId, filename: fileName)
        
        req.logger.info("👤 开始上传头像: \(ossKey), 大小: \(data.count) bytes")
        
        let ossConfigured = Environment.get("ALIYUN_OSS_ACCESS_KEY_ID")?.isEmpty == false
        
        if ossConfigured {
            let url = try await OSSService.shared.uploadFile(
                data: data,
                key: ossKey,
                contentType: contentType.description,
                client: req.client
            )
            
            req.logger.info("✅ 头像上传成功: \(url)")
            return UploadResponse(url: url, fileName: fileName)
        } else {
            // 本地存储模式
            let url = try await saveLocally(req: req, data: data, key: ossKey)
            req.logger.info("✅ 头像已保存到本地: \(url)")
            return UploadResponse(url: url, fileName: fileName)
        }
    }

    /// 保存文件到本地（当 OSS 未配置时使用）
    private func saveLocally(req: Request, data: Data, key: String) async throws -> String {
        let publicPath = req.application.directory.publicDirectory
        let filePath = publicPath + key
        let fileURL = URL(fileURLWithPath: filePath)
        let directory = fileURL.deletingLastPathComponent()
        
        // 创建目录
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        // 写入文件
        try data.write(to: fileURL)
        
        // 构建返回 URL
        let scheme = req.headers["X-Forwarded-Proto"].first ?? req.url.scheme ?? "http"
        let host = req.headers["Host"].first ?? "localhost:8080"
        return "\(scheme)://\(host)/\(key)"
    }
    
    // MARK: - 获取预签名 URL（用于客户端直传大文件）
    @Sendable
    func getPresignedURL(req: Request) async throws -> PresignedURLResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct PresignRequest: Content {
            let type: String  // "image", "video", "avatar"
            let filename: String
        }
        
        let input = try req.content.decode(PresignRequest.self)
        
        let ossKey: String
        switch input.type {
        case "image":
            ossKey = await OSSService.shared.generateImageKey(userId: userId, filename: input.filename)
        case "video":
            ossKey = await OSSService.shared.generateVideoKey(userId: userId, filename: input.filename)
        case "avatar":
            ossKey = await OSSService.shared.generateAvatarKey(userId: userId, filename: input.filename)
        default:
            throw Abort(.badRequest, reason: "不支持的文件类型")
        }
        
        let presignedURL = await OSSService.shared.generatePresignedURL(key: ossKey, expires: 3600)
        let publicURL = await OSSService.shared.publicBaseURL + "/" + ossKey
        
        return PresignedURLResponse(
            uploadURL: presignedURL,
            publicURL: publicURL,
            ossKey: ossKey,
            expiresIn: 3600
        )
    }
}

// MARK: - 请求和响应模型
struct FileUpload: Content {
    let file: File
}

struct UploadResponse: Content {
    let url: String
    let fileName: String
}

struct PresignedURLResponse: Content {
    let uploadURL: String
    let publicURL: String
    let ossKey: String
    let expiresIn: Int
}
