import Foundation

struct Reminder: Identifiable, Codable {
    let id: Int64
    let title: String
    let timeDescription: String
    let reminderType: String?
    let enabled: Bool
    let birdId: Int64?
    let birdName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case timeDescription
        case reminderType
        case enabled
        case birdId
        case birdName
    }
    
    // 手动初始化方法
    init(id: Int64, title: String, timeDescription: String, reminderType: String?, enabled: Bool, birdId: Int64?, birdName: String?) {
        self.id = id
        self.title = title
        self.timeDescription = timeDescription
        self.reminderType = reminderType
        self.enabled = enabled
        self.birdId = birdId
        self.birdName = birdName
    }
}
