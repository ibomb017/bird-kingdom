import Foundation

// MARK: - 用户模型
struct User: Codable, Identifiable {
    let id: Int64
    var phone: String              // 手机号（用于邀请）
    var nickname: String           // 昵称
    var avatarUrl: String?         // 头像
    var bio: String?               // 个人简介
    let createdAt: Date?           // 注册时间
    var birdCount: Int?            // 拥有的鸟数量
    var logCount: Int?             // 日志数量
    var activeDays: Int?           // 活跃天数
    
    // VIP 相关
    var isVip: Bool                // 是否是VIP
    var vipExpireDate: Date?       // VIP过期时间
    var vipType: VipType?          // VIP类型
    var isCoupleVip: Bool?         // 是否是情侣会员
    var couplePartnerId: Int64?    // 情侣伴侣ID
    
    enum CodingKeys: String, CodingKey {
        case id, phone, nickname, avatarUrl, bio
        case createdAt, birdCount, logCount, activeDays
        case isVip, vipExpireDate, vipType
        case isCoupleVip, couplePartnerId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        phone = try container.decode(String.self, forKey: .phone)
        nickname = try container.decode(String.self, forKey: .nickname)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        birdCount = try container.decodeIfPresent(Int.self, forKey: .birdCount)
        logCount = try container.decodeIfPresent(Int.self, forKey: .logCount)
        activeDays = try container.decodeIfPresent(Int.self, forKey: .activeDays)
        isVip = try container.decodeIfPresent(Bool.self, forKey: .isVip) ?? false
        vipType = try container.decodeIfPresent(VipType.self, forKey: .vipType)
        isCoupleVip = try container.decodeIfPresent(Bool.self, forKey: .isCoupleVip)
        couplePartnerId = try container.decodeIfPresent(Int64.self, forKey: .couplePartnerId)
        
        if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            createdAt = formatter.date(from: dateString)
        } else {
            createdAt = nil
        }
        
        if let expireDateString = try container.decodeIfPresent(String.self, forKey: .vipExpireDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            vipExpireDate = formatter.date(from: expireDateString)
        } else {
            vipExpireDate = nil
        }
    }
    
    // 手动初始化（用于预览）
    init(id: Int64, phone: String, nickname: String, avatarUrl: String? = nil, bio: String? = nil, createdAt: Date? = nil, birdCount: Int? = nil, logCount: Int? = nil, activeDays: Int? = nil, isVip: Bool = false, vipExpireDate: Date? = nil, vipType: VipType? = nil, isCoupleVip: Bool? = nil, couplePartnerId: Int64? = nil) {
        self.id = id
        self.phone = phone
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.createdAt = createdAt
        self.birdCount = birdCount
        self.logCount = logCount
        self.activeDays = activeDays
        self.isVip = isVip
        self.vipExpireDate = vipExpireDate
        self.vipType = vipType
        self.isCoupleVip = isCoupleVip
        self.couplePartnerId = couplePartnerId
    }
    
    // 隐藏手机号中间四位
    var maskedPhone: String {
        guard phone.count >= 11 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }
    
    // VIP是否有效（未过期）
    var isVipValid: Bool {
        guard isVip else { return false }
        guard let expireDate = vipExpireDate else { return isVip }
        return expireDate > Date()
    }
    
    // VIP剩余天数
    var vipRemainingDays: Int? {
        guard isVipValid, let expireDate = vipExpireDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expireDate).day
        return max(0, days ?? 0)
    }
}

// MARK: - VIP类型
enum VipType: String, Codable {
    case monthly = "MONTHLY"       // 月度会员
    case yearly = "YEARLY"         // 年度会员
    case lifetime = "LIFETIME"     // 永久会员
    
    var displayName: String {
        switch self {
        case .monthly: return "月度会员"
        case .yearly: return "年度会员"
        case .lifetime: return "永久会员"
        }
    }
}

// MARK: - 登录请求
struct LoginRequest: Codable {
    let phone: String
    let code: String  // 验证码
}

// MARK: - 登录响应
struct LoginResponse: Codable {
    let success: Bool
    let message: String
    let token: String?
    let user: User?
}

// MARK: - 发送验证码请求
struct SendCodeRequest: Codable {
    let phone: String
}

// MARK: - 发送验证码响应
struct SendCodeResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - 更新用户信息请求
struct UpdateUserRequest: Codable {
    let nickname: String?
    let bio: String?
    let avatarUrl: String?
}

// MARK: - 搜索用户响应（用于邀请）
struct SearchUserResponse: Codable {
    let found: Bool
    let user: UserBrief?
}

// MARK: - 简要用户信息（用于搜索结果）
struct UserBrief: Codable, Identifiable {
    let id: Int64
    let phone: String
    let nickname: String
    let avatarUrl: String?
    
    // 隐藏手机号中间四位
    var maskedPhone: String {
        guard phone.count >= 11 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }
}
