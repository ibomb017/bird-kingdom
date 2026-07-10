//
//  PostShareService.swift
//  BirdKingdom
//
//  帖子分享服务 - 使用 LinkPresentation 框架实现类似小红书的分享预览卡片
//  支持微信/QQ/微博等社交平台的富媒体预览
//

import SwiftUI
import LinkPresentation
import UIKit

// MARK: - 帖子分享链接元数据提供者
class PostLinkMetadataProvider: NSObject, UIActivityItemSource {
    let post: ForumPost
    let url: URL
    let preloadedImage: UIImage?
    
    /// 预加载的链接元数据（从服务端获取 OG 标签）
    var cachedMetadata: LPLinkMetadata?
    
    init(post: ForumPost, image: UIImage? = nil) {
        self.post = post
        // 构建分享链接 URL（必须是 HTTPS 公网地址）
        self.url = URL(string: "https://birdkingdom.xyz/share/post/\(post.id)")!
        self.preloadedImage = image
        super.init()
    }
    
    /// 预加载链接元数据（建议在分享前调用）
    func preloadMetadata() async {
        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            await MainActor.run {
                self.cachedMetadata = metadata
            }
            print("📤 分享元数据预加载成功: \(metadata.title ?? "无标题")")
        } catch {
            print("📤 分享元数据预加载失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UIActivityItemSource
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        // 优先使用预加载的元数据
        if let cached = cachedMetadata {
            // 如果有预加载图片，覆盖元数据中的图片
            if let image = preloadedImage {
                cached.imageProvider = NSItemProvider(object: image)
            }
            return cached
        }
        
        // 回落到本地构建的元数据
        let metadata = LPLinkMetadata()
        
        // 设置标题
        metadata.title = generateTitle()
        
        // 设置原始 URL
        metadata.originalURL = url
        metadata.url = url
        
        // 设置图片
        if let image = preloadedImage {
            metadata.imageProvider = NSItemProvider(object: image)
        } else if let firstImageUrl = getFirstImageUrl(), let imageURL = URL(string: firstImageUrl) {
            metadata.imageProvider = NSItemProvider(contentsOf: imageURL)
        }
        
        // 设置图标（App 图标）
        if let appIcon = UIImage(named: "AppIcon") {
            metadata.iconProvider = NSItemProvider(object: appIcon)
        }
        
        return metadata
    }
    
    // MARK: - 辅助方法
    
    public func generateTitle() -> String {
        switch post.postType {
        case .findBird:
            let birdName = post.birdName ?? ""
            return "🔍 寻鸟启事" + (birdName.isEmpty ? "" : " - \(birdName)")
        default:
            // 取内容前20个字作为标题
            let content = post.content
            if content.count > 20 {
                return String(content.prefix(20)) + "..."
            }
            return content.isEmpty ? "来自鸟鸟王国的分享" : content
        }
    }
    
    private func getFirstImageUrl() -> String? {
        // 视频封面优先
        if post.mediaType == "VIDEO", let cover = post.videoCover {
            return cover
        }
        // 取第一张图片
        if let firstImage = post.images.first {
            return firstImage
        }
        // 鸟儿头像
        if let birdAvatar = post.birdAvatar {
            return birdAvatar
        }
        return nil
    }
}

// MARK: - 分享帖子视图（带 LinkPresentation 预览）
struct PostShareSheet: UIViewControllerRepresentable {
    let post: ForumPost
    let previewImage: UIImage?
    
    @State private var isPreloading = true
    
    init(post: ForumPost, previewImage: UIImage? = nil) {
        self.post = post
        self.previewImage = previewImage
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // 创建分享链接
        let shareURL = URL(string: "https://birdkingdom.xyz/share/post/\(post.id)")!

        // 创建带有链接预览的分享项
        let metadataProvider = PostLinkMetadataProvider(post: post, image: previewImage)
        let title = metadataProvider.generateTitle()
        // 创建 ActivityViewController
        let activityVC = UIActivityViewController(
            activityItems: [shareURL, metadataProvider],
            applicationActivities: nil
        )
        
        // 排除一些不适合的分享方式
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .markupAsPDF
        ]
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 分享服务单例
class PostShareService {
    static let shared = PostShareService()
    private init() {}
    
    /// 元数据缓存
    private var metadataCache: [Int64: LPLinkMetadata] = [:]
    
    /// 预加载帖子的分享元数据（建议在帖子详情页 onAppear 时调用）
    func preloadMetadata(for post: ForumPost) {
        let url = URL(string: "https://birdkingdom.xyz/share/post/\(post.id)")!
        
        // 如果已缓存，跳过
        if metadataCache[post.id] != nil {
            return
        }
        
        Task {
            let provider = LPMetadataProvider()
            do {
                let metadata = try await provider.startFetchingMetadata(for: url)
                await MainActor.run {
                    self.metadataCache[post.id] = metadata
                }
                print("📤 帖子 \(post.id) 分享元数据预加载成功")
            } catch {
                print("📤 帖子 \(post.id) 分享元数据预加载失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 分享帖子（所有类型）
    func sharePost(_ post: ForumPost, from view: UIView? = nil) {
        let shareURL = URL(string: "https://birdkingdom.xyz/share/post/\(post.id)")!
        let metadataProvider = PostLinkMetadataProvider(post: post)
        
        // 如果有缓存的元数据，使用缓存
        if let cached = metadataCache[post.id] {
            metadataProvider.cachedMetadata = cached
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [metadataProvider, shareURL],
            applicationActivities: nil
        )
        
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .markupAsPDF
        ]
        
        // 在 iPad 上需要设置 popover 位置
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view ?? UIApplication.shared.windows.first?.rootViewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        presentViewController(activityVC)
    }
    
    /// 分享帖子（带预加载图片）
    func sharePostWithImage(_ post: ForumPost, image: UIImage?, from view: UIView? = nil) {
        let shareURL = URL(string: "https://birdkingdom.xyz/share/post/\(post.id)")!
        let metadataProvider = PostLinkMetadataProvider(post: post, image: image)
        
        let activityVC = UIActivityViewController(
            activityItems: [metadataProvider, shareURL],
            applicationActivities: nil
        )
        
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .markupAsPDF
        ]
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view ?? UIApplication.shared.windows.first?.rootViewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        presentViewController(activityVC)
    }
    
    /// 展示 ViewController
    private func presentViewController(_ vc: UIViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }
            topVC.present(vc, animated: true)
        }
    }
    
    /// 清除元数据缓存
    func clearCache() {
        metadataCache.removeAll()
    }
}



// MARK: - SwiftUI View Extension
extension View {
    /// 显示帖子分享弹窗
    func postShareSheet(isPresented: Binding<Bool>, post: ForumPost, previewImage: UIImage? = nil) -> some View {
        self.sheet(isPresented: isPresented) {
            PostShareSheet(post: post, previewImage: previewImage)
                .presentationDetents([.medium])
        }
    }
}
