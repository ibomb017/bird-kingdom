//
//  UniversalLinkHandler.swift
//  BirdKingdom
//
//  Universal Links 处理器
//  负责解析分享链接并导航到对应的 App 页面
//

import Foundation
import SwiftUI
import Combine

/// Universal Links 处理器单例
class UniversalLinkHandler: ObservableObject {
    static let shared = UniversalLinkHandler()
    
    /// 待打开的帖子 ID（用于延迟导航）
    @Published var pendingPostId: Int64?
    
    /// 是否应该显示帖子详情
    @Published var shouldShowPost: Bool = false
    
    private init() {}
    
    // MARK: - 链接解析
    
    /// 处理 Universal Link
    /// - Parameter url: 传入的 URL
    /// - Returns: 是否成功处理
    @discardableResult
    func handleUniversalLink(_ url: URL) -> Bool {
        print("🔗 收到 Universal Link: \(url.absoluteString)")
        
        // 解析 URL 路径
        let pathComponents = url.pathComponents
        
        // 路径格式: /share/post/{postId}
        if pathComponents.count >= 4,
           pathComponents[1] == "share",
           pathComponents[2] == "post",
           let postIdString = pathComponents.last,
           let postId = Int64(postIdString) {
            
            print("🔗 解析到帖子 ID: \(postId)")
            
            // 通知 App 导航到帖子详情
            DispatchQueue.main.async {
                self.pendingPostId = postId
                self.shouldShowPost = true
                
                // 发送通知，让 ForumView 处理导航
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenPostFromUniversalLink"),
                    object: nil,
                    userInfo: ["postId": postId]
                )
            }
            
            return true
        }
        
        print("🔗 无法解析的链接格式")
        return false
    }
    
    /// 清除待处理的链接
    func clearPendingLink() {
        pendingPostId = nil
        shouldShowPost = false
    }
    
    // MARK: - URL 验证
    
    /// 检查 URL 是否是有效的分享链接
    func isShareUrl(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host == "birdkingdom.xyz" || host == "www.birdkingdom.xyz"
    }
}

// MARK: - SwiftUI Scene Phase 支持
extension UniversalLinkHandler {
    
    /// 处理从 Scene 传入的 URL
    func handleSceneURL(_ url: URL) {
        guard isShareUrl(url) else { return }
        handleUniversalLink(url)
    }
}
