import SwiftUI
import Combine
import CryptoKit

// MARK: - 图片尺寸枚举（避免大图撑爆内存）
enum ImageSize: String {
    case thumbnail = "thumb"    // 缩略图 100x100
    case small = "small"        // 小图 200x200
    case medium = "medium"      // 中图 400x400
    case large = "large"        // 大图 800x800
    case original = "original"  // 原图
    
    var maxDimension: CGFloat {
        switch self {
        case .thumbnail: return 100
        case .small: return 200
        case .medium: return 400
        case .large: return 800
        case .original: return .infinity
        }
    }
}

// MARK: - 缓存条目（带TTL）
final class CacheEntry {
    let image: UIImage
    let createdAt: Date
    let ttl: TimeInterval
    
    init(image: UIImage, ttl: TimeInterval = 30 * 24 * 60 * 60) {
        self.image = image
        self.createdAt = Date()
        self.ttl = ttl
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > ttl
    }
}

// MARK: - 图片缓存协议
protocol ImageCache {
    func image(for key: String, size: ImageSize) -> UIImage?
    func store(_ image: UIImage, for key: String, size: ImageSize)
    func remove(for key: String)
    func clear()
}

// MARK: - 内存缓存（NSCache + TTL）
final class MemoryCache: ImageCache {
    static let shared = MemoryCache()
    
    private let cache = NSCache<NSString, CacheEntry>()
    private let defaultTTL: TimeInterval = 30 * 60 // 内存缓存30分钟
    
    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        
        // 内存警告时清理
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clear()
        }
    }
    
    private func cacheKey(_ key: String, size: ImageSize) -> String {
        "\(key)_\(size.rawValue)"
    }
    
    func image(for key: String, size: ImageSize = .original) -> UIImage? {
        let fullKey = cacheKey(key, size: size)
        guard let entry = cache.object(forKey: fullKey as NSString) else { return nil }
        
        if entry.isExpired {
            cache.removeObject(forKey: fullKey as NSString)
            return nil
        }
        return entry.image
    }
    
    func store(_ image: UIImage, for key: String, size: ImageSize = .original) {
        let fullKey = cacheKey(key, size: size)
        let resizedImage = resizeImage(image, to: size)
        let cost = resizedImage.jpegData(compressionQuality: 1.0)?.count ?? 0
        let entry = CacheEntry(image: resizedImage, ttl: defaultTTL)
        cache.setObject(entry, forKey: fullKey as NSString, cost: cost)
    }
    
    func remove(for key: String) {
        for size in [ImageSize.thumbnail, .small, .medium, .large, .original] {
            let fullKey = cacheKey(key, size: size)
            cache.removeObject(forKey: fullKey as NSString)
        }
    }
    
    func clear() {
        cache.removeAllObjects()
    }
    
    private func resizeImage(_ image: UIImage, to size: ImageSize) -> UIImage {
        guard size != .original else { return image }
        
        let maxDim = size.maxDimension
        let originalSize = image.size
        
        guard originalSize.width > maxDim || originalSize.height > maxDim else { return image }
        
        let scale = min(maxDim / originalSize.width, maxDim / originalSize.height)
        let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - 磁盘缓存（FileManager + LRU清理）
final class DiskCache: ImageCache {
    static let shared = DiskCache()
    
    private let cacheDirectory: URL
    private let metadataDirectory: URL
    private let queue = DispatchQueue(label: "com.birdkingdom.diskcache", attributes: .concurrent)
    
    // 配置
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private let cleanupThreshold: Double = 0.8 // 80%时开始清理
    private let defaultTTL: TimeInterval = 30 * 24 * 60 * 60 // 30天
    
    init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache", isDirectory: true)
        metadataDirectory = paths[0].appendingPathComponent("ImageCacheMeta", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        
        // 启动时异步清理
        Task { await cleanupIfNeeded() }
    }
    
    private func cacheKey(for key: String, size: ImageSize) -> String {
        let combined = "\(key)_\(size.rawValue)"
        let data = Data(combined.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // Fix #5: 同步版本（仅用于向后兼容，不建议在主线程调用）
    func image(for key: String, size: ImageSize = .original) -> UIImage? {
        let fileName = cacheKey(for: key, size: size)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        let metaURL = metadataDirectory.appendingPathComponent(fileName + ".meta")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        // 检查TTL
        if let metaData = try? Data(contentsOf: metaURL),
           let meta = try? JSONDecoder().decode(CacheMetadata.self, from: metaData) {
            if Date().timeIntervalSince(meta.createdAt) > meta.ttl {
                try? FileManager.default.removeItem(at: fileURL)
                try? FileManager.default.removeItem(at: metaURL)
                return nil
            }
        }
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return nil }
        
        // 更新访问时间（LRU）
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        return image
    }
    
    // Fix #5: 异步版本（推荐使用，避免阻塞主线程）
    func imageAsync(for key: String, size: ImageSize = .original) async -> UIImage? {
        let fileName = cacheKey(for: key, size: size)
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        let metaURL = metadataDirectory.appendingPathComponent(fileName + ".meta")
        
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // 检查TTL
                if let metaData = try? Data(contentsOf: metaURL),
                   let meta = try? JSONDecoder().decode(CacheMetadata.self, from: metaData) {
                    if Date().timeIntervalSince(meta.createdAt) > meta.ttl {
                        try? FileManager.default.removeItem(at: fileURL)
                        try? FileManager.default.removeItem(at: metaURL)
                        continuation.resume(returning: nil)
                        return
                    }
                }
                
                guard let data = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // 更新访问时间（LRU）
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
                continuation.resume(returning: image)
            }
        }
    }
    
    func store(_ image: UIImage, for key: String, size: ImageSize = .original) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let fileName = self.cacheKey(for: key, size: size)
            let fileURL = self.cacheDirectory.appendingPathComponent(fileName)
            let metaURL = self.metadataDirectory.appendingPathComponent(fileName + ".meta")
            
            // 根据尺寸调整压缩质量
            let quality: CGFloat = size == .thumbnail ? 0.6 : (size == .original ? 0.9 : 0.8)
            let data: Data? = key.lowercased().contains(".png") ? image.pngData() : image.jpegData(compressionQuality: quality)
            
            try? data?.write(to: fileURL)
            
            // 保存元数据
            let meta = CacheMetadata(createdAt: Date(), ttl: self.defaultTTL)
            if let metaData = try? JSONEncoder().encode(meta) {
                try? metaData.write(to: metaURL)
            }
            
            // 检查是否需要清理
            Task { await self.cleanupIfNeeded() }
        }
    }
    
    func remove(for key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            for size in [ImageSize.thumbnail, .small, .medium, .large, .original] {
                let fileName = self.cacheKey(for: key, size: size)
                let fileURL = self.cacheDirectory.appendingPathComponent(fileName)
                let metaURL = self.metadataDirectory.appendingPathComponent(fileName + ".meta")
                try? FileManager.default.removeItem(at: fileURL)
                try? FileManager.default.removeItem(at: metaURL)
            }
        }
    }
    
    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.cacheDirectory)
            try? FileManager.default.removeItem(at: self.metadataDirectory)
            try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: self.metadataDirectory, withIntermediateDirectories: true)
        }
    }
    
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
    
    func formattedCacheSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: getCacheSize())
    }
    
    // LRU清理策略
    private func cleanupIfNeeded() async {
        let currentSize = getCacheSize()
        let threshold = Int64(Double(maxCacheSize) * cleanupThreshold)
        
        guard currentSize > threshold else { return }
        
        let fileManager = FileManager.default
        let targetSize = Int64(Double(maxCacheSize) * 0.5) // 清理到50%
        
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }
        
        var allFiles: [(url: URL, date: Date, size: Int64)] = []
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            guard let attributes = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modDate = attributes.contentModificationDate,
                  let fileSize = attributes.fileSize else { continue }
            
            let size = Int64(fileSize)
            totalSize += size
            allFiles.append((fileURL, modDate, size))
        }
        
        // 按访问时间排序（最旧的在前）
        allFiles.sort { $0.date < $1.date }
        
        // 删除最旧的文件直到达到目标大小
        for file in allFiles {
            if totalSize <= targetSize { break }
            
            try? fileManager.removeItem(at: file.url)
            // 同时删除元数据
            let metaURL = metadataDirectory.appendingPathComponent(file.url.lastPathComponent + ".meta")
            try? fileManager.removeItem(at: metaURL)
            
            totalSize -= file.size
        }
    }
}

// MARK: - 缓存元数据
struct CacheMetadata: Codable {
    let createdAt: Date
    let ttl: TimeInterval
}

// MARK: - 图片加载器（ObservableObject）
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var loadFailed = false
    
    private let memoryCache: MemoryCache
    private let diskCache: DiskCache
    private var task: Task<Void, Never>?
    private var retryCount = 0
    private let maxRetries = 2
    
    init(memoryCache: MemoryCache = .shared, diskCache: DiskCache = .shared) {
        self.memoryCache = memoryCache
        self.diskCache = diskCache
    }
    
    // Fix A2: 改为异步加载，避免主线程磁盘 I/O
    func load(from urlString: String, size: ImageSize = .medium) {
        loadFailed = false
        
        // 1. 检查内存缓存（同步OK，内存访问快速）
        if let cached = memoryCache.image(for: urlString, size: size) {
            self.image = cached
            return
        }
        
        // 2. 启动异步加载（磁盘和网络都在后台）
        isLoading = true
        task?.cancel()
        task = Task { @MainActor in
            defer { isLoading = false }
            
            // 2a. 异步检查磁盘缓存（Fix A2: 不阻塞主线程）
            if let cached = await diskCache.imageAsync(for: urlString, size: size) {
                memoryCache.store(cached, for: urlString, size: size)
                self.image = cached
                return
            }
            
            // 2b. 网络加载
            guard let url = URL(string: urlString) else {
                loadFailed = true
                return
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let loadedImage = UIImage(data: data) else {
                    loadFailed = true
                    return
                }
                
                // 存储原图到磁盘，调整后的图到内存
                diskCache.store(loadedImage, for: urlString, size: .original)
                memoryCache.store(loadedImage, for: urlString, size: size)
                self.image = memoryCache.image(for: urlString, size: size)
                retryCount = 0
            } catch {
                if !Task.isCancelled {
                    // 重试逻辑
                    if retryCount < maxRetries {
                        retryCount += 1
                        try? await Task.sleep(nanoseconds: UInt64(retryCount) * 500_000_000)
                        load(from: urlString, size: size)
                    } else {
                        loadFailed = true
                    }
                }
            }
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - 图片预加载管理器（滚动预加载）
final class ImagePreloader {
    static let shared = ImagePreloader()
    
    private let memoryCache = MemoryCache.shared
    private let diskCache = DiskCache.shared
    private var preloadTasks: [String: Task<Void, Never>] = [:]
    private let queue = DispatchQueue(label: "com.birdkingdom.preloader")
    
    // 预加载图片列表
    func preload(_ urls: [String], size: ImageSize = .medium, priority: TaskPriority = .low) {
        for url in urls {
            preloadSingle(url, size: size, priority: priority)
        }
    }
    
    // 预加载单张图片
    func preloadSingle(_ urlString: String, size: ImageSize = .medium, priority: TaskPriority = .low) {
        // 已在缓存中则跳过
        if memoryCache.image(for: urlString, size: size) != nil { return }
        if diskCache.image(for: urlString, size: size) != nil { return }
        
        // 已在预加载中则跳过
        var alreadyLoading = false
        queue.sync {
            alreadyLoading = preloadTasks[urlString] != nil
        }
        if alreadyLoading { return }
        
        let task = Task(priority: priority) { [weak self] in
            guard let self = self, let url = URL(string: urlString) else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                
                self.diskCache.store(image, for: urlString, size: .original)
                self.memoryCache.store(image, for: urlString, size: size)
            } catch {
                // 预加载失败静默处理
            }
            
            self.queue.sync {
                self.preloadTasks.removeValue(forKey: urlString)
            }
        }
        
        queue.sync {
            preloadTasks[urlString] = task
        }
    }
    
    // 取消所有预加载
    func cancelAll() {
        queue.sync {
            preloadTasks.values.forEach { $0.cancel() }
            preloadTasks.removeAll()
        }
    }
}

// MARK: - 图片缓存服务（兼容旧接口）- Fix #4: 线程安全修复
class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    
    private let memoryCache = MemoryCache.shared
    private let diskCache = DiskCache.shared
    
    // Fix #4: 使用 actor 保护 loadingTasks 字典访问
    private actor LoadingTaskManager {
        private var loadingTasks: [String: Task<UIImage?, Never>] = [:]
        
        func getTask(for key: String) -> Task<UIImage?, Never>? {
            return loadingTasks[key]
        }
        
        func setTask(_ task: Task<UIImage?, Never>, for key: String) {
            loadingTasks[key] = task
        }
        
        func removeTask(for key: String) {
            loadingTasks.removeValue(forKey: key)
        }
    }
    
    private let taskManager = LoadingTaskManager()
    
    func getImage(for url: String, size: ImageSize = .medium) -> UIImage? {
        if let cached = memoryCache.image(for: url, size: size) {
            return cached
        }
        if let cached = diskCache.image(for: url, size: size) {
            memoryCache.store(cached, for: url, size: size)
            return cached
        }
        return nil
    }
    
    func setImage(_ image: UIImage, for url: String, size: ImageSize = .original) {
        memoryCache.store(image, for: url, size: size)
        diskCache.store(image, for: url, size: size)
    }
    
    func loadImage(from urlString: String, size: ImageSize = .medium) async -> UIImage? {
        if let cached = getImage(for: urlString, size: size) {
            return cached
        }
        
        // Fix #4: 使用 actor 安全访问
        if let existingTask = await taskManager.getTask(for: urlString) {
            return await existingTask.value
        }
        
        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString) else { return nil }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    setImage(image, for: urlString, size: size)
                    return getImage(for: urlString, size: size)
                }
            } catch {
                print("图片加载失败: \(error)")
            }
            return nil
        }
        
        await taskManager.setTask(task, for: urlString)
        let result = await task.value
        await taskManager.removeTask(for: urlString)
        return result
    }
    
    func preloadImages(_ urls: [String], size: ImageSize = .medium) {
        ImagePreloader.shared.preload(urls, size: size)
    }
    
    func clearCache() {
        memoryCache.clear()
        diskCache.clear()
    }
    
    func clearMemoryCache() {
        memoryCache.clear()
    }
    
    func getDiskCacheSize() -> Int64 {
        diskCache.getCacheSize()
    }
    
    func formattedCacheSize() -> String {
        diskCache.formattedCacheSize()
    }
}

// MARK: - 视频缩略图视图（带缓存）
struct CachedVideoThumbnail: View {
    let coverUrl: String?
    let duration: Int?
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        ZStack {
            // 封面图 - 使用 BirdKingdomApp.swift 中定义的 CachedAsyncImage
            if let urlString = coverUrl, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            
            // 播放按钮
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                        .offset(x: 2)
                )
            
            // 时长
            if let duration = duration, duration > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(8)
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - 懒加载列表项包装器
struct LazyLoadingPostCard<Content: View>: View {
    let content: () -> Content
    @State private var isVisible = false
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        Group {
            if isVisible {
                content()
            } else {
                // 占位符，保持布局稳定
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 200)
                    .onAppear {
                        isVisible = true
                    }
            }
        }
    }
}
