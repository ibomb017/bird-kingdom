import Foundation
import SwiftUI
import Combine

// MARK: - 认证服务
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    
    private let tokenKey = "auth_token"
    private let userKey = "current_user"
    private let baseURL = URL(string: "http://127.0.0.1:8080/api")!
    
    // 开发模式：设为 true 可跳过验证码验证（但仍调用后端API）
    private let devMode = true
    
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
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.isLoggedIn = true
            self.currentUser = user
            // 验证 token 是否有效
            Task {
                await validateToken(token)
            }
        }
    }
    
    private func saveAuth(token: String, user: User) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        self.isLoggedIn = true
        self.currentUser = user
    }
    
    private func clearAuth() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        self.isLoggedIn = false
        self.currentUser = nil
    }
    
    // MARK: - API 调用
    
    /// 发送验证码
    func sendVerificationCode(phone: String) async throws -> SendCodeResponse {
        // 开发模式：直接返回成功
        if devMode {
            return SendCodeResponse(success: true, message: "验证码已发送（开发模式）")
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/send-code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = SendCodeRequest(phone: phone)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try JSONDecoder().decode(SendCodeResponse.self, from: data)
    }
    
    /// 登录/注册（验证码验证）
    func login(phone: String, code: String) async throws -> LoginResponse {
        isLoading = true
        defer { isLoading = false }
        
        // 调用真实后端 API
        let loginResponse = try await loginToBackend(phone: phone, code: code)
        
        if loginResponse.success, let token = loginResponse.token, let user = loginResponse.user {
            saveAuth(token: token, user: user)
        }
        
        return loginResponse
    }
    
    /// 登出
    func logout() {
        clearAuth()
    }
    
    /// 验证 Token
    private func validateToken(_ token: String) async {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/validate"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                // Token 无效，清除登录状态
                clearAuth()
            }
        } catch {
            // 网络错误，保持当前状态
        }
    }
    
    /// 获取当前用户信息
    func fetchCurrentUser() async throws {
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
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
    
    /// 更新用户信息
    func updateProfile(nickname: String?, bio: String?, avatarUrl: String? = nil) async throws {
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
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
        
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
            throw AuthError.notLoggedIn
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("users/search/\(phone)"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        return try JSONDecoder().decode(SearchUserResponse.self, from: data)
    }
    
    // MARK: - Helper
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                clearAuth()
                throw AuthError.unauthorized
            }
            throw AuthError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// 获取存储的 Token
    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }
}

// MARK: - 认证错误
enum AuthError: Error, LocalizedError {
    case notLoggedIn
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    
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
        }
    }
}
