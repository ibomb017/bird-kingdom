import Foundation

struct Reminder: Identifiable, Codable, Hashable {
    let id: Int64
    let title: String
    let timeDescription: String
    let reminderType: String?
    let enabled: Bool
    let birdId: Int64?
    let birdName: String?
    // Bug #4 修复：添加已读状态和更新时间
    var isRead: Bool
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case timeDescription
        case reminderType
        case enabled
        case birdId
        case birdName
        case isRead
        case updatedAt
    }
    
    // Bug #4 修复：自定义解码以处理服务器可能不返回 isRead 的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        timeDescription = try container.decode(String.self, forKey: .timeDescription)
        reminderType = try container.decodeIfPresent(String.self, forKey: .reminderType)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        birdId = try container.decodeIfPresent(Int64.self, forKey: .birdId)
        birdName = try container.decodeIfPresent(String.self, forKey: .birdName)
        // 默认为 false（未读）
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    // 手动初始化方法
    init(id: Int64, title: String, timeDescription: String, reminderType: String?, enabled: Bool, birdId: Int64?, birdName: String?, isRead: Bool = false, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.timeDescription = timeDescription
        self.reminderType = reminderType
        self.enabled = enabled
        self.birdId = birdId
        self.birdName = birdName
        self.isRead = isRead
        self.updatedAt = updatedAt
    }
}
