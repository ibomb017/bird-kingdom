import Vapor
import Fluent
import JWT

/// 认证控制器
struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        
        // 发送登录验证码
        auth.post("send-login-code", use: sendLoginCode)
        
        // 发送注册验证码
        auth.post("send-register-code", use: sendRegisterCode)
        
        // 通用发送验证码接口（不检查用户是否存在）
        auth.post("send-code", use: sendCode)
        
        // 验证码登录
        auth.post("login", use: login)
        
        // 注册
        auth.post("register", use: register)
        
        // 密码登录
        auth.post("login-password", use: loginWithPassword)

        
        // 需要认证的路由
        let protected = auth.grouped(JWTAuthMiddleware())
        
        // 验证验证码
        protected.post("verify-code", use: verifyCode)
        
        // 设置密码
        protected.post("set-password", use: setPassword)
        
        // 修改密码
        protected.post("change-password", use: changePassword)
        
        // 重置密码
        auth.post("reset-password", use: resetPassword)
        
        // 修改手机号（完整流程）
        protected.post("change-phone", use: changePhone)
        
        // 换绑手机号子路由
        protected.post("change-phone", "verify-old", use: verifyOldPhone)
        protected.post("change-phone", "send-code", use: sendChangePhoneCode)
        
        // 删除账号
        protected.delete("delete-account", use: deleteAccount)
        
        // 获取当前用户信息
        protected.get("me", use: getCurrentUser)
        
        // 更新用户信息
        protected.put("profile", use: updateProfile)
        
        // 验证 Token 是否有效（用于登录状态保持检查）
        protected.get("validate", use: validateToken)
        
        // 检查用户是否存在
        auth.post("check-user", use: checkUser)
        
        // 搜索用户（通过手机号）
        protected.get("users", "search", ":phone", use: searchUserByPhone)
        
        // MARK: - 情侣功能路由
        let couple = protected.grouped("couple")
        couple.post("bind", use: bindCouple)
        couple.post("unbind", use: unbindCouple)
        couple.get("invitation", use: getCoupleInvitation)
        couple.post("invitation", "accept", use: acceptCoupleInvitation)
        couple.post("invitation", "reject", use: rejectCoupleInvitation)
        couple.post("cancel-pending", use: cancelPendingInvitation)
        couple.post("update-pending", use: updatePendingInvitation)
        
        // MARK: - VIP 功能路由
        let vip = protected.grouped("vip")
        vip.post("purchase", use: purchaseVip)
        vip.post("restore", use: restoreVip)
    }
    
    // MARK: - 发送登录验证码
    @Sendable
    func sendLoginCode(req: Request) async throws -> [String: Bool] {
        struct SendCodeRequest: Content {
            let phone: String
        }
        let input = try req.content.decode(SendCodeRequest.self)
        
        // 检查用户是否存在
        let existingUser = try await User.query(on: req.db)
            .filter(\.$phone == input.phone)
            .first()
            
        guard existingUser != nil else {
            req.logger.warning("❌ [Auth] 登录验证码请求失败：手机号未注册 - \(input.phone)")
            throw Abort(.notFound, reason: "该手机号未注册，请先注册")
        }
        
        return try await sendSmsCode(req: req, phone: input.phone)
    }
    
    // MARK: - 发送注册验证码
    @Sendable
    func sendRegisterCode(req: Request) async throws -> [String: Bool] {
        struct SendCodeRequest: Content {
            let phone: String
        }
        let input = try req.content.decode(SendCodeRequest.self)
        
        // 检查用户是否已存在
        let existingUser = try await User.query(on: req.db)
            .filter(\.$phone == input.phone)
            .first()
            
        guard existingUser == nil else {
            req.logger.warning("❌ [Auth] 注册验证码请求失败：手机号已注册 - \(input.phone)")
            throw Abort(.conflict, reason: "该手机号已注册，请直接登录")
        }
        
        return try await sendSmsCode(req: req, phone: input.phone)
    }
    
    // MARK: - 通用发送验证码（不检查用户是否存在）
    @Sendable
    func sendCode(req: Request) async throws -> [String: Bool] {
        struct SendCodeRequest: Content {
            let phone: String
        }
        let input = try req.content.decode(SendCodeRequest.self)
        
        // 直接发送验证码，不检查用户是否存在
        // 用于重置密码、换绑手机等场景
        return try await sendSmsCode(req: req, phone: input.phone)
    }
    
    // MARK: - 发送短信通用逻辑

    private func sendSmsCode(req: Request, phone: String) async throws -> [String: Bool] {
        // 生成6位验证码
        let code = String(format: "%06d", Int.random(in: 0...999999))
        
        // 验证码5分钟后过期
        let expireAt = Date().addingTimeInterval(5 * 60)
        
        // 保存验证码
        let verificationCode = VerificationCode(
            phone: phone,
            code: code,
            expireAt: expireAt
        )
        try await verificationCode.save(on: req.db)
        
        // 调用 Java SMS Proxy 发送短信
        let proxyUrl = Environment.get("SMS_PROXY_URL") ?? "http://127.0.0.1:8082/internal/sms/send"
        let apiKey = Environment.get("SMS_PROXY_API_KEY") ?? "dev-api-key-change-in-production"
        
        do {
            // 开发模式下，同时打印日志方便调试
            req.logger.info("📱 验证码: \(code) -> \(phone)")
            
            let response = try await req.client.post(URI(string: proxyUrl)) { request in
                request.headers.add(name: "X-API-Key", value: apiKey)
                try request.content.encode(["phone": phone, "code": code])
            }
            
            if response.status == .ok {
                struct ProxyResponse: Decodable {
                    let success: Bool
                    let message: String?
                }
                
                if let proxyBody = try? response.content.decode(ProxyResponse.self) {
                    if proxyBody.success {
                        req.logger.info("✅ 已通过 Proxy 发送短信: \(phone)")
                    } else {
                        req.logger.error("❌ SMS Proxy 业务失败: \(proxyBody.message ?? "未知错误")")
                        throw Abort(.tooManyRequests, reason: "短信发送失败: \(proxyBody.message ?? "发送频繁")")
                    }
                } else {
                    req.logger.info("✅ 已通过 Proxy 发送短信 (无法解析响应体): \(phone)")
                }
            } else {
                req.logger.error("❌ SMS Proxy 返回错误: \(response.status)")
                throw Abort(.internalServerError, reason: "短信服务暂不可用")
            }
        } catch {
            req.logger.error("❌ SMS Proxy 调用失败: \(error)")
            // 如果是 AbortError，直接抛出
            if let abort = error as? AbortError {
                throw abort
            }
            throw Abort(.internalServerError, reason: "短信发送系统故障")
        }
        
        return ["success": true]
    }
    
    // MARK: - 验证码登录
    @Sendable
    func login(req: Request) async throws -> LoginResponse {
        struct LoginRequest: Content {
            let phone: String
            let code: String
        }
        
        let input = try req.content.decode(LoginRequest.self)
        
        // 验证验证码
        guard let verificationCode = try await VerificationCode.query(on: req.db)
            .filter(\.$phone == input.phone)
            .filter(\.$used == false)
            .filter(\.$expireAt > Date())
            .sort(\.$createdAt, .descending)
            .first() else {
            throw Abort(.unauthorized, reason: "验证码错误或已过期")
        }
        
        // 开发模式允许万能验证码
        let isDevMode = Environment.get("APP_DEV_MODE") == "true"
        
        if input.code != verificationCode.code && !(isDevMode && input.code == "123456") {
            req.logger.warning("❌ [Auth] 验证码不匹配: 输入='\(input.code)', 数据库='\(verificationCode.code)', Phone='\(input.phone)'")
            throw Abort(.unauthorized, reason: "验证码错误")
        }
        
        // 标记验证码已使用
        verificationCode.used = true
        try await verificationCode.save(on: req.db)
        
        // 查找或创建用户
        var user = try await User.query(on: req.db)
            .filter(\.$phone == input.phone)
            .first()
        
        var isNewUser = false
        if user == nil {
            // 创建新用户
            user = User(
                phone: input.phone,
                nickname: "鸟友\(String(input.phone.suffix(4)))"
            )
            try await user!.save(on: req.db)
            isNewUser = true
        }
        
        guard let user = user else {
            throw Abort(.internalServerError, reason: "用户创建失败")
        }
        
        // 生成 JWT Token
        let token = try generateToken(for: user, req: req)
        
        return LoginResponse(
            success: true,
            message: isNewUser ? "注册成功" : "登录成功",
            token: token,
            user: UserDTO.from(user)
        )
    }
    
    // MARK: - 注册
    @Sendable
    func register(req: Request) async throws -> LoginResponse {
        struct RegisterRequest: Content {
            let phone: String
            let code: String
            let password: String
        }
        
        let input = try req.content.decode(RegisterRequest.self)
        
        // 验证验证码
        guard let verificationCode = try await VerificationCode.query(on: req.db)
            .filter(\.$phone == input.phone)
            .filter(\.$code == input.code)
            .filter(\.$used == false)
            .filter(\.$expireAt > Date())
            .sort(\.$createdAt, .descending)
            .first() else {
            throw Abort(.unauthorized, reason: "验证码错误或已过期")
        }
        
        // 标记验证码已使用
        verificationCode.used = true
        try await verificationCode.save(on: req.db)
        
        // 检查用户是否已存在
        if let _ = try await User.query(on: req.db)
            .filter(\.$phone == input.phone)
            .first() {
            throw Abort(.conflict, reason: "该手机号已注册")
        }
        
        // 创建新用户
        let user = User(
            phone: input.phone,
            nickname: "鸟友\(String(input.phone.suffix(4)))"
        )
        // 设置密码
        user.password = try Bcrypt.hash(input.password)
        
        try await user.save(on: req.db)
        
        // 生成 JWT Token
        let token = try generateToken(for: user, req: req)
        
        return LoginResponse(
            success: true,
            message: "注册成功",
            token: token,
            user: UserDTO.from(user)
        )
    }
    
    // MARK: - 密码登录
    @Sendable
    func loginWithPassword(req: Request) async throws -> LoginResponse {
        struct PasswordLoginRequest: Content {
            let phone: String
            let password: String
        }
        
        let input = try req.content.decode(PasswordLoginRequest.self)
        
        // 查找用户
        guard let user = try await User.query(on: req.db)
            .filter(\.$phone == input.phone)
            .first() else {
            throw Abort(.unauthorized, reason: "用户不存在")
        }
        
        // 验证密码
        guard let storedPassword = user.password else {
            throw Abort(.unauthorized, reason: "请使用验证码登录")
        }
        
        guard try Bcrypt.verify(input.password, created: storedPassword) else {
            throw Abort(.unauthorized, reason: "密码错误")
        }
        
        // 生成 JWT Token
        let token = try generateToken(for: user, req: req)
        
        return LoginResponse(
            success: true,
            message: "登录成功",
            token: token,
            user: UserDTO.from(user)
        )
    }
    
    // MARK: - 验证验证码
    @Sendable
    func verifyCode(req: Request) async throws -> [String: Bool] {
        struct VerifyRequest: Content {
            let phone: String
            let code: String
        }
        
        let input = try req.content.decode(VerifyRequest.self)
        
        guard let verificationCode = try await VerificationCode.query(on: req.db)
            .filter(\.$phone == input.phone)
            .filter(\.$code == input.code)
            .filter(\.$used == false)
            .filter(\.$expireAt > Date())
            .first() else {
            return ["valid": false]
        }
        
        // 标记为已使用
        verificationCode.used = true
        try await verificationCode.save(on: req.db)
        
        return ["valid": true]
    }
    
    // MARK: - 设置密码
    @Sendable
    func setPassword(req: Request) async throws -> [String: Bool] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct SetPasswordRequest: Content {
            let password: String
        }
        
        let input = try req.content.decode(SetPasswordRequest.self)
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // 加密密码
        user.password = try Bcrypt.hash(input.password)
        try await user.save(on: req.db)
        
        return ["success": true]
    }
    
    // MARK: - 修改密码
    @Sendable
    func changePassword(req: Request) async throws -> LoginResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct ChangePasswordRequest: Content {
            let oldPassword: String
            let newPassword: String
        }
        
        let input = try req.content.decode(ChangePasswordRequest.self)
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // 验证旧密码
        guard let storedPassword = user.password,
              try Bcrypt.verify(input.oldPassword, created: storedPassword) else {
            throw Abort(.unauthorized, reason: "原密码错误")
        }
        
        // 设置新密码
        user.password = try Bcrypt.hash(input.newPassword)
        try await user.save(on: req.db)
        
        // 生成新 Token
        let token = try generateToken(for: user, req: req)
        
        return LoginResponse(
            success: true,
            message: "密码修改成功",
            token: token,
            user: UserDTO.from(user)
        )
    }
    
    // MARK: - 重置密码
    @Sendable
    func resetPassword(req: Request) async throws -> LoginResponse {
        struct ResetPasswordRequest: Content {
            let phone: String
            let code: String
            let newPassword: String
        }
        
        let input = try req.content.decode(ResetPasswordRequest.self)
        
        // 验证验证码
        guard let verificationCode = try await VerificationCode.query(on: req.db)
            .filter(\.$phone == input.phone)
            .filter(\.$code == input.code)
            .filter(\.$used == false)
            .filter(\.$expireAt > Date())
            .first() else {
            throw Abort(.unauthorized, reason: "验证码错误或已过期")
        }
        
        verificationCode.used = true
        try await verificationCode.save(on: req.db)
        
        // 查找用户
        guard let user = try await User.query(on: req.db)
            .filter(\.$phone == input.phone)
            .first() else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // 设置新密码
        user.password = try Bcrypt.hash(input.newPassword)
        try await user.save(on: req.db)
        
        // 生成 Token
        let token = try generateToken(for: user, req: req)
        
        return LoginResponse(
            success: true,
            message: "密码重置成功",
            token: token,
            user: UserDTO.from(user)
        )
    }
    
    // MARK: - 修改手机号
    @Sendable
    func changePhone(req: Request) async throws -> [String: Bool] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct ChangePhoneRequest: Content {
            let newPhone: String
            let code: String
        }
        
        let input = try req.content.decode(ChangePhoneRequest.self)
        
        // 验证验证码
        guard let verificationCode = try await VerificationCode.query(on: req.db)
            .filter(\.$phone == input.newPhone)
            .filter(\.$code == input.code)
            .filter(\.$used == false)
            .filter(\.$expireAt > Date())
            .first() else {
            throw Abort(.unauthorized, reason: "验证码错误或已过期")
        }
        
        verificationCode.used = true
        try await verificationCode.save(on: req.db)
        
        // 检查新手机号是否已被使用
        let existingUser = try await User.query(on: req.db)
            .filter(\.$phone == input.newPhone)
            .first()
        
        if existingUser != nil {
            throw Abort(.conflict, reason: "该手机号已被使用")
        }
        
        // 更新手机号
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        user.phone = input.newPhone
        try await user.save(on: req.db)
        
        return ["success": true]
    }
    
    // MARK: - 删除账号
    @Sendable
    func deleteAccount(req: Request) async throws -> HTTPStatus {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        try await user.delete(on: req.db)
        
        return .noContent
    }
    
    // MARK: - 获取当前用户
    @Sendable
    func getCurrentUser(req: Request) async throws -> UserDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // 记录活跃状态
        await logUserActivity(userId: userId, req: req)
        
        return UserDTO.from(user)
    }
    
    // MARK: - 更新用户信息
    @Sendable
    func updateProfile(req: Request) async throws -> UserDTO {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct UpdateProfileRequest: Content {
            let nickname: String?
            let avatarUrl: String?
            let bio: String?
        }
        
        let input = try req.content.decode(UpdateProfileRequest.self)
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        if let nickname = input.nickname {
            user.nickname = nickname
        }
        if let avatarUrl = input.avatarUrl {
            user.avatarUrl = avatarUrl
        }
        if let bio = input.bio {
            user.bio = bio
        }
        
        try await user.save(on: req.db)
        
        return UserDTO.from(user)
    }
    
    // MARK: - 验证 Token 是否有效
    @Sendable
    func validateToken(req: Request) async throws -> [String: Bool] {
        // 如果能通过 JWTAuthMiddleware 到达这里，说明 Token 有效
        _ = try req.auth.require(AuthPayload.self)
        return ["valid": true]
    }
    
    // MARK: - 生成 JWT Token
    private func generateToken(for user: User, req: Request) throws -> String {
        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "用户ID无效")
        }
        
        // 记录活跃状态 (fire and forget)
        Task {
            await logUserActivity(userId: userId, req: req)
        }
        
        let payload = AuthPayload(
            userId: userId,
            phone: user.phone,
            exp: .init(value: Date().addingTimeInterval(30 * 24 * 60 * 60)) // 30天过期
        )
        
        return try req.jwt.sign(payload)
    }
    
    // MARK: - 记录用户活跃
    private func logUserActivity(userId: Int64, req: Request) async {
        do {
            // 定义中国时区
            var calendar = Calendar.current
            if let timeZone = TimeZone(identifier: "Asia/Shanghai") {
                calendar.timeZone = timeZone
            }
            
            let now = Date()
            let today = calendar.startOfDay(for: now)
            
            // 先尝试查找今天的记录
            // 注意：由于Swift Date包含时间，而DB除了DATETIME还有DATE类型，查询需谨慎
            // 这里我们使用范围查询或直接尝试插入(如果唯一约束允许)
            // 简单起见，我们查一下是否有今天的记录 (Range: today 00:00:00 to tomorrow 00:00:00)
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }
            
            let existingLog = try await UserActivityLog.query(on: req.db)
                .filter(\.$userId == userId)
                .filter(\.$activityDate >= today)
                .filter(\.$activityDate < tomorrow)
                .first()
                
            if let log = existingLog {
                // 更新最后活跃时间
                log.lastActiveAt = now
                try await log.save(on: req.db)
            } else {
                // 创建新记录
                let log = UserActivityLog(userId: userId, activityDate: today, lastActiveAt: now)
                try await log.save(on: req.db)
            }
        } catch {
            // 记录日志错误但不影响主流程
            req.logger.error("⚠️ 活跃用户日志记录失败: \(error)")
        }
    }
    
    // MARK: - 检查用户是否存在
    @Sendable
    func checkUser(req: Request) async throws -> [String: Bool] {
        struct CheckUserRequest: Content {
            let phone: String
        }
        
        let input = try req.content.decode(CheckUserRequest.self)
        
        let user = try await User.query(on: req.db)
            .filter(\.$phone == input.phone)
            .first()
        
        return ["exists": user != nil]
    }
    
    // MARK: - 搜索用户（通过手机号）
    @Sendable
    func searchUserByPhone(req: Request) async throws -> SearchUserResponse {
        guard let phone = req.parameters.get("phone") else {
            throw Abort(.badRequest, reason: "缺少手机号")
        }
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$phone == phone)
            .first() else {
            return SearchUserResponse(found: false, user: nil)
        }
        
        return SearchUserResponse(
            found: true,
            user: UserBriefDTO(id: user.id ?? 0, phone: user.phone, nickname: user.nickname, avatarUrl: user.avatarUrl)
        )
    }
    
    // MARK: - 换绑手机号 - 验证旧手机
    @Sendable
    func verifyOldPhone(req: Request) async throws -> [String: Bool] {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct VerifyOldRequest: Content {
            let code: String
        }
        
        let input = try req.content.decode(VerifyOldRequest.self)
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // 验证验证码
        guard let verificationCode = try await VerificationCode.query(on: req.db)
            .filter(\.$phone == user.phone)
            .filter(\.$code == input.code)
            .filter(\.$used == false)
            .filter(\.$expireAt > Date())
            .first() else {
            throw Abort(.unauthorized, reason: "验证码错误或已过期")
        }
        
        verificationCode.used = true
        try await verificationCode.save(on: req.db)
        
        return ["success": true]
    }
    
    // MARK: - 换绑手机号 - 发送新手机验证码
    @Sendable
    func sendChangePhoneCode(req: Request) async throws -> [String: Bool] {
        struct SendCodeRequest: Content {
            let newPhone: String
        }
        
        let input = try req.content.decode(SendCodeRequest.self)
        
        // 检查新手机号是否已被使用
        let existingUser = try await User.query(on: req.db)
            .filter(\.$phone == input.newPhone)
            .first()
        
        if existingUser != nil {
            throw Abort(.conflict, reason: "该手机号已被使用")
        }
        
        return try await sendSmsCode(req: req, phone: input.newPhone)
    }
    
    // MARK: - 情侣功能 - 绑定
    @Sendable
    func bindCouple(req: Request) async throws -> CoupleActionResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct BindRequest: Content {
            let partnerPhone: String
        }
        
        let input = try req.content.decode(BindRequest.self)
        
        // 查找目标用户
        guard let partner = try await User.query(on: req.db)
            .filter(\.$phone == input.partnerPhone)
            .first() else {
            return CoupleActionResponse(success: false, message: "用户不存在")
        }
        
        guard let partnerId = partner.id else {
            return CoupleActionResponse(success: false, message: "用户信息无效")
        }
        
        if partnerId == userId {
            return CoupleActionResponse(success: false, message: "不能与自己绑定")
        }
        
        // 检查对方是否已有情侣
        if partner.couplePartnerId != nil {
            return CoupleActionResponse(success: false, message: "对方已有情侣")
        }
        
        // 检查自己是否已有情侣
        guard let user = try await User.find(userId, on: req.db) else {
            return CoupleActionResponse(success: false, message: "用户不存在")
        }
        
        if user.couplePartnerId != nil {
            return CoupleActionResponse(success: false, message: "您已有情侣")
        }
        
        // 创建邀请或直接绑定（简化版本：直接绑定）
        user.couplePartnerId = partnerId
        partner.couplePartnerId = userId
        
        try await user.save(on: req.db)
        try await partner.save(on: req.db)
        
        return CoupleActionResponse(success: true, message: "绑定成功")
    }
    
    // MARK: - 情侣功能 - 解绑
    @Sendable
    func unbindCouple(req: Request) async throws -> CoupleActionResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let user = try await User.find(userId, on: req.db) else {
            return CoupleActionResponse(success: false, message: "用户不存在")
        }
        
        guard let partnerId = user.couplePartnerId else {
            return CoupleActionResponse(success: false, message: "您还没有情侣")
        }
        
        // 解除双方绑定
        user.couplePartnerId = nil
        try await user.save(on: req.db)
        
        if let partner = try await User.find(partnerId, on: req.db) {
            partner.couplePartnerId = nil
            try await partner.save(on: req.db)
        }
        
        return CoupleActionResponse(success: true, message: "解绑成功")
    }
    
    // MARK: - 情侣功能 - 获取邀请
    @Sendable
    func getCoupleInvitation(req: Request) async throws -> CoupleInvitationDTO {
        // 简化版本：返回空邀请
        return CoupleInvitationDTO(pending: false, invitation: nil)
    }
    
    // MARK: - 情侣功能 - 接受邀请
    @Sendable
    func acceptCoupleInvitation(req: Request) async throws -> CoupleActionResponse {
        return CoupleActionResponse(success: true, message: "已接受邀请")
    }
    
    // MARK: - 情侣功能 - 拒绝邀请
    @Sendable
    func rejectCoupleInvitation(req: Request) async throws -> CoupleActionResponse {
        return CoupleActionResponse(success: true, message: "已拒绝邀请")
    }
    
    // MARK: - 情侣功能 - 取消待处理邀请
    @Sendable
    func cancelPendingInvitation(req: Request) async throws -> CoupleActionResponse {
        return CoupleActionResponse(success: true, message: "已取消邀请")
    }
    
    // MARK: - 情侣功能 - 更新待处理邀请
    @Sendable
    func updatePendingInvitation(req: Request) async throws -> CoupleActionResponse {
        return CoupleActionResponse(success: true, message: "已更新邀请")
    }
    
    // MARK: - VIP - 购买
    @Sendable
    func purchaseVip(req: Request) async throws -> VipActionResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        struct PurchaseRequest: Content {
            let productId: String?
            let receipt: String?
        }
        
        let input = try req.content.decode(PurchaseRequest.self)
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // TODO: 验证 Apple 收据
        // 暂时直接开通 VIP (1年)
        user.vipExpireDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        try await user.save(on: req.db)
        
        return VipActionResponse(success: true, message: "购买成功", expireDate: user.vipExpireDate)
    }
    
    // MARK: - VIP - 恢复购买
    @Sendable
    func restoreVip(req: Request) async throws -> VipActionResponse {
        let userId = try req.auth.require(AuthPayload.self).userId
        
        guard let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "用户不存在")
        }
        
        // TODO: 验证 Apple 收据恢复
        // 暂时返回当前 VIP 状态
        return VipActionResponse(
            success: true,
            message: user.vipExpireDate != nil ? "恢复成功" : "没有可恢复的购买",
            expireDate: user.vipExpireDate
        )
    }
}

// MARK: - JWT 认证负载
struct AuthPayload: JWTPayload, Authenticatable {
    let userId: Int64
    let phone: String
    let exp: ExpirationClaim
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

// MARK: - JWT 认证中间件
struct JWTAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let token = request.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "缺少认证令牌")
        }
        
        do {
            let payload = try await request.jwt.verify(token, as: AuthPayload.self)
            request.auth.login(payload)
        } catch {
            throw Abort(.unauthorized, reason: "令牌无效或已过期")
        }
        
        return try await next.respond(to: request)
    }
}

// MARK: - 响应模型
struct LoginResponse: Content {
    let success: Bool
    let message: String
    let token: String?
    let user: UserDTO?
}

// MARK: - Search User Response
struct SearchUserResponse: Content {
    let found: Bool
    let user: UserBriefDTO?
}

struct UserBriefDTO: Content {
    let id: Int64
    let phone: String
    let nickname: String
    let avatarUrl: String?
}

// MARK: - Couple Response
struct CoupleActionResponse: Content {
    let success: Bool
    let message: String
}

struct CoupleInvitationDTO: Content {
    let pending: Bool
    let invitation: CoupleInvitationItem?
}

struct CoupleInvitationItem: Content {
    let id: Int64
    let fromUserId: Int64
    let fromUserNickname: String
    let createdAt: Date
}

// MARK: - VIP Response
struct VipActionResponse: Content {
    let success: Bool
    let message: String
    let expireDate: Date?
}
