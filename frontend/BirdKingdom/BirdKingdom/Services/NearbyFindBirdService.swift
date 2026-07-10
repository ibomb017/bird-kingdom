import Foundation
import CoreLocation
import Combine

/// 附近寻鸟帖提醒服务
/// 定时轮询最新寻鸟帖，如果帖子在当前用户5公里范围内且未曾提醒过，弹窗通知
class NearbyFindBirdService: ObservableObject {
    static let shared = NearbyFindBirdService()
    
    /// 需要弹窗展示的寻鸟帖（由 UI 层 consume）
    @Published var alertPost: ForumPostDTO? = nil
    
    /// 轮询间隔（秒）
    private let pollInterval: TimeInterval = 60
    
    /// 提醒范围（公里）
    private let alertRadiusKm: Double = 10.0
    
    /// 已经提醒过的帖子 ID（防止重复弹窗）
    private var alertedPostIds: Set<Int64> = []
    
    /// UserDefaults key，持久化已提醒过的帖子
    private let alertedIdsKey = "NearbyFindBird_AlertedIds"
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 恢复已提醒列表
        if let saved = UserDefaults.standard.array(forKey: alertedIdsKey) as? [Int64] {
            alertedPostIds = Set(saved)
        }
    }
    
    /// 启动后台检测（不在启动时立即弹窗，60秒后开始静默检测新帖）
    func startPolling() {
        stopPolling()
        
        // 不立即检查，避免启动时弹窗打扰用户
        // 60秒后开始首次检测，之后每60秒检测一次新的寻鸟帖
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkNearbyFindBirdPosts()
        }
    }
    
    /// 停止轮询
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 标记帖子已提醒（用户关闭弹窗后调用）
    func markAlerted(_ postId: Int64) {
        alertedPostIds.insert(postId)
        saveAlertedIds()
        alertPost = nil
    }
    
    /// 核心检查逻辑
    private func checkNearbyFindBirdPosts() {
        // 前置条件：用户已登录 + 有当前位置
        guard AuthService.shared.isLoggedIn,
              let currentLocation = LocationService.shared.currentLocation else {
            return
        }
        
        Task {
            do {
                // 获取最新的帖子（第一页，包含寻鸟帖）
                let page = try await ApiService.shared.getPosts(page: 0, size: 50, sort: "latest")
                
                // 筛选寻鸟帖
                let findBirdPosts = page.content.filter { $0.postType == "FIND_BIRD" }
                
                // 逐个检查距离
                for post in findBirdPosts {
                    // 跳过已提醒的
                    guard !alertedPostIds.contains(post.id) else { continue }
                    
                    // 跳过自己发的
                    if let authorId = post.authorId,
                       let myId = AuthService.shared.currentUser?.id,
                       authorId == myId {
                        continue
                    }
                    
                    // 跳过已找到的
                    if post.isFound == true { continue }
                    
                    // 跳过没有定位的
                    guard let lat = post.latitude, let lng = post.longitude else { continue }
                    
                    // 只提醒最近24小时内发布的
                    if let createdAt = post.createdAt {
                        let postDate = parseDate(createdAt)
                        if let postDate = postDate {
                            let hoursSincePost = Date().timeIntervalSince(postDate) / 3600
                            if hoursSincePost > 24 { continue }
                        }
                    }
                    
                    // 计算距离
                    let postLocation = CLLocation(latitude: lat, longitude: lng)
                    let distanceKm = currentLocation.distance(from: postLocation) / 1000.0
                    
                    if distanceKm <= alertRadiusKm {
                        // 在10公里范围内，触发弹窗与系统本地通知
                        await MainActor.run {
                            self.alertPost = post
                        }
                        
                        let birdName = post.birdName ?? "小鸟"
                        let location = post.locationName ?? "附近"
                        try? await NotificationService.shared.scheduleImmediateNotification(
                            id: "nearby_find_bird_\(post.id)",
                            title: "🚨 附近有鸟儿走失",
                            body: "您附近10公里内有人发布了寻鸟帖：🐦 鸟儿：\(birdName)，📍 位置：\(location)，请帮忙留意！"
                        )
                        
                        // 一次只弹一个
                        break
                    }
                }
            } catch {
                print("🔍 附近寻鸟帖检查失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 解析后端返回的日期字符串（兼容多种格式）
    private func parseDate(_ string: String) -> Date? {
        // 尝试 ISO8601 带毫秒
        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso1.date(from: string) { return date }
        
        // 尝试 ISO8601 不带毫秒
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        if let date = iso2.date(from: string) { return date }
        
        // 尝试常规格式
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd HH:mm:ss"] {
            df.dateFormat = fmt
            if let date = df.date(from: string) { return date }
        }
        
        return nil
    }
    
    private func saveAlertedIds() {
        // 只保留最近500个，防止无限增长
        let idsArray = Array(alertedPostIds.suffix(500))
        UserDefaults.standard.set(idsArray, forKey: alertedIdsKey)
    }
}
