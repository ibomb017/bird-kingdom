import Foundation
import UIKit
import os.log

private let logger = Logger(subsystem: "com.birdkingdom", category: "LogImageStorage")

/// 日志图片本地存储服务
/// 负责将日志图片持久化到 Documents 目录，支持离线创建带图日志
class LogImageStorage {
    static let shared = LogImageStorage()
    
    private init() {
        createImagesDirectoryIfNeeded()
    }
    
    // MARK: - 目录管理
    
    /// P0 修复：图片存储根目录按用户隔离: Documents/users/{userId}/logs/images/
    /// 确保多用户切换时不会看到其他用户的图片
    private var imagesDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let userId = AuthService.shared.currentUserId ?? "anonymous"
        return documentsPath.appendingPathComponent("users/\(userId)/logs/images", isDirectory: true)
    }
    
    /// 获取指定日志的图片目录
    private func imageDirectory(for logLocalId: String) -> URL {
        return imagesDirectory.appendingPathComponent(logLocalId, isDirectory: true)
    }
    
    /// 创建图片存储目录
    private func createImagesDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            logger.info("📁 日志图片目录已创建: \(self.imagesDirectory.path)")
        } catch {
            logger.error("创建图片目录失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 保存图片
    
    /// 保存多张图片到本地
    /// - Parameters:
    ///   - images: 要保存的图片数组
    ///   - logLocalId: 日志本地 ID
    /// - Returns: 保存后的本地路径数组（相对于 Documents 目录）
    func saveImages(_ images: [UIImage], for logLocalId: String) -> [String] {
        guard !images.isEmpty else { return [] }
        
        let logDirectory = imageDirectory(for: logLocalId)
        let userId = AuthService.shared.currentUserId ?? "anonymous"
        
        // 创建日志专属目录
        do {
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("创建日志图片目录失败: \(error.localizedDescription)")
            return []
        }
        
        var savedPaths: [String] = []
        
        for (index, image) in images.enumerated() {
            let fileName = "\(index)_\(UUID().uuidString).jpg"
            let fileURL = logDirectory.appendingPathComponent(fileName)
            
            // 压缩图片并保存
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                logger.warning("⚠️ 图片 \(index) 压缩失败")
                continue
            }
            
            do {
                try imageData.write(to: fileURL)
                // 重举修复 #1: 存储相对路径必须包含 userId，与 imagesDirectory 一致
                let relativePath = "users/\(userId)/logs/images/\(logLocalId)/\(fileName)"
                savedPaths.append(relativePath)
                logger.info("💾 图片已保存: \(relativePath)")
            } catch {
                logger.error("保存图片失败: \(error.localizedDescription)")
            }
        }
        
        return savedPaths
    }
    
    /// P0 新增：保存鸟儿头像到本地
    /// - Parameters:
    ///   - image: 头像图片
    ///   - birdId: 鸟儿本地 ID
    /// - Returns: 保存后的相对路径
    func saveImage(_ image: UIImage, birdId: String) -> String? {
        // 重用 saveImages 逻辑，但使用 birdId 作为目录名的前缀或独立目录
        // 为了区分，这里使用 "avatars/{birdId}"
        let userId = AuthService.shared.currentUserId ?? "anonymous"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let avatarDirectory = documentsPath.appendingPathComponent("users/\(userId)/avatars/\(birdId)", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: avatarDirectory, withIntermediateDirectories: true)
            
            let fileName = "avatar_\(UUID().uuidString).jpg"
            let fileURL = avatarDirectory.appendingPathComponent(fileName)
            
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                try imageData.write(to: fileURL)
                let relativePath = "users/\(userId)/avatars/\(birdId)/\(fileName)"
                logger.info("💾 头像已保存: \(relativePath)")
                return relativePath
            }
        } catch {
            logger.error("保存头像失败: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - 加载图片
    
    /// 从本地路径加载图片
    /// - Parameter relativePath: 相对于 Documents 目录的路径
    /// - Returns: 加载的图片，如果加载失败返回 nil
    func loadImage(at relativePath: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(relativePath)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.warning("⚠️ 图片文件不存在: \(relativePath)")
            return nil
        }
        
        guard let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            logger.error("加载图片失败: \(relativePath)")
            return nil
        }
        
        return image
    }
    
    /// 加载日志的所有本地图片
    /// - Parameter localImagePaths: 本地图片路径数组
    /// - Returns: 加载的图片数组（失败的会被跳过）
    func loadImages(from localImagePaths: [String]) -> [UIImage] {
        return localImagePaths.compactMap { loadImage(at: $0) }
    }
    
    /// 获取图片的完整文件 URL
    /// - Parameter relativePath: 相对路径
    /// - Returns: 完整的文件 URL
    func fileURL(for relativePath: String) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(relativePath)
    }
    
    // MARK: - 删除图片
    
    /// 删除日志对应的所有图片
    /// - Parameter logLocalId: 日志本地 ID
    func deleteImages(for logLocalId: String) {
        let logDirectory = imageDirectory(for: logLocalId)
        
        do {
            if FileManager.default.fileExists(atPath: logDirectory.path) {
                try FileManager.default.removeItem(at: logDirectory)
                logger.info("🗑️ 已删除日志图片目录: \(logLocalId)")
            }
        } catch {
            logger.error("删除图片目录失败: \(error.localizedDescription)")
        }
    }
    
    /// 删除单张图片
    /// - Parameter relativePath: 相对路径
    func deleteImage(at relativePath: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(relativePath)
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                logger.info("🗑️ 已删除图片: \(relativePath)")
            }
        } catch {
            logger.error("删除图片失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 清理
    
    /// 清理所有日志图片（仅用于调试或账号注销）
    func clearAllImages() {
        do {
            if FileManager.default.fileExists(atPath: imagesDirectory.path) {
                try FileManager.default.removeItem(at: imagesDirectory)
                createImagesDirectoryIfNeeded()
                logger.info("🗑️ 已清理所有日志图片")
            }
        } catch {
            logger.error("清理图片目录失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取本地图片存储大小（字节）
    func calculateStorageSize() -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = FileManager.default.enumerator(at: imagesDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
    
    /// 格式化存储大小
    func formattedStorageSize() -> String {
        let bytes = calculateStorageSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
