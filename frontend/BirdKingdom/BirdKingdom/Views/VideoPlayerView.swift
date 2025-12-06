import SwiftUI
import AVKit

// 全屏视频播放器 - 类似小红书
struct VideoPlayerView: View {
    let initialPost: ForumPost
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    
    @State private var currentIndex = 0
    @State private var videoPosts: [ForumPost] = []
    @State private var isLoading = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !videoPosts.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(videoPosts.enumerated()), id: \.element.id) { index, post in
                        VideoPlayerCard(post: post)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
                .ignoresSafeArea()
            }
            
            // 关闭按钮
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            loadVideoPosts()
        }
        .onChange(of: currentIndex) { newIndex in
            // 快到底部时加载更多
            if newIndex >= videoPosts.count - 2 {
                loadMoreVideos()
            }
        }
    }
    
    private func loadVideoPosts() {
        // 初始化视频列表，将当前视频放在第一位
        videoPosts = [initialPost]
        
        // 加载更多视频
        loadMoreVideos()
    }
    
    private func loadMoreVideos() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                // 获取随机视频帖子
                let postsPage = try await ApiService.shared.getPosts(page: 0, size: 50)
                let allPosts = postsPage.content.map { ForumPost.from(dto: $0) }
                let newVideoPosts = allPosts
                    .filter { $0.mediaType == "VIDEO" && !videoPosts.contains(where: { $0.id == $0.id }) }
                    .shuffled()
                    .prefix(5)
                
                await MainActor.run {
                    videoPosts.append(contentsOf: newVideoPosts)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// 单个视频卡片
struct VideoPlayerCard: View {
    let post: ForumPost
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = true
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        ZStack {
            // 视频播放器
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        togglePlayPause()
                    }
            } else {
                // 加载中
                ProgressView()
                    .tint(.white)
            }
            
            // 右侧操作栏
            VStack {
                Spacer()
                
                HStack {
                    // 左侧信息
                    VStack(alignment: .leading, spacing: 12) {
                        // 作者信息
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(post.authorName.prefix(1))
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                )
                            
                            Text(post.authorName)
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        
                        // 内容
                        Text(post.content)
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .font(.subheadline)
                    }
                    .padding(.leading)
                    
                    // 右侧按钮
                    VStack(spacing: 24) {
                        // 点赞
                        VStack(spacing: 4) {
                            Button {
                                // TODO: 点赞
                            } label: {
                                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(post.isLiked ? .red : .white)
                            }
                            Text("\(post.likeCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        // 评论
                        VStack(spacing: 4) {
                            Button {
                                // TODO: 评论
                            } label: {
                                Image(systemName: "bubble.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            Text("\(post.commentCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        // 收藏
                        VStack(spacing: 4) {
                            Button {
                                // TODO: 收藏
                            } label: {
                                Image(systemName: post.isFavorited ? "bookmark.fill" : "bookmark")
                                    .font(.title2)
                                    .foregroundColor(post.isFavorited ? forestGreen : .white)
                            }
                            Text("\(post.favoriteCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        // 分享
                        Button {
                            // TODO: 分享
                        } label: {
                            Image(systemName: "arrowshape.turn.up.right")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing)
                }
                .padding(.bottom, 40)
            }
            
            // 播放/暂停图标
            if showControls && !isPlaying {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func setupPlayer() {
        guard let videoURL = URL(string: post.videoUrl ?? "") else { return }
        
        let player = AVPlayer(url: videoURL)
        self.player = player
        
        // 自动播放
        player.play()
        isPlaying = true
        
        // 循环播放
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        // 3秒后隐藏控制按钮
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showControls = false
        }
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        showControls = true
        
        // 3秒后隐藏控制按钮
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if isPlaying {
                showControls = false
            }
        }
    }
}

#Preview {
    VideoPlayerView(initialPost: ForumPost.samplePosts[0])
}
