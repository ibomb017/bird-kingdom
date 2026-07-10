import Foundation

/// 周期类型（原生理周期，现扩展为通用周期）
enum CycleType: String, Codable, CaseIterable {
    case EGG_LAYING = "EGG_LAYING" // 产蛋期
    case BATHING = "BATHING"       // 洗澡周期
    
    var displayName: String {
        let isEn = LanguageManager.shared.isEnglish
        switch self {
        case .EGG_LAYING: return isEn ? "Egg Laying" : "产蛋期"
        case .BATHING: return isEn ? "Bathing" : "洗澡"
        }
    }
    
    var icon: String {
        switch self {
        case .EGG_LAYING: return "oval"
        case .BATHING: return "drop.fill"
        }
    }
    
    var color: String {
        switch self {
        case .EGG_LAYING: return "pink"
        case .BATHING: return "blue"
        }
    }
    
    /// P1 修复：各类型周期的合理持续天数范围
    var validDurationRange: ClosedRange<Int> {
        switch self {
        case .EGG_LAYING: return 1...30    // 产蛋期通常 1-30 天
        case .BATHING: return 1...1        // 洗澡通常只有一天
        }
    }
}

// MARK: - 周期状态机（P1 S3-01 修复）

/// 周期状态枚举
enum CycleStatus: String {
    case planned    // 计划中（开始日期在未来）
    case active     // 进行中
    case ended      // 已结束
    case invalid    // 无效（日期错误等）
    
    var displayName: String {
        switch self {
        case .planned: return "计划中"
        case .active: return "进行中"
        case .ended: return "已结束"
        case .invalid: return "数据异常"
        }
    }
}

// MARK: - 异常类型（P1 BIO-01 修复）

/// 周期异常类型
enum CycleAnomalyType: String, Codable {
    case tooShort = "TOO_SHORT"                 // 持续时间过短
    case tooLong = "TOO_LONG"                   // 持续时间过长
    case startAfterEnd = "START_AFTER_END"      // 开始日期晚于结束日期
    case futureStart = "FUTURE_START"           // 开始日期在未来
    case impossibleEggData = "IMPOSSIBLE_EGG_DATA"  // 孵化数 > 产蛋数
    case negativeCount = "NEGATIVE_COUNT"       // 负数计数
    
    var displayName: String {
        switch self {
        case .tooShort: return "周期过短"
        case .tooLong: return "周期过长"
        case .startAfterEnd: return "日期错误"
        case .futureStart: return "未来日期"
        case .impossibleEggData: return "数据异常"
        case .negativeCount: return "数值错误"
        }
    }
}

// MARK: - 预测置信度（企业级优化）

/// 预测置信度
enum CycleConfidence: String, Codable {
    case high       // 历史数据充足（≥5条）+ 标准差低
    case medium     // 历史数据 2-4 条
    case low        // 仅品种参考
    case unknown    // 无任何数据
    case anomalous  // 存在异常记录
    
    var displayName: String {
        switch self {
        case .high: return "高置信度"
        case .medium: return "中置信度"
        case .low: return "低置信度"
        case .unknown: return "无法预测"
        case .anomalous: return "数据异常"
        }
    }
}

// MARK: - 生理周期记录

/// 生理周期记录
struct BirdCycleRecord: Identifiable, Codable {
    let id: Int64
    let birdId: Int64
    let cycleType: CycleType
    let startDate: Date
    var endDate: Date?
    var notes: String?
    var eggCount: Int?       // 产蛋数（仅产蛋期）
    var hatchedCount: Int?   // 孵化成功数
    let createdAt: Date?
    
    // MARK: - 状态机（P1 S3-01 修复）
    
    /// 周期当前状态
    var status: CycleStatus {
        // 无效状态检查
        if let end = endDate, end < startDate {
            return .invalid
        }
        
        // 计划中（未来开始）
        if startDate > Date() {
            return .planned
        }
        
        // 已结束
        if endDate != nil {
            return .ended
        }
        
        // 进行中
        return .active
    }
    
    /// 是否正在进行中（兼容旧代码）
    var isActive: Bool {
        status == .active
    }
    
    /// 持续天数（P2 M4-03 修复：使用固定时区）
    var durationDays: Int {
        let end = endDate ?? Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar.dateComponents([.day], from: startDate, to: end).day ?? 0
    }
    
    // MARK: - 数据校验（P1 P1-01, M4-01 修复）
    
    /// 日期是否有效
    var isDateValid: Bool {
        guard let end = endDate else { return true }
        return startDate <= end
    }
    
    /// 产蛋数据是否有效
    var isEggDataValid: Bool {
        // 检查负数
        if let egg = eggCount, egg < 0 { return false }
        if let hatched = hatchedCount, hatched < 0 { return false }
        
        // 检查孵化数 <= 产蛋数
        if let egg = eggCount, let hatched = hatchedCount {
            return hatched <= egg
        }
        return true
    }
    
    /// 整体数据是否有效
    var isValid: Bool {
        isDateValid && isEggDataValid && status != .invalid
    }
    
    // MARK: - 异常检测（P1 BIO-01 修复）
    
    /// 检测周期异常
    var anomalies: [CycleAnomalyType] {
        var result: [CycleAnomalyType] = []
        
        // 日期错误
        if let end = endDate, end < startDate {
            result.append(.startAfterEnd)
        }
        
        // 未来开始日期（对于已结束的周期是异常）
        if startDate > Date() && endDate != nil {
            result.append(.futureStart)
        }
        
        // 持续时间异常（仅对已结束的周期）
        if endDate != nil {
            let duration = durationDays
            let validRange = cycleType.validDurationRange
            if duration < validRange.lowerBound {
                result.append(.tooShort)
            } else if duration > validRange.upperBound {
                result.append(.tooLong)
            }
        }
        
        // 产蛋数据异常
        if let egg = eggCount, egg < 0 {
            result.append(.negativeCount)
        }
        if let hatched = hatchedCount, hatched < 0 {
            result.append(.negativeCount)
        }
        if let egg = eggCount, let hatched = hatchedCount, hatched > egg {
            result.append(.impossibleEggData)
        }
        
        return result
    }
    
    /// 是否为异常周期
    var isAnomalous: Bool {
        !anomalies.isEmpty
    }
    
    /// 异常描述
    var anomalyDescription: String? {
        guard isAnomalous else { return nil }
        return anomalies.map { $0.displayName }.joined(separator: "、")
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, birdId, cycleType, startDate, endDate, notes, eggCount, hatchedCount, createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        birdId = try container.decode(Int64.self, forKey: .birdId)
        cycleType = try container.decode(CycleType.self, forKey: .cycleType)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        eggCount = try container.decodeIfPresent(Int.self, forKey: .eggCount)
        hatchedCount = try container.decodeIfPresent(Int.self, forKey: .hatchedCount)
        
        // 日期解析 - 使用中国时区避免日期偏移问题
        // 问题：后端返回的是纯日期字符串 (如 "2026-01-28")
        // ISO8601DateFormatter 默认使用 UTC 时区解析，导致在中国时区 (UTC+8) 显示时日期可能偏移
        let chinaTimeZone = TimeZone(identifier: "Asia/Shanghai")!
        
        // 方法1：使用 DateFormatter 直接解析纯日期，指定中国时区
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = chinaTimeZone
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // 方法2：ISO8601DateFormatter（作为备用）
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        isoFormatter.timeZone = chinaTimeZone
        
        if let startStr = try? container.decode(String.self, forKey: .startDate) {
            // 优先使用 DateFormatter（更可靠地处理中国时区）
            if let parsed = dateFormatter.date(from: startStr) {
                startDate = parsed
            } else if let parsed = isoFormatter.date(from: startStr) {
                startDate = parsed
            } else {
                startDate = Date()
            }
        } else {
            startDate = Date()
        }
        
        if let endStr = try? container.decodeIfPresent(String.self, forKey: .endDate) {
            if let parsed = dateFormatter.date(from: endStr) {
                endDate = parsed
            } else if let parsed = isoFormatter.date(from: endStr) {
                endDate = parsed
            } else {
                endDate = nil
            }
        } else {
            endDate = nil
        }
        
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
    
    // 用于创建新记录
    init(birdId: Int64, cycleType: CycleType, startDate: Date, notes: String? = nil) {
        self.id = 0
        self.birdId = birdId
        self.cycleType = cycleType
        self.startDate = startDate
        self.endDate = nil
        self.notes = notes
        self.eggCount = nil
        self.hatchedCount = nil
        self.createdAt = nil
    }
    
    // 用于从本地记录创建（包含完整参数）
    init(id: Int64, birdId: Int64, cycleType: CycleType, startDate: Date, endDate: Date? = nil, notes: String? = nil, eggCount: Int? = nil, hatchedCount: Int? = nil) {
        self.id = id
        self.birdId = birdId
        self.cycleType = cycleType
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.eggCount = eggCount
        self.hatchedCount = hatchedCount
        self.createdAt = nil
    }
}

// MARK: - 周期预测结果（企业级优化）

/// 周期预测结果
struct CyclePrediction {
    let predictedDate: Date
    let confidence: CycleConfidence
    let source: PredictionSource
    let reasoning: String
    
    /// 是否已过期
    var isPastDue: Bool {
        predictedDate < Date()
    }
    
    /// 过期天数
    var daysPastDue: Int {
        guard isPastDue else { return 0 }
        return Calendar.current.dateComponents([.day], from: predictedDate, to: Date()).day ?? 0
    }
}

/// 预测来源
enum PredictionSource: Int, Comparable {
    case individualHistory = 1      // 个体历史数据
    case recentTrend = 2            // 最近趋势
    case speciesReference = 3       // 品种参考值
    case unknown = 4                // 兜底
    
    static func < (lhs: PredictionSource, rhs: PredictionSource) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .individualHistory: return "历史数据"
        case .recentTrend: return "近期趋势"
        case .speciesReference: return "品种参考"
        case .unknown: return "未知"
        }
    }
}

// MARK: - 请求 DTO

/// 创建周期请求
struct CreateCycleRequest: Codable {
    let cycleType: CycleType
    let startDate: String
    let notes: String?
    
    init(cycleType: CycleType, startDate: Date, notes: String? = nil) {
        self.cycleType = cycleType
        // P3 修复：使用 DateFormatter 并显式设置北京时区，确保日期不偏移
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        self.startDate = formatter.string(from: startDate)
        self.notes = notes
    }
}

/// 更新周期请求
struct UpdateCycleRequest: Codable {
    var endDate: String?
    var notes: String?
    var eggCount: Int?
    var hatchedCount: Int?
}

