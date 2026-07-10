import Foundation

struct BirdLog: Identifiable, Codable, Hashable {
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BirdLog, rhs: BirdLog) -> Bool {
        lhs.id == rhs.id
    }
    
    let id: Int64
    let birdId: Int64
    var birdName: String
    let logDate: Date
    let weight: Double?
    let feedAmount: Double?
    let waterAmount: Double?
    let mood: String?
    let behavior: String?
    let isMolting: Bool?
    let isBreeding: Bool?
    let temperature: Double?
    let humidity: Double?
    let isCleaned: Bool?
    let healthScore: Int?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?  // 添加：匹配后端 BirdLogDTO
    let imageUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case birdId
        case birdName
        case logDate
        case weight
        case feedAmount
        case waterAmount
        case mood
        case behavior
        case isMolting
        case isBreeding
        case temperature
        case humidity
        case isCleaned
        case healthScore
        case notes
        case createdAt
        case updatedAt
        case imageUrls
    }

    init(id: Int64,
         birdId: Int64,
         birdName: String,
         logDate: Date,
         weight: Double?,
         feedAmount: Double?,
         waterAmount: Double?,
         mood: String?,
         behavior: String?,
         isMolting: Bool?,
         isBreeding: Bool?,
         temperature: Double?,
         humidity: Double?,
         isCleaned: Bool?,
         healthScore: Int?,
         notes: String?,
         createdAt: Date?,
         updatedAt: Date? = nil,
         imageUrls: [String]? = nil) {
        self.id = id
        self.birdId = birdId
        self.birdName = birdName
        self.logDate = logDate
        self.weight = weight
        self.feedAmount = feedAmount
        self.waterAmount = waterAmount
        self.mood = mood
        self.behavior = behavior
        self.isMolting = isMolting
        self.isBreeding = isBreeding
        self.temperature = temperature
        self.humidity = humidity
        self.isCleaned = isCleaned
        self.healthScore = healthScore
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageUrls = imageUrls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int64.self, forKey: .id)
        birdId = try container.decode(Int64.self, forKey: .birdId)
        // Swift 后端可能不返回 birdName，使用默认值
        birdName = (try? container.decode(String.self, forKey: .birdName)) ?? "未知鸟儿"

        // logDate 支持 Date 类型（Swift 后端）和字符串类型（Java 后端）
        if let date = try? container.decode(Date.self, forKey: .logDate) {
            logDate = date
        } else {
            logDate = try BirdLog.decodeDate(forKey: .logDate, in: container)
        }
        
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        feedAmount = try container.decodeIfPresent(Double.self, forKey: .feedAmount)
        waterAmount = try container.decodeIfPresent(Double.self, forKey: .waterAmount)
        mood = try container.decodeIfPresent(String.self, forKey: .mood)
        behavior = try container.decodeIfPresent(String.self, forKey: .behavior)
        isMolting = try container.decodeIfPresent(Bool.self, forKey: .isMolting)
        isBreeding = try container.decodeIfPresent(Bool.self, forKey: .isBreeding)
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        humidity = try container.decodeIfPresent(Double.self, forKey: .humidity)
        isCleaned = try container.decodeIfPresent(Bool.self, forKey: .isCleaned)
        healthScore = try container.decodeIfPresent(Int.self, forKey: .healthScore)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try BirdLog.decodeOptionalDate(forKey: .createdAt, in: container)
        updatedAt = try BirdLog.decodeOptionalDate(forKey: .updatedAt, in: container)
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(birdId, forKey: .birdId)
        try container.encode(birdName, forKey: .birdName)
        try container.encode(logDate, forKey: .logDate)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(feedAmount, forKey: .feedAmount)
        try container.encodeIfPresent(waterAmount, forKey: .waterAmount)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(behavior, forKey: .behavior)
        try container.encodeIfPresent(isMolting, forKey: .isMolting)
        try container.encodeIfPresent(isBreeding, forKey: .isBreeding)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(humidity, forKey: .humidity)
        try container.encodeIfPresent(isCleaned, forKey: .isCleaned)
        try container.encodeIfPresent(healthScore, forKey: .healthScore)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(imageUrls, forKey: .imageUrls)
    }

    // 中国时区
    private static let chinaTimeZone = TimeZone(identifier: "Asia/Shanghai")!
    
    private static func decodeDate(forKey key: CodingKeys,
                                   in container: KeyedDecodingContainer<CodingKeys>) throws -> Date {
        let dateString = try container.decode(String.self, forKey: key)
        
        // 尝试多种日期格式，优先处理纯日期格式
        // 所有格式化器都使用中国时区
        let formatters: [Any] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = chinaTimeZone
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                formatter.timeZone = chinaTimeZone
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = chinaTimeZone
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = chinaTimeZone
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = chinaTimeZone
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let iso8601Formatter = formatter as? ISO8601DateFormatter {
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }
            } else if let dateFormatter = formatter as? DateFormatter {
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
        }
        
        throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Date string does not match expected format: \(dateString)")
    }

    private static func decodeOptionalDate(forKey key: CodingKeys,
                                           in container: KeyedDecodingContainer<CodingKeys>) throws -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        if let stringValue = try container.decodeIfPresent(String.self, forKey: key) {
            return parseDate(from: stringValue)
        }
        return nil
    }

    private static func parseDate(from string: String) -> Date? {
        if let dateOnly = dateOnlyFormatter.date(from: string) {
            return dateOnly
        }
        if let plainDate = plainDateTimeFormatter.date(from: string) {
            return plainDate
        }
        if let isoDate = isoFormatter.date(from: string) {
            return isoDate
        }
        if let isoFraction = isoFractionalFormatter.date(from: string) {
            return isoFraction
        }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter
    }()

    private static let plainDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var moodText: String {
        let isEn = LanguageManager.shared.isEnglish
        switch mood {
        case "HAPPY":
            return isEn ? "Happy" : "开心"
        case "NORMAL":
            return isEn ? "Normal" : "正常"
        case "QUIET":
            return isEn ? "Quiet" : "安静"
        case "ANXIOUS":
            return isEn ? "Anxious" : "焦虑"
        default:
            return mood ?? ""
        }
    }

    var summary: String {
        var parts: [String] = []
        // 不在 summary 中显示体重，体重单独在卡片底部显示为小标签
        if mood != nil { parts.append(moodText) }
        if let notes = notes, !notes.isEmpty { parts.append(notes) }
        return parts.joined(separator: " · ")
    }
    
    /// 判断日志是否有实际内容（文字或图片）
    /// 如果只有体重或心情数据，则不算有内容，应该只显示在体重趋势中
    var hasContent: Bool {
        // 有文字记录
        if let notes = notes, !notes.isEmpty {
            return true
        }
        // 有图片
        if let imageUrls = imageUrls, !imageUrls.isEmpty {
            return true
        }
        return false
    }
}

// MARK: - 体重趋势DTO（匹配后端返回的扁平结构）
/// 后端返回格式: [{date, weight, birdId}, ...]
struct WeightTrendDTO: Codable {
    let date: Date
    let weight: Double
    let birdId: Int64
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weight = try container.decode(Double.self, forKey: .weight)
        birdId = try container.decode(Int64.self, forKey: .birdId)
        
        // 日期解析：支持 Date 类型（Swift 后端）和字符串类型
        if let directDate = try? container.decode(Date.self, forKey: .date) {
            date = directDate
        } else {
            let dateString = try container.decode(String.self, forKey: .date)
            let formatters: [DateFormatter] = [
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
                    f.timeZone = TimeZone(identifier: "Asia/Shanghai")
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    f.timeZone = TimeZone(identifier: "Asia/Shanghai")
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd"
                    f.timeZone = TimeZone(identifier: "Asia/Shanghai")
                    return f
                }()
            ]
            
            for formatter in formatters {
                if let d = formatter.date(from: dateString) {
                    date = d
                    return
                }
            }
            
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "无法解析日期: \(dateString)")
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case date, weight, birdId
    }
}
