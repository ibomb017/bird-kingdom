import Foundation

/// 全局日期格式化工具
/// 解决 ISO8601DateFormatter 默认使用 UTC 时区导致的日期偏移问题
///
/// 核心问题：
/// - Swift 的 ISO8601DateFormatter 在 formatOptions 包含 .withInternetDateTime 时
///   会强制使用 UTC 时区（输出 "Z" 后缀），忽略 timeZone 属性的设置
/// - 这导致北京时间 2026-02-02 16:00 会被格式化为 "2026-02-02T08:00:00Z"
/// - 后端解析时虽然能正确还原时间点，但在某些场景下（如仅使用日期部分）会导致日期偏移一天
///
/// 解决方案：
/// - 使用 DateFormatter 替代 ISO8601DateFormatter，显式指定时区
/// - 提供统一的日期格式化接口，确保所有模块使用一致的时区处理
enum DateFormatters {
    
    // MARK: - 中国时区常量
    
    /// 中国标准时区（UTC+8）
    static let chinaTimeZone = TimeZone(identifier: "Asia/Shanghai")!
    
    /// POSIX Locale（用于日期格式化，避免本地化影响）
    static let posixLocale = Locale(identifier: "en_US_POSIX")
    
    // MARK: - API 日期格式化器（发送给后端）
    
    /// ISO8601 日期时间格式化器（带时区偏移量，如 "2026-02-02T16:00:00+08:00"）
    /// 用于：日志、体重记录等需要精确时间的场景
    static let apiDateTime: DateFormatter = {
        let formatter = DateFormatter()
        // 使用带时区偏移量的 ISO8601 格式，后端可正确解析
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.timeZone = chinaTimeZone
        formatter.locale = posixLocale
        return formatter
    }()
    
    /// 纯日期格式化器（如 "2026-02-02"）
    /// 用于：周期开始日期、支出日期等只需要日期不需要时间的场景
    static let apiDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = chinaTimeZone
        formatter.locale = posixLocale
        return formatter
    }()
    
    // MARK: - UI 显示日期格式化器
    
    /// UI 显示用日期格式化器（如 "2026-02-02"）
    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = chinaTimeZone
        formatter.locale = posixLocale
        return formatter
    }()
    
    /// UI 显示用时间格式化器（如 "16:00"）
    static let displayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = chinaTimeZone
        formatter.locale = posixLocale
        return formatter
    }()
    
    /// UI 显示用日期时间格式化器（如 "2026-02-02 16:00"）
    static let displayDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = chinaTimeZone
        formatter.locale = posixLocale
        return formatter
    }()
    
    // MARK: - 便捷方法
    
    /// 将 Date 格式化为 API 可接受的 ISO8601 字符串（带时区）
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式如 "2026-02-02T16:00:00+08:00" 的字符串
    static func toAPIDateTime(_ date: Date) -> String {
        return apiDateTime.string(from: date)
    }
    
    /// 将 Date 格式化为纯日期字符串
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式如 "2026-02-02" 的字符串
    static func toAPIDateOnly(_ date: Date) -> String {
        return apiDateOnly.string(from: date)
    }
    
    /// 从 API 日期字符串解析为 Date
    /// 支持多种格式：ISO8601（带/不带时区）、纯日期等
    /// - Parameter string: 日期字符串
    /// - Returns: 解析后的 Date，如果解析失败返回 nil
    static func parseFromAPI(_ string: String) -> Date? {
        // 尝试多种格式的解析器
        let formatters: [DateFormatter] = [
            apiDateTime,        // "2026-02-02T16:00:00+08:00"
            apiDateOnly,        // "2026-02-02"
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                f.timeZone = chinaTimeZone
                f.locale = posixLocale
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.timeZone = chinaTimeZone
                f.locale = posixLocale
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                f.timeZone = chinaTimeZone
                f.locale = posixLocale
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        // 最后尝试 ISO8601DateFormatter（支持 "Z" 后缀的 UTC 时间）
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }
        
        // 尝试不带小数秒的 ISO8601
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: string)
    }
    
    // MARK: - Calendar 辅助方法
    
    /// 获取使用中国时区的 Calendar
    static var chinaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chinaTimeZone
        return calendar
    }
    
    /// 获取某个日期在中国时区的开始时间（00:00:00）
    /// - Parameter date: 输入日期
    /// - Returns: 该日期在中国时区的开始时间
    static func startOfDay(_ date: Date) -> Date {
        return chinaCalendar.startOfDay(for: date)
    }
    
    /// 判断两个日期在中国时区是否是同一天
    /// - Parameters:
    ///   - date1: 第一个日期
    ///   - date2: 第二个日期
    /// - Returns: 是否是同一天
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return chinaCalendar.isDate(date1, inSameDayAs: date2)
    }
    
    /// 获取某个日期在中国时区的日期标签（用于分组显示）
    /// - Parameter date: 输入日期
    /// - Returns: 格式如 "2026-02-02" 的字符串
    static func dateLabel(for date: Date) -> String {
        return displayDate.string(from: date)
    }
}

// MARK: - Date 扩展

extension Date {
    /// 使用中国时区格式化为 API 日期时间字符串
    var apiDateTimeString: String {
        DateFormatters.toAPIDateTime(self)
    }
    
    /// 使用中国时区格式化为纯日期字符串
    var apiDateOnlyString: String {
        DateFormatters.toAPIDateOnly(self)
    }
    
    /// 使用中国时区格式化为显示用时间字符串
    var displayTimeString: String {
        DateFormatters.displayTime.string(from: self)
    }
    
    /// 使用中国时区格式化为显示用日期时间字符串
    var displayDateTimeString: String {
        DateFormatters.displayDateTime.string(from: self)
    }
    
    /// 获取在中国时区的当天开始时间
    var startOfDayInChina: Date {
        DateFormatters.startOfDay(self)
    }
}
