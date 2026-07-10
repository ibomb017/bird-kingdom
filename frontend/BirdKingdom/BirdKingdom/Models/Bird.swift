import Foundation

struct Bird: Identifiable, Codable, Hashable {
    let id: Int64
    let nickname: String
    let species: String
    let gender: String?
    let hatchDate: Date?             // 破壳日期
    let adoptionDate: Date?          // 领养日期
    let birthdayType: String?        // 生日类型：HATCH 或 ADOPTION
    let deathDate: Date?             // 死亡日期
    let featherColor: String?
    let source: String?
    let avatarUrl: String?
    let notes: String?
    let medicalHistory: String?
    let fatherInfo: String?
    let motherInfo: String?
    let legRingId: String?
    let ageMonths: Int?
    let isDeleted: Bool?             // 是否已删除
    let deletedAt: Date?             // 删除时间
    
    // 丢失状态
    var isLost: Bool?                // 是否丢失
    var lostDate: Date?              // 丢失日期
    var lostLocation: String?        // 丢失地点
    var lostPostId: Int64?           // 关联的寻鸟帖子ID
    
    // 主人信息
    let ownerId: Int64?              // 主人用户ID
    let ownerName: String?           // 主人用户名
    let isShared: Bool?              // 是否被共享
    let sharedWith: [BirdCoOwner]?   // 共享给的用户列表
    let shareRole: ShareRole?        // 当前用户对此鸟的角色
    
    // 情侣共享相关
    let isOwner: Bool?               // 是否是当前用户的鸟（false表示是伴侣的鸟）
    let isCoupleShared: Bool?        // 是否是情侣共享的鸟

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case species
        case gender
        case hatchDate
        case adoptionDate
        case birthdayType
        case deathDate
        case featherColor
        case source
        case avatarUrl
        case notes
        case medicalHistory
        case fatherInfo
        case motherInfo
        case legRingId
        case ageMonths
        case isDeleted
        case deletedAt
        case isLost
        case lostDate
        case lostLocation
        case lostPostId
        case ownerId
        case ownerName
        case isShared
        case sharedWith
        case shareRole
        case isOwner
        case isCoupleShared
    }
    
    // 手动初始化方法（用于预览和测试）
    init(id: Int64, nickname: String, species: String, gender: String?, hatchDate: Date? = nil, adoptionDate: Date? = nil, birthdayType: String? = "HATCH", deathDate: Date? = nil, featherColor: String?, source: String?, avatarUrl: String?, notes: String?, medicalHistory: String? = nil, fatherInfo: String? = nil, motherInfo: String? = nil, legRingId: String? = nil, ageMonths: Int?, isDeleted: Bool? = false, deletedAt: Date? = nil, isLost: Bool? = false, lostDate: Date? = nil, lostLocation: String? = nil, lostPostId: Int64? = nil, ownerId: Int64? = nil, ownerName: String? = nil, isShared: Bool? = false, sharedWith: [BirdCoOwner]? = nil, shareRole: ShareRole? = .owner, isOwner: Bool? = true, isCoupleShared: Bool? = false) {
        self.id = id
        self.nickname = nickname
        self.species = species
        self.gender = gender
        self.hatchDate = hatchDate
        self.adoptionDate = adoptionDate
        self.birthdayType = birthdayType
        self.deathDate = deathDate
        self.featherColor = featherColor
        self.source = source
        self.avatarUrl = avatarUrl
        self.notes = notes
        self.medicalHistory = medicalHistory
        self.fatherInfo = fatherInfo
        self.motherInfo = motherInfo
        self.legRingId = legRingId
        self.ageMonths = ageMonths
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.isLost = isLost
        self.lostDate = lostDate
        self.lostLocation = lostLocation
        self.lostPostId = lostPostId
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.isShared = isShared
        self.sharedWith = sharedWith
        self.shareRole = shareRole
        self.isOwner = isOwner
        self.isCoupleShared = isCoupleShared
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int64.self, forKey: .id)
        nickname = try container.decode(String.self, forKey: .nickname)
        species = try container.decode(String.self, forKey: .species)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        birthdayType = try container.decodeIfPresent(String.self, forKey: .birthdayType)
        featherColor = try container.decodeIfPresent(String.self, forKey: .featherColor)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        medicalHistory = try container.decodeIfPresent(String.self, forKey: .medicalHistory)
        fatherInfo = try container.decodeIfPresent(String.self, forKey: .fatherInfo)
        motherInfo = try container.decodeIfPresent(String.self, forKey: .motherInfo)
        legRingId = try container.decodeIfPresent(String.self, forKey: .legRingId)
        ageMonths = try container.decodeIfPresent(Int.self, forKey: .ageMonths)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted)
        isLost = try container.decodeIfPresent(Bool.self, forKey: .isLost)
        lostLocation = try container.decodeIfPresent(String.self, forKey: .lostLocation)
        lostPostId = try container.decodeIfPresent(Int64.self, forKey: .lostPostId)
        ownerId = try container.decodeIfPresent(Int64.self, forKey: .ownerId)
        ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName)
        isShared = try container.decodeIfPresent(Bool.self, forKey: .isShared)
        sharedWith = try container.decodeIfPresent([BirdCoOwner].self, forKey: .sharedWith)
        shareRole = try container.decodeIfPresent(ShareRole.self, forKey: .shareRole)
        isOwner = try container.decodeIfPresent(Bool.self, forKey: .isOwner)
        isCoupleShared = try container.decodeIfPresent(Bool.self, forKey: .isCoupleShared)
        
        // 使用辅助函数解码日期（支持 ISO 8601 格式）
        hatchDate = Self.decodeDate(from: container, forKey: .hatchDate)
        adoptionDate = Self.decodeDate(from: container, forKey: .adoptionDate)
        deathDate = Self.decodeDate(from: container, forKey: .deathDate)
        deletedAt = Self.decodeDate(from: container, forKey: .deletedAt)
        lostDate = Self.decodeDate(from: container, forKey: .lostDate)
    }
    
    /// 辅助函数：解码日期，支持多种格式（ISO 8601、yyyy-MM-dd 等）
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        // 首先尝试直接解码 Date（ISO 8601 格式）
        if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
            return date
        }
        
        // 回退：尝试解码字符串格式
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        
        // ISO 8601 格式解析器
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // ISO 8601 无毫秒版本
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // 回退：简单日期格式 yyyy-MM-dd（兼容旧后端）
        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd"
        simpleDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = simpleDateFormatter.date(from: dateString) {
            return date
        }
        
        // 回退：带时间的格式 yyyy-MM-dd'T'HH:mm:ss
        simpleDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return simpleDateFormatter.date(from: dateString)
    }

    var ageText: String {
        guard let ageMonths = ageMonths else { return "" }
        let isEn = LanguageManager.shared.isEnglish
        if ageMonths >= 12 {
            let years = ageMonths / 12
            let months = ageMonths % 12
            if months == 0 { return isEn ? "\(years)y" : "\(years)岁" }
            return isEn ? "\(years)y \(months)m" : "\(years)岁\(months)个月"
        }
        return isEn ? "\(ageMonths)m" : "\(ageMonths)个月"
    }
    
    // 是否已故
    var isDead: Bool {
        deathDate != nil
    }
    
    // 获取生日日期（根据 birthdayType 选择）
    var birthdayDate: Date? {
        if birthdayType == "ADOPTION", let adoptionDate = adoptionDate {
            return adoptionDate
        } else if let hatchDate = hatchDate {
            return hatchDate
        }
        return nil
    }
    
    // 距离生日还有多少天
    var daysUntilBirthday: Int? {
        guard let birthDate = birthdayDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var nextBirthday = calendar.date(bySetting: .year, value: calendar.component(.year, from: today), of: birthDate)!
        if nextBirthday < today {
            nextBirthday = calendar.date(byAdding: .year, value: 1, to: nextBirthday)!
        }
        
        return calendar.dateComponents([.day], from: today, to: nextBirthday).day
    }
    
    // 距离忌日还有多少天
    var daysUntilMemorialDay: Int? {
        guard let deathDate = deathDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var nextMemorialDay = calendar.date(bySetting: .year, value: calendar.component(.year, from: today), of: deathDate)!
        if nextMemorialDay < today {
            nextMemorialDay = calendar.date(byAdding: .year, value: 1, to: nextMemorialDay)!
        }
        
        return calendar.dateComponents([.day], from: today, to: nextMemorialDay).day
    }
    
    // 是否是今天生日
    var isBirthdayToday: Bool {
        daysUntilBirthday == 0
    }
    
    // 是否是今天忌日
    var isMemorialDayToday: Bool {
        daysUntilMemorialDay == 0
    }
    
    // 是否是主人（情侣共享的鸟如果没有被邀请共同抚养，则不是主人）
    var isRealOwner: Bool {
        // 如果是情侣共享的鸟，且没有被邀请共同抚养，则不是主人
        if isCoupleShared == true && isShared != true {
            return false
        }
        return shareRole == .owner || shareRole == nil
    }
    
    // 是否可以编辑
    // 共享鸟儿和情侣共享鸟均有编辑权限
    var canEdit: Bool {
        return true
    }
    
    // 是否可以管理共享（添加/移除共享用户）
    // - 原始主人（isOwner == true）可以管理
    // - "主人"角色的共享者（shareRole == .owner）也可以管理
    // - "查看者"角色不能管理共享
    var canManageSharing: Bool {
        // 原始主人
        if isOwner == true {
            return true
        }
        // "主人"角色的共享者
        if shareRole == .owner {
            return true
        }
        return false
    }
}

// MARK: - 共享角色
enum ShareRole: String, Codable, Hashable {
    case owner = "OWNER"           // 主人（完全权限）
    case viewer = "VIEWER"         // 查看者（只读）
}

// MARK: - 共同主人信息
struct BirdCoOwner: Identifiable, Codable, Hashable {
    let id: Int64           // 共享记录ID
    let userId: Int64       // 用户ID
    let nickname: String    // 用户昵称
    let avatar: String?     // 用户头像
    let phone: String?      // 用户手机号
    let role: ShareRole     // 共享角色
    let sharedAt: Date?     // 共享时间
    
    // 兼容旧代码的别名
    var username: String { nickname }
    
    enum CodingKeys: String, CodingKey {
        case id, userId, nickname, avatar, phone, role, sharedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        userId = try container.decode(Int64.self, forKey: .userId)
        nickname = try container.decode(String.self, forKey: .nickname)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        role = try container.decode(ShareRole.self, forKey: .role)
        
        if let dateString = try container.decodeIfPresent(String.self, forKey: .sharedAt) {
            let formatter = ISO8601DateFormatter()
            sharedAt = formatter.date(from: dateString)
        } else {
            sharedAt = nil
        }
    }
}

// MARK: - 共享邀请
struct ShareInvitation: Identifiable, Codable {
    let id: Int64
    let birdId: Int64
    let birdName: String
    let birdSpecies: String?
    let ownerName: String       // 后端返回的是 ownerName
    let role: ShareRole
    let createdAt: String?      // 后端返回的是字符串格式
    
    // 兼容旧代码
    var fromUsername: String { ownerName }
    
    enum CodingKeys: String, CodingKey {
        case id, birdId, birdName, birdSpecies, ownerName, role, createdAt
    }
}

// MARK: - 共享请求
struct ShareRequest: Codable {
    let birdId: Int64
    let targetPhone: String  // 目标用户手机号
    let role: ShareRole
}

// MARK: - 共享响应
struct ShareResponse: Codable {
    let success: Bool
    let message: String
    let invitation: ShareInvitation?
}
