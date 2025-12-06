import Foundation
import UIKit

enum ApiError: LocalizedError {
    case invalidResponse
    case serverError(String)
    case networkError(Error)
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP错误: \(statusCode)"
        }
    }
}

final class ApiService {
    static let shared = ApiService()
    private init() {}

    // iOS 模拟器访问本机后端建议使用 localhost 或 127.0.0.1
    private let baseURL = URL(string: "http://127.0.0.1:8080/api")!

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // 让每个模型自己处理日期解码
        return decoder
    }()

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // MARK: - 鸟档案

    func getBirds() async throws -> [Bird] {
        let url = baseURL.appendingPathComponent("birds")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Bird].self, from: data)
    }

    func getBird(id: Int) async throws -> Bird {
        let url = baseURL.appendingPathComponent("birds/\(id)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Bird.self, from: data)
    }

    func createBird(_ bird: Bird) async throws -> Bird {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(bird)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Bird.self, from: data)
    }

    func updateBird(id: Int64, nickname: String, species: String, gender: String?, hatchDate: Date?, adoptionDate: Date?, birthdayType: String?, featherColor: String?, source: String?, avatarUrl: String?, notes: String?) async throws -> Bird {
        let url = baseURL.appendingPathComponent("birds/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var body: [String: Any?] = [
            "nickname": nickname,
            "species": species,
            "gender": gender,
            "featherColor": featherColor,
            "source": source,
            "avatarUrl": avatarUrl,
            "notes": notes,
            "birthdayType": birthdayType
        ]
        
        if let hatchDate = hatchDate {
            body["hatchDate"] = dateFormatter.string(from: hatchDate)
        }
        if let adoptionDate = adoptionDate {
            body["adoptionDate"] = dateFormatter.string(from: adoptionDate)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Bird.self, from: data)
    }

    func deleteBird(id: Int64) async throws {
        let url = baseURL.appendingPathComponent("birds/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    func restoreBird(id: Int64) async throws -> Bird {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(id)/restore"))
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Bird.self, from: data)
    }
    
    func getDeletedBirds(userId: Int64) async throws -> [Bird] {
        let url = baseURL.appendingPathComponent("birds/deleted").appending(queryItems: [URLQueryItem(name: "userId", value: String(userId))])
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Bird].self, from: data)
    }
    
    func getActiveBirds(userId: Int64) async throws -> [Bird] {
        let url = baseURL.appendingPathComponent("birds/active").appending(queryItems: [URLQueryItem(name: "userId", value: String(userId))])
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Bird].self, from: data)
    }

    // MARK: - 日志

    func getLogs() async throws -> [BirdLog] {
        let url = baseURL.appendingPathComponent("logs")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdLog].self, from: data)
    }

    func getLogs(byBird birdId: Int) async throws -> [BirdLog] {
        let url = baseURL.appendingPathComponent("logs/bird/\(birdId)")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([BirdLog].self, from: data)
    }

    /// 创建日志（可带体重），用于"写新日志"页面
    func createLog(birdId: Int64, date: Date, weight: Double?, notes: String) async throws -> BirdLog {
        var request = URLRequest(url: baseURL.appendingPathComponent("logs"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 后端 BirdLogDTO.logDate 是 LocalDate，这里用 yyyy-MM-dd 即可
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        var body: [String: Any] = [
            "birdId": birdId,
            "logDate": formatter.string(from: date),
            "notes": notes
        ]

        if let weight = weight {
            body["weight"] = weight
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdLog.self, from: data)
    }

    // MARK: - 提醒

    func getReminders() async throws -> [Reminder] {
        let url = baseURL.appendingPathComponent("reminders")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([Reminder].self, from: data)
    }
    
    func createReminder(title: String, timeDescription: String, reminderType: String?, enabled: Bool) async throws -> Reminder {
        var request = URLRequest(url: baseURL.appendingPathComponent("reminders"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "title": title,
            "timeDescription": timeDescription,
            "enabled": enabled
        ]
        if let reminderType = reminderType {
            body["reminderType"] = reminderType
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Reminder.self, from: data)
    }
    
    func updateReminder(id: Int64, title: String, timeDescription: String, reminderType: String?, enabled: Bool) async throws -> Reminder {
        var request = URLRequest(url: baseURL.appendingPathComponent("reminders/\(id)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "title": title,
            "timeDescription": timeDescription,
            "enabled": enabled
        ]
        if let reminderType = reminderType {
            body["reminderType"] = reminderType
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Reminder.self, from: data)
    }
    
    func toggleReminder(id: Int64) async throws -> Reminder {
        var request = URLRequest(url: baseURL.appendingPathComponent("reminders/\(id)/toggle"))
        request.httpMethod = "PATCH"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(Reminder.self, from: data)
    }
    
    func deleteReminder(id: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("reminders/\(id)"))
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }

    // MARK: - 鸟类共享功能
    
    /// 发送共享邀请
    func shareBird(birdId: Int64, targetPhone: String, role: ShareRole) async throws -> ShareResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/share"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证 Token
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "targetPhone": targetPhone,
            "role": role.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ShareResponse.self, from: data)
    }
    
    /// 获取待处理的共享邀请
    func getPendingInvitations() async throws -> [ShareInvitation] {
        let url = baseURL.appendingPathComponent("share/invitations/pending")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([ShareInvitation].self, from: data)
    }
    
    /// 接受共享邀请
    func acceptInvitation(invitationId: Int64) async throws -> ShareResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("share/invitations/\(invitationId)/accept"))
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ShareResponse.self, from: data)
    }
    
    /// 拒绝共享邀请
    func rejectInvitation(invitationId: Int64) async throws -> ShareResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("share/invitations/\(invitationId)/reject"))
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ShareResponse.self, from: data)
    }
    
    /// 获取鸟的共享用户列表
    func getBirdSharedUsers(birdId: Int64) async throws -> [BirdCoOwner] {
        // 开发模式：暂时返回空列表
        // TODO: 实现后端API
        return []
        
        // 正式实现：
        // let url = baseURL.appendingPathComponent("birds/\(birdId)/shared-users")
        // let (data, response) = try await URLSession.shared.data(from: url)
        // try Self.validate(response: response)
        // return try jsonDecoder.decode([BirdCoOwner].self, from: data)
    }
    
    /// 移除共享用户
    func removeSharedUser(birdId: Int64, userId: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/shared-users/\(userId)"))
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    /// 更新共享用户角色
    func updateSharedUserRole(birdId: Int64, userId: Int64, newRole: ShareRole) async throws -> BirdCoOwner {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/shared-users/\(userId)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["role": newRole.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(BirdCoOwner.self, from: data)
    }
    
    /// 退出共享（被共享者主动退出）
    func leaveSharedBird(birdId: Int64) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("birds/\(birdId)/leave"))
        request.httpMethod = "POST"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, expectedStatusCode: 204)
    }
    
    // MARK: - 论坛帖子
    
    /// 获取帖子列表
    func getPosts(page: Int = 0, size: Int = 20) async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/posts")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 创建帖子
    func createPost(content: String, postType: String = "NORMAL", images: [String] = [], latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil) async throws -> ForumPostDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "content": content,
            "postType": postType,
            "images": images
        ]
        if let lat = latitude { body["latitude"] = lat }
        if let lng = longitude { body["longitude"] = lng }
        if let loc = locationName { body["locationName"] = loc }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostDTO.self, from: data)
    }
    
    /// 点赞/取消点赞
    func togglePostLike(postId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)/like"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Bool].self, from: data)
    }
    
    /// 收藏/取消收藏
    func togglePostFavorite(postId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)/favorite"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Bool].self, from: data)
    }
    
    /// 获取用户收藏的帖子
    func getFavorites(page: Int = 0, size: Int = 20) async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/favorites")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 获取用户的帖子
    func getUserPosts(userId: Int64, page: Int = 0, size: Int = 20) async throws -> ForumPostPage {
        var url = baseURL.appendingPathComponent("forum/posts/user/\(userId)")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(ForumPostPage.self, from: data)
    }
    
    /// 获取帖子评论
    func getComments(postId: Int64, page: Int = 0, size: Int = 20) async throws -> CommentPage {
        var url = baseURL.appendingPathComponent("forum/posts/\(postId)/comments")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        var request = URLRequest(url: url)
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(CommentPage.self, from: data)
    }
    
    /// 添加评论
    func addComment(postId: Int64, content: String, parentId: Int64? = nil) async throws -> CommentDTO {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/posts/\(postId)/comments"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = ["content": content]
        if let parentId = parentId { body["parentId"] = parentId }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode(CommentDTO.self, from: data)
    }
    
    /// 评论点赞/取消点赞
    func toggleCommentLike(commentId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("forum/comments/\(commentId)/like"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Bool].self, from: data)
    }
    
    // MARK: - 用户关注
    
    /// 关注/取消关注用户
    func toggleFollow(userId: Int64) async throws -> [String: Bool] {
        var request = URLRequest(url: baseURL.appendingPathComponent("users/\(userId)/follow"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Bool].self, from: data)
    }
    
    /// 获取用户的关注列表
    func getFollowing(userId: Int64, page: Int = 0, size: Int = 20) async throws -> UserPage {
        var url = baseURL.appendingPathComponent("users/\(userId)/following")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(UserPage.self, from: data)
    }
    
    /// 获取用户的粉丝列表
    func getFollowers(userId: Int64, page: Int = 0, size: Int = 20) async throws -> UserPage {
        var url = baseURL.appendingPathComponent("users/\(userId)/followers")
        url.append(queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
        
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode(UserPage.self, from: data)
    }
    
    /// 获取关注统计
    func getFollowStats(userId: Int64) async throws -> [String: Int] {
        let url = baseURL.appendingPathComponent("users/\(userId)/follow-stats")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response)
        return try jsonDecoder.decode([String: Int].self, from: data)
    }
    
    // MARK: - 账号管理
    
    /// 注销账号
    func deleteAccount() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/delete-account"))
        request.httpMethod = "DELETE"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 发送验证码
    func sendVerificationCode(phone: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/send-code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone": phone]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 验证验证码（用于验证当前手机号）
    func verifyCode(phone: String, code: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/verify-code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone": phone, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode([String: Bool].self, from: data)
        if result["valid"] != true {
            throw ApiError.serverError("验证码错误")
        }
    }
    
    /// 修改手机号
    func changePhone(newPhone: String, code: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/change-phone"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["newPhone": newPhone, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode([String: Bool].self, from: data)
        if result["success"] != true {
            throw ApiError.serverError("修改手机号失败")
        }
    }
    
    /// 设置密码
    func setPassword(password: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/set-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 密码登录
    func loginWithPassword(phone: String, password: String) async throws -> (token: String, user: User) {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/login-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone": phone, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        guard result.success, let token = result.token, let user = result.user else {
            throw ApiError.serverError(result.message ?? "登录失败")
        }
        
        return (token, user)
    }
    
    /// 解绑情侣伴侣
    func unbindCouplePartner() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/couple/unbind"))
        request.httpMethod = "POST"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
    }
    
    /// 购买/续费VIP
    func purchaseVip(vipType: String, duration: Int?) async throws -> VipPurchaseResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/vip/purchase"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = ["vipType": vipType]
        if let duration = duration {
            body["duration"] = duration
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode(VipPurchaseResponse.self, from: data)
        return result
    }
    
    // VIP购买响应
    struct VipPurchaseResponse: Codable {
        let success: Bool
        let message: String
        let vipType: String?
        let expireDate: String?
        let remainingDays: Int?
    }
    
    // MARK: - 文件上传
    
    /// 上传鸟儿头像
    func uploadBirdAvatar(image: UIImage) async throws -> String {
        // 1. 先调整图片尺寸（最大1024x1024）
        let resizedImage = resizeImage(image: image, maxSize: 1024)
        
        // 2. 压缩图片
        guard var imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            throw ApiError.invalidResponse
        }
        
        // 3. 如果文件仍然大于3MB，继续压缩
        var quality: CGFloat = 0.6
        while imageData.count > 3_000_000 && quality > 0.1 {
            quality -= 0.1
            if let compressed = resizedImage.jpegData(compressionQuality: quality) {
                imageData = compressed
            }
        }
        
        let sizeInMB = Double(imageData.count) / 1_000_000.0
        print("📤 开始上传头像")
        print("📦 原始尺寸: \(image.size.width)x\(image.size.height)")
        print("📦 调整后尺寸: \(resizedImage.size.width)x\(resizedImage.size.height)")
        print("📦 压缩质量: \(String(format: "%.1f", quality * 100))%")
        print("📦 文件大小: \(String(format: "%.2f", sizeInMB)) MB (\(imageData.count) bytes)")
        
        // 检查文件大小
        if imageData.count > 8_000_000 {
            print("⚠️ 警告：文件仍然较大，可能上传失败")
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("upload/bird-avatar"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendString("\r\n--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 响应状态码: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ 错误信息: \(errorString)")
                }
            }
        }
        
        try Self.validate(response: response)
        
        let result = try JSONDecoder().decode([String: String].self, from: data)
        guard let url = result["url"] else {
            throw ApiError.invalidResponse
        }
        
        print("✅ 上传成功: \(url)")
        
        // 返回完整URL
        return "http://127.0.0.1:8080\(url)"
    }
    
    /// 上传用户头像
    func uploadUserAvatar(image: UIImage) async throws -> String {
        return try await uploadBirdAvatar(image: image)
    }
    
    /// 调整图片大小
    private func resizeImage(image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        
        // 如果图片已经小于最大尺寸，直接返回
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        // 计算缩放比例
        let widthRatio = maxSize / size.width
        let heightRatio = maxSize / size.height
        let ratio = min(widthRatio, heightRatio)
        
        // 计算新尺寸
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // 创建新图片
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }

    // MARK: - Helpers

    private static func validate(response: URLResponse, expectedStatusCode: Int = 200) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }
        // 允许 200 和 expectedStatusCode
        let validCodes = [200, 201, expectedStatusCode]
        guard validCodes.contains(httpResponse.statusCode) else {
            throw ApiError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - 论坛帖子 DTO

struct ForumPostDTO: Codable {
    let id: Int64
    let authorId: Int64?
    let authorName: String?
    let authorAvatar: String?
    let content: String
    let postType: String?
    let mediaType: String?
    let images: [String]?
    let videoUrl: String?
    let videoCover: String?
    let videoDuration: Int?
    let likeCount: Int?
    let commentCount: Int?
    let viewCount: Int?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let distance: Double?
    let birdName: String?
    let birdSpecies: String?
    let lostLocation: String?
    let contactPhone: String?
    let reward: String?
    let isFound: Bool?
    let isLiked: Bool?
    let isFavorited: Bool?
    let isFollowing: Bool?
    let createdAt: String?
    let timeAgo: String?
}

struct ForumPostPage: Codable {
    let content: [ForumPostDTO]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let first: Bool
    let last: Bool
}

// MARK: - 评论 DTO

struct CommentDTO: Codable {
    let id: Int64
    let postId: Int64?
    let authorId: Int64?
    let authorName: String?
    let authorAvatar: String?
    let content: String
    let likeCount: Int?
    let parentId: Int64?
    let replies: [CommentDTO]?
    let isLiked: Bool?
    let createdAt: String?
    let timeAgo: String?
}

struct CommentPage: Codable {
    let content: [CommentDTO]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let first: Bool
    let last: Bool
}

// MARK: - 用户 DTO

struct UserDTO: Codable {
    let id: Int64
    let phone: String?
    let nickname: String?
    let avatarUrl: String?
    let bio: String?
    let isVip: Bool?
    let vipType: String?
    let vipExpireDate: String?
    let createdAt: String?
    let birdCount: Int?
    let postCount: Int?
    let followerCount: Int?
    let followingCount: Int?
}

struct UserPage: Codable {
    let content: [UserDTO]
    let totalElements: Int
    let totalPages: Int
    let number: Int
    let size: Int
    let first: Bool
    let last: Bool
}

// MARK: - Data Extension
extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
