import Foundation
import UserNotifications
import Combine

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - 权限管理
    
    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("请求通知权限失败: \(error)")
            return false
        }
    }
    
    /// 检查当前权限状态
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - 提醒管理
    
    /// 创建提醒通知
    func scheduleReminder(
        id: String,
        title: String,
        body: String,
        date: Date,
        repeats: Bool = false
    ) async throws {
        // 确保有权限
        if !isAuthorized {
            let granted = await requestAuthorization()
            guard granted else {
                throw NotificationError.permissionDenied
            }
        }
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        // 设置触发时间
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        
        // 创建请求
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        // 添加通知
        try await UNUserNotificationCenter.current().add(request)
        
        print("✅ 已设置提醒: \(title) - \(date)")
    }
    
    /// 取消指定提醒
    func cancelReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        print("❌ 已取消提醒: \(id)")
    }
    
    /// 取消所有提醒
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("❌ 已取消所有提醒")
    }
    
    /// 获取所有待处理的提醒
    func getPendingReminders() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    // MARK: - 快捷提醒方法
    
    /// 创建喂食提醒
    func scheduleFeedingReminder(birdName: String, time: Date) async throws {
        let id = "feeding_\(birdName)_\(time.timeIntervalSince1970)"
        try await scheduleReminder(
            id: id,
            title: "🍎 喂食提醒",
            body: "该给\(birdName)喂食啦！",
            date: time,
            repeats: false
        )
    }
    
    /// 创建换羽期提醒
    func scheduleMoltingReminder(birdName: String, date: Date) async throws {
        let id = "molting_\(birdName)_\(date.timeIntervalSince1970)"
        try await scheduleReminder(
            id: id,
            title: "🪶 换羽期提醒",
            body: "\(birdName)即将进入换羽期，注意补充营养",
            date: date,
            repeats: false
        )
    }
    
    /// 创建体检提醒
    func scheduleCheckupReminder(birdName: String, date: Date) async throws {
        let id = "checkup_\(birdName)_\(date.timeIntervalSince1970)"
        try await scheduleReminder(
            id: id,
            title: "🏥 体检提醒",
            body: "\(birdName)该做定期体检了",
            date: date,
            repeats: false
        )
    }
    
    /// 创建洗澡提醒
    func scheduleBathReminder(birdName: String, time: Date) async throws {
        let id = "bath_\(birdName)_\(time.timeIntervalSince1970)"
        try await scheduleReminder(
            id: id,
            title: "🛁 洗澡提醒",
            body: "该给\(birdName)洗澡啦！",
            date: time,
            repeats: false
        )
    }
    
    /// 创建自定义提醒
    func scheduleCustomReminder(title: String, content: String, time: Date) async throws {
        let id = "custom_\(time.timeIntervalSince1970)"
        try await scheduleReminder(
            id: id,
            title: title,
            body: content,
            date: time,
            repeats: false
        )
    }
}

// MARK: - 错误类型

enum NotificationError: LocalizedError {
    case permissionDenied
    case scheduleFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "通知权限未授权，请在设置中开启"
        case .scheduleFailed:
            return "设置提醒失败"
        }
    }
}
