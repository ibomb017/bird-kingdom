import Foundation

struct BirdLog: Identifiable, Codable {
    let id: Int64
    let birdId: Int64
    let birdName: String
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
         createdAt: Date?) {
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int64.self, forKey: .id)
        birdId = try container.decode(Int64.self, forKey: .birdId)
        birdName = try container.decode(String.self, forKey: .birdName)

        logDate = try BirdLog.decodeDate(forKey: .logDate, in: container)
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
    }

    private static func decodeDate(forKey key: CodingKeys,
                                   in container: KeyedDecodingContainer<CodingKeys>) throws -> Date {
        let dateString = try container.decode(String.self, forKey: key)
        
        // 尝试多种日期格式，优先处理纯日期格式
        let formatters = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            ISO8601DateFormatter()
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
        return formatter
    }()

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var moodText: String {
        switch mood {
        case "HAPPY":
            return "开心"
        case "NORMAL":
            return "正常"
        case "QUIET":
            return "安静"
        case "ANXIOUS":
            return "焦虑"
        default:
            return mood ?? ""
        }
    }

    var summary: String {
        var parts: [String] = []
        if let weight = weight { parts.append("体重\(weight)g") }
        if mood != nil { parts.append(moodText) }
        if let notes = notes, !notes.isEmpty { parts.append(notes) }
        return parts.joined(separator: " · ")
    }
}
