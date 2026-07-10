import Foundation
import SwiftUI
import Combine
import Security

// MARK: - P0-V04 FIX: 用户切换通知
extension Notification.Name {
    static let userDidChange = Notification.Name("com.birdkingdom.userDidChange")
}

// MARK: - Keychain 帮助类（线程安全）
class KeychainHelper: @unchecked Sendable {
    static let shared = KeychainHelper()
    private let service = "com.birdkingdom.app"
    
    private init() {}
    
    func save(_ data: Data, forKey key: String) {
        // 先尝试删除旧数据
        delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ Keychain 保存成功: \(key)")
        } else {
            print("⚠️ Keychain 保存失败: \(key), 错误码: \(status)")
        }
    }
    
    func read(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            print("✅ Keychain 读取成功: \(key)")
            return result as? Data
        } else {
            print("⚠️ Keychain 读取失败: \(key), 错误码: \(status)")
            return nil
        }
    }
    
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ Keychain 删除成功: \(key)")
        }
    }
}

// MARK: - 认证服务
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    
    // #6 修复：401 处理互斥锁，防止并发 401 重复触发登出
    private var isHandlingTokenExpiration: Bool = false
    
    // #8 修复：登录互斥锁，防止快速切换账号时状态混乱
    private var isLoggingIn: Bool = false
    
    /// 当前用户ID（便捷访问）
    var currentUserId: String? {
        currentUser.map { String($0.id) }
    }
    
    private let tokenKey = "com.birdkingdom.auth_token"
    private let userKey = "com.birdkingdom.current_user"
    private let baseURL = AppConfig.apiBaseURL
    
    // 开发模式：设为 true 可跳过验证码验证（但仍调用后端API）
    // 注意：关闭开发模式后，每个用户需要用自己的手机号登录
    private let devMode = false
    
    private init() {
        // 检查本地存储的登录状态
        loadStoredAuth()
        
        // 开发模式：检查 Token 是否是旧的模拟 Token，如果是则清除并重新登录
        if devMode {
            if let token = getToken(), token.starts(with: "dev_token") {
                // 清除旧的模拟 Token
                clearAuth()
            }
            
            if !isLoggedIn {
                Task {
                    await devLogin()
                }
            }
        }
    }
    
    // MARK: - 开发模式：自动登录
    func devLogin() async {
        do {
            // 调用真实后端 API 登录（使用任意验证码）
            let response = try await loginToBackend(phone: "13800138000", code: "123456")
            if response.success, let token = response.token, let user = response.user {
                await MainActor.run {
                    saveAuth(token: token, user: user)
                }
                print("开发模式自动登录成功")
            }
        } catch {
            print("开发模式自动登录失败: \(error)")
            // 如果后端登录失败，使用模拟数据（仅用于UI显示）
            await MainActor.run {
                let mockUser = User(
                    id: 1,
                    phone: "13800138000",
                    nickname: "鸟の守护者",
                    avatarUrl: nil,
                    bio: "爱鸟人士，养了3只可爱的小鸟🐦",
                    createdAt: Date(),
                    birdCount: 3,
                    logCount: 128,
                    activeDays: 32
                )
                self.isLoggedIn = true
                self.currentUser = mockUser
            }
        }
    }
    
    // 调用后端登录 API
    private func loginToBackend(phone: String, code: String) async throws -> LoginResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = LoginRequest(phone: phone, code: code)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }
    
    // MARK: - 本地存储
    
    private func loadStoredAuth() {
        // 从 Keychain 读取 token（更安全）
        if let tokenData = KeychainHelper.shared.read(forKey: tokenKey),
           let token = String(data: tokenData, encoding: .utf8) {
            // 从 UserDefaults 读取用户信息（非敏感数据）
            if let userData = UserDefaults.standard.data(forKey: userKey),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                self.isLoggedIn = true
                self.currentUser = user
                
                // 异步验证 token 是否有效（不阻塞启动）
                Task {
                    await validateToken(token)
                }
            }
        }
    }
    
    private func saveAuth(token: String, user: User) {
        // 保存 token 到 Keychain（加密存储，更安全）
        if let tokenData = token.data(using: .utf8) {
            KeychainHelper.shared.save(tokenData, forKey: tokenKey)
        }
        // 保存用户信息到 UserDefaults（非敏感数据）
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        self.isLoggedIn = true
        self.currentUser = user
        
        // P0-V04 FIX: 发送用户切换通知
        NotificationCenter.default.post(name: .userDidChange, object: nil)
        
        // 登录成功后立即加载拉黑列表，确保广场帖子过滤生效
        Task {
            await SocialService.shared.loadBlockedUsers()
        }
    }
    
    // #3 修复：改进登出原子性，使用标记保证完整性
    // #16 修复：登出时清除 OfflineDataService 用户数据
    private func clearAuth() {
        // 设置清理标记（用于 App 重启时检测中断的清理）
        UserDefaults.standard.set(true, forKey: "isLoggingOut")
        
        // #16 修复：先清除 OfflineDataService 中的用户数据（必须在 currentUserId 仍可用时调用）
        OfflineDataService.shared.clearAllUserData()
        
        // 清除 Keychain 中的 Token
        KeychainHelper.shared.delete(forKey: tokenKey)
        // 清除 UserDefaults 中的用户信息
        UserDefaults.standard.removeObject(forKey: userKey)
        self.isLoggedIn = false
        self.currentUser = nil
        
        // 清除其他服务的用户数据（防止数据泄露）
        SocialService.shared.clearAllData()
        TrashService.shared.clearAllData()
        PostCacheService.shared.clearAllCache()
        PostStore.shared.clearAll()  // Fix #21: 清理帖子状态
        
        // #7 FIX: 清除幂等性缓存
        IdempotencyHelper.shared.clearAll()
        
        // 重置主题为默认
        UserDefaults.standard.removeObject(forKey: "selectedTheme")
        
        // 清理完成，移除标记
        UserDefaults.standard.removeObject(forKey: "isLoggingOut")
        
        // 重置 401 处理标志
        isHandlingTokenExpiration = false
        
        // P0-V04 FIX: 发送用户切换通知
        NotificationCenter.default.post(name: .userDidChange, object: nil)
    }
    
    // MARK: - API 调用
    
    /// 发送登录验证码（手机号必须已注册）
    func sendLoginCode(phone: String) async throws -> SendCodeResponse {
        let url = baseURL.appendingPathComponent("auth/send-login-code")
        print("🚀 [AuthService] 发送登录验证码: \(url.absoluteString)")
        print("📦 [AuthService] 参数: phone=\(phone)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = SendCodeRequest(phone: phone)
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 [AuthService] 状态码: \(httpResponse.statusCode)")
                if let str = String(data: data, encoding: .utf8) {
                    print("📄 [AuthService] 响应: \(str)")
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    if let errorResp = try? JSONDecoder().decode(VaporErrorResponse.self, from: data) {
                        print("⚠️ [AuthService] 服务端错误: \(errorResp.reason)")
                        throw AuthError.serverError(errorResp.reason)
                    }
                }
            }
            
            try validateResponse(response)
            return try JSONDecoder().decode(SendCodeResponse.self, from: data)
        } catch {
            print("❌ [AuthService] 请求崩溃: \(error)")
            throw error
        }
    }
    
    /// 发送注册验证码（手机号必须未注册）
    func sendRegisterCode(phone: String) async throws -> SendCodeResponse {
        let url = baseURL.appendingPathComponent("auth/send-register-code")
        print("🚀 [AuthService] 发送注册验证码: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = SendCodeRequest(phone: phone)
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 [AuthService] 状态码: \(httpResponse.statusCode)")
                if let str = String(data: data, encoding: .utf8) {
                    print("📄 [AuthService] 响应: \(str)")
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    if let errorResp = try? JSONDecoder().decode(VaporErrorResponse.self, from: data) {
                        print("⚠️ [AuthService] 服务端错误: \(errorResp.reason)")
                        throw AuthError.serverError(errorResp.reason)
                    }
                }
            }
            
            try validateResponse(response)
            return try JSONDecoder().decode(SendCodeResponse.self, from: data)
        } catch {
            print("❌ [AuthService] 请求崩溃: \(error)")
            throw error
        }
    }
    
    /// 登录（手机号必须已注册）
    func login(phone: String, code: String) async throws -> LoginResponse {
        isLoading = true
        defer { isLoading = false }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["phone": phone, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 尝试解析服务端错误信息
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            if let errorResp = try? JSONDecoder().decode(VaporErrorResponse.self, from: data) {
                // 如果是 401 且 reason 是关于验证码的，不应该当作 token 过期
                if httpResponse.statusCode == 401 && (errorResp.reason.contains("验证码") || errorResp.reason.contains("密码")) {
                     throw AuthError.loginFailed(errorResp.reason)
                }
                throw AuthError.serverError(errorResp.reason)
            }
        }
        
        try validateResponse(response)
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        if loginResponse.success, let token = loginResponse.token, let user = loginResponse.user {
            saveAuth(token: token, user: user)
        }
        
        return loginResponse
    }
    
    /// 注册（手机号必须未注册，需要设置密码）
    func register(phone: String, code: String, password: String) async throws -> LoginResponse {
        isLoading = true
        defer { isLoading = false }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["phone": phone, "code": code, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 尝试解析服务端错误信息
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            if let errorResp = try? JSONDecoder().decode(VaporErrorResponse.self, from: data) {
                // 注册错误（如验证码不正确）
                if httpResponse.statusCode == 401 && (errorResp.reason.contains("验证码")) {
                     throw AuthError.loginFailed(errorResp.reason)
                }
                throw AuthError.serverError(errorResp.reason)
            }
        }
        
        try validateResponse(response)
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        if loginResponse.success, let token = loginResponse.token, let user = loginResponse.user {
            saveAuth(token: token, user: user)
        }
        
        return loginResponse
    }
    
    /// 密码登录 - 用于已注册用户
    func loginWithPassword(phone: String, password: String) async throws -> LoginResponse {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("auth/login-password"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: String] = ["phone": phone, "password": password]
            request.httpBody = try JSONEncoder().encode(body)
            
            print("🚀 [AuthService] Password Login Request: \(request.url?.absoluteString ?? "nil")")
            print("📦 [AuthService] Body: phone=\(phone), password=******")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 [AuthService] Response Status: \(httpResponse.statusCode)")
                if let str = String(data: data, encoding: .utf8) {
                    print("📄 [AuthService] Response Body: \(str)")
                }
                
                if httpResponse.statusCode == 401 {
                    if let errorResponse = try? JSONDecoder().decode(LoginResponse.self, from: data) {
                        throw AuthError.loginFailed(errorResponse.message)
                    }
                    throw AuthError.loginFailed("密码错误或用户未注册")
                } else if httpResponse.statusCode == 404 {
                    throw AuthError.loginFailed("该手机号未注册")
                } else if httpResponse.statusCode != 200 {
                    throw AuthError.loginFailed("登录失败，状态码: \(httpResponse.statusCode)")
                }
            }
            
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            
            if !loginResponse.success {
                let errorMsg = loginResponse.message
                print("⚠️ [AuthService] Login Failed: \(errorMsg)")
                throw AuthError.loginFailed(errorMsg)
            }
            
            if let token = loginResponse.token, let user = loginResponse.user {
                print("✅ [AuthService] Login Success for user: \(user.id)")
                saveAuth(token: token, user: user)
            } else {
                 print("⚠️ [AuthService] Result Missing Token or User")
                 throw AuthError.loginFailed("登录失败，未获取到用户信息")
            }
            
            return loginResponse
        } catch {
            print("❌ [AuthService] Network Error: \(error)")
            throw error
        }
    }
    
    /// 设置密码
    func setPassword(password: String) async throws {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/set-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = ["password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        // 更新用户信息，标记已设置密码
        if var user = currentUser {
            user.hasPassword = true
            currentUser = user
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: userKey)
            }
        }
    }
    
    /// 检查用户是否存在（用于判断是登录还是注册）
    func checkUserExists(phone: String) async throws -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/check-user"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["phone": phone]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let result = try JSONDecoder().decode([String: Bool].self, from: data)
        return result["exists"] ?? false
    }
    
    // MARK: - 换绑手机号
    
    /// 验证旧手机号（换绑第一步）
    func verifyOldPhone(code: String) async throws {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/change-phone/verify-old"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = ["code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }
    
    /// 发送换绑验证码到新手机号（换绑第二步）
    func sendChangePhoneCode(newPhone: String) async throws {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/change-phone/send-code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = ["newPhone": newPhone]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }
    
    /// 完成换绑手机号（换绑第三步）
    func completeChangePhone(newPhone: String, code: String) async throws {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/change-phone"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = ["newPhone": newPhone, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        // 更新本地用户信息
        if var user = currentUser {
            user.phone = newPhone
            currentUser = user
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: userKey)
            }
        }
    }
    
    // MARK: - Fix #25 & #6: API 401 时统一处理 Token 过期（带互斥锁）
    
    /// 处理 Token 过期（由 ApiService 在收到 401 时调用）
    /// #6 修复：添加互斥锁防止并发 401 重复触发
    func handleTokenExpired() {
        // 防止重复处理
        guard isLoggedIn && !isHandlingTokenExpiration else { return }
        
        isHandlingTokenExpiration = true
        
        clearAuth()
        
        // 发送通知，让 UI 层可以响应（如弹出重新登录提示）
        NotificationCenter.default.post(
            name: NSNotification.Name("TokenExpired"),
            object: nil,
            userInfo: ["message": "登录已过期，请重新登录"]
        )
    }
    
    /// 登出
    func logout() {
        clearAuth()
        // 清空支出数据
        Task { @MainActor in
            ExpenseService.shared.clearData()
        }
    }
    
    /// 验证 Token
    private func validateToken(_ token: String) async {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/validate"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // 只有明确的401未授权才清除登录状态
                // 其他错误（如500服务器错误、网络超时等）保持登录状态
                if httpResponse.statusCode == 401 {
                    clearAuth()
                }
            }
        } catch {
            // 网络错误，保持当前状态，不清除登录
            print("Token验证网络错误，保持登录状态: \(error.localizedDescription)")
        }
    }
    
    /// 获取当前用户信息
    func fetchCurrentUser() async throws {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/me"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let user = try JSONDecoder().decode(User.self, from: data)
        self.currentUser = user
        
        // 更新本地存储
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
    }
    
    /// P0-01: 从后端校验VIP状态（防止本地缓存篡改）
    /// 返回后端确认的VIP有效性，同时刷新本地用户数据
    func checkVipStatus() async throws -> Bool {
        try await fetchCurrentUser()
        return currentUser?.isVipValid ?? false
    }
    
    /// 更新用户信息
    func updateProfile(nickname: String?, bio: String?, avatarUrl: String? = nil) async throws {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/profile"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = UpdateUserRequest(nickname: nickname, bio: bio, avatarUrl: avatarUrl)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let user = try JSONDecoder().decode(User.self, from: data)
        self.currentUser = user
        
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
    }
    
    /// 通过手机号搜索用户
    func searchUserByPhone(_ phone: String) async throws -> SearchUserResponse {
        // 开发模式：模拟搜索结果
        if devMode {
            if phone.count == 11 {
                let mockUser = UserBrief(id: 2, phone: phone, nickname: "小鸟爱好者", avatarUrl: nil)
                return SearchUserResponse(found: true, user: mockUser)
            } else {
                return SearchUserResponse(found: false, user: nil)
            }
        }
        
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/users/search/\(phone)"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode(SearchUserResponse.self, from: data)
    }
    
    // MARK: - 情侣邀请
    
    /// 获取待确认的情侣邀请
    func getPendingCoupleInvitation() async throws -> CoupleInvitationResponse {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/invitation"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CoupleInvitationResponse.self, from: data)
    }
    
    /// 接受情侣邀请
    func acceptCoupleInvitation() async throws -> CoupleActionResponse {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/invitation/accept"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let result = try JSONDecoder().decode(CoupleActionResponse.self, from: data)
        
        // 接受成功后刷新用户信息
        if result.success {
            try await fetchCurrentUser()
        }
        
        return result
    }
    
    /// 拒绝情侣邀请
    func rejectCoupleInvitation() async throws -> CoupleActionResponse {
        guard let token = getToken() else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/invitation/reject"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode(CoupleActionResponse.self, from: data)
    }
    
    // MARK: - Helper
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                // P0 修复：401 只抛出错误，不自动清除登录状态
                // 只有 auth/validate 接口会在确认 Token 无效时调用 clearAuth
                throw AuthError.unauthorized
            }
            throw AuthError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// 获取存储的 Token (nonisolated 允许在任何线程调用)
    nonisolated func getToken() -> String? {
        // 从 Keychain 读取 Token（安全存储）
        guard let tokenData = KeychainHelper.shared.read(forKey: "com.birdkingdom.auth_token") else {
            return nil
        }
        return String(data: tokenData, encoding: .utf8)
    }
}

// MARK: - 认证错误
enum AuthError: Error, LocalizedError {
    case notLoggedIn
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case loginFailed(String)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "请先登录"
        case .invalidResponse:
            return "服务器响应无效"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .httpError(let code):
            return "请求失败 (\(code))"
        case .loginFailed(let message):
            return message
        case .serverError(let message):
            return message
        }
    }
}

struct VaporErrorResponse: Decodable {
    let error: Bool
    let reason: String
}
