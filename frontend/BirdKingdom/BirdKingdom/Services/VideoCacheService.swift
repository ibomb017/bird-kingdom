import Foundation
import AVFoundation
import CryptoKit
import Combine

// MARK: - 视频缓存服务（磁盘缓存）
class VideoCacheService: ObservableObject {
    static let shared = VideoCacheService()
    
    private let diskCacheDirectory: URL
    private let queue = DispatchQueue(label: "com.birdkingdom.videocache", attributes: .concurrent)
    
    // 磁盘缓存限制（5GB）
    private let maxDiskCacheSize: Int64 = 5 * 1024 * 1024 * 1024
    // 缓存过期时间（30天）
    private let cacheExpiration: TimeInterval = 30 * 24 * 60 * 60
    
    // 下载任务管理
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    
    private init() {
        // 设置磁盘缓存目录
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        diskCacheDirectory = paths[0].appendingPathComponent("VideoCache", isDirectory: true)
        
        // 创建缓存目录
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        
        // 启动时清理过期缓存
        Task {
            await cleanExpiredCache()
        }
    }
    
    // MARK: - 公开接口
    
    /// 获取缓存的视频本地URL
    func getCachedVideoURL(for remoteURL: String) -> URL? {
        let fileName = cacheFileName(for: remoteURL)
        let fileURL = diskCacheDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 更新访问时间
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        
        return fileURL
    }
    
    /// 检查视频是否已缓存
    func isVideoCached(for remoteURL: String) -> Bool {
        return getCachedVideoURL(for: remoteURL) != nil
    }
    
    /// 获取视频URL（优先本地缓存，否则返回远程URL）
    func getVideoURL(for remoteURL: String) -> URL? {
        // 优先返回本地缓存
        if let localURL = getCachedVideoURL(for: remoteURL) {
            return localURL
        }
        
        // 返回远程URL
        return URL(string: remoteURL)
    }
    
    /// 下载并缓存视频
    func downloadAndCacheVideo(from remoteURL: String, completion: @escaping (URL?) -> Void) {
        // 如果已缓存，直接返回
        if let cachedURL = getCachedVideoURL(for: remoteURL) {
            completion(cachedURL)
            return
        }
        
        guard let url = URL(string: remoteURL) else {
            completion(nil)
            return
        }
        
        // 如果已经在下载，等待完成
        if downloadTasks[remoteURL] != nil {
            // 等待现有任务完成后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.downloadAndCacheVideo(from: remoteURL, completion: completion)
            }
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            defer {
                self.downloadTasks.removeValue(forKey: remoteURL)
            }
            
            guard let tempURL = tempURL, error == nil else {
                print("❌ 视频下载失败: \(error?.localizedDescription ?? "未知错误")")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 移动到缓存目录
            let fileName = self.cacheFileName(for: remoteURL)
            let destURL = self.diskCacheDirectory.appendingPathComponent(fileName)
            
            do {
                // 如果已存在，先删除
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                print("✅ 视频缓存成功: \(fileName)")
                
                DispatchQueue.main.async {
                    completion(destURL)
                }
            } catch {
                print("❌ 视频缓存失败: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        
        downloadTasks[remoteURL] = task
        task.resume()
    }
    
    /// 异步下载并缓存视频
    func downloadAndCacheVideo(from remoteURL: String) async -> URL? {
        await withCheckedContinuation { continuation in
            downloadAndCacheVideo(from: remoteURL) { url in
                continuation.resume(returning: url)
            }
        }
    }
    
    /// 预加载视频（后台下载）
    func preloadVideo(_ remoteURL: String) {
        guard !isVideoCached(for: remoteURL) else { return }
        
        Task {
            _ = await downloadAndCacheVideo(from: remoteURL)
        }
    }
    
    /// 预加载多个视频
    func preloadVideos(_ urls: [String]) {
        for url in urls {
            preloadVideo(url)
        }
    }
    
    /// 清除所有视频缓存
    func clearCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.diskCacheDirectory)
            try? FileManager.default.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true)
            print("🗑️ 已清除所有视频缓存")
        }
    }
    
    /// 获取缓存大小
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
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
    
    // MARK: - 私有方法
    
    /// 生成缓存文件名
    private func cacheFileName(for url: String) -> String {
        let data = Data(url.utf8)
        let hash = Insecure.MD5.hash(data: data)
        let hashString = hash.map { String(format: "%02x", $0) }.joined()
        
        // 保留原始扩展名
        let ext = URL(string: url)?.pathExtension ?? "mp4"
        return "\(hashString).\(ext)"
    }
    
    /// 清理过期缓存
    private func cleanExpiredCache() async {
        let fileManager = FileManager.default
        let now = Date()
        
        guard let enumerator = fileManager.enumerator(
            at: diskCacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }
        
        var totalSize: Int64 = 0
        var filesToDelete: [URL] = []
        var allFiles: [(url: URL, date: Date, size: Int64)] = []
        
        for case let fileURL as URL in enumerator {
            guard let attributes = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modDate = attributes.contentModificationDate,
                  let fileSize = attributes.fileSize else { continue }
            
            let size = Int64(fileSize)
            totalSize += size
            
            // 检查是否过期
            if now.timeIntervalSince(modDate) > cacheExpiration {
                filesToDelete.append(fileURL)
                totalSize -= size
            } else {
                allFiles.append((fileURL, modDate, size))
            }
        }
        
        // 删除过期文件
        for fileURL in filesToDelete {
            try? fileManager.removeItem(at: fileURL)
        }
        
        // 如果超过限制，按LRU删除
        if totalSize > maxDiskCacheSize {
            allFiles.sort { $0.date < $1.date }
            
            for file in allFiles {
                if totalSize <= maxDiskCacheSize {
                    break
                }
                try? fileManager.removeItem(at: file.url)
                totalSize -= file.size
            }
        }
        
        if !filesToDelete.isEmpty {
            print("🗑️ 清理了 \(filesToDelete.count) 个过期视频缓存")
        }
    }
}
