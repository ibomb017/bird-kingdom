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
    var hasPassword: Bool          // 是否已设置密码
    
    // VIP 相关
    var isVip: Bool                // 是否是VIP
    var vipExpireDate: Date?       // VIP过期时间
    var vipType: VipType?          // VIP类型
    var isCoupleVip: Bool?         // 是否是情侣会员
    var couplePartnerId: Int64?    // 情侣伴侣ID
    var couplePartnerName: String? // 情侣伴侣昵称
    var couplePartnerAvatar: String? // 情侣伴侣头像
    var pendingCouplePhone: String? // 预留的伴侣手机号（对方未注册时）
    var pendingCouplePartnerName: String? // 预留绑定对象的昵称（如果已注册）
    var isPendingConfirmation: Bool? // 是否等待对方确认
    
    enum CodingKeys: String, CodingKey {
        case id, phone, nickname, avatarUrl, bio
        case createdAt, birdCount, logCount, activeDays, hasPassword
        case isVip, vipExpireDate, vipType
        case isCoupleVip, couplePartnerId, couplePartnerName, couplePartnerAvatar
        case pendingCouplePhone, pendingCouplePartnerName, isPendingConfirmation
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
        hasPassword = try container.decodeIfPresent(Bool.self, forKey: .hasPassword) ?? false
        isVip = try container.decodeIfPresent(Bool.self, forKey: .isVip) ?? false
        vipType = try container.decodeIfPresent(VipType.self, forKey: .vipType)
        isCoupleVip = try container.decodeIfPresent(Bool.self, forKey: .isCoupleVip)
        couplePartnerId = try container.decodeIfPresent(Int64.self, forKey: .couplePartnerId)
        couplePartnerName = try container.decodeIfPresent(String.self, forKey: .couplePartnerName)
        couplePartnerAvatar = try container.decodeIfPresent(String.self, forKey: .couplePartnerAvatar)
        pendingCouplePhone = try container.decodeIfPresent(String.self, forKey: .pendingCouplePhone)
        pendingCouplePartnerName = try container.decodeIfPresent(String.self, forKey: .pendingCouplePartnerName)
        isPendingConfirmation = try container.decodeIfPresent(Bool.self, forKey: .isPendingConfirmation)
        
        // 尝试解码日期（支持 ISO8601、自定义格式、时间戳三种格式）
        createdAt = Self.parseDate(from: container, forKey: .createdAt)
        vipExpireDate = Self.parseDate(from: container, forKey: .vipExpireDate)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(phone, forKey: .phone)
        try container.encode(nickname, forKey: .nickname)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(birdCount, forKey: .birdCount)
        try container.encodeIfPresent(logCount, forKey: .logCount)
        try container.encodeIfPresent(activeDays, forKey: .activeDays)
        try container.encode(hasPassword, forKey: .hasPassword)
        try container.encode(isVip, forKey: .isVip)
        try container.encodeIfPresent(vipType, forKey: .vipType)
        try container.encodeIfPresent(isCoupleVip, forKey: .isCoupleVip)
        try container.encodeIfPresent(couplePartnerId, forKey: .couplePartnerId)
        try container.encodeIfPresent(couplePartnerName, forKey: .couplePartnerName)
        try container.encodeIfPresent(couplePartnerAvatar, forKey: .couplePartnerAvatar)
        try container.encodeIfPresent(pendingCouplePhone, forKey: .pendingCouplePhone)
        try container.encodeIfPresent(pendingCouplePartnerName, forKey: .pendingCouplePartnerName)
        try container.encodeIfPresent(isPendingConfirmation, forKey: .isPendingConfirmation)
        
        // 日期编码为时间戳（Double）
        if let date = createdAt {
            try container.encode(date.timeIntervalSince1970, forKey: .createdAt)
        }
        if let date = vipExpireDate {
            try container.encode(date.timeIntervalSince1970, forKey: .vipExpireDate)
        }
    }
    
    // 手动初始化（用于预览）
    init(id: Int64, phone: String, nickname: String, avatarUrl: String? = nil, bio: String? = nil, createdAt: Date? = nil, birdCount: Int? = nil, logCount: Int? = nil, activeDays: Int? = nil, hasPassword: Bool = false, isVip: Bool = false, vipExpireDate: Date? = nil, vipType: VipType? = nil, isCoupleVip: Bool? = nil, couplePartnerId: Int64? = nil, couplePartnerName: String? = nil, pendingCouplePhone: String? = nil) {
        self.id = id
        self.phone = phone
        self.nickname = nickname
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.createdAt = createdAt
        self.birdCount = birdCount
        self.logCount = logCount
        self.activeDays = activeDays
        self.hasPassword = hasPassword
        self.isVip = isVip
        self.vipExpireDate = vipExpireDate
        self.vipType = vipType
        self.isCoupleVip = isCoupleVip
        self.couplePartnerId = couplePartnerId
        self.couplePartnerName = couplePartnerName
        self.pendingCouplePhone = pendingCouplePhone
    }
    
    // MARK: - 日期解析辅助方法
    /// 解析日期，支持 ISO8601（带Z时区）、自定义格式、时间戳三种格式
    private static func parseDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        // 1. 尝试解析为字符串格式
        if let dateString = try? container.decodeIfPresent(String.self, forKey: key) {
            // 1.1 尝试 ISO8601 格式（服务端使用: "2025-01-23T16:49:02Z"）
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            // 1.2 尝试不带毫秒的 ISO8601
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            // 1.3 尝试自定义格式（无时区）
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            customFormatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = customFormatter.date(from: dateString) {
                return date
            }
        }
        // 2. 尝试解析为时间戳（Double）
        if let timestamp = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    // 隐藏手机号中间四位
    var maskedPhone: String {
        guard phone.count >= 11 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }
    
    // VIP是否有效（未过期）
    // ⚠️ #11 安全警告：此计算属性依赖本地 Date()，可能被系统时间篡改
    // 关键操作（如VIP功能验证）应调用 AuthService.shared.checkVipStatus() 获取服务端确认
    var isVipValid: Bool {
        // P0 修改：暂时全免费，所有人都是VIP
        return true
        // guard isVip else { return false }
        // guard let expireDate = vipExpireDate else { return isVip }
        // return expireDate > Date()
    }
    
    // VIP剩余天数
    var vipRemainingDays: Int? {
        guard isVipValid, let expireDate = vipExpireDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expireDate).day
        return max(0, days ?? 0)
    }
    
    // MARK: - #12 FIX: 情侣绑定状态管理
    
    /// 情侣绑定状态枚举
    enum CoupleBindingStatus {
        case notBound                    // 未绑定
        case pendingPartnerRegistration  // 等待对方注册（已预留手机号）
        case pendingConfirmation         // 等待对方确认
        case bound                       // 已绑定
        
        var displayText: String {
            let isEn = LanguageManager.shared.isEnglish
            switch self {
            case .notBound: return isEn ? "Not Bound" : "未绑定"
            case .pendingPartnerRegistration: return isEn ? "Pending Registration" : "等待对方注册"
            case .pendingConfirmation: return isEn ? "Pending Confirmation" : "等待对方确认"
            case .bound: return isEn ? "Bound" : "已绑定"
            }
        }
        
        var isPending: Bool {
            switch self {
            case .pendingPartnerRegistration, .pendingConfirmation:
                return true
            default:
                return false
            }
        }
    }
    
    /// 获取当前情侣绑定状态
    var coupleBindingStatus: CoupleBindingStatus {
        // 已绑定：有伴侣ID
        if couplePartnerId != nil {
            return .bound
        }
        
        // 等待对方确认：有预留手机号且对方已注册（有昵称）
        if let _ = pendingCouplePhone, pendingCouplePartnerName != nil {
            return .pendingConfirmation
        }
        
        // 等待对方注册：有预留手机号但对方未注册
        if pendingCouplePhone != nil {
            return .pendingPartnerRegistration
        }
        
        // 未绑定
        return .notBound
    }
    
    /// 是否有未完成的绑定流程
    var hasPendingCoupleBinding: Bool {
        return coupleBindingStatus.isPending
    }
    
    /// 获取伴侣显示名称（已绑定或待确认）
    var couplePartnerDisplayName: String? {
        if let name = couplePartnerName {
            return name
        }
        if let name = pendingCouplePartnerName {
            return name + " (待确认)"
        }
        if let phone = pendingCouplePhone {
            // 隐藏中间四位
            let masked = phone.count >= 11
                ? "\(phone.prefix(3))****\(phone.suffix(4))"
                : phone
            return masked + " (待注册)"
        }
        return nil
    }
}

// MARK: - VIP类型
enum VipType: String, Codable {
    case monthly = "MONTHLY"               // 月度会员
    case yearly = "YEARLY"                 // 年度会员
    case lifetime = "LIFETIME"             // 永久会员
    case coupleLifetime = "COUPLE_LIFETIME" // 情侣永久会员
    
    var displayName: String {
        switch self {
        case .monthly: return "月度会员"
        case .yearly: return "年度会员"
        case .lifetime: return "永久会员"
        case .coupleLifetime: return "情侣永久会员"
        }
    }
    
    /// VIP显示优先级（数值越大优先级越高）
    var displayPriority: Int {
        switch self {
        case .coupleLifetime: return 4  // 最高优先级
        case .lifetime: return 3
        case .yearly: return 2
        case .monthly: return 1
        }
    }
}

// MARK: - User VIP展示扩展
extension User {
    /// FIX: VIP显示名称（按优先级：情侣永久VIP > 永久VIP > 年度 > 月度）
    var vipDisplayName: String? {
        guard isVipValid else { return nil }
        
        // 情侣永久VIP优先级最高
        if isCoupleVip == true && vipType == .coupleLifetime {
            return "情侣永久会员"
        }
        
        // 其他VIP类型
        return vipType?.displayName
    }
    
    /// VIP标签是否显示为永久（不显示过期时间）
    var isLifetimeVip: Bool {
        return vipType == .lifetime || vipType == .coupleLifetime
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
    let message: String?
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

// MARK: - 情侣邀请响应
struct CoupleInvitationResponse: Codable {
    let pending: Bool
    let invitation: CoupleInvitationItem?
    
    // 便捷访问属性（兼容现有代码）
    var hasPendingInvitation: Bool { pending }
    var inviterName: String? { invitation?.fromUserNickname }
    var inviterAvatarUrl: String? { invitation?.fromUserAvatarUrl }
    var inviterPhone: String? { invitation?.fromUserPhone }
    var inviterId: Int64? { invitation?.fromUserId }
}

struct CoupleInvitationItem: Codable {
    let id: Int64
    let fromUserId: Int64
    let fromUserNickname: String
    let fromUserPhone: String?
    let fromUserAvatarUrl: String?
    let createdAt: Date?  // 可选，因为后端可能不返回完全匹配的格式
}

// MARK: - 情侣邀请操作响应
struct CoupleActionResponse: Codable {
    let success: Bool
    let message: String
    let partnerName: String?
    let partnerId: Int64?
    
    // 解码时提供默认值
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decode(Bool.self, forKey: .success)
        self.message = try container.decode(String.self, forKey: .message)
        self.partnerName = try container.decodeIfPresent(String.self, forKey: .partnerName)
        self.partnerId = try container.decodeIfPresent(Int64.self, forKey: .partnerId)
    }
    
    enum CodingKeys: String, CodingKey {
        case success, message, partnerName, partnerId
    }
}

