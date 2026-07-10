//
//  MyMessagesView.swift
//  BirdKingdom
//
//  我的消息页面
//

import SwiftUI

struct MyMessagesView: View {
    @ObservedObject var messageService = MessageNotificationService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedNotification: MessageNotificationItem?
    @State private var showPostDetail = false
    @State private var selectedPostId: Int64?
    
    // 消息通知开关（存储在 UserDefaults）
    @AppStorage("enableMessageNotifications") private var enableNotifications = true
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        Group {
            if messageService.notifications.isEmpty && !messageService.isLoading {
                emptyView
            } else {
                notificationsList
            }
        }
        .themedBackground()
        .themedNavigationBar(title: L10n.myMessages)
        .toolbar {
            // 左侧：通知开关
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    enableNotifications.toggle()
                } label: {
                    Image(systemName: enableNotifications ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(enableNotifications ? primaryColor : .gray)
                }
                .help(enableNotifications ? NSLocalizedString("点击关闭消息通知", comment: "") : NSLocalizedString("点击开启消息通知", comment: ""))
            }
            
            // 右侧：全部已读
            ToolbarItem(placement: .navigationBarTrailing) {
                if messageService.unreadCount > 0 {
                    Button(NSLocalizedString("全部已读", comment: "")) {
                        Task {
                            try? await messageService.markAllAsRead()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(primaryColor)
                }
            }
        }
        .task {
            try? await messageService.fetchNotifications(refresh: true)
        }
        .refreshable {
            try? await messageService.fetchNotifications(refresh: true)
        }
        .navigationDestination(isPresented: $showPostDetail) {
            if let postId = selectedPostId {
                PostDetailViewWrapper(postId: postId)
                    .hidesTabBar()
            }
        }
        .onChange(of: enableNotifications) { newValue in
            // 通知状态变化时触发触觉反馈
            let generator = UIImpactFeedbackGenerator(style: newValue ? .medium : .light)
            generator.impactOccurred()
        }
    }
    
    // MARK: - 空状态
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(NSLocalizedString("暂无消息", comment: ""))
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("当有人点赞、收藏或评论你的帖子时\n会在这里收到通知", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 通知列表
    
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(messageService.notifications) { notification in
                    VStack(spacing: 0) {
                        NotificationRowView(
                            notification: notification,
                            primaryColor: primaryColor
                        ) {
                            // 触觉反馈
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            // 点击通知
                            Task {
                                await messageService.markAsRead(notification.id)
                            }
                            
                            // 如果有帖子ID，跳转到帖子详情
                            if let postId = notification.postId {
                                selectedPostId = postId
                                showPostDetail = true
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            // 未读消息：淡色主题背景；已读消息：白色背景
                            notification.isRead 
                                ? Color(.systemBackground) 
                                : primaryColor.opacity(0.08)
                        )
                        .animation(.easeInOut(duration: 0.3), value: notification.isRead)
                        
                        // 分割线
                        Divider()
                            .padding(.leading, 72)
                    }
                }
                
                // 加载更多
                if messageService.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - 通知行视图

struct NotificationRowView: View {
    let notification: MessageNotificationItem
    let primaryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 发送者头像 + 未读红点
                ZStack(alignment: .topTrailing) {
                    avatarView
                    
                    // 未读红点
                    if !notification.isRead {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                
                // 通知内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.senderNickname ?? NSLocalizedString("用户", comment: ""))
                            .font(.subheadline)
                            .fontWeight(notification.isRead ? .regular : .semibold)
                            .foregroundColor(.primary)
                        
                        Text(notification.typeDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 评论内容（如果有）
                    if let content = notification.content, !content.isEmpty,
                       (notification.type == "POST_COMMENT" || notification.type == "COMMENT_REPLY") {
                        Text(content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // 时间
                    Text(notification.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 帖子缩略图
                if let postImage = notification.postImage,
                   let url = URL(string: postImage) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                }
                
                // 通知类型图标
                Image(systemName: notification.icon)
                    .font(.caption)
                    .foregroundColor(notification.iconColor)
                    .opacity(notification.isRead ? 0.6 : 1.0)
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let avatarUrl = notification.senderAvatar,
           let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(primaryColor.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(primaryColor.opacity(0.5))
                    )
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(primaryColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundColor(primaryColor.opacity(0.5))
                )
        }
    }
}

// MARK: - 帖子详情包装器

struct PostDetailViewWrapper: View {
    let postId: Int64
    @State private var post: ForumPost?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if let post = post {
                PostDetailView(post: post, primaryColor: ThemeManager.shared.primaryColor)
            } else if isLoading {
                ProgressView(L10n.loading)
            } else if let error = errorMessage {
                VStack {
                    Text(error)
                        .foregroundColor(.secondary)
                    Button(L10n.retry) {
                        loadPost()
                    }
                }
            }
        }
        .task {
            loadPost()
        }
    }
    
    private func loadPost() {
        isLoading = true
        Task {
            do {
                let postDTO = try await ApiService.shared.getPost(postId: postId)
                await MainActor.run {
                    self.post = ForumPost.from(dto: postDTO)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = NSLocalizedString("帖子可能已被删除", comment: "")
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MyMessagesView()
    }
}
