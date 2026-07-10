import Foundation
import UserNotifications

/// 周期提醒服务 - 管理本地通知
class CycleReminderService {
    static let shared = CycleReminderService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - 请求通知权限
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("通知权限请求失败: \(error)")
            return false
        }
    }
    
    // MARK: - 设置周期提醒
    
    /// 设置预测周期提醒（提前 N 天）
    func scheduleCycleReminder(
        birdId: Int64,
        birdName: String,
        cycleType: CycleType,
        predictedDate: Date,
        daysBefore: Int = 3
    ) {
        // 计算提醒日期
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: predictedDate) else { return }
        
        // 确保提醒日期在未来
        guard reminderDate > Date() else { return }
        
        let identifier = "cycle_\(birdId)_\(cycleType.rawValue)"
        
        let content = UNMutableNotificationContent()
        content.title = "\(cycleType.icon) \(cycleType.displayName)提醒"
        content.body = "\(birdName) 预计 \(daysBefore) 天后进入\(cycleType.displayName)"
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "birdId": birdId,
            "cycleType": cycleType.rawValue
        ]
        
        // 创建触发器
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("设置提醒失败: \(error)")
            } else {
                print("已设置\(cycleType.displayName)提醒: \(reminderDate)")
            }
        }
    }
    
    /// 取消某鸟的某类型周期提醒
    func cancelReminder(birdId: Int64, cycleType: CycleType) {
        let identifier = "cycle_\(birdId)_\(cycleType.rawValue)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// 取消某鸟的所有周期提醒
    func cancelAllReminders(birdId: Int64) {
        let identifiers = CycleType.allCases.map { "cycle_\(birdId)_\($0.rawValue)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - 根据历史记录自动设置提醒
    
    /// 根据周期历史自动设置下次提醒
    /// - Parameters:
    ///   - speciesInfo: 可选的品种信息，用于在无历史数据时回退到参考值
    func autoScheduleReminders(birdId: Int64, birdName: String, cycles: [BirdCycleRecord], speciesEntity: ParrotSpeciesEntity? = nil) {
        // 按类型分组
        let groupedCycles = Dictionary(grouping: cycles) { $0.cycleType }
        
        for cycleType in CycleType.allCases {
            let typeCycles = groupedCycles[cycleType] ?? []
            // 过滤已结束的周期
            let completedCycles = typeCycles.filter { !$0.isActive }
            
            if completedCycles.count >= 2 {
                // 有足够历史数据，使用平均间隔
                let avgInterval = calculateAverageInterval(completedCycles)
                guard avgInterval > 0 else { continue }
                
                // 从最近一次结束日期预测下次
                if let lastEndDate = completedCycles.first?.endDate {
                    if let predictedDate = Calendar.current.date(byAdding: .day, value: avgInterval, to: lastEndDate) {
                        scheduleCycleReminder(
                            birdId: birdId,
                            birdName: birdName,
                            cycleType: cycleType,
                            predictedDate: predictedDate
                        )
                    }
                }
            }
            // 注意：已移除 .MOLTING (换羽期) 相关逻辑，因为当前 CycleType 不再包含此类型
        }
    }
    
    private func calculateAverageInterval(_ cycles: [BirdCycleRecord]) -> Int {
        guard cycles.count >= 2 else { return 0 }
        var intervals: [Int] = []
        for i in 0..<(cycles.count - 1) {
            let days = Calendar.current.dateComponents([.day], from: cycles[i + 1].startDate, to: cycles[i].startDate).day ?? 0
            intervals.append(abs(days))
        }
        guard !intervals.isEmpty else { return 0 }
        return intervals.reduce(0, +) / intervals.count
    }
    
    // MARK: - 获取待处理提醒
    
    func getPendingReminders() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
}
