import Foundation

// MARK: - 帖子缓存服务
class PostCacheService {
    static let shared = PostCacheService()
    
    private let cacheDirectory: URL
    private let recommendedCacheFile = "recommended_posts.json"
    private let nearbyCacheFile = "nearby_posts.json"
    private let followingCacheFile = "following_posts.json"
    
    // 缓存过期时间（24小时）
    private let cacheExpiration: TimeInterval = 24 * 60 * 60
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        // 获取缓存目录
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("PostCache", isDirectory: true)
        
        // 创建缓存目录
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 设置日期格式
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - 缓存数据结构
    struct CachedPosts: Codable {
        let posts: [ForumPostDTO]
        let cachedAt: Date
        
        // Fix A5: 处理系统时间回拨
        var isExpired: Bool {
            let elapsed = Date().timeIntervalSince(cachedAt)
            // 时间回拨检测：elapsed 为负数视为过期
            return elapsed < 0 || elapsed > PostCacheService.shared.cacheExpiration
        }
    }
    
    // MARK: - 保存缓存
    
    /// 缓存推荐帖子
    func cacheRecommendedPosts(_ posts: [ForumPostDTO]) {
        savePosts(posts, to: recommendedCacheFile)
    }
    
    /// 缓存附近帖子
    func cacheNearbyPosts(_ posts: [ForumPostDTO]) {
        savePosts(posts, to: nearbyCacheFile)
    }
    
    /// 缓存关注帖子
    func cacheFollowingPosts(_ posts: [ForumPostDTO]) {
        savePosts(posts, to: followingCacheFile)
    }
    
    private func savePosts(_ posts: [ForumPostDTO], to filename: String) {
        let cached = CachedPosts(posts: posts, cachedAt: Date())
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        // Fix C1: 使用 replaceItemAt 实现真正的原子替换
        let tempURL = cacheDirectory.appendingPathComponent(filename + ".tmp.\(UUID().uuidString)")
        
        do {
            let data = try encoder.encode(cached)
            // 先写入临时文件
            try data.write(to: tempURL, options: .atomic)
            
            // 使用 replaceItemAt 实现原子替换（如果目标存在）
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: fileURL)
            }
            print("📦 缓存帖子成功: \(filename), 数量: \(posts.count)")
        } catch {
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempURL)
            print("❌ 缓存帖子失败: \(error)")
        }
    }
    
    // MARK: - 读取缓存
    
    /// 获取缓存的推荐帖子
    func getCachedRecommendedPosts() -> [ForumPostDTO]? {
        return loadPosts(from: recommendedCacheFile)
    }
    
    /// 获取缓存的附近帖子
    func getCachedNearbyPosts() -> [ForumPostDTO]? {
        return loadPosts(from: nearbyCacheFile)
    }
    
    /// 获取缓存的关注帖子
    func getCachedFollowingPosts() -> [ForumPostDTO]? {
        return loadPosts(from: followingCacheFile)
    }
    
    private func loadPosts(from filename: String) -> [ForumPostDTO]? {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let cached = try decoder.decode(CachedPosts.self, from: data)
            
            // 检查是否过期（但仍然返回数据，只是标记）
            if cached.isExpired {
                print("⚠️ 缓存已过期: \(filename)")
            }
            
            print("📖 读取缓存成功: \(filename), 数量: \(cached.posts.count)")
            return cached.posts
        } catch {
            // Fix #8: 删除损坏的缓存文件，避免持续解析失败
            try? FileManager.default.removeItem(at: fileURL)
            print("🗑️ 已删除损坏缓存: \(filename), 错误: \(error)")
            return nil
        }
    }
    
    // MARK: - 清理缓存
    
    /// 清除所有帖子缓存
    func clearAllCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("🗑️ 已清除所有帖子缓存")
    }
    
    /// 清除过期缓存
    func clearExpiredCache() {
        let files = [recommendedCacheFile, nearbyCacheFile, followingCacheFile]
        
        for filename in files {
            let fileURL = cacheDirectory.appendingPathComponent(filename)
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let cached = try decoder.decode(CachedPosts.self, from: data)
                
                if cached.isExpired {
                    try FileManager.default.removeItem(at: fileURL)
                    print("🗑️ 清除过期缓存: \(filename)")
                }
            } catch {
                // 解析失败的也删除
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    /// 获取缓存大小（字节）
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    /// 格式化缓存大小
    func formattedCacheSize() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
