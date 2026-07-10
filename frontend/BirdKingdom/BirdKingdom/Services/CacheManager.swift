import Foundation
import Network
import Combine

// MARK: - 统一缓存管理器
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    // 网络状态监控
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.birdkingdom.networkmonitor")
    
    @Published var isOnline: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case unknown
    }
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - 网络监控
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else {
                    self?.connectionType = .unknown
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - 缓存统计
    
    /// 获取总缓存大小
    func getTotalCacheSize() -> Int64 {
        let imageSize = ImageCacheService.shared.getDiskCacheSize()
        let videoSize = VideoCacheService.shared.getCacheSize()
        let postSize = PostCacheService.shared.getCacheSize()
        return imageSize + videoSize + postSize
    }
    
    /// 格式化总缓存大小
    func formattedTotalCacheSize() -> String {
        let size = getTotalCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// 获取各类缓存大小详情
    func getCacheSizeDetails() -> (images: String, videos: String, posts: String, total: String) {
        let imageSize = ImageCacheService.shared.formattedCacheSize()
        let videoSize = VideoCacheService.shared.formattedCacheSize()
        let postSize = PostCacheService.shared.formattedCacheSize()
        let total = formattedTotalCacheSize()
        return (imageSize, videoSize, postSize, total)
    }
    
    // MARK: - 缓存清理
    
    /// 清除所有缓存（包括图片、视频、帖子和本地离线数据）
    func clearAllCache() {
        // 1. 清除图片缓存
        ImageCacheService.shared.clearCache()
        
        // 2. 清除视频缓存
        VideoCacheService.shared.clearCache()
        
        // 3. 清除帖子缓存
        PostCacheService.shared.clearAllCache()
        
        // 4. P0 关键修复：清除 OfflineDataService 的所有本地数据
        // 这可以解决"未知鸟儿"等脏数据问题
        OfflineDataService.shared.clearAllLocalData()
        
        // 5. 清除日志图片本地存储
        LogImageStorage.shared.clearAllImages()
        
        print("🗑️ 已清除所有缓存（图片、视频、帖子、本地离线数据）")
    }
    
    /// 只清除图片缓存
    func clearImageCache() {
        ImageCacheService.shared.clearCache()
    }
    
    /// 只清除视频缓存
    func clearVideoCache() {
        VideoCacheService.shared.clearCache()
    }
    
    /// 只清除帖子缓存
    func clearPostCache() {
        PostCacheService.shared.clearAllCache()
    }
    
    // MARK: - 智能预加载
    
    /// 根据网络状态智能预加载
    func smartPreload(imageURLs: [String], videoURLs: [String] = []) {
        // 预加载图片（任何网络都加载）
        ImageCacheService.shared.preloadImages(imageURLs)
        
        // 视频只在WiFi下预加载
        if connectionType == .wifi && isOnline {
            VideoCacheService.shared.preloadVideos(videoURLs)
        }
    }
    
    // MARK: - 离线模式支持
    
    /// 检查是否有可用的离线数据
    func hasOfflineData() -> Bool {
        let hasPosts = PostCacheService.shared.getCachedRecommendedPosts() != nil
        let hasImages = ImageCacheService.shared.getDiskCacheSize() > 0
        return hasPosts || hasImages
    }
    
    /// 获取离线状态提示
    func getOfflineStatusMessage() -> String {
        if isOnline {
            return ""
        }
        
        if hasOfflineData() {
            return "当前处于离线模式，显示缓存内容"
        } else {
            return "无网络连接，暂无缓存内容可显示"
        }
    }
}
