import Foundation
import SwiftUI
import Combine

// MARK: - 后台发布服务
// 像小红书/抖音那样，用户可以退出发布页面，在后台完成上传

@MainActor
class BackgroundPostService: ObservableObject {
    static let shared = BackgroundPostService()
    
    // 发布状态
    enum PostStatus {
        case idle
        case uploading(progress: Double)
        case success
        case failed(error: String)
    }
    
    // 当前发布状态
    @Published var status: PostStatus = .idle
    @Published var progress: Double = 0.0
    @Published var isPublishing: Bool = false
    @Published var currentTask: String = "" // 当前任务描述
    
    // 发布成功后的帖子
    @Published var lastPublishedPost: ForumPost? = nil
    
    private init() {}
    
    // MARK: - 后台发布帖子
    func publishPost(
        content: String,
        images: [UIImage],
        videoData: Data? = nil,
        videoThumbnail: UIImage? = nil,
        customCover: UIImage? = nil,
        mediaType: String = "IMAGE",
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        birdIds: [Int64]? = nil
    ) {
        // 如果已经在发布中，不重复发布
        guard !isPublishing else {
            print("⚠️ 已有发布任务在进行中")
            return
        }
        
        isPublishing = true
        progress = 0.0
        status = .uploading(progress: 0)
        currentTask = "准备发布..."
        
        Task {
            do {
                var imageUrls: [String] = []
                var videoUrlString: String? = nil
                var videoCoverString: String? = nil
                
                if mediaType == "VIDEO" {
                    // 视频模式
                    if let videoData = videoData {
                        currentTask = "正在上传视频..."
                        progress = 0.1
                        status = .uploading(progress: 0.1)
                        
                        // 创建临时文件
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("upload_video_\(UUID().uuidString).mp4")
                        try videoData.write(to: tempURL)
                        
                        videoUrlString = try await ApiService.shared.uploadPostVideo(videoURL: tempURL)
                        
                        // 清理临时文件
                        try? FileManager.default.removeItem(at: tempURL)
                        
                        progress = 0.6
                        status = .uploading(progress: 0.6)
                        
                        // 上传封面
                        if let cover = customCover ?? videoThumbnail {
                            currentTask = "正在上传封面..."
                            videoCoverString = try await ApiService.shared.uploadPostImage(image: cover)
                        }
                        
                        progress = 0.8
                        status = .uploading(progress: 0.8)
                    }
                } else {
                    // 图片模式：并行上传
                    if !images.isEmpty {
                        currentTask = "正在上传图片 (0/\(images.count))..."
                        progress = 0.1
                        status = .uploading(progress: 0.1)
                        
                        var uploadedCount = 0
                        let totalImages = images.count
                        
                        imageUrls = try await withThrowingTaskGroup(of: (Int, String).self) { group in
                            for (index, image) in images.enumerated() {
                                group.addTask {
                                    let url = try await ApiService.shared.uploadPostImage(image: image)
                                    return (index, url)
                                }
                            }
                            
                            var results: [(Int, String)] = []
                            for try await result in group {
                                results.append(result)
                                uploadedCount += 1
                                await MainActor.run {
                                    self.currentTask = "正在上传图片 (\(uploadedCount)/\(totalImages))..."
                                    self.progress = 0.1 + (Double(uploadedCount) / Double(totalImages)) * 0.6
                                    self.status = .uploading(progress: self.progress)
                                }
                            }
                            
                            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
                        }
                        
                        progress = 0.8
                        status = .uploading(progress: 0.8)
                    }
                }
                
                // 创建帖子
                currentTask = "正在发布..."
                progress = 0.9
                status = .uploading(progress: 0.9)
                
                let postDTO = try await ApiService.shared.createPost(
                    content: content,
                    postType: "NORMAL",
                    images: imageUrls,
                    mediaType: mediaType,
                    videoUrl: videoUrlString,
                    videoCover: videoCoverString,
                    videoDuration: nil,
                    latitude: latitude,
                    longitude: longitude,
                    locationName: locationName,
                    birdIds: birdIds
                )
                
                let newPost = ForumPost.from(dto: postDTO)
                
                // 更新我的帖子列表
                SocialService.shared.insertNewPost(postDTO)
                
                // 发送通知刷新帖子列表
                NotificationCenter.default.post(name: NSNotification.Name("PostPublished"), object: newPost)
                
                progress = 1.0
                status = .success
                currentTask = "发布成功！"
                lastPublishedPost = newPost
                isPublishing = false
                
                print("✅ 后台发布成功，帖子ID: \(postDTO.id)")
                
                // 3秒后重置状态
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.status = .idle
                    self.currentTask = ""
                    self.progress = 0
                }
                
            } catch {
                print("❌ 后台发布失败: \(error)")
                status = .failed(error: error.localizedDescription)
                currentTask = "发布失败"
                isPublishing = false
                
                // 5秒后重置状态
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run {
                    self.status = .idle
                    self.currentTask = ""
                    self.progress = 0
                }
            }
        }
    }
    
    // MARK: - 重置状态
    func reset() {
        status = .idle
        progress = 0.0
        isPublishing = false
        currentTask = ""
        lastPublishedPost = nil
    }
}

// MARK: - 发布进度条视图（显示在顶部）
struct PublishProgressBar: View {
    @ObservedObject var service = BackgroundPostService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        Group {
            switch service.status {
            case .uploading(let progress):
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                    
                    Text(service.currentTask)
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            themeManager.primaryColor.opacity(0.8)
                            themeManager.primaryColor
                                .frame(width: geo.size.width * progress)
                        }
                    }
                )
                .cornerRadius(0)
                .transition(.move(edge: .top).combined(with: .opacity))
                
            case .success:
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    
                    Text("发布成功！")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green)
                .transition(.move(edge: .top).combined(with: .opacity))
                
            case .failed(let error):
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                    
                    Text("发布失败: \(error)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button("重试") {
                        // 可以在这里添加重试逻辑
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red)
                .transition(.move(edge: .top).combined(with: .opacity))
                
            case .idle:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: service.isPublishing)
    }
}
