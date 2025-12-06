import Foundation

struct Bird: Identifiable, Codable {
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
    let ageMonths: Int?
    let isDeleted: Bool?             // 是否已删除
    let deletedAt: Date?             // 删除时间
    
    // 主人信息
    let ownerId: Int64?              // 主人用户ID
    let ownerName: String?           // 主人用户名
    let isShared: Bool?              // 是否被共享
    let sharedWith: [BirdCoOwner]?   // 共享给的用户列表
    let shareRole: ShareRole?        // 当前用户对此鸟的角色

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
        case ageMonths
        case isDeleted
        case deletedAt
        case ownerId
        case ownerName
        case isShared
        case sharedWith
        case shareRole
    }
    
    // 手动初始化方法（用于预览和测试）
    init(id: Int64, nickname: String, species: String, gender: String?, hatchDate: Date? = nil, adoptionDate: Date? = nil, birthdayType: String? = "HATCH", deathDate: Date? = nil, featherColor: String?, source: String?, avatarUrl: String?, notes: String?, medicalHistory: String? = nil, ageMonths: Int?, isDeleted: Bool? = false, deletedAt: Date? = nil, ownerId: Int64? = nil, ownerName: String? = nil, isShared: Bool? = false, sharedWith: [BirdCoOwner]? = nil, shareRole: ShareRole? = .owner) {
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
        self.ageMonths = ageMonths
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.isShared = isShared
        self.sharedWith = sharedWith
        self.shareRole = shareRole
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
        ageMonths = try container.decodeIfPresent(Int.self, forKey: .ageMonths)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted)
        ownerId = try container.decodeIfPresent(Int64.self, forKey: .ownerId)
        ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName)
        isShared = try container.decodeIfPresent(Bool.self, forKey: .isShared)
        sharedWith = try container.decodeIfPresent([BirdCoOwner].self, forKey: .sharedWith)
        shareRole = try container.decodeIfPresent(ShareRole.self, forKey: .shareRole)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 自定义日期解码
        if let hatchDateString = try container.decodeIfPresent(String.self, forKey: .hatchDate) {
            hatchDate = dateFormatter.date(from: hatchDateString)
        } else {
            hatchDate = nil
        }
        
        if let adoptionDateString = try container.decodeIfPresent(String.self, forKey: .adoptionDate) {
            adoptionDate = dateFormatter.date(from: adoptionDateString)
        } else {
            adoptionDate = nil
        }
        
        if let deathDateString = try container.decodeIfPresent(String.self, forKey: .deathDate) {
            deathDate = dateFormatter.date(from: deathDateString)
        } else {
            deathDate = nil
        }
        
        if let deletedAtString = try container.decodeIfPresent(String.self, forKey: .deletedAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            deletedAt = formatter.date(from: deletedAtString)
        } else {
            deletedAt = nil
        }
    }

    var ageText: String {
        guard let ageMonths = ageMonths else { return "" }
        if ageMonths >= 12 {
            let years = ageMonths / 12
            let months = ageMonths % 12
            if months == 0 { return "\(years)岁" }
            return "\(years)岁\(months)个月"
        }
        return "\(ageMonths)个月"
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
    
    // 是否是主人
    var isOwner: Bool {
        shareRole == .owner || shareRole == nil
    }
    
    // 是否可以编辑（主人有完全权限）
    var canEdit: Bool {
        shareRole == .owner || shareRole == nil
    }
}

// MARK: - 共享角色
enum ShareRole: String, Codable {
    case owner = "OWNER"           // 主人（完全权限）
    case viewer = "VIEWER"         // 查看者（只读）
}

// MARK: - 共同主人信息
struct BirdCoOwner: Identifiable, Codable {
    let id: Int64           // 共享记录ID
    let userId: Int64       // 用户ID
    let username: String    // 用户名
    let avatarUrl: String?  // 用户头像
    let role: ShareRole     // 共享角色
    let sharedAt: Date?     // 共享时间
    
    enum CodingKeys: String, CodingKey {
        case id, userId, username, avatarUrl, role, sharedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        userId = try container.decode(Int64.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
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
    let fromUserId: Int64
    let fromUsername: String
    let toUserId: Int64
    let role: ShareRole
    let status: InvitationStatus
    let createdAt: Date?
    let expiresAt: Date?
    
    enum InvitationStatus: String, Codable {
        case pending = "PENDING"
        case accepted = "ACCEPTED"
        case rejected = "REJECTED"
        case expired = "EXPIRED"
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
