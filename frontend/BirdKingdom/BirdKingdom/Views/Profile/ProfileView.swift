//
//  ProfileView.swift
//  BirdKingdom
//
//  我的页面及相关视图
//

import SwiftUI
import PhotosUI

// MARK: - 我的页面
struct ProfileView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var trashService = TrashService.shared
    @ObservedObject var socialService = SocialService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var expenseService = ExpenseService.shared
    @ObservedObject var messageNotificationService = MessageNotificationService.shared  // 消息通知服务
    @ObservedObject var splashService = SplashService.shared  // 开屏服务
    @State private var showLogin = false
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var showAbout = false
    @State private var showThemeSelection = false
    @State private var showVip = false
    @State private var showCoupleBinding = false
    @State private var showContactAuthor = false
    @State private var showLegal = false
    // @State private var showAvatarPicker = false // 已移除
    @State private var showTrash = false
    @State private var showExpenseList = false
    @State private var showSplashPurchase = false
    @State private var showMyFavorites = false
    @State private var showMessages = false
    
    // 头像选择相关状态
    @State private var showAvatarSelection = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var tempImage: UIImage?  // 用于相机临时存储
    @State private var imageToCrop: IdentifiableImage?  // 控制裁剪器弹出
    @State private var selectedAvatar: UIImage? // 用于Cropper返回结果，并触发上传逻辑
    @State private var isUploadingAvatar = false
    @State private var errorMessage = ""
    @State private var showError = false

    @State private var showInvitations = false
    @State private var showFollowing = false
    @State private var showFollowers = false
    @State private var showMyPosts = false
    @State private var showDeleteAccount = false
    @State private var showClearCacheAlert = false
    @State private var showMyMessages = false  // 我的消息
    @State private var showSplashOrders = false  // 开屏历史订单
    @State private var showPrivacyCenter = false // 隐私中心页面
    @State private var showLanguageSelector = false // 语言选择页面
    
    // 实时统计数据
    @State private var birdCount: Int = 0
    @State private var logCount: Int = 0
    @State private var pendingInvitationCount: Int = 0  // 待处理邀请数量（持久红点）
    
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)

    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if authService.isLoggedIn, let user = authService.currentUser {
                    // 已登录状态
                    loggedInContent(user: user)
                } else {
                    // 未登录状态
                    notLoggedInContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(themeManager.pageBackgroundGradient)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountConfirmView(onDeleted: {
                // 账号删除成功后退出登录
                authService.logout()
            })
        }
        .navigationDestination(isPresented: $showEditProfile) {
            if let user = authService.currentUser {
                EditProfileView(user: user)
                    .onAppear { TabBarVisibilityManager.shared.hide() }
                    .onDisappear { TabBarVisibilityManager.shared.show() }
            }
        }
        .navigationDestination(isPresented: $showInvitations) {
            PendingInvitationsView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { 
                    TabBarVisibilityManager.shared.show()
                    Task { await loadPendingInvitationCount() }
                }
        }
        .navigationDestination(isPresented: $showVip) {
            VipView()
        }
        .confirmationDialog(NSLocalizedString("修改头像", comment: ""), isPresented: $showAvatarSelection, titleVisibility: .visible) {
            Button(NSLocalizedString("从相册选择", comment: "")) {
                showPhotoPicker = true
            }
            Button(NSLocalizedString("拍摄照片", comment: "")) {
                showCamera = true
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }
            
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage.downsample(from: data, toMaxDimension: 1500) {
                        // 延迟设置 imageToCrop，等待 photosPicker 完全关闭
                        await MainActor.run {
                            // 重置 selectedItem 以便下次可以选择同一张图片
                            self.selectedItem = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.imageToCrop = IdentifiableImage(image: image)
                            }
                        }
                    } else {
                        throw NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("无法加载图片数据", comment: "")])
                    }
                } catch {
                    print("❌ 图片加载失败: \(error)")
                    await MainActor.run {
                        self.selectedItem = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.errorMessage = NSLocalizedString("图片加载失败。如果是iCloud照片，请确保网络连接正常后重试。", comment: "")
                            self.showError = true
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(image: $tempImage)
                .ignoresSafeArea()
        }
        // 监听 Camera 关闭
        .onChange(of: showCamera) { _, isOpen in
            if !isOpen, let image = tempImage {
                // 延迟设置 imageToCrop，等待 camera fullScreenCover 完全关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.imageToCrop = IdentifiableImage(image: image)
                    self.tempImage = nil
                }
            }
        }
        // 使用 item 版本的 fullScreenCover
        .fullScreenCover(item: $imageToCrop) { wrapper in
            ImageCropperView(croppedImage: $selectedAvatar, originalImage: wrapper.image)
        }
        // 监听 selectedAvatar 变化（裁剪完成后触发上传）
        .onChange(of: selectedAvatar) { _, newImage in
            if let image = newImage {
                uploadAvatar(image)
            }
        }
        .navigationDestination(isPresented: $showTrash) {
            TrashView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showFollowing) {
            FollowListView(title: L10n.myFollowing, users: socialService.followingUsers, isFollowingList: true)
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showFollowers) {
            FollowListView(title: L10n.myFollowers, users: socialService.followerUsers, isFollowingList: false)
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showExpenseList) {
            ExpenseListView()
        }
        .navigationDestination(isPresented: $showMyPosts) {
            MyPostsView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showMyFavorites) {
            MyFavoritesView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showSplashPurchase) {
            SplashPurchaseView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showThemeSelection) {
            ThemeSelectionView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showHelp) {
            HelpView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showAbout) {
            AboutView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showContactAuthor) {
            ContactAuthorView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showMyMessages) {
            MyMessagesView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .alert(L10n.clearCache, isPresented: $showClearCacheAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(NSLocalizedString("清除", comment: ""), role: .destructive) {
                CacheManager.shared.clearAllCache()
                // P0 修复：清除缓存后刷新首页数据，确保数据一致性
                NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
            }
        } message: {
            let details = CacheManager.shared.getCacheSizeDetails()
            Text("当前缓存:\n图片: \(details.images)\n视频: \(details.videos)\n帖子: \(details.posts)\n\n⚠️ 将清除所有本地数据（包括未同步的离线日志），请确保网络正常后再操作")
        }
        // #14 修复：使用 .task 替代 onAppear + Task，实现自动取消机制
        // #13 修复：.task(id:) 可防止重复请求（如需要可添加 id 参数）
        .task {
            await loadStatsAsync()
            // 监听VIP页面打开通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowVIPPage"),
                object: nil,
                queue: .main
            ) { _ in
                showVip = true
            }
        }
        // #17 修复：监听 App 进入前台时刷新 VIP 状态，实现即时降级
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await refreshVipStatus()
            }
        }
        .sheet(isPresented: $showPrivacyCenter) {
            PrivacyPolicyView()
        }
        .alert(L10n.hintTitle, isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // #14 修复：使用 async 版本的加载方法，配合 .task 自动取消
    private func loadStatsAsync() async {
        do {
            let birds = try await ApiService.shared.getBirds()
            let logs = try await ApiService.shared.getLogs()
            birdCount = birds.count
            logCount = logs.count
            
            // 加载关注统计和列表
            if let userId = authService.currentUser?.id {
                await socialService.loadFollowStats(userId: Int64(userId))
                await socialService.loadFollowingUsers(userId: Int64(userId))
                await socialService.loadFollowerUsers(userId: Int64(userId))
                await socialService.loadMyPosts()
                await socialService.loadMyFavorites()
            }
            
            // 加载支出统计
            await expenseService.fetchStats()
            
            // 加载待处理邀请数量（持久红点）
            await loadPendingInvitationCount()
            
            // 加载未读消息数量
            await messageNotificationService.fetchUnreadCount()
        } catch {
            print("加载统计数据失败: \(error)")
        }
    }
    
    // #17 修复：刷新 VIP 状态，用于 App 进入前台时即时降级
    private func refreshVipStatus() async {
        do {
            try await authService.fetchCurrentUser()
        } catch {
            print("刷新VIP状态失败: \(error)")
        }
    }
    
    // 加载待处理邀请数量
    private func loadPendingInvitationCount() async {
        do {
            let invitations = try await ApiService.shared.getPendingInvitations()
            pendingInvitationCount = invitations.count
        } catch {
            print("加载待处理邀请失败: \(error)")
        }
    }
    
    // 上传头像
    private func uploadAvatar(_ image: UIImage) {
        guard !isUploadingAvatar else { return }
        isUploadingAvatar = true
        
        Task {
            do {
                // 1. 上传图片到 OSS / 本地存储
                let avatarUrl = try await ApiService.shared.uploadUserAvatar(image: image)
                print("✅ 头像上传成功: \(avatarUrl)")
                
                // 2. 更新用户 Profile，将新的 avatarUrl 保存到数据库
                try await authService.updateProfile(nickname: nil, bio: nil, avatarUrl: avatarUrl)
                print("✅ 用户 Profile 更新成功")
                
                // 3. 刷新用户信息
                try await authService.fetchCurrentUser()
                
                await MainActor.run {
                    isUploadingAvatar = false
                    // 清除所有临时状态，释放内存
                    selectedAvatar = nil
                    tempImage = nil
                    selectedItem = nil
                    imageToCrop = nil
                }
            } catch {
                print("❌ 头像上传/更新失败: \(error)")
                await MainActor.run {
                    isUploadingAvatar = false
                    errorMessage = "头像上传失败: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // MARK: - 已登录内容
    private func loggedInContent(user: User) -> some View {
        VStack(spacing: 16) {
            // 用户信息卡片
            userInfoCard(user: user)
            
            
            // 统计数据
            statsSection(user: user)
            
            // 功能菜单
            menuSection
            
            // 系统设置入口
            settingsSection
        }
    }
    

    
    // 用户信息卡片
    private func userInfoCard(user: User) -> some View {
        HStack(spacing: 16) {
            // 头像（点击可修改）
            Button {
                showAvatarSelection = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    // 头像主体
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(themeManager.primaryColor.opacity(0.15))
                            .frame(width: 70, height: 70)
                            .overlay(
                                avatarContent(for: user)
                            )

                        
                        // 相机图标
                        ZStack {
                            Circle()
                                .fill(themeManager.primaryColor)
                                .frame(width: 24, height: 24)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                        }
                        .offset(x: 2, y: 2)
                    }
                    

                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(user.nickname)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(user.maskedPhone)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button {
                showEditProfile = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.primaryColor.opacity(0.6))
            }
        }
        .padding(20)
        .background(Color.adaptiveCard)
        .cornerRadius(16)
        .shadow(color: themeManager.primaryColor.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    // 头像内容
    @ViewBuilder
    private func avatarContent(for user: User) -> some View {
        if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
            if avatarUrl.hasPrefix("preset:") {
                // 预设头像
                let iconName = String(avatarUrl.dropFirst(7))
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(themeManager.primaryColor)
            } else if avatarUrl.hasPrefix("http") {
                // 网络头像
                AsyncImage(url: URL(string: AppConfig.applyCDN(to: avatarUrl))) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image("bird")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(themeManager.primaryColor.opacity(0.5))
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
            } else {
                // 其他情况显示默认
                Image("bird")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(themeManager.primaryColor.opacity(0.5))
            }
        } else {
            // 无头像时显示默认图标
            Image("bird")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundColor(themeManager.primaryColor.opacity(0.5))
        }
    }
    
    // 统计数据
    private func statsSection(user: User) -> some View {
        HStack(spacing: 12) {
            statTile(icon: "yensign.circle.fill", label: NSLocalizedString("支出", comment: ""), value: "¥\(ExpenseService.formatAmount(expenseService.totalExpense))", action: { 
                showExpenseList = true
            })
            statTile(icon: "person.2.fill", label: NSLocalizedString("关注", comment: ""), value: "\(socialService.followingCount)", action: { showFollowing = true })
            statTile(icon: "heart.fill", label: NSLocalizedString("粉丝", comment: ""), value: "\(socialService.followerCount)", action: { showFollowers = true })
        }
    }
    
    private func statTile(icon: String, label: String, value: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryColor)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.adaptiveCard)
            .cornerRadius(12)
            .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
    
    // 功能菜单
    private var menuSection: some View {
        VStack(spacing: 0) {
            // 我的消息 - 显示未读消息数量 (社交功能置顶)
            menuRow(
                icon: "bell.badge",
                title: L10n.myMessages,
                badge: messageNotificationService.unreadCount > 0 ? "\(messageNotificationService.unreadCount)" : nil,
                isRedDot: true  // 未读消息使用红点样式
            ) {
                showMyMessages = true
            }
            Divider().padding(.leading, 50)
            
            // 鸟鸟庆生开屏专属权益入口 (营收项目提前)
            menuRow(icon: "sparkles", title: NSLocalizedString("鸟鸟开屏庆生", comment: ""), badge: "¥\(SplashService.shared.currentPrice.formatted(.number.precision(.fractionLength(0))))") {
                showSplashPurchase = true
            }
            Divider().padding(.leading, 50)
            
            menuRow(icon: "doc.text", title: NSLocalizedString("我的帖子", comment: ""), badge: socialService.myPosts.isEmpty ? nil : "\(socialService.myPosts.count)") {
                showMyPosts = true
            }
            Divider().padding(.leading, 50)
            
            menuRow(icon: "bookmark", title: NSLocalizedString("我的收藏", comment: ""), badge: socialService.favoritePostIds.isEmpty ? nil : "\(socialService.favoritePostIds.count)") {
                showMyFavorites = true
            }
            Divider().padding(.leading, 50)
            
            // 共享邀请 - VIP功能（显示待处理邀请数量）
            menuRow(
                icon: "envelope.badge",
                title: L10n.shareInvitations,
                badge: pendingInvitationCount > 0 ? "\(pendingInvitationCount)" : nil,
                isRedDot: true
            ) {
                showInvitations = true
            }
            Divider().padding(.leading, 50)
            
            // 回收站
            menuRow(
                icon: "trash",
                title: L10n.recycleBin,
                badge: !trashService.deletedBirds.isEmpty ? "\(trashService.deletedBirds.count)" : nil,
                isRedDot: true
            ) {
                showTrash = true
            }
        }
        .background(Color.adaptiveCard)
        .cornerRadius(14)
        .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 6, x: 0, y: 2)
    }
    
    // 设置区域 (仅保留系统设置入口，所有设置项已移入二级页面 SettingsView)
    private var settingsSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "gearshape.fill", title: NSLocalizedString("设置", comment: ""), badge: nil) {
                showSettings = true
            }
        }
        .background(Color.adaptiveCard)
        .cornerRadius(14)
        .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 6, x: 0, y: 2)
    }
    
    private func menuRow(icon: String, title: String, badge: String?, isRedDot: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(themeManager.primaryColor)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                
                // 徽章
                if let badge = badge {
                    if isRedDot {
                        // 红点样式（用于共享邀请）
                        Text(badge)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    } else {
                        // 原先的灰色样式
                        Text(badge)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
    

    
    // MARK: - 未登录内容
    private var notLoggedInContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            
            // 图标
            Image("bird")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .opacity(0.4)
            
            Text(NSLocalizedString("登录鸟鸟王国", comment: ""))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(NSLocalizedString("登录后可以同步数据、共享鸟儿信息", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showLogin = true
            } label: {
                Text(NSLocalizedString("手机号登录 / 注册", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.primaryColor)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 关注/粉丝列表视图
struct FollowListView: View {
    let title: String
    let users: [UserProfile]
    let isFollowingList: Bool
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    @State private var selectedUser: UserProfile?
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        Group {
            if users.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: isFollowingList ? "person.2" : "heart")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(isFollowingList ? NSLocalizedString("还没有关注任何人", comment: "") : NSLocalizedString("还没有粉丝", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(users, id: \.id) { user in
                        Button {
                            selectedUser = user
                        } label: {
                            UserRowView(user: user, primaryColor: themeManager.primaryColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .themedBackground()
        .themedNavigationBar(title: title)
        .navigationDestination(item: $selectedUser) { user in
            UserProfileView(user: user)
                .hidesTabBar()
        }
    }
}

// MARK: - 用户行视图
struct UserRowView: View {
    let user: UserProfile
    let primaryColor: Color
    @ObservedObject var socialService = SocialService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            UserAvatarView(avatarUrl: user.avatar, size: 50)
            
            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                Text(user.nickname)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    Label(String(format: NSLocalizedString("%d只鸟", comment: ""), user.birdCount), systemImage: "leaf.fill")
                    Label(String(format: NSLocalizedString("%d帖子", comment: ""), user.postCount), systemImage: "doc.text")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 关注按钮
            Button {
                withAnimation(.spring(response: 0.3)) {
                    socialService.toggleFollow(userId: user.id)
                }
            } label: {
                Text(socialService.isFollowing(userId: user.id) ? NSLocalizedString("已关注", comment: "") : NSLocalizedString("关注", comment: ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(socialService.isFollowing(userId: user.id) ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(socialService.isFollowing(userId: user.id) ? Color(uiColor: .systemGray5) : primaryColor)
                    .cornerRadius(14)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 用户主页视图
struct UserProfileView: View {
    let user: UserProfile
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    @ObservedObject var authService = AuthService.shared
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    // 从API加载的真实数据
    @State private var userStats: UserFullStats?
    @State private var userPosts: [ForumPost] = []
    @State private var isLoading = true
    @State private var isFollowing = false
    
    // 决定当前用户看到该资料主页用户的 VIP 显示名称
    private var vipBadgeText: String? {
        guard let stats = userStats, stats.isVip == true else { return nil }
        
        let currentUser = authService.currentUser
        // 检查观察者是否是资料主人本人，或者是资料主人的情侣伴侣
        let isSelfOrPartner = (stats.id == currentUser?.id) || 
            (currentUser != nil && stats.couplePartnerId != nil && currentUser?.id == stats.couplePartnerId)
        
        if stats.vipType == "COUPLE_LIFETIME" {
            if isSelfOrPartner {
                return NSLocalizedString("情侣永久会员", comment: "")
            } else {
                return NSLocalizedString("永久会员", comment: "") // 外人眼里显示普通永久会员
            }
        }
        
        // 其他 VIP 类型
        if stats.vipType == "LIFETIME" {
            return NSLocalizedString("永久会员", comment: "")
        } else if stats.vipType == "YEARLY" {
            return NSLocalizedString("年度会员", comment: "")
        } else if stats.vipType == "MONTHLY" {
            return NSLocalizedString("月度会员", comment: "")
        }
        
        return nil
    }
    
    // 点击交互状态
    @State private var showBirdList = false
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    @State private var selectedBirdForPreview: Bird? = nil
    @State private var userBirds: [Bird] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 用户头像和基本信息
                VStack(spacing: 12) {
                    // 显示实际头像
                    if let avatarUrl = userStats?.avatarUrl ?? user.avatar, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            default:
                                defaultAvatarView
                            }
                        }
                    } else {
                        defaultAvatarView
                    }
                    
                    HStack(spacing: 6) {
                        Text(userStats?.nickname ?? user.nickname)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let badgeText = vipBadgeText {
                            let isCoupleStyle = badgeText == NSLocalizedString("情侣永久会员", comment: "")
                            HStack(spacing: 2) {
                                Image(systemName: isCoupleStyle ? "sparkles" : "crown.fill")
                                    .font(.system(size: 10))
                                Text(NSLocalizedString(badgeText, comment: ""))
                                    .font(.system(size: 10))
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                isCoupleStyle ?
                                LinearGradient(colors: [Color(red: 1.0, green: 0.4, blue: 0.6), Color(red: 1.0, green: 0.6, blue: 0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color(red: 0.85, green: 0.65, blue: 0.13), Color(red: 1.0, green: 0.84, blue: 0.0)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(4)
                        }
                    }
                    
                    // 个人简介
                    let bioText = userStats?.bio ?? user.bio
                    Text(bioText?.isEmpty == false ? bioText! : NSLocalizedString("这个人很懒，还没有写简介~", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // 关注按钮（不是自己才显示，自己显示提示文字）
                    if authService.currentUser?.id != user.id {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                socialService.toggleFollow(userId: user.id)
                                isFollowing.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: isFollowing ? "checkmark" : "plus")
                                Text(isFollowing ? NSLocalizedString("已关注", comment: "") : NSLocalizedString("关注", comment: ""))
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isFollowing ? .secondary : .white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(isFollowing ? Color(uiColor: .systemGray5) : themeManager.primaryColor)
                            .cornerRadius(20)
                        }
                    } else {
                        // 查看自己时显示提示
                        Text(NSLocalizedString("不能关注自己哦~", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.top, 20)
                
                // 统计数据 - 可点击
                HStack(spacing: 0) {
                    // 鸟儿 - 可点击查看鸟儿列表
                    userStatItem(value: "\(userStats?.birdCount ?? user.birdCount)", label: NSLocalizedString("鸟儿", comment: ""))
                        .onTapGesture {
                            showBirdList = true
                        }
                    Divider().frame(height: 40)
                    // 帖子 - 不可点击（已在下方显示）
                    userStatItem(value: "\(userStats?.postCount ?? user.postCount)", label: NSLocalizedString("帖子", comment: ""))
                    Divider().frame(height: 40)
                    // 粉丝 - 可点击查看粉丝列表
                    userStatItem(value: "\(userStats?.followerCount ?? user.followerCount)", label: NSLocalizedString("粉丝", comment: ""))
                        .onTapGesture {
                            showFollowersList = true
                        }
                    Divider().frame(height: 40)
                    // 关注 - 可点击查看关注列表
                    userStatItem(value: "\(userStats?.followingCount ?? user.followingCount)", label: NSLocalizedString("关注", comment: ""))
                        .onTapGesture {
                            showFollowingList = true
                        }
                }
                .padding(.vertical, 16)
                .background(Color.adaptiveCard)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5)
                .padding(.horizontal, 16)
                
                // TA的帖子
                VStack(spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("TA的帖子", comment: ""))
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if userPosts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.4))
                            Text(NSLocalizedString("暂无帖子", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else {
                        // 使用与广场页面相同的瀑布流布局
                        WaterfallGrid(posts: userPosts, videoPosts: userPosts.filter { $0.mediaType == "VIDEO" }, primaryColor: themeManager.primaryColor, backgroundColor: themeManager.backgroundColor)
                            .padding(.horizontal, 10)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .themedBackground()
        .themedNavigationBar(title: userStats?.nickname ?? user.nickname)
        .onAppear {
            loadUserData()
        }
        // 鸟儿列表页面
        .navigationDestination(isPresented: $showBirdList) {
            UserBirdsListView(userId: user.id, userName: userStats?.nickname ?? user.nickname)
                .hidesTabBar()
        }
        // 粉丝列表页面
        .navigationDestination(isPresented: $showFollowersList) {
            UserFollowListView(userId: user.id, userName: userStats?.nickname ?? user.nickname, listType: .followers)
                .hidesTabBar()
        }
        // 关注列表页面
        .navigationDestination(isPresented: $showFollowingList) {
            UserFollowListView(userId: user.id, userName: userStats?.nickname ?? user.nickname, listType: .following)
                .hidesTabBar()
        }
    }
    
    // 默认头像视图
    private var defaultAvatarView: some View {
        Circle()
            .fill(themeManager.primaryColor.opacity(0.15))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.primaryColor)
            )
    }
    
    // 从API加载用户数据
    private func loadUserData() {
        isLoading = true
        print("📊 开始加载用户数据，userId: \(user.id)")
        
        Task {
            do {
                // 加载用户统计信息
                print("📊 调用getUserFullStats API...")
                let stats = try await ApiService.shared.getUserFullStats(userId: user.id)
                print("📊 获取到用户统计: 鸟儿=\(stats.birdCount), 帖子=\(stats.postCount), 粉丝=\(stats.followerCount), 关注=\(stats.followingCount)")
                await MainActor.run {
                    userStats = stats
                    isFollowing = stats.isFollowing
                }
                
                // 加载用户帖子
                print("📊 调用getUserPosts API...")
                let postsPage = try await ApiService.shared.getUserPosts(userId: user.id)
                let posts = postsPage.content.map { ForumPost.from(dto: $0) }
                print("📊 获取到用户帖子数量: \(posts.count)")
                await MainActor.run {
                    userPosts = posts
                    isLoading = false
                }
            } catch {
                print("❌ 加载用户数据失败: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func userStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 我的帖子视图
struct MyPostsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var isLoading = true
    
    // 从后端获取的我的帖子
    private var myPosts: [ForumPost] {
        socialService.myPosts.map { ForumPost.from(dto: $0) }
    }
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(L10n.loading)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if myPosts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(NSLocalizedString("还没有发布过帖子", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("去广场发布你的第一条帖子吧", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    // 使用与广场页面相同的瀑布流布局
                    WaterfallGrid(posts: myPosts, videoPosts: myPosts.filter { $0.mediaType == "VIDEO" }, primaryColor: themeManager.primaryColor, backgroundColor: themeManager.backgroundColor)
                        .padding(.horizontal, 10)
                }
            }
        }
        .themedBackground()
        .navigationTitle(L10n.myPosts)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        Task {
            await socialService.loadMyPosts()
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - 我的收藏视图
struct MyFavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var isLoading = true
    
    // 从后端获取的收藏帖子
    private var favoritePosts: [ForumPost] {
        socialService.myFavorites.map { ForumPost.from(dto: $0) }
    }
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(L10n.loading)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if favoritePosts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "star")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(NSLocalizedString("还没有收藏任何帖子", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("在广场浏览时点击星星按钮收藏", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    // 使用与广场页面相同的瀑布流布局
                    WaterfallGrid(posts: favoritePosts, videoPosts: favoritePosts.filter { $0.mediaType == "VIDEO" }, primaryColor: themeManager.primaryColor, backgroundColor: themeManager.backgroundColor)
                        .padding(.horizontal, 10)
                }
            }
        }
        .themedBackground()
        .navigationTitle(L10n.myFavorites)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        Task {
            await socialService.loadMyFavorites()
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - 编辑个人资料视图
struct EditProfileView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showChangePhone = false
    @State private var showSetPassword = false
    
    @ObservedObject var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        Form {
            Section(NSLocalizedString("基本信息", comment: "")) {
                VStack(alignment: .trailing, spacing: 0) {
                    HStack {
                        HStack(spacing: 2) {
                            Text(L10n.birdName)
                            Text("*")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        Spacer()
                        TextField(NSLocalizedString("请输入昵称", comment: ""), text: $nickname)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if nickname.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(NSLocalizedString("昵称是必填项", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                            .transition(.opacity)
                    }
                }
                
                Button {
                    showChangePhone = true
                } label: {
                    HStack {
                        Text(L10n.phone)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(user.maskedPhone)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(L10n.accountSecurity) {
                Button {
                    showSetPassword = true
                } label: {
                    HStack {
                        Text(authService.currentUser?.hasPassword == true ? NSLocalizedString("修改密码", comment: "") : NSLocalizedString("设置密码", comment: ""))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(authService.currentUser?.hasPassword == true ? NSLocalizedString("验证后可修改", comment: "") : NSLocalizedString("用于快速登录", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(NSLocalizedString("个人简介", comment: "")) {
                TextEditor(text: $bio)
                    .frame(minHeight: 80)
            }
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .navigationTitle(L10n.editProfile)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.save) { saveProfile() }
                    .fontWeight(.semibold)
                    .foregroundColor(!nickname.isEmpty && !isLoading ? primaryColor : .gray)
                    .disabled(isLoading || nickname.isEmpty)
            }
        }
        .onAppear {
                nickname = user.nickname
                bio = user.bio ?? ""
            }
            .alert(NSLocalizedString("错误", comment: ""), isPresented: $showError) {
                Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .navigationDestination(isPresented: $showChangePhone) {
                ChangePhoneView()
                    .hidesTabBar()
            }
            .navigationDestination(isPresented: $showSetPassword) {
                SetPasswordView()
                    .hidesTabBar()
            }
    }
    
    private func saveProfile() {
        isLoading = true
        Task {
            do {
                try await authService.updateProfile(nickname: nickname, bio: bio)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = NSLocalizedString("保存失败", comment: "")
                    showError = true
                }
            }
        }
    }
}

// NOTE: Food models (FoodSafetyLevel, FoodCategory, BirdType, FoodPreference, BirdFood) 
//       have been moved to Models/FoodModels.swift


fileprivate let synonymGroups = [
    // 症状同义词
    [NSLocalizedString("拉稀", comment: ""), NSLocalizedString("拉肚子", comment: ""), NSLocalizedString("腹泻", comment: ""), NSLocalizedString("稀便", comment: ""), NSLocalizedString("水便", comment: ""), NSLocalizedString("便稀", comment: ""), NSLocalizedString("拉水", comment: ""), NSLocalizedString("不成形", comment: ""), NSLocalizedString("绿便", comment: ""), NSLocalizedString("血便", comment: ""), NSLocalizedString("便血", comment: ""), NSLocalizedString("拉血", comment: ""), NSLocalizedString("稀", comment: "")],
    [NSLocalizedString("不吃", comment: ""), NSLocalizedString("拒食", comment: ""), NSLocalizedString("吃不下", comment: ""), NSLocalizedString("厌食", comment: ""), NSLocalizedString("挑食", comment: ""), NSLocalizedString("不开食", comment: ""), NSLocalizedString("不进食", comment: ""), NSLocalizedString("食欲不振", comment: ""), NSLocalizedString("食欲下降", comment: ""), NSLocalizedString("不肯吃", comment: ""), NSLocalizedString("不吃食", comment: ""), NSLocalizedString("吃不下饭", comment: "")],
    [NSLocalizedString("喘气", comment: ""), NSLocalizedString("张嘴喘", comment: ""), NSLocalizedString("呼吸急促", comment: ""), NSLocalizedString("喘粗气", comment: ""), NSLocalizedString("呼吸困难", comment: ""), NSLocalizedString("憋气", comment: ""), NSLocalizedString("不通气", comment: ""), NSLocalizedString("张嘴呼吸", comment: ""), NSLocalizedString("喘", comment: "")],
    [NSLocalizedString("炸毛", comment: ""), NSLocalizedString("没精神", comment: ""), NSLocalizedString("打蔫", comment: ""), NSLocalizedString("不爱动", comment: ""), NSLocalizedString("缩成一团", comment: ""), NSLocalizedString("发抖", comment: ""), NSLocalizedString("虚弱", comment: ""), NSLocalizedString("精神差", comment: ""), NSLocalizedString("萎靡", comment: ""), NSLocalizedString("蓬毛", comment: ""), NSLocalizedString("松毛", comment: "")],
    [NSLocalizedString("眼红", comment: ""), NSLocalizedString("眼肿", comment: ""), NSLocalizedString("流眼泪", comment: ""), NSLocalizedString("流泪", comment: ""), NSLocalizedString("眼屎", comment: ""), NSLocalizedString("睁不开", comment: ""), NSLocalizedString("眼炎", comment: ""), NSLocalizedString("结膜炎", comment: ""), NSLocalizedString("红眼", comment: "")],
    [NSLocalizedString("感冒", comment: ""), NSLocalizedString("受凉", comment: ""), NSLocalizedString("着凉", comment: ""), NSLocalizedString("受寒", comment: ""), NSLocalizedString("流鼻涕", comment: ""), NSLocalizedString("打喷嚏", comment: ""), NSLocalizedString("流气", comment: "")],
    [NSLocalizedString("吐食", comment: ""), NSLocalizedString("呕吐", comment: ""), NSLocalizedString("甩头吐", comment: ""), NSLocalizedString("反胃", comment: ""), NSLocalizedString("吐了", comment: ""), NSLocalizedString("甩食", comment: ""), NSLocalizedString("干呕", comment: "")],
    [NSLocalizedString("掉毛", comment: ""), NSLocalizedString("脱毛", comment: ""), NSLocalizedString("啄羽", comment: ""), NSLocalizedString("咬毛", comment: ""), NSLocalizedString("拔毛", comment: ""), NSLocalizedString("自残", comment: ""), NSLocalizedString("秃了", comment: ""), NSLocalizedString("啄毛", comment: ""), NSLocalizedString("羽毛脱落", comment: "")],
    [NSLocalizedString("流血", comment: ""), NSLocalizedString("受伤", comment: ""), NSLocalizedString("出血", comment: ""), NSLocalizedString("骨折", comment: ""), NSLocalizedString("外伤", comment: ""), NSLocalizedString("磕破", comment: ""), NSLocalizedString("伤口", comment: "")],
    [NSLocalizedString("难产", comment: ""), NSLocalizedString("下不出蛋", comment: ""), NSLocalizedString("卡蛋", comment: ""), NSLocalizedString("蛋阻留", comment: ""), NSLocalizedString("生不出", comment: "")],
    
    // 食物同义词
    [NSLocalizedString("板栗", comment: ""), NSLocalizedString("栗子", comment: ""), NSLocalizedString("甘栗", comment: ""), NSLocalizedString("毛栗", comment: "")],
    [NSLocalizedString("土豆", comment: ""), NSLocalizedString("马铃薯", comment: ""), NSLocalizedString("洋芋", comment: "")],
    [NSLocalizedString("西红柿", comment: ""), NSLocalizedString("番茄", comment: ""), NSLocalizedString("洋柿子", comment: "")],
    [NSLocalizedString("玉米", comment: ""), NSLocalizedString("苞谷", comment: ""), NSLocalizedString("包谷", comment: ""), NSLocalizedString("棒子", comment: ""), NSLocalizedString("玉蜀黍", comment: "")],
    [NSLocalizedString("红薯", comment: ""), NSLocalizedString("番薯", comment: ""), NSLocalizedString("地瓜", comment: ""), NSLocalizedString("山芋", comment: ""), NSLocalizedString("红苕", comment: "")],
    [NSLocalizedString("花生", comment: ""), NSLocalizedString("落花生", comment: ""), NSLocalizedString("长生果", comment: ""), NSLocalizedString("地豆", comment: "")],
    [NSLocalizedString("西兰花", comment: ""), NSLocalizedString("绿花菜", comment: ""), NSLocalizedString("青花菜", comment: ""), NSLocalizedString("花椰菜", comment: "")],
    [NSLocalizedString("白菜", comment: ""), NSLocalizedString("大白菜", comment: ""), NSLocalizedString("黄芽白", comment: ""), NSLocalizedString("结球白菜", comment: "")],
    [NSLocalizedString("卷心菜", comment: ""), NSLocalizedString("圆白菜", comment: ""), NSLocalizedString("洋白菜", comment: ""), NSLocalizedString("包菜", comment: ""), NSLocalizedString("莲花白", comment: "")],
    [NSLocalizedString("苹果", comment: ""), NSLocalizedString("蛇果", comment: ""), NSLocalizedString("沙果", comment: "")],
    [NSLocalizedString("哈密瓜", comment: ""), NSLocalizedString("哈蜜瓜", comment: ""), NSLocalizedString("网纹瓜", comment: ""), NSLocalizedString("甜瓜", comment: "")],
    [NSLocalizedString(NSLocalizedString("胡萝卜", comment: ""), comment: ""), NSLocalizedString("红萝卜", comment: ""), "胡萝卜"],
    [NSLocalizedString("猕猴桃", comment: ""), NSLocalizedString("奇异果", comment: ""), NSLocalizedString("毛梨", comment: "")],
    [NSLocalizedString("南瓜", comment: ""), NSLocalizedString("麦瓜", comment: ""), NSLocalizedString("倭瓜", comment: ""), NSLocalizedString("金瓜", comment: "")],
    [NSLocalizedString("黄瓜", comment: ""), NSLocalizedString("青瓜", comment: ""), NSLocalizedString("胡瓜", comment: "")],
    [NSLocalizedString("辣椒", comment: ""), NSLocalizedString("秦椒", comment: ""), NSLocalizedString("海椒", comment: ""), NSLocalizedString("甜椒", comment: ""), NSLocalizedString("彩椒", comment: "")],
    [NSLocalizedString("燕麦", comment: ""), NSLocalizedString("莜麦", comment: ""), NSLocalizedString("麦片", comment: "")],
    [NSLocalizedString("油菜", comment: ""), NSLocalizedString("青菜", comment: ""), NSLocalizedString("油白菜", comment: ""), NSLocalizedString("上海青", comment: ""), NSLocalizedString("小白菜", comment: "")],
    [NSLocalizedString("空心菜", comment: ""), NSLocalizedString("通菜", comment: ""), NSLocalizedString("蕹菜", comment: ""), NSLocalizedString("无心菜", comment: "")],
    [NSLocalizedString("菠菜", comment: ""), NSLocalizedString("波斯草", comment: ""), NSLocalizedString("红根菜", comment: ""), NSLocalizedString("飞龙菜", comment: "")],
    [NSLocalizedString("生菜", comment: ""), NSLocalizedString("莴苣", comment: ""), NSLocalizedString("叶用莴苣", comment: "")],
    [NSLocalizedString("蒲公英", comment: ""), NSLocalizedString("婆婆丁", comment: ""), NSLocalizedString("黄花地丁", comment: "")],
    [NSLocalizedString("车前草", comment: ""), NSLocalizedString("车轮菜", comment: ""), NSLocalizedString("猪耳草", comment: "")],
    [NSLocalizedString("面包虫", comment: ""), NSLocalizedString("黄粉虫", comment: "")],
    [NSLocalizedString("大麦虫", comment: ""), NSLocalizedString("超级面包虫", comment: "")]
]

fileprivate func expandKeywords(from query: String) -> [String] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    
    var expanded = [trimmed]
    
    for group in synonymGroups {
        var matched = false
        for word in group {
            if trimmed.localizedCaseInsensitiveContains(word) || word.localizedCaseInsensitiveContains(trimmed) {
                matched = true
                break
            }
        }
        if matched {
            for word in group {
                if !expanded.contains(where: { $0.localizedCaseInsensitiveCompare(word) == .orderedSame }) {
                    expanded.append(word)
                }
            }
        }
    }
    return expanded
}

fileprivate func fuzzyMatch(_ query: String, in target: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let t = target.lowercased()
    if q.isEmpty { return true }
    
    // 1. 包含关系 (Direct contains)
    if t.contains(q) { return true }
    
    // 2. 子序列匹配 (Subsequence match, e.g. "煮鸡肉" -> "煮熟的鸡肉")
    var qIdx = q.startIndex
    var tIdx = t.startIndex
    while qIdx < q.endIndex && tIdx < t.endIndex {
        if q[qIdx] == t[tIdx] {
            qIdx = q.index(after: qIdx)
        }
        tIdx = t.index(after: tIdx)
    }
    if qIdx == q.endIndex { return true }
    
    // 3. 错别字/近音字模糊容错 (Character overlap ratio for common typos)
    if q.count >= 3 {
        let qChars = Array(q)
        var matchCount = 0
        for char in qChars {
            if t.contains(char) {
                matchCount += 1
            }
        }
        if matchCount >= q.count - 1 {
            return true
        }
    }
    
    return false
}

// MARK: - 食物查询视图
struct FoodQueryView: View {
    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory? = nil
    @State private var selectedSafetyLevel: FoodSafetyLevel? = nil
    @State private var selectedFood: BirdFood? = nil
    
    // API数据状态
    @State private var allFoods: [BirdFood] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var hasLoadedFromAPI = false
    
    // 缓存key
    private let foodsCacheKey = "foods_encyclopedia_cache"
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    private var filteredFoods: [BirdFood] {
        var foods = allFoods
        
        // 按分类筛选
        if let category = selectedCategory {
            foods = foods.filter { $0.category == category }
        }
        
        // 按安全等级筛选
        if let level = selectedSafetyLevel {
            foods = foods.filter { $0.safetyLevel == level }
        }
        
        // 按搜索词筛选 (使用智能模糊搜索+拼写容错)
        if !searchText.isEmpty {
            let keywords = expandKeywords(from: searchText)
            foods = foods.filter { food in
                keywords.contains { kw in
                    fuzzyMatch(kw, in: food.name) ||
                    fuzzyMatch(kw, in: food.description)
                }
            }
        }
        
        return foods
    }
    
    // 从缓存加载食物数据
    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: foodsCacheKey),
           let cached = try? JSONDecoder().decode([FoodEncyclopediaDTO].self, from: data) {
            self.allFoods = cached.map { $0.toBirdFood() }
            print("📖 食物数据从缓存加载: \(cached.count) 条")
        }
    }
    
    // 保存到缓存
    private func saveToCache(_ dtos: [FoodEncyclopediaDTO]) {
        if let data = try? JSONEncoder().encode(dtos) {
            UserDefaults.standard.set(data, forKey: foodsCacheKey)
            print("✅ 食物数据已缓存: \(dtos.count) 条")
        }
    }
    
    // 从API加载食物数据
    private func loadFoods() {
        guard !isLoading else { return }
        
        // 先加载缓存
        if allFoods.isEmpty {
            loadFromCache()
        }
        
        // 如果有缓存数据，后台静默刷新
        if !allFoods.isEmpty {
            Task {
                do {
                    let foodDTOs = try await ApiService.shared.getAllFoods()
                    await MainActor.run {
                        self.allFoods = foodDTOs.map { $0.toBirdFood() }
                        self.saveToCache(foodDTOs)
                    }
                } catch {
                    print("食物数据后台刷新失败: \(error)")
                }
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let foodDTOs = try await ApiService.shared.getAllFoods()
                await MainActor.run {
                    self.allFoods = foodDTOs.map { $0.toBirdFood() }
                    self.hasLoadedFromAPI = true
                    self.isLoading = false
                    self.saveToCache(foodDTOs)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = NSLocalizedString("网络加载失败，请检查网络连接", comment: "")
                    self.isLoading = false
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 搜索栏
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(NSLocalizedString("搜索食物名称...", comment: ""), text: $searchText)
                        .font(.subheadline)
                        .submitLabel(.search)
                        .onSubmit {
                            hideKeyboard()
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.adaptiveCard)  // P2-UI04 FIX: 深色模式兼容
                .cornerRadius(12)
                
                if !searchText.isEmpty {
                    Button(L10n.cancel) {
                        searchText = ""
                        hideKeyboard()
                    }
                    .foregroundColor(themeManager.primaryColor)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
            
            // 安全等级筛选
            HStack(spacing: 8) {
                ForEach(FoodSafetyLevel.allCases, id: \.self) { level in
                    Button {
                        if selectedSafetyLevel == level {
                            selectedSafetyLevel = nil
                        } else {
                            selectedSafetyLevel = level
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: level.icon)
                                .font(.caption)
                            Text(level.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedSafetyLevel == level ? level.color : Color.adaptiveCard)  // P2-UI04 FIX
                        .foregroundColor(selectedSafetyLevel == level ? .white : level.color)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(level.color, lineWidth: 1)
                        )
                    }
                }
                Spacer()
            }
            
            // 分类筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 全部按钮
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text(L10n.all)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == nil ?
                                AnyView(LinearGradient(colors: themeManager.gradientColors, startPoint: .top, endPoint: .bottom)) :
                                AnyView(Color.adaptiveCard)  // 深色模式兼容
                            )
                            .foregroundColor(selectedCategory == nil ? .white : .primary)
                            .cornerRadius(14)
                    }
                    
                    ForEach(FoodCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                Text(category.rawValue)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == category ?
                                AnyView(LinearGradient(colors: themeManager.gradientColors, startPoint: .top, endPoint: .bottom)) :
                                AnyView(Color.adaptiveCard)  // 深色模式兼容
                            )
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .cornerRadius(14)
                        }
                    }
                }
            }
            
            // 统计信息
            HStack {
                Text(String(format: NSLocalizedString("共 %d 种食物", comment: ""), filteredFoods.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                // 各等级数量
                HStack(spacing: 12) {
                    let safeCount = filteredFoods.filter { $0.safetyLevel == .safe }.count
                    let cautionCount = filteredFoods.filter { $0.safetyLevel == .caution }.count
                    let dangerCount = filteredFoods.filter { $0.safetyLevel == .dangerous }.count
                    
                    Label("\(safeCount)", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(FoodSafetyLevel.safe.color)
                    Label("\(cautionCount)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(FoodSafetyLevel.caution.color)
                    Label("\(dangerCount)", systemImage: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(FoodSafetyLevel.dangerous.color)
                }
            }
            
            // 错误提示（苹果原生风格）
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
            }
            
            // 食物列表
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(L10n.loading)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if filteredFoods.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text(NSLocalizedString("没有找到相关食物", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredFoods) { food in
                        // P2-07: 传递searchText用于高亮显示
                        FoodCard(food: food, searchText: searchText)
                            .onTapGesture {
                                selectedFood = food
                            }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedFood) { food in
            // UI-001 FIX: 传递搜索关键词用于高亮显示
            FoodDetailView(food: food, searchKeyword: searchText)
                .hidesTabBar()
        }
        .onAppear {
            if !hasLoadedFromAPI && allFoods.isEmpty {
                loadFoods()
            }
        }
    }
}

// NOTE: HighlightedText has been moved to Views/Shared/HighlightedText.swift

// MARK: - 食物卡片（P2-07: 支持搜索高亮）
struct FoodCard: View {
    let food: BirdFood
    var searchText: String = ""
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 食物信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // P2-07: 名称高亮
                    HighlightedText(food.name, highlight: searchText, highlightColor: themeManager.primaryColor)
                        .fontWeight(.medium)
                    
                    Text(food.safetyLevel.rawValue)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(food.safetyLevel.color)
                        .cornerRadius(4)
                }
                
                // P2-07: 描述高亮
                HighlightedText(food.description, highlight: searchText, highlightColor: themeManager.primaryColor.opacity(0.7), font: .caption, baseColor: .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 分类标签
            Text(food.category.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(food.safetyLevel.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 食物详情视图
struct FoodDetailView: View {
    let food: BirdFood
    var searchKeyword: String = ""
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部基本信息卡片
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(food.safetyLevel.color.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: food.safetyLevel.icon)
                                .font(.system(size: 36))
                                .foregroundColor(food.safetyLevel.color)
                        }
                        .padding(.top, 10)
                        
                        VStack(spacing: 8) {
                            // 名称高亮
                            HighlightedText(food.name, highlight: searchKeyword, highlightColor: themeManager.primaryColor)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            // 安全等级标签
                            HStack(spacing: 6) {
                                Image(systemName: food.safetyLevel.icon)
                                    .font(.caption2)
                                Text(food.safetyLevel.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(food.safetyLevel.color))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 4)
                    
                    VStack(spacing: 16) {
                        // 分类信息
                        infoCard(title: NSLocalizedString("食物分类", comment: ""), icon: food.category.icon) {
                            Text(food.category.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        // 简介
                        infoCard(title: NSLocalizedString("简介", comment: ""), icon: "doc.text") {
                            HighlightedText(food.description, highlight: searchKeyword, highlightColor: themeManager.primaryColor)
                                .font(.body)
                                .lineSpacing(4)
                        }
                        
                        // 注意事项
                        infoCard(title: NSLocalizedString("注意事项", comment: ""), icon: "exclamationmark.circle") {
                            HighlightedText(food.notes, highlight: searchKeyword, highlightColor: themeManager.primaryColor, baseColor: food.safetyLevel == .dangerous ? .red : .primary)
                                .font(.body)
                                .lineSpacing(4)
                        }
                        
                        // 营养成分
                        if !food.nutrients.isEmpty {
                            infoCard(title: NSLocalizedString("主要营养", comment: ""), icon: "leaf") {
                                FlowLayout(spacing: 8) {
                                    ForEach(food.nutrients, id: \.self) { nutrient in
                                        Text(nutrient)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(themeManager.primaryColor.opacity(0.1))
                                            .foregroundColor(themeManager.primaryColor)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        
                        // 鸟类偏好
                        if !food.birdPreferences.isEmpty {
                            birdPreferencesSection
                        }
                        
                        // 权威来源
                        if !food.sources.isEmpty {
                            sourcesSection
                        }
                        
                        // 危险警告
                        if food.safetyLevel == .dangerous {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("危险警告", comment: ""))
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    
                                    Text(NSLocalizedString("此食物对鸟类有毒或有害，请绝对不要喂食！如果鸟儿误食，请立即联系兽医。", comment: ""))
                                        .font(.subheadline)
                                        .foregroundColor(.red.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .themedNavigationBar(title: NSLocalizedString("食物详情", comment: ""))
        }
    }
    
    private func infoCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.secondaryColor)
                    .frame(width: 24, height: 24)
                    .background(themeManager.secondaryColor.opacity(0.15))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content()
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        // 移除阴影，使用更原生的卡片质感
    }
    
    // MARK: - 鸟类偏好区域
    private var birdPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.secondaryColor)
                    .frame(width: 24, height: 24)
                    .background(themeManager.secondaryColor.opacity(0.15))
                    .clipShape(Circle())
                
                Text(NSLocalizedString("鸟类喜好", comment: ""))
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                // 特别爱吃的鸟类
                let lovedBy = food.birdPreferences.filter { $0.value == .loves }
                if !lovedBy.isEmpty {
                    preferenceRow(title: NSLocalizedString("特别爱吃", comment: ""), icon: "heart.fill", color: FoodPreference.loves.color, items: lovedBy)
                }
                
                // 喜欢的鸟类
                let likedBy = food.birdPreferences.filter { $0.value == .likes }
                if !likedBy.isEmpty {
                    preferenceRow(title: NSLocalizedString("喜欢", comment: ""), icon: "hand.thumbsup.fill", color: FoodPreference.likes.color, items: likedBy)
                }
                
                // 不太爱吃的鸟类
                let dislikedBy = food.birdPreferences.filter { $0.value == .dislikes }
                if !dislikedBy.isEmpty {
                    preferenceRow(title: NSLocalizedString("不太爱吃", comment: ""), icon: "hand.thumbsdown", color: FoodPreference.dislikes.color, items: dislikedBy)
                }
                
                // 不适合的鸟类
                let unsuitableFor = food.birdPreferences.filter { $0.value == .unsuitable }
                if !unsuitableFor.isEmpty {
                    preferenceRow(title: NSLocalizedString("不适合", comment: ""), icon: "xmark.circle.fill", color: FoodPreference.unsuitable.color, items: unsuitableFor)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func preferenceRow(title: String, icon: String, color: Color, items: [BirdType: FoodPreference]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)
            
            FlowLayout(spacing: 8) {
                ForEach(Array(items.keys), id: \.self) { birdType in
                    Text(birdType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.1))
                        .foregroundColor(color)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 权威来源区域
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.secondaryColor)
                    .frame(width: 24, height: 24)
                    .background(themeManager.secondaryColor.opacity(0.15))
                    .clipShape(Circle())
                
                Text(NSLocalizedString("参考来源", comment: ""))
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(food.sources, id: \.self) { source in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(source)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Divider().padding(.vertical, 4)
                
                Text(NSLocalizedString("以上信息来源于权威兽医学文献和研究，仅供参考。如有疑问请咨询专业禽类兽医。", comment: ""))
                    .font(.caption)
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - 流式布局


// MARK: - 症状查询视图（P2-08: 支持多选分类）
struct SymptomQueryView: View {
    @State private var selectedSymptom: BirdSymptom? = nil
    @State private var searchText = ""
    // P2-08: 改为多选分类
    @State private var selectedCategories: Set<String> = []
    
    // API数据状态
    @State private var allSymptoms: [BirdSymptom] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var hasLoadedFromAPI = false
    
    // 缓存key
    private let symptomsCacheKey = "symptoms_encyclopedia_cache"
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    private var symptoms: [BirdSymptom] {
        return allSymptoms
    }


    
    // 分类列表
    private let categories: [(name: String, icon: String)] = [
        (NSLocalizedString("消化系统", comment: ""), "leaf"),
        (NSLocalizedString("呼吸系统", comment: ""), "wind"),
        (NSLocalizedString("病毒性疾病", comment: ""), "bolt.shield"),
        (NSLocalizedString("细菌性疾病", comment: ""), "staroflife"),
        (NSLocalizedString("真菌感染", comment: ""), "allergens"),
        (NSLocalizedString("寄生虫病", comment: ""), "ant"),
        (NSLocalizedString("营养代谢", comment: ""), "carrot"),
        (NSLocalizedString("繁殖相关", comment: ""), "egg"),
        (NSLocalizedString("神经系统", comment: ""), "brain.head.profile"),
        (NSLocalizedString("外伤中毒", comment: ""), "bandage"),
        (NSLocalizedString("行为异常", comment: ""), "figure.walk"),
        (NSLocalizedString("肿瘤", comment: ""), "circle.fill")
    ]
    
    // S-001 FIX: 症状分类匹配改用精确匹配（避免误判）
    // 定义每个UI分类对应的数据库分类值
    private static let categoryMapping: [String: [String]] = [
        NSLocalizedString("消化系统", comment: ""): [NSLocalizedString("消化系统", comment: ""), NSLocalizedString("消化系统疾病", comment: "")],
        NSLocalizedString("呼吸系统", comment: ""): [NSLocalizedString("呼吸系统", comment: ""), NSLocalizedString("呼吸系统疾病", comment: "")],
        NSLocalizedString("病毒性疾病", comment: ""): [NSLocalizedString("病毒性疾病", comment: ""), NSLocalizedString("病毒感染", comment: "")],
        NSLocalizedString("细菌性疾病", comment: ""): [NSLocalizedString("细菌性疾病", comment: ""), NSLocalizedString("细菌感染", comment: "")],
        NSLocalizedString("真菌感染", comment: ""): [NSLocalizedString("真菌感染", comment: ""), NSLocalizedString("真菌性疾病", comment: "")],
        NSLocalizedString("寄生虫病", comment: ""): [NSLocalizedString("寄生虫病", comment: ""), NSLocalizedString("寄生虫感染", comment: "")],
        NSLocalizedString("营养代谢", comment: ""): [NSLocalizedString("营养代谢", comment: ""), NSLocalizedString("营养性疾病", comment: ""), NSLocalizedString("代谢性疾病", comment: "")],
        NSLocalizedString("繁殖相关", comment: ""): [NSLocalizedString("繁殖相关", comment: ""), NSLocalizedString("繁殖系统", comment: "")],
        NSLocalizedString("神经系统", comment: ""): [NSLocalizedString("神经系统", comment: ""), NSLocalizedString("神经系统疾病", comment: "")],
        NSLocalizedString("外伤中毒", comment: ""): [NSLocalizedString("外伤中毒", comment: ""), NSLocalizedString("外伤", comment: ""), NSLocalizedString("中毒", comment: "")],
        NSLocalizedString("行为异常", comment: ""): [NSLocalizedString("行为异常", comment: ""), NSLocalizedString("行为问题", comment: "")],
        NSLocalizedString("肿瘤", comment: ""): [NSLocalizedString("肿瘤", comment: ""), NSLocalizedString("肿瘤性疾病", comment: "")]
    ]
    
    private func symptomMatchesCategory(_ symptom: BirdSymptom, category: String) -> Bool {
        // S-001 FIX: 使用精确匹配而非模糊contains
        guard let validCategories = Self.categoryMapping[category] else {
            return true // 未知分类默认匹配
        }
        // 精确匹配：症状分类必须完全等于映射中的某个值
        return validCategories.contains { validCategory in
            symptom.category == validCategory
        }
    }
    
    // P3-03: 按紧急程度排序
    @State private var sortBySeverity = true
    
    private var filteredSymptoms: [BirdSymptom] {
        var result = symptoms
        
        // P2-08: 按多选分类筛选（OR逻辑：匹配任意一个选中分类）
        if !selectedCategories.isEmpty {
            result = result.filter { symptom in
                selectedCategories.contains { category in
                    symptomMatchesCategory(symptom, category: category)
                }
            }
        }
        
        // S-002 FIX: 按搜索词筛选 (使用智能模糊搜索+拼写容错)
        if !searchText.isEmpty {
            let keywords = expandKeywords(from: searchText)
            result = result.filter { symptom in
                keywords.contains { kw in
                    fuzzyMatch(kw, in: symptom.name) ||
                    fuzzyMatch(kw, in: symptom.description) ||
                    symptom.possibleCauses.contains { fuzzyMatch(kw, in: $0) } ||
                    symptom.suggestions.contains { fuzzyMatch(kw, in: $0) } ||
                    symptom.whenToSeeVet.contains { fuzzyMatch(kw, in: $0) } ||
                    symptom.prevention.contains { fuzzyMatch(kw, in: $0) }
                }
            }
        }
        
        // P3-03: 按紧急程度排序（高→中→低）
        if sortBySeverity {
            result.sort { s1, s2 in
                let order: [BirdSymptom.Severity: Int] = [.high: 0, .medium: 1, .low: 2]
                return (order[s1.severity] ?? 2) < (order[s2.severity] ?? 2)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 搜索框区域
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.primaryColor.opacity(0.6))
                    TextField(NSLocalizedString("搜索症状名称...", comment: ""), text: $searchText)
                        .font(.subheadline)
                        .submitLabel(.search)
                        .onSubmit {
                            hideKeyboard()
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.adaptiveCard)
                        .shadow(color: themeManager.primaryColor.opacity(0.08), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.primaryColor.opacity(0.15), lineWidth: 1)
                )
                
                if !searchText.isEmpty {
                    Button(L10n.cancel) {
                        searchText = ""
                        hideKeyboard()
                    }
                    .foregroundColor(themeManager.primaryColor)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
            
            // P2-08: 症状分类多选筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.name) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                // P2-08: 多选逻辑
                                if selectedCategories.contains(category.name) {
                                    selectedCategories.remove(category.name)
                                } else {
                                    selectedCategories.insert(category.name)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 11))
                                Text(category.name)
                                    .font(.caption)
                                    .fontWeight(selectedCategories.contains(category.name) ? .semibold : .regular)
                                // P2-08: 显示选中标记
                                if selectedCategories.contains(category.name) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategories.contains(category.name) ?
                                LinearGradient(colors: themeManager.gradientColors, startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.white, Color.white], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(selectedCategories.contains(category.name) ? .white : themeManager.primaryColor)
                            .cornerRadius(20)
                            .shadow(color: selectedCategories.contains(category.name) ? themeManager.primaryColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedCategories.contains(category.name) ? Color.clear : themeManager.primaryColor.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            
            // 结果统计
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.caption)
                        .foregroundColor(themeManager.primaryColor)
                    Text(String(format: NSLocalizedString("找到 %d 个相关症状", comment: ""), filteredSymptoms.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    // P2-08: 显示已选分类数
                    if !selectedCategories.isEmpty {
                        Text(String(format: NSLocalizedString("(%d个分类)", comment: ""), selectedCategories.count))
                            .font(.caption2)
                            .foregroundColor(themeManager.primaryColor)
                    }
                }
                Spacer()
                
                // P3-03: 紧急程度排序开关
                Button {
                    withAnimation {
                        sortBySeverity.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sortBySeverity ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                            .font(.caption)
                        Text(sortBySeverity ? NSLocalizedString("按紧急度", comment: "") : NSLocalizedString("默认排序", comment: ""))
                            .font(.caption)
                    }
                    .foregroundColor(sortBySeverity ? themeManager.primaryColor : .secondary)
                }
                
                if !selectedCategories.isEmpty || !searchText.isEmpty {
                    Button {
                        withAnimation {
                            selectedCategories.removeAll()
                            searchText = ""
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                            Text(NSLocalizedString("重置", comment: ""))
                                .font(.caption)
                        }
                        .foregroundColor(themeManager.primaryColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGroupedBackground))
            
            // 症状列表
            if filteredSymptoms.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bird")
                        .font(.system(size: 50))
                        .foregroundColor(themeManager.primaryColor.opacity(0.3))
                    Text(NSLocalizedString("未找到相关症状", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("试试其他关键词或分类吧", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredSymptoms) { symptom in
                        SymptomCard(symptom: symptom, primaryColor: themeManager.primaryColor) {
                            selectedSymptom = symptom
                        }
                    }
                }
                .padding(16)
            }
            
            // 底部提示区域
            VStack(spacing: 12) {
                // 温馨提示
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(themeManager.primaryColor.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(themeManager.primaryColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("温馨提示", comment: ""))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryColor)
                        Text(NSLocalizedString("以上信息仅供参考，如症状严重或持续请咨询专业兽医", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.primaryColor.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.primaryColor.opacity(0.15), lineWidth: 1)
                        )
                )
                
                // 就医提示
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(themeManager.primaryColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 16))
                            .foregroundColor(themeManager.primaryColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("需要就医", comment: ""))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryColor)
                        Text(NSLocalizedString("抽搐、出血、呼吸困难等情况请及时联系兽医", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.primaryColor.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.primaryColor.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGray6).opacity(0.3))
        .navigationDestination(item: $selectedSymptom) { symptom in
            SymptomDetailView(symptom: symptom)
                .hidesTabBar()
        }
        .onAppear {
            if !hasLoadedFromAPI && allSymptoms.isEmpty {
                loadSymptoms()
            }
        }
    }
    
    // 从缓存加载症状数据
    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: symptomsCacheKey),
           let cached = try? JSONDecoder().decode([SymptomDTO].self, from: data) {
            self.allSymptoms = cached.map { $0.toBirdSymptom() }
            print("📖 症状数据从缓存加载: \(cached.count) 条")
        }
    }
    
    // 保存到缓存
    private func saveToCache(_ dtos: [SymptomDTO]) {
        if let data = try? JSONEncoder().encode(dtos) {
            UserDefaults.standard.set(data, forKey: symptomsCacheKey)
            print("✅ 症状数据已缓存: \(dtos.count) 条")
        }
    }
    
    // 从API加载症状数据
    private func loadSymptoms() {
        guard !isLoading else { return }
        
        // 先加载缓存
        if allSymptoms.isEmpty {
            loadFromCache()
        }
        
        // 如果有缓存数据，后台静默刷新
        if !allSymptoms.isEmpty {
            Task {
                do {
                    let symptomDTOs = try await ApiService.shared.getAllSymptoms()
                    await MainActor.run {
                        self.allSymptoms = symptomDTOs.map { $0.toBirdSymptom() }
                        self.saveToCache(symptomDTOs)
                    }
                } catch {
                    print("症状数据后台刷新失败: \(error)")
                }
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let symptomDTOs = try await ApiService.shared.getAllSymptoms()
                await MainActor.run {
                    self.allSymptoms = symptomDTOs.map { $0.toBirdSymptom() }
                    self.hasLoadedFromAPI = true
                    self.isLoading = false
                    self.saveToCache(symptomDTOs)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = NSLocalizedString("网络加载失败，请检查网络连接", comment: "")
                    self.isLoading = false
                }
            }
        }
    }
}


// 症状卡片
struct SymptomCard: View {
    let symptom: BirdSymptom
    let primaryColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(symptom.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // 严重程度标签（用红黄绿区分）
                        HStack(spacing: 3) {
                            Circle()
                                .fill(symptom.severityColor)
                                .frame(width: 6, height: 6)
                            Text(symptom.severityText)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(symptom.severityColor.opacity(0.12))
                        .foregroundColor(symptom.severityColor)
                        .cornerRadius(10)
                    }
                    
                    Text(symptom.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(primaryColor.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptiveCard)
                    .shadow(color: primaryColor.opacity(0.06), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(primaryColor.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// 症状详情视图
// 症状详情视图
struct SymptomDetailView: View {
    let symptom: BirdSymptom
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头部基本信息卡片
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(symptom.severityColor.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: symptom.icon)
                                .font(.system(size: 36))
                                .foregroundColor(symptom.severityColor)
                        }
                        .padding(.top, 10)
                        
                        VStack(spacing: 8) {
                            Text(symptom.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 6) {
                                Text(symptom.severityText)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(symptom.severityColor.opacity(0.15))
                                    .foregroundColor(symptom.severityColor)
                                    .cornerRadius(6)
                                
                                Text(symptom.category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(uiColor: .systemGray6))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 4)
                    
                    VStack(spacing: 16) {
                        // 症状描述
                        DetailSection(title: NSLocalizedString("症状描述", comment: ""), icon: "doc.text", iconColor: themeManager.secondaryColor) {
                            Text(symptom.description)
                                .font(.body)
                                .lineSpacing(4)
                                .foregroundColor(Color(uiColor: .label))
                        }
                        
                        // 可能原因
                        DetailSection(title: NSLocalizedString("可能原因", comment: ""), icon: "questionmark.circle", iconColor: themeManager.secondaryColor) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(symptom.possibleCauses, id: \.self) { cause in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(themeManager.primaryColor)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 9)
                                        Text(cause)
                                            .font(.body)
                                            .foregroundColor(Color(uiColor: .secondaryLabel))
                                    }
                                }
                            }
                        }
                        
                        // 处理建议
                        DetailSection(title: NSLocalizedString("处理建议", comment: ""), icon: "lightbulb", iconColor: themeManager.secondaryColor) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(symptom.suggestions.enumerated()), id: \.offset) { index, suggestion in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(width: 20, height: 20)
                                            .background(themeManager.primaryColor)
                                            .clipShape(Circle())
                                            .padding(.top, 2)
                                        Text(suggestion)
                                            .font(.body)
                                            .foregroundColor(Color(uiColor: .secondaryLabel))
                                    }
                                }
                            }
                        }
                        
                        // 何时就医
                        DetailSection(title: NSLocalizedString("何时需要就医", comment: ""), icon: "cross.case", iconColor: .red) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(symptom.whenToSeeVet, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 14))
                                            .padding(.top, 4)
                                        Text(item)
                                            .font(.body)
                                            .foregroundColor(Color(uiColor: .secondaryLabel))
                                    }
                                }
                            }
                        }
                        
                        // 预防措施
                        if !symptom.prevention.isEmpty {
                            DetailSection(title: NSLocalizedString("预防措施", comment: ""), icon: "shield.checkered", iconColor: .green) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(symptom.prevention, id: \.self) { item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 14))
                                                .padding(.top, 4)
                                            Text(item)
                                                .font(.body)
                                                .foregroundColor(Color(uiColor: .secondaryLabel))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .themedNavigationBar(title: NSLocalizedString("症状详情", comment: ""))
        }
    }
}

// 详情区块
struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    var iconColor: Color = ThemeManager.shared.primaryColor
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.15))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// 鸟类症状数据模型
struct BirdSymptom: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let severity: Severity
    let category: String
    let possibleCauses: [String]
    let suggestions: [String]
    let whenToSeeVet: [String]
    let prevention: [String]
    
    enum Severity: Hashable {
        case low, medium, high
    }
    
    // Hashable conformance
    static func == (lhs: BirdSymptom, rhs: BirdSymptom) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // 标签颜色（红黄绿）
    var severityColor: Color {
        switch severity {
        case .low: return Color(red: 0.35, green: 0.65, blue: 0.45)    // 绿色 - 轻微
        case .medium: return Color(red: 0.90, green: 0.70, blue: 0.20) // 黄色 - 留意
        case .high: return Color(red: 0.85, green: 0.35, blue: 0.35)   // 红色 - 关注
        }
    }
    
    var severityText: String {
        switch severity {
        case .low: return NSLocalizedString("轻微", comment: "")
        case .medium: return NSLocalizedString("留意", comment: "")
        case .high: return NSLocalizedString("关注", comment: "")
        }
    }
    
    // 所有症状和疾病数据（基于专业兽医资料整理）
    static let allSymptoms: [BirdSymptom] = [
        // ========== 常见症状 ==========
        BirdSymptom(
            name: NSLocalizedString("羽毛蓬松/炸毛", comment: ""),
            description: NSLocalizedString("鸟儿羽毛持续蓬松、炸毛，看起来像个毛球。这是鸟类身体不适的重要信号，通过蓬松羽毛来保持体温。健康的鸟只有在休息或睡觉时才会短暂蓬松羽毛。", comment: ""),
            icon: "wind",
            severity: .medium,
            category: NSLocalizedString("综合症状", comment: ""),
            possibleCauses: [
                NSLocalizedString("环境温度过低，鸟儿通过蓬松羽毛保暖（正常温度应在20-28°C）", comment: ""),
                NSLocalizedString("感冒或呼吸道感染的早期症状", comment: ""),
                NSLocalizedString("消化系统疾病如肠炎、嗉囊炎", comment: ""),
                NSLocalizedString("寄生虫感染（体内或体外）", comment: ""),
                NSLocalizedString("细菌或病毒感染", comment: ""),
                NSLocalizedString("营养不良或维生素缺乏", comment: ""),
                NSLocalizedString("受到惊吓或应激反应（短暂性）", comment: "")
            ],
            suggestions: [
                NSLocalizedString("立即检查环境温度，保持在22-28°C之间", comment: ""),
                NSLocalizedString("将鸟笼移至避风温暖处，可用布部分遮盖保温", comment: ""),
                NSLocalizedString("仔细观察是否伴随其他症状：拉稀、不吃东西、呕吐、打喷嚏等", comment: ""),
                NSLocalizedString("检查粪便颜色和形状是否正常", comment: ""),
                NSLocalizedString("提供温水和易消化的食物", comment: ""),
                NSLocalizedString("减少惊扰，保持环境安静", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("持续蓬松超过6-12小时且无好转", comment: ""),
                NSLocalizedString("伴随食欲下降或完全拒食", comment: ""),
                NSLocalizedString("伴随腹泻、呕吐或异常粪便", comment: ""),
                NSLocalizedString("精神极度萎靡，眼睛无神", comment: ""),
                NSLocalizedString("站立不稳或趴在笼底", comment: ""),
                NSLocalizedString("呼吸急促或张嘴呼吸", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持适宜稳定的环境温度（22-28°C）", comment: ""),
                NSLocalizedString("避免将鸟笼放在空调直吹或窗边", comment: ""),
                NSLocalizedString("定期清洁消毒鸟笼", comment: ""),
                NSLocalizedString("提供均衡营养的饮食", comment: ""),
                NSLocalizedString("定期观察鸟的精神状态", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("食欲下降/拒食", comment: ""),
            description: NSLocalizedString("鸟儿进食量明显减少或完全不吃东西。由于鸟类新陈代谢快，24小时不进食可能危及生命。食欲下降往往是多种疾病的早期信号。", comment: ""),
            icon: "fork.knife",
            severity: .high,
            category: NSLocalizedString("消化系统", comment: ""),
            possibleCauses: [
                NSLocalizedString("嗉囊炎或嗉囊积食（嗉囊膨大、有酸臭味）", comment: ""),
                NSLocalizedString("肠炎（常伴随腹泻）", comment: ""),
                NSLocalizedString("念珠菌感染（口腔可能有白色斑点）", comment: ""),
                NSLocalizedString("呼吸道感染影响进食", comment: ""),
                NSLocalizedString("口腔溃疡或喙部问题", comment: ""),
                NSLocalizedString("寄生虫感染（滴虫、球虫等）", comment: ""),
                NSLocalizedString("食物变质或不新鲜", comment: ""),
                NSLocalizedString("环境应激（新环境、惊吓等）", comment: ""),
                NSLocalizedString("中毒", comment: "")
            ],
            suggestions: [
                NSLocalizedString("检查嗉囊是否膨大或有硬块（正常应柔软）", comment: ""),
                NSLocalizedString("检查口腔是否有白色斑点或异味", comment: ""),
                NSLocalizedString("更换新鲜食物和干净饮水", comment: ""),
                NSLocalizedString("尝试喂食鸟儿平时最喜欢的食物", comment: ""),
                NSLocalizedString("观察并记录粪便情况", comment: ""),
                NSLocalizedString("保持环境温暖（25-28°C）", comment: ""),
                NSLocalizedString("可尝试用注射器（去针头）滴喂少量温葡萄糖水", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("超过12-24小时不进食（紧急！）", comment: ""),
                NSLocalizedString("嗉囊肿胀、有酸臭味或触摸有硬块", comment: ""),
                NSLocalizedString("体重明显下降（超过10%）", comment: ""),
                NSLocalizedString("伴随呕吐或严重腹泻", comment: ""),
                NSLocalizedString("口腔有白色斑点或溃疡", comment: ""),
                NSLocalizedString("精神萎靡，反应迟钝", comment: "")
            ],
            prevention: [
                NSLocalizedString("每天提供新鲜食物和干净饮水", comment: ""),
                NSLocalizedString("定期清洗消毒食盆和水盆", comment: ""),
                NSLocalizedString("保持规律的喂食时间", comment: ""),
                NSLocalizedString("定期称重监测健康状况", comment: ""),
                NSLocalizedString("避免喂食变质或不适合的食物", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("腹泻/拉稀", comment: ""),
            description: NSLocalizedString("粪便呈水样或稀糊状，颜色可能异常（绿色、黄色、白色或带血），排便次数增多。正常鸟粪应该是成形的，中间白色（尿酸）周围深色（粪便）。", comment: ""),
            icon: "drop.triangle",
            severity: .high,
            category: NSLocalizedString("消化系统", comment: ""),
            possibleCauses: [
                NSLocalizedString("细菌性肠炎（大肠杆菌、沙门氏菌等）", comment: ""),
                NSLocalizedString("病毒感染", comment: ""),
                NSLocalizedString("寄生虫感染（球虫、滴虫等）", comment: ""),
                NSLocalizedString("念珠菌或其他真菌感染", comment: ""),
                NSLocalizedString("食物不洁、变质或中毒", comment: ""),
                NSLocalizedString("饮食突然改变", comment: ""),
                NSLocalizedString("应激反应", comment: ""),
                NSLocalizedString("摄入过多水分或水果", comment: ""),
                NSLocalizedString("抗生素使用后菌群失调", comment: "")
            ],
            suggestions: [
                NSLocalizedString("立即停止喂食水果、蔬菜和油性食物", comment: ""),
                NSLocalizedString("只提供干净的谷物和清水", comment: ""),
                NSLocalizedString("可在饮水中加入少量电解质补充液", comment: ""),
                NSLocalizedString("保持环境温暖（25-28°C），避免受凉", comment: ""),
                NSLocalizedString("及时清理粪便，保持笼内清洁干燥", comment: ""),
                NSLocalizedString("观察并记录粪便颜色、性状和频率", comment: ""),
                NSLocalizedString("隔离病鸟，防止传染", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("腹泻持续超过12-24小时", comment: ""),
                NSLocalizedString("粪便带血或呈黑色（可能内出血）", comment: ""),
                NSLocalizedString("粪便呈黄绿色水样且恶臭", comment: ""),
                NSLocalizedString("伴随呕吐或完全拒食", comment: ""),
                NSLocalizedString("精神萎靡，羽毛蓬松", comment: ""),
                NSLocalizedString("体重快速下降", comment: ""),
                NSLocalizedString("肛门周围被粪便污染严重", comment: "")
            ],
            prevention: [
                NSLocalizedString("每天更换新鲜食物和饮水", comment: ""),
                NSLocalizedString("定期清洗消毒食盆、水盆和鸟笼", comment: ""),
                NSLocalizedString("避免突然更换食物种类", comment: ""),
                NSLocalizedString("新鸟隔离观察2-4周后再合群", comment: ""),
                NSLocalizedString("定期驱虫（遵医嘱）", comment: ""),
                NSLocalizedString("夏季特别注意食物保鲜", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("呕吐/甩头吐食", comment: ""),
            description: NSLocalizedString("鸟儿频繁甩头并吐出食物或粘液。需区分正常的求偶喂食行为和病理性呕吐。病理性呕吐通常伴随精神萎靡，呕吐物可能有异味。", comment: ""),
            icon: "arrow.up.heart",
            severity: .high,
            category: NSLocalizedString("消化系统", comment: ""),
            possibleCauses: [
                NSLocalizedString("嗉囊炎（最常见原因）", comment: ""),
                NSLocalizedString("嗉囊积食或阻塞", comment: ""),
                NSLocalizedString("念珠菌感染", comment: ""),
                NSLocalizedString("细菌性感染", comment: ""),
                NSLocalizedString("寄生虫感染（滴虫等）", comment: ""),
                NSLocalizedString("中毒（重金属、有毒植物等）", comment: ""),
                NSLocalizedString("异物吞入", comment: ""),
                NSLocalizedString("胃部酵母菌过度繁殖", comment: "")
            ],
            suggestions: [
                NSLocalizedString("立即停止喂食，让嗉囊休息", comment: ""),
                NSLocalizedString("检查嗉囊是否膨大、有硬块或异味", comment: ""),
                NSLocalizedString("轻轻触摸嗉囊，正常应柔软无硬块", comment: ""),
                NSLocalizedString("检查呕吐物的颜色和气味", comment: ""),
                NSLocalizedString("保持环境温暖安静", comment: ""),
                NSLocalizedString("如嗉囊积食，可轻柔按摩帮助消化（需谨慎）", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("频繁呕吐超过2-3次", comment: ""),
                NSLocalizedString("呕吐物有酸臭味或异常颜色", comment: ""),
                NSLocalizedString("嗉囊明显肿胀或有硬块", comment: ""),
                NSLocalizedString("伴随腹泻或拒食", comment: ""),
                NSLocalizedString("精神萎靡，羽毛蓬松", comment: ""),
                NSLocalizedString("怀疑吞入异物或中毒", comment: "")
            ],
            prevention: [
                NSLocalizedString("控制喂食量，避免过度喂食", comment: ""),
                NSLocalizedString("手养幼鸟时注意奶温和喂食速度", comment: ""),
                NSLocalizedString("确保嗉囊排空后再喂下一餐", comment: ""),
                NSLocalizedString("提供易消化的食物", comment: ""),
                NSLocalizedString("避免接触有毒物质", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("呼吸困难/张嘴呼吸", comment: ""),
            description: NSLocalizedString("鸟儿张嘴呼吸、呼吸急促、尾巴随呼吸上下摆动，可能有喘息声或呼吸杂音。这是紧急情况，需立即处理。", comment: ""),
            icon: "lungs",
            severity: .high,
            category: NSLocalizedString("呼吸系统", comment: ""),
            possibleCauses: [
                NSLocalizedString("呼吸道感染（细菌、病毒、真菌）", comment: ""),
                NSLocalizedString("曲霉菌病（真菌性肺炎，常见且危险）", comment: ""),
                NSLocalizedString("气囊炎", comment: ""),
                NSLocalizedString("肺炎", comment: ""),
                NSLocalizedString("鹦鹉热/衣原体感染", comment: ""),
                NSLocalizedString("异物卡住气管", comment: ""),
                NSLocalizedString("心脏疾病", comment: ""),
                NSLocalizedString("特氟龙中毒（不粘锅过热产生的烟雾）", comment: ""),
                NSLocalizedString("过度肥胖压迫呼吸系统", comment: ""),
                NSLocalizedString("窦炎（眼睛下方肿胀）", comment: "")
            ],
            suggestions: [
                NSLocalizedString("这是紧急情况，应尽快就医！", comment: ""),
                NSLocalizedString("立即将鸟儿移至安静、温暖、通风的环境", comment: ""),
                NSLocalizedString("远离任何烟雾、香水、清洁剂等刺激源", comment: ""),
                NSLocalizedString("保持空气流通但避免冷风直吹", comment: ""),
                NSLocalizedString("不要强迫喂食或喂水", comment: ""),
                NSLocalizedString("减少惊扰，让鸟保持安静", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("出现呼吸困难症状应立即就医！", comment: ""),
                NSLocalizedString("张嘴呼吸持续不缓解", comment: ""),
                NSLocalizedString("呼吸时有明显杂音或喘息声", comment: ""),
                NSLocalizedString("尾巴随呼吸明显上下摆动", comment: ""),
                NSLocalizedString("嘴唇、舌头或脚爪发紫（缺氧）", comment: ""),
                NSLocalizedString("眼睛下方或鼻孔周围肿胀", comment: "")
            ],
            prevention: [
                NSLocalizedString("绝对避免使用不粘锅等含特氟龙的厨具（过热会释放致命毒气）", comment: ""),
                NSLocalizedString("保持空气清新，避免烟雾、香水、杀虫剂", comment: ""),
                NSLocalizedString("定期清洁鸟笼，避免霉菌滋生", comment: ""),
                NSLocalizedString("保持适宜的温湿度", comment: ""),
                NSLocalizedString("定期体检，早期发现问题", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("打喷嚏/流鼻涕", comment: ""),
            description: NSLocalizedString("鸟儿打喷嚏，鼻孔周围可能有分泌物或结痂。偶尔打喷嚏可能是灰尘刺激，但频繁打喷嚏需要重视。", comment: ""),
            icon: "nose",
            severity: .medium,
            category: NSLocalizedString("呼吸系统", comment: ""),
            possibleCauses: [
                NSLocalizedString("感冒（受凉、温度变化）", comment: ""),
                NSLocalizedString("上呼吸道感染", comment: ""),
                NSLocalizedString("窦炎", comment: ""),
                NSLocalizedString("空气中灰尘或异物刺激", comment: ""),
                NSLocalizedString("环境过于干燥", comment: ""),
                NSLocalizedString("对某些物质过敏", comment: ""),
                NSLocalizedString("维生素A缺乏", comment: ""),
                NSLocalizedString("鹦鹉热/衣原体感染（人畜共患病）", comment: "")
            ],
            suggestions: [
                NSLocalizedString("检查鼻孔是否通畅，有无分泌物", comment: ""),
                NSLocalizedString("将鸟笼移至避风温暖处（22-25°C）", comment: ""),
                NSLocalizedString("保持适当的空气湿度（50-60%）", comment: ""),
                NSLocalizedString("避免在鸟儿附近使用香水、清洁剂、杀虫剂", comment: ""),
                NSLocalizedString("如鼻孔有分泌物，可用棉签轻轻清理", comment: ""),
                NSLocalizedString("确保通风良好但避免直吹冷风", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("频繁打喷嚏，每天多次", comment: ""),
                NSLocalizedString("鼻孔有明显分泌物或结痂", comment: ""),
                NSLocalizedString("伴随呼吸困难或张嘴呼吸", comment: ""),
                NSLocalizedString("伴随眼睛红肿或流泪", comment: ""),
                NSLocalizedString("精神萎靡，食欲下降", comment: ""),
                NSLocalizedString("症状持续超过2-3天", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持环境清洁，定期除尘", comment: ""),
                NSLocalizedString("避免使用有刺激性气味的物品", comment: ""),
                NSLocalizedString("保持适宜的温湿度，避免温差过大", comment: ""),
                NSLocalizedString("提供富含维生素A的食物（如胡萝卜）", comment: "")
            ]
        ),
        
        // ========== 常见疾病 ==========
        BirdSymptom(
            name: NSLocalizedString("嗉囊炎/嗉囊积食", comment: ""),
            description: NSLocalizedString("嗉囊是鸟类食道的膨大部分，用于暂存和软化食物。嗉囊炎是最常见的消化道疾病之一，尤其多发于幼鸟。表现为嗉囊膨大、食物不消化、有酸臭味。", comment: ""),
            icon: "stomach",
            severity: .high,
            category: NSLocalizedString("消化系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("过度喂食或喂食过快（尤其是手养幼鸟）", comment: ""),
                NSLocalizedString("食物温度不当（过冷或过热）", comment: ""),
                NSLocalizedString("食物变质或不洁", comment: ""),
                NSLocalizedString("细菌感染（大肠杆菌等）", comment: ""),
                NSLocalizedString("念珠菌感染", comment: ""),
                NSLocalizedString("寄生虫（滴虫）感染", comment: ""),
                NSLocalizedString("异物吞入", comment: ""),
                NSLocalizedString("维生素和无机盐缺乏", comment: ""),
                NSLocalizedString("嗉囊肌肉功能障碍", comment: "")
            ],
            suggestions: [
                NSLocalizedString("立即停止喂食，让嗉囊休息6-12小时", comment: ""),
                NSLocalizedString("轻轻触摸嗉囊检查：正常应柔软，积食时有硬块", comment: ""),
                NSLocalizedString("轻症可喂服酵母片或乳酶生助消化", comment: ""),
                NSLocalizedString("可滴入少量温水或植物油软化食物", comment: ""),
                NSLocalizedString("轻柔按摩嗉囊帮助消化（从上往下）", comment: ""),
                NSLocalizedString("保持环境温暖（25-28°C）", comment: ""),
                NSLocalizedString("严重时需要洗胃，必须就医处理", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("嗉囊明显膨大超过12小时不消退", comment: ""),
                NSLocalizedString("嗉囊有酸臭味", comment: ""),
                NSLocalizedString("口腔有粘稠液体流出", comment: ""),
                NSLocalizedString("完全拒食或频繁呕吐", comment: ""),
                NSLocalizedString("精神极度萎靡", comment: ""),
                NSLocalizedString("怀疑吞入异物", comment: "")
            ],
            prevention: [
                NSLocalizedString("手养幼鸟时控制喂食量和速度", comment: ""),
                NSLocalizedString("确保食物温度适宜（38-40°C）", comment: ""),
                NSLocalizedString("等嗉囊排空后再喂下一餐", comment: ""),
                NSLocalizedString("保持食物和器具清洁", comment: ""),
                NSLocalizedString("提供易消化的食物", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("肠炎", comment: ""),
            description: NSLocalizedString("肠炎是鸟类最常见的消化道疾病，主要表现为腹泻。由细菌、病毒、寄生虫感染或食物不洁引起。夏季高发。", comment: ""),
            icon: "microbe",
            severity: .high,
            category: NSLocalizedString("消化系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("细菌感染（大肠杆菌、沙门氏菌等）", comment: ""),
                NSLocalizedString("病毒感染", comment: ""),
                NSLocalizedString("寄生虫感染（球虫、滴虫等）", comment: ""),
                NSLocalizedString("食物不洁、变质或发霉", comment: ""),
                NSLocalizedString("饮水不清洁", comment: ""),
                NSLocalizedString("季节变化、气候突变", comment: ""),
                NSLocalizedString("受寒", comment: "")
            ],
            suggestions: [
                NSLocalizedString("立即隔离病鸟", comment: ""),
                NSLocalizedString("停止喂食水果蔬菜，只给干净谷物", comment: ""),
                NSLocalizedString("提供干净饮水，可加入少量电解质", comment: ""),
                NSLocalizedString("保持环境温暖干燥", comment: ""),
                NSLocalizedString("及时清理粪便，消毒鸟笼", comment: ""),
                NSLocalizedString("可在饮水中加入0.1%土霉素（遵医嘱）", comment: ""),
                NSLocalizedString("严重脱水时需补充葡萄糖盐水", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("腹泻持续超过24小时", comment: ""),
                NSLocalizedString("粪便带血或呈黑色", comment: ""),
                NSLocalizedString("严重水样便", comment: ""),
                NSLocalizedString("伴随呕吐", comment: ""),
                NSLocalizedString("精神萎靡，羽毛蓬松", comment: ""),
                NSLocalizedString("体重快速下降", comment: "")
            ],
            prevention: [
                NSLocalizedString("每天更换新鲜食物和饮水", comment: ""),
                NSLocalizedString("夏季特别注意食物保鲜", comment: ""),
                NSLocalizedString("定期清洗消毒食盆水盆", comment: ""),
                NSLocalizedString("保持鸟笼清洁干燥", comment: ""),
                NSLocalizedString("新鸟隔离观察后再合群", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("念珠菌感染", comment: ""),
            description: NSLocalizedString("白色念珠菌是一种机会性真菌，正常存在于鸟类消化道。当鸟抵抗力下降或菌群失调时会过度繁殖致病。幼鸟和使用抗生素后的鸟更易感染。", comment: ""),
            icon: "allergens",
            severity: .high,
            category: NSLocalizedString("真菌感染", comment: ""),
            possibleCauses: [
                NSLocalizedString("抵抗力下降", comment: ""),
                NSLocalizedString("长期使用抗生素导致菌群失调", comment: ""),
                NSLocalizedString("营养不良", comment: ""),
                NSLocalizedString("环境卫生差", comment: ""),
                NSLocalizedString("手养幼鸟喂食器具不洁", comment: ""),
                NSLocalizedString("应激", comment: ""),
                NSLocalizedString("其他疾病继发", comment: "")
            ],
            suggestions: [
                NSLocalizedString("检查口腔是否有白色斑点或假膜", comment: ""),
                NSLocalizedString("检查嗉囊是否有异味", comment: ""),
                NSLocalizedString("停止使用抗生素（如正在使用）", comment: ""),
                NSLocalizedString("保持环境清洁干燥", comment: ""),
                NSLocalizedString("提供均衡营养", comment: ""),
                NSLocalizedString("需使用抗真菌药物治疗（制霉菌素等，遵医嘱）", comment: ""),
                NSLocalizedString("同时补充益生菌和维生素B族", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("口腔有白色斑点或假膜", comment: ""),
                NSLocalizedString("嗉囊有酸臭味", comment: ""),
                NSLocalizedString("频繁呕吐，食物未消化", comment: ""),
                NSLocalizedString("严重腹泻", comment: ""),
                NSLocalizedString("精神萎靡，消瘦", comment: ""),
                NSLocalizedString("幼鸟生长迟缓", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持食物和器具清洁", comment: ""),
                NSLocalizedString("避免滥用抗生素", comment: ""),
                NSLocalizedString("提供均衡营养", comment: ""),
                NSLocalizedString("保持环境干燥通风", comment: ""),
                NSLocalizedString("定期消毒鸟笼和用具", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("感冒/上呼吸道感染", comment: ""),
            description: NSLocalizedString("鸟类感冒多发于秋冬季节，由温度变化、受凉或细菌感染引起。表现为打喷嚏、流鼻涕、精神萎靡。如不及时治疗可能发展为肺炎。", comment: ""),
            icon: "thermometer.snowflake",
            severity: .medium,
            category: NSLocalizedString("呼吸系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("气温急剧变化", comment: ""),
                NSLocalizedString("受凉或淋雨", comment: ""),
                NSLocalizedString("冷风直吹", comment: ""),
                NSLocalizedString("环境温度过低", comment: ""),
                NSLocalizedString("细菌感染", comment: "")
            ],
            suggestions: [
                NSLocalizedString("立即将鸟笼移至避风温暖处", comment: ""),
                NSLocalizedString("保持室内温度稳定在22-25°C", comment: ""),
                NSLocalizedString("如鼻孔有分泌物，用棉签轻轻清理", comment: ""),
                NSLocalizedString("可用1%麻黄素溶液或植物油滴鼻通畅呼吸", comment: ""),
                NSLocalizedString("可在饲料中加入0.1-0.2%磺胺嘧啶，连喂3天", comment: ""),
                NSLocalizedString("或在饮水中加0.2%感冒通，连喂3-5天", comment: ""),
                NSLocalizedString("多喂些面包虫等营养食物", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("症状持续超过3天不见好转", comment: ""),
                NSLocalizedString("出现呼吸困难或张嘴呼吸", comment: ""),
                NSLocalizedString("鼻孔被粘稠分泌物堵塞", comment: ""),
                NSLocalizedString("精神极度萎靡", comment: ""),
                NSLocalizedString("伴随其他症状如腹泻", comment: "")
            ],
            prevention: [
                NSLocalizedString("避免将鸟笼放在空调直吹或窗边", comment: ""),
                NSLocalizedString("秋冬季节注意保暖", comment: ""),
                NSLocalizedString("避免温度剧烈变化", comment: ""),
                NSLocalizedString("保持环境通风但避免冷风直吹", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("肺炎", comment: ""),
            description: NSLocalizedString("肺炎是严重的呼吸道疾病，可由感冒发展而来，也可由细菌、真菌或病毒直接感染引起。死亡率较高，需及时治疗。", comment: ""),
            icon: "waveform.path.ecg",
            severity: .high,
            category: NSLocalizedString("呼吸系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("感冒治疗不及时恶化", comment: ""),
                NSLocalizedString("细菌感染（多杀性巴氏杆菌、大肠杆菌、肺炎双球菌等）", comment: ""),
                NSLocalizedString("曲霉菌等真菌感染", comment: ""),
                NSLocalizedString("病毒感染", comment: ""),
                NSLocalizedString("体质下降、抗病力降低", comment: "")
            ],
            suggestions: [
                NSLocalizedString("这是严重疾病，应尽快就医！", comment: ""),
                NSLocalizedString("将鸟放在暖和避风处，温度保持在22-25°C", comment: ""),
                NSLocalizedString("加强护理，喂给易消化的食物和活虫", comment: ""),
                NSLocalizedString("可用泰乐菌素治疗（混料0.05-0.08%，连服5天）", comment: ""),
                NSLocalizedString("或用庆大霉素加在饮水中（每次5-10滴，每天2次，连喂5-7天）", comment: ""),
                NSLocalizedString("补充体液：用滴管滴入葡萄糖水，每次0.5ml，每天2-3次", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("呼吸急促、气喘", comment: ""),
                NSLocalizedString("身体随呼吸颤抖", comment: ""),
                NSLocalizedString("全身缩起呈球状", comment: ""),
                NSLocalizedString("精神极度萎靡，食欲废绝", comment: ""),
                NSLocalizedString("体温明显升高", comment: "")
            ],
            prevention: [
                NSLocalizedString("感冒要及时治疗，防止恶化", comment: ""),
                NSLocalizedString("保持环境温暖稳定", comment: ""),
                NSLocalizedString("加强营养，提高抵抗力", comment: ""),
                NSLocalizedString("保持环境清洁卫生", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("曲霉菌病", comment: ""),
            description: NSLocalizedString("曲霉菌病是由曲霉菌引起的真菌性呼吸道感染，主要侵害气囊和肺部。环境潮湿、通风不良、饲料发霉是主要诱因。此病较难治愈，重在预防。", comment: ""),
            icon: "aqi.medium",
            severity: .high,
            category: NSLocalizedString("真菌感染", comment: ""),
            possibleCauses: [
                NSLocalizedString("环境潮湿、通风不良", comment: ""),
                NSLocalizedString("饲料发霉", comment: ""),
                NSLocalizedString("垫料潮湿发霉", comment: ""),
                NSLocalizedString("鸟笼清洁不彻底", comment: ""),
                NSLocalizedString("抵抗力下降", comment: ""),
                NSLocalizedString("长期使用抗生素", comment: "")
            ],
            suggestions: [
                NSLocalizedString("此病治疗困难，必须就医！", comment: ""),
                NSLocalizedString("改善环境通风，降低湿度", comment: ""),
                NSLocalizedString("彻底清洁消毒鸟笼", comment: ""),
                NSLocalizedString("更换所有饲料和垫料", comment: ""),
                NSLocalizedString("检查并丢弃任何发霉的食物", comment: ""),
                NSLocalizedString("需使用抗真菌药物治疗（两性霉素B、伊曲康唑等，遵医嘱）", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("呼吸困难、张嘴呼吸", comment: ""),
                NSLocalizedString("呼吸时有杂音", comment: ""),
                NSLocalizedString("精神萎靡，食欲下降", comment: ""),
                NSLocalizedString("消瘦", comment: ""),
                NSLocalizedString("症状持续不见好转", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持环境干燥通风（这是最重要的！）", comment: ""),
                NSLocalizedString("定期检查饲料，丢弃任何发霉的食物", comment: ""),
                NSLocalizedString("定期清洁消毒鸟笼", comment: ""),
                NSLocalizedString("保持垫料干燥，定期更换", comment: ""),
                NSLocalizedString("避免滥用抗生素", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("滴虫病", comment: ""),
            description: NSLocalizedString("滴虫病是由毛滴虫引起的寄生虫病，主要侵害消化道和呼吸道。通过污染的饮水和食物传播，也可通过亲鸟喂食传给幼鸟。", comment: ""),
            icon: "ant",
            severity: .high,
            category: NSLocalizedString("寄生虫病", comment: ""),
            possibleCauses: [
                NSLocalizedString("饮水或食物被滴虫污染", comment: ""),
                NSLocalizedString("与感染鸟接触", comment: ""),
                NSLocalizedString("亲鸟喂食传播给幼鸟", comment: ""),
                NSLocalizedString("环境卫生差", comment: "")
            ],
            suggestions: [
                NSLocalizedString("需要显微镜检查确诊", comment: ""),
                NSLocalizedString("隔离病鸟", comment: ""),
                NSLocalizedString("使用甲硝唑治疗（遵医嘱）", comment: ""),
                NSLocalizedString("彻底清洁消毒环境", comment: ""),
                NSLocalizedString("更换所有饮水和食物", comment: ""),
                NSLocalizedString("治疗期间注意环境消毒", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("口腔有黄白色干酪样物质", comment: ""),
                NSLocalizedString("吞咽困难", comment: ""),
                NSLocalizedString("频繁呕吐", comment: ""),
                NSLocalizedString("嗉囊肿胀", comment: ""),
                NSLocalizedString("呼吸困难（严重时）", comment: ""),
                NSLocalizedString("消瘦、精神萎靡", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持饮水清洁，每天更换", comment: ""),
                NSLocalizedString("定期清洁消毒水盆", comment: ""),
                NSLocalizedString("新鸟隔离检疫", comment: ""),
                NSLocalizedString("避免与野鸟接触", comment: ""),
                NSLocalizedString("定期驱虫检查", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("啄羽症/自残", comment: ""),
            description: NSLocalizedString("鸟儿频繁啄自己或同伴的羽毛，导致羽毛脱落、皮肤裸露甚至出血。这是一种复杂的行为问题，可能由生理或心理因素引起。", comment: ""),
            icon: "hand.raised.slash",
            severity: .medium,
            category: NSLocalizedString("行为异常", comment: ""),
            possibleCauses: [
                NSLocalizedString("营养缺乏（氨基酸、维生素B族、锌、硫等）", comment: ""),
                NSLocalizedString("体外寄生虫（羽虱、螨虫）刺激", comment: ""),
                NSLocalizedString("皮肤病", comment: ""),
                NSLocalizedString("无聊、缺乏刺激", comment: ""),
                NSLocalizedString("焦虑、压力过大", comment: ""),
                NSLocalizedString("笼内密度过大", comment: ""),
                NSLocalizedString("光照过强或过热", comment: ""),
                NSLocalizedString("激素变化（发情期）", comment: "")
            ],
            suggestions: [
                NSLocalizedString("检查是否有体外寄生虫", comment: ""),
                NSLocalizedString("调整饲料配比，增加蛋黄、维生素、微量元素", comment: ""),
                NSLocalizedString("加喂羽毛粉和钙粉", comment: ""),
                NSLocalizedString("提供新鲜水果蔬菜", comment: ""),
                NSLocalizedString("增加玩具和互动时间", comment: ""),
                NSLocalizedString("如有寄生虫，使用相应药物治疗", comment: ""),
                NSLocalizedString("保持适当的光照和温度", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("皮肤出现伤口或出血", comment: ""),
                NSLocalizedString("大面积羽毛脱落", comment: ""),
                NSLocalizedString("发现寄生虫", comment: ""),
                NSLocalizedString("伴随其他异常症状", comment: ""),
                NSLocalizedString("行为持续恶化", comment: "")
            ],
            prevention: [
                NSLocalizedString("提供均衡营养的饮食", comment: ""),
                NSLocalizedString("定期检查和预防体外寄生虫", comment: ""),
                NSLocalizedString("提供丰富的环境刺激", comment: ""),
                NSLocalizedString("保持规律的互动时间", comment: ""),
                NSLocalizedString("避免笼内过度拥挤", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("结膜炎/眼炎", comment: ""),
            description: NSLocalizedString("眼睛红肿、流泪、有分泌物，眼睑可能肿胀粘连。可由外伤、异物、感染或维生素缺乏引起。", comment: ""),
            icon: "eye",
            severity: .medium,
            category: NSLocalizedString("眼部疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("细菌或病毒感染", comment: ""),
                NSLocalizedString("异物进入眼睛", comment: ""),
                NSLocalizedString("眼部外伤", comment: ""),
                NSLocalizedString("维生素A缺乏", comment: ""),
                NSLocalizedString("上呼吸道感染蔓延", comment: ""),
                NSLocalizedString("窦炎继发", comment: "")
            ],
            suggestions: [
                NSLocalizedString("将鸟笼移至暗处，减少光线刺激", comment: ""),
                NSLocalizedString("用1-2%硼酸溶液或生理盐水冲洗患眼", comment: ""),
                NSLocalizedString("滴入金霉素、氯霉素或土霉素眼药水/眼膏", comment: ""),
                NSLocalizedString("每天3-6次", comment: ""),
                NSLocalizedString("在饲料中添加维生素A或鱼肝油", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("眼睛明显红肿或有脓性分泌物", comment: ""),
                NSLocalizedString("眼睛无法睁开", comment: ""),
                NSLocalizedString("上下眼睑粘连", comment: ""),
                NSLocalizedString("视力似乎受到影响", comment: ""),
                NSLocalizedString("症状持续超过2-3天", comment: ""),
                NSLocalizedString("伴随其他症状", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持环境清洁，减少灰尘", comment: ""),
                NSLocalizedString("提供富含维生素A的食物", comment: ""),
                NSLocalizedString("避免尖锐物品伤害", comment: ""),
                NSLocalizedString("定期检查眼睛健康", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("中暑", comment: ""),
            description: NSLocalizedString("夏季高温时，如果环境闷热、通风差、饮水不足，鸟类容易中暑。鸟没有汗腺，散热困难，中暑可在几分钟内致死。", comment: ""),
            icon: "sun.max.trianglebadge.exclamationmark",
            severity: .high,
            category: NSLocalizedString("环境相关", comment: ""),
            possibleCauses: [
                NSLocalizedString("环境温度过高", comment: ""),
                NSLocalizedString("通风不良、闷热", comment: ""),
                NSLocalizedString("阳光直射", comment: ""),
                NSLocalizedString("饮水供给不足", comment: ""),
                NSLocalizedString("运输过程中拥挤闷热", comment: "")
            ],
            suggestions: [
                NSLocalizedString("这是紧急情况！", comment: ""),
                NSLocalizedString("立即将鸟笼移至阴凉通风处", comment: ""),
                NSLocalizedString("每隔一段时间喷洒冷水降温", comment: ""),
                NSLocalizedString("提供清凉的饮水", comment: ""),
                NSLocalizedString("可在绿豆汤中加1-2滴十滴水灌服", comment: ""),
                NSLocalizedString("严重时可在翅膀静脉处放血（需专业操作）", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("出现中暑症状应紧急处理", comment: ""),
                NSLocalizedString("呼吸急促、张口喘气", comment: ""),
                NSLocalizedString("翅膀张开下垂", comment: ""),
                NSLocalizedString("站立不稳、虚脱", comment: ""),
                NSLocalizedString("抽搐或痉挛", comment: "")
            ],
            prevention: [
                NSLocalizedString("夏季将鸟笼放在凉爽通风处", comment: ""),
                NSLocalizedString("避免阳光直射", comment: ""),
                NSLocalizedString("每天提供充足清凉的饮水", comment: ""),
                NSLocalizedString("闷热天气可每天给鸟洗浴1次", comment: ""),
                NSLocalizedString("经常观察鸟的状态", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("尾脂腺炎（生黄）", comment: ""),
            description: NSLocalizedString("尾脂腺位于鸟尾部上方，分泌油脂用于梳理羽毛。当腺体阻塞发炎时，会红肿化脓。常见于画眉、百灵等鸟类。", comment: ""),
            icon: "drop.fill",
            severity: .medium,
            category: NSLocalizedString("皮肤疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("缺乏沙浴或水浴", comment: ""),
                NSLocalizedString("尾部受伤感染", comment: ""),
                NSLocalizedString("长期不理羽毛导致腺体阻塞", comment: ""),
                NSLocalizedString("患病期间不梳理羽毛", comment: "")
            ],
            suggestions: [
                NSLocalizedString("用5%碘酊和75%酒精消毒患处", comment: ""),
                NSLocalizedString("用消毒针刺破尾脂腺尖", comment: ""),
                NSLocalizedString("轻轻挤压排出阻塞的分泌物", comment: ""),
                NSLocalizedString("用脱脂棉擦净后涂5%碘酊消毒", comment: ""),
                NSLocalizedString("半天内不要喂水", comment: ""),
                NSLocalizedString("痊愈前停止沙浴、水浴", comment: ""),
                NSLocalizedString("多喂营养丰富的食物", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("尾脂腺明显红肿化脓", comment: ""),
                NSLocalizedString("有大量脓性分泌物", comment: ""),
                NSLocalizedString("伴随发热、精神萎靡", comment: ""),
                NSLocalizedString("自行处理后不见好转", comment: "")
            ],
            prevention: [
                NSLocalizedString("定期提供沙浴或水浴", comment: ""),
                NSLocalizedString("保持鸟笼清洁", comment: ""),
                NSLocalizedString("观察鸟是否正常梳理羽毛", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("趾炎/脚部感染", comment: ""),
            description: NSLocalizedString("脚趾红肿、发热、疼痛，严重时化脓甚至趾骨脱落。多因脚部受伤后被粪便污染感染引起。", comment: ""),
            icon: "figure.stand",
            severity: .medium,
            category: NSLocalizedString("外伤感染", comment: ""),
            possibleCauses: [
                NSLocalizedString("脚掌被粗糙的栖木或笼底划伤", comment: ""),
                NSLocalizedString("伤口被粪便污染感染", comment: ""),
                NSLocalizedString("葡萄球菌感染", comment: ""),
                NSLocalizedString("冻伤", comment: ""),
                NSLocalizedString("笼内卫生差", comment: "")
            ],
            suggestions: [
                NSLocalizedString("用0.5%高锰酸钾水或盐水浸泡患脚1-2分钟", comment: ""),
                NSLocalizedString("涂抹碘酒或红药水", comment: ""),
                NSLocalizedString("可涂四环素、金霉素或红霉素软膏", comment: ""),
                NSLocalizedString("在饲料中加喂螺旋霉素或氟哌酸（遵医嘱）", comment: ""),
                NSLocalizedString("保持鸟笼清洁", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("脚趾明显肿胀化脓", comment: ""),
                NSLocalizedString("无法正常站立或抓握", comment: ""),
                NSLocalizedString("有干酪样渗出物", comment: ""),
                NSLocalizedString("症状持续恶化", comment: "")
            ],
            prevention: [
                NSLocalizedString("使用光滑适当粗细的栖木", comment: ""),
                NSLocalizedString("每天清理鸟笼粪便", comment: ""),
                NSLocalizedString("定期消毒鸟笼", comment: ""),
                NSLocalizedString("冬季注意保暖防冻", comment: "")
            ]
        ),
        
        // ========== 病毒性疾病 ==========
        BirdSymptom(
            name: NSLocalizedString("鹦鹉喙羽症(PBFD)", comment: ""),
            description: NSLocalizedString("由圆环病毒引起的致死性传染病，主要影响羽毛和喙部。病毒攻击羽毛毛囊、喙和爪基质，导致进行性羽毛、爪和喙的畸形和坏死。多见于3岁以下幼鸟，目前无法治愈。", comment: ""),
            icon: "exclamationmark.shield",
            severity: .high,
            category: NSLocalizedString("病毒性疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("圆环病毒(Circovirus)感染", comment: ""),
                NSLocalizedString("通过粪便、羽毛屑、嗉囊分泌物传播", comment: ""),
                NSLocalizedString("垂直传播（母鸟传给幼鸟）", comment: ""),
                NSLocalizedString("与感染鸟接触", comment: "")
            ],
            suggestions: [
                NSLocalizedString("目前无法治愈，只能支持性治疗", comment: ""),
                NSLocalizedString("立即隔离疑似感染鸟", comment: ""),
                NSLocalizedString("加强营养支持，提高免疫力", comment: ""),
                NSLocalizedString("保持环境清洁", comment: ""),
                NSLocalizedString("定期检测，早期发现", comment: ""),
                NSLocalizedString("考虑安乐死以防止传播（严重情况）", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("羽毛异常脱落或变形", comment: ""),
                NSLocalizedString("新长出的羽毛畸形、卷曲或断裂", comment: ""),
                NSLocalizedString("喙部变形、过度生长或断裂", comment: ""),
                NSLocalizedString("羽毛颜色异常改变", comment: ""),
                NSLocalizedString("免疫力下降，反复感染", comment: "")
            ],
            prevention: [
                NSLocalizedString("新鸟隔离检疫至少30天", comment: ""),
                NSLocalizedString("购买前进行PBFD检测", comment: ""),
                NSLocalizedString("避免与野鸟接触", comment: ""),
                NSLocalizedString("定期消毒鸟笼和用具", comment: ""),
                NSLocalizedString("不与来源不明的鸟混养", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("多瘤病毒感染", comment: ""),
            description: NSLocalizedString("多瘤病毒(APV)主要影响幼鸟，可导致突然死亡。成年鸟可能携带病毒但无症状。幼鸟感染后死亡率极高，存活者可能出现羽毛发育异常。", comment: ""),
            icon: "bolt.trianglebadge.exclamationmark",
            severity: .high,
            category: NSLocalizedString("病毒性疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("多瘤病毒感染", comment: ""),
                NSLocalizedString("通过粪便、羽毛、嗉囊分泌物传播", comment: ""),
                NSLocalizedString("垂直传播", comment: ""),
                NSLocalizedString("与感染鸟或其排泄物接触", comment: "")
            ],
            suggestions: [
                NSLocalizedString("目前无特效治疗", comment: ""),
                NSLocalizedString("立即隔离病鸟", comment: ""),
                NSLocalizedString("支持性治疗：保温、补液、营养支持", comment: ""),
                NSLocalizedString("彻底消毒环境", comment: ""),
                NSLocalizedString("存活幼鸟可能终身携带病毒", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("幼鸟突然死亡", comment: ""),
                NSLocalizedString("食欲废绝、呕吐", comment: ""),
                NSLocalizedString("体重下降、消瘦", comment: ""),
                NSLocalizedString("皮下出血点", comment: ""),
                NSLocalizedString("羽毛发育异常（存活者）", comment: ""),
                NSLocalizedString("腹部肿胀", comment: "")
            ],
            prevention: [
                NSLocalizedString("可接种疫苗预防", comment: ""),
                NSLocalizedString("新鸟严格隔离检疫", comment: ""),
                NSLocalizedString("繁殖前进行病毒检测", comment: ""),
                NSLocalizedString("保持严格的卫生管理", comment: ""),
                NSLocalizedString("避免不同来源的鸟混养", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("前胃扩张症(PDD)", comment: ""),
            description: NSLocalizedString("又称鸟类博尔纳病，由禽博尔纳病毒引起，主要影响消化系统和神经系统。病毒导致前胃（腺胃）扩张，食物无法正常消化。此病目前无法治愈，预后较差。", comment: ""),
            icon: "waveform.path.ecg.rectangle",
            severity: .high,
            category: NSLocalizedString("病毒性疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("禽博尔纳病毒(ABV)感染", comment: ""),
                NSLocalizedString("通过粪便传播", comment: ""),
                NSLocalizedString("可能通过羽毛屑传播", comment: ""),
                NSLocalizedString("发病机制尚未完全明确", comment: "")
            ],
            suggestions: [
                NSLocalizedString("目前无法治愈", comment: ""),
                NSLocalizedString("使用非甾体抗炎药可能缓解症状", comment: ""),
                NSLocalizedString("提供易消化的食物", comment: ""),
                NSLocalizedString("少量多餐", comment: ""),
                NSLocalizedString("保持环境安静，减少应激", comment: ""),
                NSLocalizedString("隔离病鸟", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("频繁呕吐，吐出未消化的食物", comment: ""),
                NSLocalizedString("粪便中有未消化的种子", comment: ""),
                NSLocalizedString("体重持续下降", comment: ""),
                NSLocalizedString("嗉囊排空缓慢", comment: ""),
                NSLocalizedString("神经症状：共济失调、震颤、抽搐", comment: ""),
                NSLocalizedString("头部倾斜或转圈", comment: "")
            ],
            prevention: [
                NSLocalizedString("新鸟隔离检疫", comment: ""),
                NSLocalizedString("避免与感染鸟接触", comment: ""),
                NSLocalizedString("保持良好的卫生习惯", comment: ""),
                NSLocalizedString("定期健康检查", comment: "")
            ]
        ),
        
        // ========== 细菌性疾病 ==========
        BirdSymptom(
            name: NSLocalizedString("鹦鹉热/衣原体病", comment: ""),
            description: NSLocalizedString("由鹦鹉热衣原体引起的人畜共患病，可传染给人类。病鸟可能长期带菌排毒。人感染后出现类似流感的症状，严重可致肺炎。养鸟者需特别注意防护。", comment: ""),
            icon: "person.badge.shield.checkmark",
            severity: .high,
            category: NSLocalizedString("细菌性疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("鹦鹉热衣原体(Chlamydia psittaci)感染", comment: ""),
                NSLocalizedString("吸入含病原体的粉尘（干燥粪便、羽毛屑）", comment: ""),
                NSLocalizedString("与感染鸟密切接触", comment: ""),
                NSLocalizedString("应激可激活潜伏感染", comment: "")
            ],
            suggestions: [
                NSLocalizedString("立即隔离病鸟", comment: ""),
                NSLocalizedString("使用抗生素治疗（四环素类，遵医嘱）", comment: ""),
                NSLocalizedString("治疗周期通常需要45天", comment: ""),
                NSLocalizedString("人员接触时戴口罩", comment: ""),
                NSLocalizedString("彻底消毒环境（2%漂白粉或5%甲酚皂液）", comment: ""),
                NSLocalizedString("如人出现流感样症状需就医并告知养鸟史", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("绿色腹泻", comment: ""),
                NSLocalizedString("鼻腔分泌物", comment: ""),
                NSLocalizedString("呼吸困难", comment: ""),
                NSLocalizedString("眼睛红肿、流泪", comment: ""),
                NSLocalizedString("精神萎靡、食欲下降", comment: ""),
                NSLocalizedString("羽毛蓬松", comment: "")
            ],
            prevention: [
                NSLocalizedString("新鸟隔离检疫并检测", comment: ""),
                NSLocalizedString("保持良好通风", comment: ""),
                NSLocalizedString("清理鸟笼时戴口罩", comment: ""),
                NSLocalizedString("定期消毒", comment: ""),
                NSLocalizedString("避免鸟粪干燥后扬尘", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("禽分枝杆菌病", comment: ""),
            description: NSLocalizedString("由禽分枝杆菌引起的慢性消耗性疾病，病程长，治疗困难。主要影响消化系统，导致慢性消瘦。有潜在的人畜共患风险。", comment: ""),
            icon: "staroflife",
            severity: .high,
            category: NSLocalizedString("细菌性疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("禽分枝杆菌感染", comment: ""),
                NSLocalizedString("通过粪便-口腔途径传播", comment: ""),
                NSLocalizedString("污染的食物和饮水", comment: ""),
                NSLocalizedString("免疫力低下时易感", comment: "")
            ],
            suggestions: [
                NSLocalizedString("治疗非常困难，需长期抗生素", comment: ""),
                NSLocalizedString("隔离病鸟", comment: ""),
                NSLocalizedString("彻底消毒环境", comment: ""),
                NSLocalizedString("考虑安乐死（严重情况）", comment: ""),
                NSLocalizedString("接触病鸟后注意个人卫生", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("慢性消瘦，体重持续下降", comment: ""),
                NSLocalizedString("腹泻", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("羽毛质量下降", comment: ""),
                NSLocalizedString("腹部可能有肿块", comment: "")
            ],
            prevention: [
                NSLocalizedString("新鸟隔离检疫", comment: ""),
                NSLocalizedString("保持环境清洁", comment: ""),
                NSLocalizedString("避免与野鸟接触", comment: ""),
                NSLocalizedString("定期健康检查", comment: "")
            ]
        ),
        
        // ========== 寄生虫病 ==========
        BirdSymptom(
            name: NSLocalizedString("球虫病", comment: ""),
            description: NSLocalizedString("由球虫（艾美耳球虫）引起的肠道寄生虫病，主要通过粪便-口腔途径传播。幼鸟和免疫力低下的鸟更易感染，可导致严重腹泻和死亡。", comment: ""),
            icon: "ant.circle",
            severity: .high,
            category: NSLocalizedString("寄生虫病", comment: ""),
            possibleCauses: [
                NSLocalizedString("艾美耳球虫感染", comment: ""),
                NSLocalizedString("摄入被球虫卵囊污染的食物或水", comment: ""),
                NSLocalizedString("环境卫生差", comment: ""),
                NSLocalizedString("免疫力低下", comment: "")
            ],
            suggestions: [
                NSLocalizedString("使用抗球虫药物治疗（遵医嘱）", comment: ""),
                NSLocalizedString("隔离病鸟", comment: ""),
                NSLocalizedString("彻底清洁消毒环境", comment: ""),
                NSLocalizedString("保持环境干燥", comment: ""),
                NSLocalizedString("补充电解质和营养", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("血便或带血腹泻", comment: ""),
                NSLocalizedString("严重腹泻、脱水", comment: ""),
                NSLocalizedString("体重下降", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("幼鸟生长迟缓", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持环境清洁干燥", comment: ""),
                NSLocalizedString("定期清理粪便", comment: ""),
                NSLocalizedString("避免粪便污染食物和水", comment: ""),
                NSLocalizedString("新鸟隔离检疫", comment: ""),
                NSLocalizedString("定期粪便检查", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("贾第虫病", comment: ""),
            description: NSLocalizedString("由贾第鞭毛虫引起的肠道寄生虫病，可导致皮肤瘙痒、羽毛问题和腹泻。此病为人畜共患病，可通过污染的水源传播给人。", comment: ""),
            icon: "drop.degreesign",
            severity: .medium,
            category: NSLocalizedString("寄生虫病", comment: ""),
            possibleCauses: [
                NSLocalizedString("贾第鞭毛虫感染", comment: ""),
                NSLocalizedString("饮用被污染的水", comment: ""),
                NSLocalizedString("与感染鸟接触", comment: ""),
                NSLocalizedString("环境卫生差", comment: "")
            ],
            suggestions: [
                NSLocalizedString("使用抗寄生虫药物治疗（甲硝唑等，遵医嘱）", comment: ""),
                NSLocalizedString("更换干净的饮水", comment: ""),
                NSLocalizedString("彻底清洁消毒水盆", comment: ""),
                NSLocalizedString("保持环境清洁", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("频繁瘙痒、啄羽", comment: ""),
                NSLocalizedString("皮肤干燥", comment: ""),
                NSLocalizedString("腹泻", comment: ""),
                NSLocalizedString("羽毛质量下降", comment: ""),
                NSLocalizedString("体重下降", comment: "")
            ],
            prevention: [
                NSLocalizedString("提供干净的饮水", comment: ""),
                NSLocalizedString("定期清洗消毒水盆", comment: ""),
                NSLocalizedString("保持环境卫生", comment: ""),
                NSLocalizedString("定期粪便检查", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("气囊螨", comment: ""),
            description: NSLocalizedString("气囊螨寄生在鸟类的气囊和气管中，导致呼吸困难。常见于雀类和小型鹦鹉。感染严重时可导致窒息死亡。", comment: ""),
            icon: "wind.circle",
            severity: .high,
            category: NSLocalizedString("寄生虫病", comment: ""),
            possibleCauses: [
                NSLocalizedString("气囊螨寄生", comment: ""),
                NSLocalizedString("与感染鸟接触", comment: ""),
                NSLocalizedString("通过呼吸道传播", comment: "")
            ],
            suggestions: [
                NSLocalizedString("需要兽医治疗", comment: ""),
                NSLocalizedString("使用伊维菌素等药物（遵医嘱）", comment: ""),
                NSLocalizedString("隔离病鸟", comment: ""),
                NSLocalizedString("彻底消毒环境", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("呼吸时有喘息声或咔嗒声", comment: ""),
                NSLocalizedString("张嘴呼吸", comment: ""),
                NSLocalizedString("声音嘶哑或改变", comment: ""),
                NSLocalizedString("呼吸困难", comment: ""),
                NSLocalizedString("尾巴随呼吸摆动", comment: "")
            ],
            prevention: [
                NSLocalizedString("新鸟隔离检疫", comment: ""),
                NSLocalizedString("避免与野鸟接触", comment: ""),
                NSLocalizedString("定期健康检查", comment: ""),
                NSLocalizedString("保持环境清洁", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("羽虱/羽螨", comment: ""),
            description: NSLocalizedString("羽虱和羽螨是常见的体外寄生虫，寄生在羽毛和皮肤上，吸食血液或啃食羽毛。导致鸟儿瘙痒、烦躁、羽毛损坏。", comment: ""),
            icon: "ladybug",
            severity: .medium,
            category: NSLocalizedString("寄生虫病", comment: ""),
            possibleCauses: [
                NSLocalizedString("与感染鸟接触", comment: ""),
                NSLocalizedString("从野鸟传播", comment: ""),
                NSLocalizedString("环境中存在寄生虫", comment: ""),
                NSLocalizedString("鸟笼和巢箱不清洁", comment: "")
            ],
            suggestions: [
                NSLocalizedString("使用鸟类专用杀虫剂或药浴", comment: ""),
                NSLocalizedString("可用神奇药笔涂抹（注意安全）", comment: ""),
                NSLocalizedString("彻底清洁消毒鸟笼和巢箱", comment: ""),
                NSLocalizedString("用开水烫洗巢箱", comment: ""),
                NSLocalizedString("阳光暴晒鸟笼", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("频繁瘙痒、啄羽", comment: ""),
                NSLocalizedString("羽毛损坏、脱落", comment: ""),
                NSLocalizedString("皮肤可见寄生虫或虫卵", comment: ""),
                NSLocalizedString("贫血（严重感染时）", comment: ""),
                NSLocalizedString("烦躁不安、睡眠差", comment: "")
            ],
            prevention: [
                NSLocalizedString("定期检查羽毛和皮肤", comment: ""),
                NSLocalizedString("保持鸟笼清洁", comment: ""),
                NSLocalizedString("定期消毒巢箱", comment: ""),
                NSLocalizedString("新鸟隔离检疫", comment: ""),
                NSLocalizedString("避免与野鸟接触", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("疥螨病(脸部疥癣)", comment: ""),
            description: NSLocalizedString("由疥螨(Knemidokoptes)引起，主要侵害喙部、蜡膜、眼周和脚部。形成灰白色蜂窝状或海绵状痂皮，严重时导致喙部变形。常见于虎皮鹦鹉。", comment: ""),
            icon: "face.dashed",
            severity: .medium,
            category: NSLocalizedString("寄生虫病", comment: ""),
            possibleCauses: [
                NSLocalizedString("疥螨感染", comment: ""),
                NSLocalizedString("与感染鸟接触", comment: ""),
                NSLocalizedString("免疫力低下时易发病", comment: ""),
                NSLocalizedString("很多鸟携带但不发病", comment: "")
            ],
            suggestions: [
                NSLocalizedString("使用伊维菌素治疗（遵医嘱）", comment: ""),
                NSLocalizedString("可涂抹凡士林或矿物油窒息螨虫", comment: ""),
                NSLocalizedString("隔离病鸟", comment: ""),
                NSLocalizedString("彻底消毒鸟笼", comment: ""),
                NSLocalizedString("治疗需要持续数周", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("喙部、蜡膜出现灰白色痂皮", comment: ""),
                NSLocalizedString("眼周出现结痂", comment: ""),
                NSLocalizedString("脚部出现鳞片状增厚", comment: ""),
                NSLocalizedString("喙部变形", comment: ""),
                NSLocalizedString("严重瘙痒", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持鸟儿健康，增强免疫力", comment: ""),
                NSLocalizedString("新鸟隔离检疫", comment: ""),
                NSLocalizedString("定期检查喙部和脚部", comment: ""),
                NSLocalizedString("保持环境清洁", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("蛔虫/绦虫感染", comment: ""),
            description: NSLocalizedString("肠道寄生虫感染，蛔虫和绦虫是最常见的类型。通过粪便-口腔途径传播，可导致消瘦、腹泻和营养不良。", comment: ""),
            icon: "arrow.triangle.2.circlepath",
            severity: .medium,
            category: NSLocalizedString("寄生虫病", comment: ""),
            possibleCauses: [
                NSLocalizedString("摄入被虫卵污染的食物或水", comment: ""),
                NSLocalizedString("摄入中间宿主（如昆虫）", comment: ""),
                NSLocalizedString("环境卫生差", comment: ""),
                NSLocalizedString("与感染鸟接触", comment: "")
            ],
            suggestions: [
                NSLocalizedString("使用驱虫药治疗（遵医嘱）", comment: ""),
                NSLocalizedString("彻底清洁消毒环境", comment: ""),
                NSLocalizedString("更换所有垫料", comment: ""),
                NSLocalizedString("定期驱虫", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("粪便中可见虫体", comment: ""),
                NSLocalizedString("体重下降、消瘦", comment: ""),
                NSLocalizedString("腹泻", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("羽毛质量下降", comment: "")
            ],
            prevention: [
                NSLocalizedString("定期驱虫（每3-6个月）", comment: ""),
                NSLocalizedString("保持环境清洁", comment: ""),
                NSLocalizedString("避免喂食野外捕捉的昆虫", comment: ""),
                NSLocalizedString("定期粪便检查", comment: "")
            ]
        ),
        
        // ========== 营养代谢病 ==========
        BirdSymptom(
            name: NSLocalizedString("维生素A缺乏症", comment: ""),
            description: NSLocalizedString("维生素A缺乏是鹦鹉最常见的营养问题之一，主要因长期只吃种子饲料导致。影响皮肤、黏膜和免疫系统，增加感染风险。", comment: ""),
            icon: "carrot",
            severity: .medium,
            category: NSLocalizedString("营养代谢病", comment: ""),
            possibleCauses: [
                NSLocalizedString("长期只吃种子饲料", comment: ""),
                NSLocalizedString("饮食单一，缺乏蔬果", comment: ""),
                NSLocalizedString("吸收障碍", comment: "")
            ],
            suggestions: [
                NSLocalizedString("补充维生素A（遵医嘱）", comment: ""),
                NSLocalizedString("增加富含维生素A的食物：胡萝卜、红薯、深绿色蔬菜", comment: ""),
                NSLocalizedString("改善饮食结构，增加蔬果比例", comment: ""),
                NSLocalizedString("可添加鱼肝油", comment: ""),
                NSLocalizedString("严重者需注射补充", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("口腔、鼻腔黏膜增厚", comment: ""),
                NSLocalizedString("口腔出现白色斑点或脓肿", comment: ""),
                NSLocalizedString("眼睛问题", comment: ""),
                NSLocalizedString("呼吸道反复感染", comment: ""),
                NSLocalizedString("皮肤干燥、羽毛质量差", comment: ""),
                NSLocalizedString("肾脏问题", comment: "")
            ],
            prevention: [
                NSLocalizedString("提供均衡多样的饮食", comment: ""),
                NSLocalizedString("每天提供新鲜蔬果", comment: ""),
                NSLocalizedString("不要只喂种子饲料", comment: ""),
                NSLocalizedString("可使用营养丸补充", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("钙缺乏症/低钙血症", comment: ""),
            description: NSLocalizedString("钙缺乏会导致骨骼问题、软壳蛋、抽搐等。产蛋期母鸟尤其需要充足的钙。严重时可导致抽搐甚至死亡。", comment: ""),
            icon: "bone",
            severity: .high,
            category: NSLocalizedString("营养代谢病", comment: ""),
            possibleCauses: [
                NSLocalizedString("饮食中钙含量不足", comment: ""),
                NSLocalizedString("维生素D3缺乏（影响钙吸收）", comment: ""),
                NSLocalizedString("缺乏阳光照射", comment: ""),
                NSLocalizedString("产蛋期消耗过多", comment: "")
            ],
            suggestions: [
                NSLocalizedString("补充钙质：墨鱼骨、钙粉、蛋壳粉", comment: ""),
                NSLocalizedString("补充维生素D3", comment: ""),
                NSLocalizedString("适当晒太阳（每天10-15分钟）", comment: ""),
                NSLocalizedString("严重抽搐需紧急就医", comment: ""),
                NSLocalizedString("产蛋期加强钙补充", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("抽搐、痉挛", comment: ""),
                NSLocalizedString("站立不稳、无力", comment: ""),
                NSLocalizedString("软壳蛋或无壳蛋", comment: ""),
                NSLocalizedString("蛋阻留（难产）", comment: ""),
                NSLocalizedString("骨折", comment: ""),
                NSLocalizedString("幼鸟腿部畸形", comment: "")
            ],
            prevention: [
                NSLocalizedString("常备墨鱼骨或矿物块", comment: ""),
                NSLocalizedString("定期补充钙粉", comment: ""),
                NSLocalizedString("适当晒太阳", comment: ""),
                NSLocalizedString("产蛋期加强营养", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("脂肪肝病", comment: ""),
            description: NSLocalizedString("因高脂肪饮食和缺乏运动导致肝脏脂肪堆积。常见于笼养鸟，尤其是只吃种子的鸟。可导致肝功能衰竭。", comment: ""),
            icon: "liver.fill",
            severity: .high,
            category: NSLocalizedString("营养代谢病", comment: ""),
            possibleCauses: [
                NSLocalizedString("高脂肪饮食（过多种子、坚果）", comment: ""),
                NSLocalizedString("缺乏运动", comment: ""),
                NSLocalizedString("肥胖", comment: ""),
                NSLocalizedString("遗传因素", comment: "")
            ],
            suggestions: [
                NSLocalizedString("调整饮食，减少高脂肪食物", comment: ""),
                NSLocalizedString("增加蔬果和低脂食物", comment: ""),
                NSLocalizedString("增加运动量，扩大活动空间", comment: ""),
                NSLocalizedString("可使用护肝药物（遵医嘱）", comment: ""),
                NSLocalizedString("定期监测体重", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("肥胖", comment: ""),
                NSLocalizedString("绿色或黄色粪便", comment: ""),
                NSLocalizedString("腹部肿胀", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("喙部或指甲过度生长", comment: ""),
                NSLocalizedString("羽毛质量下降", comment: "")
            ],
            prevention: [
                NSLocalizedString("提供均衡低脂饮食", comment: ""),
                NSLocalizedString("限制种子和坚果摄入", comment: ""),
                NSLocalizedString("提供足够的运动空间", comment: ""),
                NSLocalizedString("定期称重监测", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("肥胖症", comment: ""),
            description: NSLocalizedString("因过度喂食和缺乏运动导致体内脂肪过多。肥胖会增加心脏病、脂肪肝、关节问题等风险，缩短寿命。", comment: ""),
            icon: "scalemass",
            severity: .medium,
            category: NSLocalizedString("营养代谢病", comment: ""),
            possibleCauses: [
                NSLocalizedString("过度喂食", comment: ""),
                NSLocalizedString("高脂肪饮食", comment: ""),
                NSLocalizedString("缺乏运动", comment: ""),
                NSLocalizedString("笼子太小", comment: "")
            ],
            suggestions: [
                NSLocalizedString("减少高脂肪食物（种子、坚果）", comment: ""),
                NSLocalizedString("增加蔬果比例", comment: ""),
                NSLocalizedString("控制每日食量", comment: ""),
                NSLocalizedString("增加运动：更大的笼子、放飞时间", comment: ""),
                NSLocalizedString("逐渐减重，不要突然节食", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("明显肥胖，腹部膨大", comment: ""),
                NSLocalizedString("皮下可见黄色脂肪", comment: ""),
                NSLocalizedString("活动减少，不爱飞", comment: ""),
                NSLocalizedString("呼吸急促", comment: ""),
                NSLocalizedString("胸骨摸不到", comment: "")
            ],
            prevention: [
                NSLocalizedString("提供均衡饮食", comment: ""),
                NSLocalizedString("控制食量", comment: ""),
                NSLocalizedString("提供足够运动空间", comment: ""),
                NSLocalizedString("定期称重监测", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("痛风", comment: ""),
            description: NSLocalizedString("尿酸代谢障碍导致尿酸盐在关节或内脏沉积。分为关节型和内脏型。常见于老年鸟或肾功能不全的鸟。", comment: ""),
            icon: "figure.walk.diamond",
            severity: .high,
            category: NSLocalizedString("营养代谢病", comment: ""),
            possibleCauses: [
                NSLocalizedString("高蛋白饮食", comment: ""),
                NSLocalizedString("肾功能不全", comment: ""),
                NSLocalizedString("脱水", comment: ""),
                NSLocalizedString("维生素A缺乏", comment: ""),
                NSLocalizedString("某些药物影响", comment: "")
            ],
            suggestions: [
                NSLocalizedString("降低饮食中蛋白质含量", comment: ""),
                NSLocalizedString("保证充足饮水", comment: ""),
                NSLocalizedString("使用降尿酸药物（遵医嘱）", comment: ""),
                NSLocalizedString("治疗原发病（如肾病）", comment: ""),
                NSLocalizedString("止痛治疗", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("关节肿胀、变形", comment: ""),
                NSLocalizedString("脚趾出现白色结节", comment: ""),
                NSLocalizedString("行走困难、跛行", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("食欲下降", comment: "")
            ],
            prevention: [
                NSLocalizedString("提供均衡饮食，避免过高蛋白", comment: ""),
                NSLocalizedString("保证充足饮水", comment: ""),
                NSLocalizedString("定期健康检查", comment: ""),
                NSLocalizedString("及时治疗肾脏问题", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("甲状腺肿", comment: ""),
            description: NSLocalizedString("因碘缺乏导致甲状腺肿大，压迫气管和食道。常见于只吃种子的鸟，尤其是虎皮鹦鹉。", comment: ""),
            icon: "circle.hexagongrid",
            severity: .medium,
            category: NSLocalizedString("营养代谢病", comment: ""),
            possibleCauses: [
                NSLocalizedString("碘缺乏", comment: ""),
                NSLocalizedString("长期只吃种子饲料", comment: ""),
                NSLocalizedString("饮食单一", comment: "")
            ],
            suggestions: [
                NSLocalizedString("补充碘：碘化钾溶液加入饮水", comment: ""),
                NSLocalizedString("改善饮食，增加蔬果", comment: ""),
                NSLocalizedString("使用含碘的矿物块", comment: ""),
                NSLocalizedString("严重者需就医", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("呼吸困难", comment: ""),
                NSLocalizedString("吞咽困难", comment: ""),
                NSLocalizedString("呕吐或反流", comment: ""),
                NSLocalizedString("颈部可见肿胀", comment: ""),
                NSLocalizedString("声音改变", comment: "")
            ],
            prevention: [
                NSLocalizedString("提供均衡饮食", comment: ""),
                NSLocalizedString("使用含碘的矿物补充剂", comment: ""),
                NSLocalizedString("不要只喂种子", comment: "")
            ]
        ),
        
        // ========== 繁殖相关疾病 ==========
        BirdSymptom(
            name: NSLocalizedString("蛋阻留(难产)", comment: ""),
            description: NSLocalizedString("蛋无法正常排出，卡在输卵管或泄殖腔中。这是紧急情况，如不及时处理可在24-48小时内致死。常见于初产母鸟、钙缺乏或蛋过大的情况。", comment: ""),
            icon: "exclamationmark.octagon",
            severity: .high,
            category: NSLocalizedString("繁殖相关", comment: ""),
            possibleCauses: [
                NSLocalizedString("钙缺乏导致子宫收缩无力", comment: ""),
                NSLocalizedString("蛋过大或畸形", comment: ""),
                NSLocalizedString("输卵管炎症或肿瘤", comment: ""),
                NSLocalizedString("初产母鸟", comment: ""),
                NSLocalizedString("过度产蛋导致疲劳", comment: ""),
                NSLocalizedString("环境温度过低", comment: "")
            ],
            suggestions: [
                NSLocalizedString("这是紧急情况！", comment: ""),
                NSLocalizedString("保持环境温暖（28-30°C）", comment: ""),
                NSLocalizedString("增加湿度", comment: ""),
                NSLocalizedString("在泄殖腔滴入少量植物油或凡士林润滑", comment: ""),
                NSLocalizedString("轻轻按摩腹部（从前向后）", comment: ""),
                NSLocalizedString("补充钙质", comment: ""),
                NSLocalizedString("如1-2小时内无法排出必须就医", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("有产蛋姿势但产不出", comment: ""),
                NSLocalizedString("腹部膨大，可触摸到蛋", comment: ""),
                NSLocalizedString("肛门膨出", comment: ""),
                NSLocalizedString("精神萎靡、羽毛蓬松", comment: ""),
                NSLocalizedString("呼吸急促", comment: ""),
                NSLocalizedString("站立困难或瘫痪", comment: "")
            ],
            prevention: [
                NSLocalizedString("产蛋期充足补钙", comment: ""),
                NSLocalizedString("适当晒太阳补充维生素D", comment: ""),
                NSLocalizedString("避免过度繁殖", comment: ""),
                NSLocalizedString("控制产蛋（减少光照时间）", comment: ""),
                NSLocalizedString("保持适宜温度", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("慢性产蛋/过度产蛋", comment: ""),
            description: NSLocalizedString("母鸟持续产蛋不停止，消耗大量钙质和营养，可导致钙缺乏、蛋阻留、输卵管脱垂等严重问题。", comment: ""),
            icon: "repeat.circle",
            severity: .medium,
            category: NSLocalizedString("繁殖相关", comment: ""),
            possibleCauses: [
                NSLocalizedString("光照时间过长", comment: ""),
                NSLocalizedString("环境过于舒适", comment: ""),
                NSLocalizedString("有巢箱或类似巢穴的环境", comment: ""),
                NSLocalizedString("与伴侣或主人过度亲密", comment: ""),
                NSLocalizedString("激素失调", comment: "")
            ],
            suggestions: [
                NSLocalizedString("减少光照时间（每天不超过10-12小时）", comment: ""),
                NSLocalizedString("移除巢箱和类似巢穴的物品", comment: ""),
                NSLocalizedString("改变环境布置", comment: ""),
                NSLocalizedString("减少抚摸背部和腹部", comment: ""),
                NSLocalizedString("补充钙质", comment: ""),
                NSLocalizedString("严重时可能需要激素治疗", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("持续产蛋不停", comment: ""),
                NSLocalizedString("软壳蛋或无壳蛋", comment: ""),
                NSLocalizedString("体重下降", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("出现蛋阻留症状", comment: "")
            ],
            prevention: [
                NSLocalizedString("控制光照时间", comment: ""),
                NSLocalizedString("不提供巢箱（非繁殖期）", comment: ""),
                NSLocalizedString("避免过度亲密的互动", comment: ""),
                NSLocalizedString("提供均衡营养", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("输卵管脱垂", comment: ""),
            description: NSLocalizedString("输卵管从泄殖腔脱出体外，通常发生在产蛋困难或过度产蛋后。这是紧急情况，需要立即处理。", comment: ""),
            icon: "arrow.down.circle.dotted",
            severity: .high,
            category: NSLocalizedString("繁殖相关", comment: ""),
            possibleCauses: [
                NSLocalizedString("蛋阻留后用力过度", comment: ""),
                NSLocalizedString("过度产蛋", comment: ""),
                NSLocalizedString("钙缺乏", comment: ""),
                NSLocalizedString("输卵管感染", comment: ""),
                NSLocalizedString("肌肉无力", comment: "")
            ],
            suggestions: [
                NSLocalizedString("这是紧急情况，需立即就医！", comment: ""),
                NSLocalizedString("保持脱出组织湿润（用生理盐水）", comment: ""),
                NSLocalizedString("防止鸟啄伤脱出组织", comment: ""),
                NSLocalizedString("不要自行尝试复位", comment: ""),
                NSLocalizedString("保持环境安静", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("泄殖腔有组织脱出", comment: ""),
                NSLocalizedString("脱出组织红肿或出血", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("拒食", comment: "")
            ],
            prevention: [
                NSLocalizedString("预防蛋阻留", comment: ""),
                NSLocalizedString("控制产蛋", comment: ""),
                NSLocalizedString("充足补钙", comment: ""),
                NSLocalizedString("及时治疗产蛋问题", comment: "")
            ]
        ),
        
        // ========== 其他疾病 ==========
        BirdSymptom(
            name: NSLocalizedString("胃部酵母菌病(巨细菌病)", comment: ""),
            description: NSLocalizedString("由巨型酵母菌(Macrorhabdus ornithogaster)引起的消化道疾病，主要影响腺胃。常见于虎皮鹦鹉、玄凤和金丝雀。可导致慢性消瘦。", comment: ""),
            icon: "circle.hexagonpath",
            severity: .high,
            category: NSLocalizedString("真菌感染", comment: ""),
            possibleCauses: [
                NSLocalizedString("巨型酵母菌感染", comment: ""),
                NSLocalizedString("与感染鸟接触", comment: ""),
                NSLocalizedString("通过粪便传播", comment: ""),
                NSLocalizedString("应激或免疫力下降时发病", comment: "")
            ],
            suggestions: [
                NSLocalizedString("使用抗真菌药物治疗（两性霉素B等，遵医嘱）", comment: ""),
                NSLocalizedString("治疗周期较长", comment: ""),
                NSLocalizedString("饮水中加入少量苹果醋酸化（轻症）", comment: ""),
                NSLocalizedString("隔离病鸟", comment: ""),
                NSLocalizedString("提供易消化的食物", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("频繁呕吐，食物未消化", comment: ""),
                NSLocalizedString("粪便中有未消化的种子", comment: ""),
                NSLocalizedString("慢性消瘦", comment: ""),
                NSLocalizedString("精神时好时坏", comment: ""),
                NSLocalizedString("羽毛质量下降", comment: "")
            ],
            prevention: [
                NSLocalizedString("新鸟隔离检疫", comment: ""),
                NSLocalizedString("定期健康检查", comment: ""),
                NSLocalizedString("保持环境清洁", comment: ""),
                NSLocalizedString("避免应激", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("便秘", comment: ""),
            description: NSLocalizedString("粪便干燥、排便困难或无法排便。可能由饮食、饮水不足或疾病引起。严重时可导致肠梗阻。", comment: ""),
            icon: "exclamationmark.arrow.circlepath",
            severity: .medium,
            category: NSLocalizedString("消化系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("饮水不足", comment: ""),
                NSLocalizedString("饮食中缺乏纤维", comment: ""),
                NSLocalizedString("缺乏油脂性食物", comment: ""),
                NSLocalizedString("运动不足", comment: ""),
                NSLocalizedString("肠道疾病或梗阻", comment: ""),
                NSLocalizedString("异物吞入", comment: "")
            ],
            suggestions: [
                NSLocalizedString("增加饮水", comment: ""),
                NSLocalizedString("喂食少量植物油（1-5ml）", comment: ""),
                NSLocalizedString("增加蔬果和纤维", comment: ""),
                NSLocalizedString("可用蓖麻油滴入泄殖腔润滑", comment: ""),
                NSLocalizedString("轻轻按摩腹部", comment: ""),
                NSLocalizedString("增加运动", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("长时间无粪便排出", comment: ""),
                NSLocalizedString("有排便姿势但排不出", comment: ""),
                NSLocalizedString("腹部膨大", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("呕吐", comment: ""),
                NSLocalizedString("怀疑吞入异物", comment: "")
            ],
            prevention: [
                NSLocalizedString("保证充足饮水", comment: ""),
                NSLocalizedString("提供含纤维的食物", comment: ""),
                NSLocalizedString("适量喂食油脂性食物", comment: ""),
                NSLocalizedString("提供足够运动空间", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("窦炎", comment: ""),
            description: NSLocalizedString("鼻窦感染发炎，导致眼睛下方或周围肿胀。常继发于上呼吸道感染或维生素A缺乏。", comment: ""),
            icon: "eye.trianglebadge.exclamationmark",
            severity: .medium,
            category: NSLocalizedString("呼吸系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("细菌感染", comment: ""),
                NSLocalizedString("上呼吸道感染蔓延", comment: ""),
                NSLocalizedString("维生素A缺乏", comment: ""),
                NSLocalizedString("真菌感染", comment: ""),
                NSLocalizedString("外伤", comment: "")
            ],
            suggestions: [
                NSLocalizedString("需要兽医治疗", comment: ""),
                NSLocalizedString("可能需要冲洗窦腔", comment: ""),
                NSLocalizedString("使用抗生素治疗（遵医嘱）", comment: ""),
                NSLocalizedString("补充维生素A", comment: ""),
                NSLocalizedString("保持环境清洁", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("眼睛下方或周围肿胀", comment: ""),
                NSLocalizedString("单眼或双眼肿胀", comment: ""),
                NSLocalizedString("眼睛或鼻孔有分泌物", comment: ""),
                NSLocalizedString("打喷嚏、甩头", comment: ""),
                NSLocalizedString("食欲下降", comment: "")
            ],
            prevention: [
                NSLocalizedString("及时治疗呼吸道感染", comment: ""),
                NSLocalizedString("补充维生素A", comment: ""),
                NSLocalizedString("保持环境清洁", comment: ""),
                NSLocalizedString("避免刺激性气体", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("鼻石症", comment: ""),
            description: NSLocalizedString("鼻腔内分泌物、灰尘等积累形成硬块，堵塞鼻孔。常与维生素A缺乏有关。", comment: ""),
            icon: "nose.fill",
            severity: .medium,
            category: NSLocalizedString("呼吸系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("维生素A缺乏", comment: ""),
                NSLocalizedString("慢性鼻炎", comment: ""),
                NSLocalizedString("环境灰尘过多", comment: ""),
                NSLocalizedString("鼻腔分泌物积累", comment: "")
            ],
            suggestions: [
                NSLocalizedString("需要兽医手术取出鼻石", comment: ""),
                NSLocalizedString("补充维生素A", comment: ""),
                NSLocalizedString("保持环境清洁，减少灰尘", comment: ""),
                NSLocalizedString("术后可能需要抗生素", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("鼻孔堵塞", comment: ""),
                NSLocalizedString("呼吸困难", comment: ""),
                NSLocalizedString("鼻孔周围可见硬块", comment: ""),
                NSLocalizedString("张嘴呼吸", comment: "")
            ],
            prevention: [
                NSLocalizedString("补充维生素A", comment: ""),
                NSLocalizedString("保持环境清洁", comment: ""),
                NSLocalizedString("避免灰尘和烟雾", comment: ""),
                NSLocalizedString("及时治疗鼻炎", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("癫痫/抽搐", comment: ""),
            description: NSLocalizedString("大脑异常放电导致的发作性症状，表现为抽搐、失去平衡、意识障碍等。可由多种原因引起，需要查明病因。", comment: ""),
            icon: "bolt.heart",
            severity: .high,
            category: NSLocalizedString("神经系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("中毒（重金属、杀虫剂等）", comment: ""),
                NSLocalizedString("感染（病毒、细菌）", comment: ""),
                NSLocalizedString("代谢问题（低钙、低血糖）", comment: ""),
                NSLocalizedString("肿瘤", comment: ""),
                NSLocalizedString("外伤", comment: ""),
                NSLocalizedString("遗传因素", comment: "")
            ],
            suggestions: [
                NSLocalizedString("发作时保持环境安静黑暗", comment: ""),
                NSLocalizedString("移除笼内可能造成伤害的物品", comment: ""),
                NSLocalizedString("不要强行抓握发作中的鸟", comment: ""),
                NSLocalizedString("记录发作时间和表现", comment: ""),
                NSLocalizedString("尽快就医查明原因", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("抽搐发作", comment: ""),
                NSLocalizedString("失去平衡、倒地", comment: ""),
                NSLocalizedString("头部后仰或转圈", comment: ""),
                NSLocalizedString("意识丧失", comment: ""),
                NSLocalizedString("发作后精神萎靡", comment: "")
            ],
            prevention: [
                NSLocalizedString("避免接触有毒物质", comment: ""),
                NSLocalizedString("保持均衡营养", comment: ""),
                NSLocalizedString("定期健康检查", comment: ""),
                NSLocalizedString("减少应激", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("歪头症/斜颈", comment: ""),
            description: NSLocalizedString("头部持续倾斜或转圈，可能由内耳感染、神经系统问题或中毒引起。需要查明病因进行治疗。", comment: ""),
            icon: "arrow.triangle.turn.up.right.circle",
            severity: .high,
            category: NSLocalizedString("神经系统疾病", comment: ""),
            possibleCauses: [
                NSLocalizedString("内耳感染", comment: ""),
                NSLocalizedString("中耳炎", comment: ""),
                NSLocalizedString("脑部感染或损伤", comment: ""),
                NSLocalizedString("中毒", comment: ""),
                NSLocalizedString("前胃扩张症", comment: ""),
                NSLocalizedString("维生素缺乏", comment: "")
            ],
            suggestions: [
                NSLocalizedString("需要兽医诊断病因", comment: ""),
                NSLocalizedString("根据病因进行针对性治疗", comment: ""),
                NSLocalizedString("保持环境安全，防止摔伤", comment: ""),
                NSLocalizedString("可能需要辅助喂食", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("头部持续倾斜", comment: ""),
                NSLocalizedString("转圈行走", comment: ""),
                NSLocalizedString("失去平衡", comment: ""),
                NSLocalizedString("眼球震颤", comment: ""),
                NSLocalizedString("无法正常进食", comment: "")
            ],
            prevention: [
                NSLocalizedString("及时治疗耳部感染", comment: ""),
                NSLocalizedString("避免接触有毒物质", comment: ""),
                NSLocalizedString("保持均衡营养", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("骨折", comment: ""),
            description: NSLocalizedString("骨骼断裂，常见于翅膀和腿部。多因撞击、摔落或被夹伤引起。需要及时固定和治疗。", comment: ""),
            icon: "bandage.fill",
            severity: .high,
            category: NSLocalizedString("外伤", comment: ""),
            possibleCauses: [
                NSLocalizedString("撞击门窗或墙壁", comment: ""),
                NSLocalizedString("从高处摔落", comment: ""),
                NSLocalizedString("被门夹伤", comment: ""),
                NSLocalizedString("被其他动物攻击", comment: ""),
                NSLocalizedString("钙缺乏导致骨骼脆弱", comment: "")
            ],
            suggestions: [
                NSLocalizedString("限制活动，将鸟放在小笼或箱中", comment: ""),
                NSLocalizedString("移除栖木，铺软垫", comment: ""),
                NSLocalizedString("尽快就医", comment: ""),
                NSLocalizedString("不要自行尝试复位", comment: ""),
                NSLocalizedString("保持环境安静", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("翅膀下垂、无法飞行", comment: ""),
                NSLocalizedString("腿部无法站立或悬吊", comment: ""),
                NSLocalizedString("患处肿胀", comment: ""),
                NSLocalizedString("明显疼痛", comment: ""),
                NSLocalizedString("骨骼变形", comment: "")
            ],
            prevention: [
                NSLocalizedString("放飞前关好门窗", comment: ""),
                NSLocalizedString("窗户贴防撞贴纸", comment: ""),
                NSLocalizedString("补充钙质", comment: ""),
                NSLocalizedString("避免危险环境", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("出血/外伤", comment: ""),
            description: NSLocalizedString("皮肤或血管破损导致出血。鸟类血量少，大量出血可危及生命。需要及时止血处理。", comment: ""),
            icon: "drop.fill",
            severity: .high,
            category: NSLocalizedString("外伤", comment: ""),
            possibleCauses: [
                NSLocalizedString("血羽断裂", comment: ""),
                NSLocalizedString("指甲剪太短", comment: ""),
                NSLocalizedString("外伤", comment: ""),
                NSLocalizedString("被其他鸟攻击", comment: ""),
                NSLocalizedString("撞击", comment: "")
            ],
            suggestions: [
                NSLocalizedString("保持冷静", comment: ""),
                NSLocalizedString("用干净纱布或棉球压迫止血", comment: ""),
                NSLocalizedString("血羽出血可用止血粉或面粉", comment: ""),
                NSLocalizedString("严重时需拔除断裂的血羽", comment: ""),
                NSLocalizedString("大量出血需紧急就医", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("出血无法止住", comment: ""),
                NSLocalizedString("大量出血", comment: ""),
                NSLocalizedString("伤口较深", comment: ""),
                NSLocalizedString("精神萎靡", comment: ""),
                NSLocalizedString("血羽反复出血", comment: "")
            ],
            prevention: [
                NSLocalizedString("剪指甲时注意不要剪太短", comment: ""),
                NSLocalizedString("避免危险环境", comment: ""),
                NSLocalizedString("分开有攻击性的鸟", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("中毒", comment: ""),
            description: NSLocalizedString("摄入或吸入有毒物质导致的急性或慢性中毒。常见毒物包括重金属、特氟龙烟雾、有毒植物、杀虫剂等。可能危及生命。", comment: ""),
            icon: "exclamationmark.triangle",
            severity: .high,
            category: NSLocalizedString("中毒", comment: ""),
            possibleCauses: [
                NSLocalizedString("重金属中毒（铅、锌）：啃咬含铅/锌物品", comment: ""),
                NSLocalizedString("特氟龙中毒：不粘锅过热产生的烟雾", comment: ""),
                NSLocalizedString("有毒植物：牛油果、巧克力、洋葱等", comment: ""),
                NSLocalizedString("杀虫剂、清洁剂", comment: ""),
                NSLocalizedString("香水、空气清新剂", comment: ""),
                NSLocalizedString("烟草烟雾", comment: "")
            ],
            suggestions: [
                NSLocalizedString("立即移除毒物来源", comment: ""),
                NSLocalizedString("保持通风（吸入性中毒）", comment: ""),
                NSLocalizedString("紧急就医", comment: ""),
                NSLocalizedString("带上可疑毒物样本", comment: ""),
                NSLocalizedString("不要自行催吐", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("突然精神萎靡", comment: ""),
                NSLocalizedString("呕吐、腹泻", comment: ""),
                NSLocalizedString("抽搐", comment: ""),
                NSLocalizedString("呼吸困难", comment: ""),
                NSLocalizedString("共济失调", comment: ""),
                NSLocalizedString("突然死亡", comment: "")
            ],
            prevention: [
                NSLocalizedString("绝对不用不粘锅（特氟龙）", comment: ""),
                NSLocalizedString("移除含铅锌的物品", comment: ""),
                NSLocalizedString("不喂有毒食物", comment: ""),
                NSLocalizedString("避免使用杀虫剂、香水", comment: ""),
                NSLocalizedString("保持通风", comment: "")
            ]
        ),
        BirdSymptom(
            name: NSLocalizedString("脂肪瘤", comment: ""),
            description: NSLocalizedString("皮下脂肪组织形成的良性肿瘤，表现为皮下可移动的软性肿块。常见于肥胖的鸟，尤其是虎皮鹦鹉和玄凤。", comment: ""),
            icon: "circle.fill",
            severity: .medium,
            category: NSLocalizedString("肿瘤", comment: ""),
            possibleCauses: [
                NSLocalizedString("肥胖", comment: ""),
                NSLocalizedString("高脂肪饮食", comment: ""),
                NSLocalizedString("遗传因素", comment: ""),
                NSLocalizedString("缺乏运动", comment: "")
            ],
            suggestions: [
                NSLocalizedString("调整饮食，减少脂肪摄入", comment: ""),
                NSLocalizedString("增加运动", comment: ""),
                NSLocalizedString("定期监测肿块大小", comment: ""),
                NSLocalizedString("较大的肿瘤可能需要手术切除", comment: "")
            ],
            whenToSeeVet: [
                NSLocalizedString("发现皮下肿块", comment: ""),
                NSLocalizedString("肿块快速增大", comment: ""),
                NSLocalizedString("影响活动或飞行", comment: ""),
                NSLocalizedString("肿块表面破溃", comment: "")
            ],
            prevention: [
                NSLocalizedString("保持健康体重", comment: ""),
                NSLocalizedString("低脂饮食", comment: ""),
                NSLocalizedString("充足运动", comment: "")
            ]
        )
    ]
}

// MARK: - 使用帮助视图
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    private let helpSections: [(title: String, icon: String, items: [(question: String, answer: String)])] = [
        (
            title: NSLocalizedString("首页功能", comment: ""),
            icon: "house.fill",
            items: [
                (NSLocalizedString("如何添加我的鸟儿？", comment: ""), NSLocalizedString("点击首页右上角的「+」按钮，填写鸟儿的基本信息（昵称、品种、性别、出生日期等），还可以拍照或从相册选择头像，即可创建鸟儿档案。", comment: "")),
                (NSLocalizedString("如何更换鸟儿头像？", comment: ""), NSLocalizedString("在鸟儿详情页点击「编辑」，点击顶部的头像区域，选择「从相册选择」或「拍摄照片」，裁剪后头像将自动保存。离线时选择的头像会在联网后自动上传。", comment: "")),
                (NSLocalizedString("如何记录鸟儿的日志？", comment: ""), NSLocalizedString("在首页点击鸟儿卡片进入详情页，点击「写日志」按钮，可以记录鸟儿的体重、饮食、心情、行为、健康状况等信息，还可以拍照记录。", comment: "")),
                (NSLocalizedString("如何查看体重趋势？", comment: ""), NSLocalizedString("首页体重模块显示最近7天的体重变化曲线。点击标题栏可查看完整历史趋势图。", comment: "")),
                (NSLocalizedString("如何记录洗澡/产蛋？", comment: ""), NSLocalizedString("在首页「记录」模块点击「查看全部」或直接点击日历中的日期，可记录产蛋或洗澡情况。首页日历会用不同颜色标记不同事件。", comment: "")),
                (NSLocalizedString("如何设置喂食提醒？", comment: ""), NSLocalizedString("在首页点击「提醒」标签，点击「+」添加新提醒，设置提醒时间和重复周期即可。提醒会在设定时间推送通知。", comment: "")),
                (NSLocalizedString("如何记录支出？", comment: ""), NSLocalizedString("在首页点击「支出」标签，可以记录养鸟花费，支持多种类别（食物、玩具、医疗等）。关联多只鸟儿时，系统会自动平摊费用。", comment: "")),
                (NSLocalizedString("如何编辑鸟儿信息？", comment: ""), NSLocalizedString("在鸟儿详情页点击「编辑」按钮，可修改昵称、品种、性别、生日、羽色、来源、脚环编号、父母信息、病例记录等所有信息。清空某个字段后保存，该信息将被移除。", comment: "")),
                (NSLocalizedString("如何标记鸟儿已故？", comment: ""), NSLocalizedString("在编辑鸟儿页面，开启「忌日」开关并选择日期。如果误操作，可以再次编辑关闭「忌日」开关来撤销。", comment: "")),
                (NSLocalizedString("如何共享鸟儿给家人？", comment: ""), NSLocalizedString("在鸟儿详情页点击「共享」按钮，输入家人的手机号，选择权限（主人/查看者）发送邀请。对方在「共享邀请」中接受后即可共同管理。", comment: "")),
                (NSLocalizedString("误删的鸟儿如何恢复？", comment: ""), NSLocalizedString("在「我的」页面点击「回收站」，找到已删除的鸟儿点击「恢复」。回收站中的鸟儿将在7天后自动永久删除。", comment: ""))
            ]
        ),
        (
            title: NSLocalizedString("百科功能", comment: ""),
            icon: "book.fill",
            items: [
                (NSLocalizedString("如何使用智能问诊？", comment: ""), NSLocalizedString("进入「百科」页面，选择「智能问诊」，可以向AI鸟医咨询养鸟相关问题，获取专业的饲养建议和健康解答。", comment: "")),
                (NSLocalizedString("如何查询鸟类品种信息？", comment: ""), NSLocalizedString("在「百科」页面选择「鸟类百科」，可以搜索或按分类浏览各种宠物鸟的详细信息，包括习性、饲养要点等。", comment: "")),
                (NSLocalizedString("如何查询食物是否安全？", comment: ""), NSLocalizedString("在「百科」页面选择「食物查询」，搜索或浏览食物列表，查看该食物对鸟儿是否安全，了解喂食注意事项。", comment: "")),
                (NSLocalizedString("如何根据症状判断疾病？", comment: ""), NSLocalizedString("在「百科」页面选择「症状查询」，根据鸟儿的异常表现进行搜索，获取可能的原因和就医建议。", comment: ""))
            ]
        ),
        (
            title: NSLocalizedString("广场功能", comment: ""),
            icon: "globe.asia.australia.fill",
            items: [
                (NSLocalizedString("如何发布帖子？", comment: ""), NSLocalizedString("在「广场」页面点击右下角的「+」按钮，输入内容、添加图片或视频，可关联多只鸟儿，点击发布即可分享给鸟友。", comment: "")),
                (NSLocalizedString("如何发布视频帖子？", comment: ""), NSLocalizedString("发布帖子时选择「视频」模式，从相册选择视频，可自定义封面。视频会自动上传到云端。", comment: "")),
                (NSLocalizedString("如何发布寻鸟启事？", comment: ""), NSLocalizedString("在「广场」点击「+」按钮，选择「寻鸟启事」类型，填写走失鸟儿的品种、特征、走失地点和联系方式，帮助鸟友找鸟。", comment: "")),
                (NSLocalizedString("如何关注其他鸟友？", comment: ""), NSLocalizedString("点击帖子作者头像进入主页，点击「关注」按钮即可关注。", comment: "")),
                (NSLocalizedString("如何收藏喜欢的帖子？", comment: ""), NSLocalizedString("在帖子详情页点击「收藏」按钮，收藏的帖子可以在「我的」页面的「我的收藏」中查看。", comment: "")),
                (NSLocalizedString("如何查看大图？", comment: ""), NSLocalizedString("点击帖子中的图片即可查看原始比例的完整大图，支持缩放和滑动浏览。", comment: ""))
            ]
        ),
        (
            title: NSLocalizedString("账号与会员", comment: ""),
            icon: "person.fill",
            items: [
                (NSLocalizedString("如何修改个人资料？", comment: ""), NSLocalizedString("在「我的」页面点击头像或昵称区域，可修改昵称和个人简介。清空简介后保存，简介将被移除。", comment: "")),
                (NSLocalizedString("如何更换用户头像？", comment: ""), NSLocalizedString("在「我的」页面点击头像，选择「从相册选择」或「拍摄照片」，裁剪后头像将自动上传更新。", comment: "")),
                (NSLocalizedString("VIP会员有什么特权？", comment: ""), NSLocalizedString("VIP会员享有：无限鸟儿档案、回收站恢复功能、专属标识、优先客服、情侣共享等特权。目前所有功能免费体验中！", comment: "")),
                (NSLocalizedString("如何开通VIP会员？", comment: ""), NSLocalizedString("目前所有VIP会员特权免费向用户提供体验！您只需注册并登录账号，即可直接享受包括无限鸟儿档案、回收站恢复、情侣共享等在内的全部会员特权。", comment: "")),
                (NSLocalizedString("什么是情侣共享？", comment: ""), NSLocalizedString("绑定伴侣账号后，双方可以共同管理所有鸟儿档案。在「我的」页面点击「情侣绑定」，输入伴侣手机号发送邀请，对方确认后即可共享。即使对方尚未注册，也可以预留手机号等待对方注册后自动绑定。", comment: "")),
                (NSLocalizedString("如何查看共享邀请？", comment: ""), NSLocalizedString("在「我的」页面点击「共享邀请」（有红点提示），可以查看并接受/拒绝收到的鸟儿共享邀请。", comment: "")),
                (NSLocalizedString("什么是鸟鸟开屏庆生？", comment: ""), NSLocalizedString("一项付费功能（¥10/次），可在指定日期让您的鸟儿照片出现在APP启动画面，为爱鸟庆祝生日或纪念日。购买后在日历中选择日期并上传照片即可。", comment: "")),
                (NSLocalizedString("如何查看隐私设置？", comment: ""), NSLocalizedString("在「我的」页面点击「隐私中心」，可查看和管理您的隐私权限设置。", comment: ""))
            ]
        ),
        (
            title: NSLocalizedString("数据与离线", comment: ""),
            icon: "icloud.fill",
            items: [
                (NSLocalizedString("数据会丢失吗？", comment: ""), NSLocalizedString("您的数据会自动同步到云端，更换设备后登录同一账号即可恢复所有数据。建议保持网络连接以确保数据及时同步。", comment: "")),
                (NSLocalizedString("可以离线使用吗？", comment: ""), NSLocalizedString("支持离线使用！在没有网络时，您可以正常添加鸟儿、记录日志、编辑信息、更换头像等。所有修改会在联网后自动同步到云端。", comment: "")),
                (NSLocalizedString("离线修改的数据如何同步？", comment: ""), NSLocalizedString("当网络恢复时，APP会自动将离线期间的所有变更（包括新增鸟儿、日志、头像等）上传到服务器。同步过程在后台进行，无需手动操作。", comment: "")),
                (NSLocalizedString("数据同步失败怎么办？", comment: ""), NSLocalizedString("如果同步遇到问题，可以在「我的」→「设置」中尝试「清除缓存」，然后重新打开APP让数据重新同步。", comment: "")),
                (NSLocalizedString("如何清除本地缓存？", comment: ""), NSLocalizedString("在「我的」页面点击「清除缓存」，可以清除本地临时文件，但不会删除您的账号数据。", comment: "")),
                (NSLocalizedString("如何反馈问题？", comment: ""), NSLocalizedString("您可以通过「关于鸟鸟王国」页面底部的联系方式向我们反馈问题和建议。", comment: "")),
                (NSLocalizedString("如何注销账号？", comment: ""), NSLocalizedString("在「我的」页面底部点击「注销账号」，确认后所有数据将被永久删除，此操作不可逆。", comment: ""))
            ]
        )
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部图标
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeManager.primaryColor)
                        
                        Text(NSLocalizedString("使用帮助", comment: ""))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(NSLocalizedString("快速了解鸟鸟王国的各项功能", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // 帮助分类
                    ForEach(helpSections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            // 分类标题
                            HStack(spacing: 10) {
                                Image(systemName: section.icon)
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryColor)
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryColor)
                            }
                            .padding(.horizontal, 16)
                            
                            // 问答列表
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(item.question)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Text(item.answer)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(16)
                                    
                                    if index < section.items.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color.adaptiveCard)
                            .cornerRadius(14)
                            .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                    }
                    
                    // 底部提示
                    VStack(spacing: 8) {
                        Text(NSLocalizedString("还有其他问题？", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(NSLocalizedString("请通过「关于鸟鸟王国」页面联系我们", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .themedBackground()
        .themedNavigationBar(title: NSLocalizedString("使用帮助", comment: ""))
    }
}

// MARK: - 关于鸟鸟王国视图
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var themeManager = ThemeManager.shared
    private var secondaryColor: Color { themeManager.secondaryColor }
    
    @State private var showUserAgreement = false
    @State private var showPrivacyPolicy = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App 图标和名称
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [themeManager.primaryColor, secondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image("bird")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                        }
                        .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        VStack(spacing: 4) {
                            Text(NSLocalizedString("鸟鸟王国", comment: ""))
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Bird Kingdom")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.3"
                            Text(LanguageManager.shared.current == .zh ? "版本 \(version)" : "Version \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 30)
                    
                    // 应用介绍
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.aboutUs)
                            .font(.headline)
                            .foregroundColor(themeManager.primaryColor)
                        
                        Text(NSLocalizedString("鸟鸟王国是一款专为爱鸟人士打造的宠物鸟管理应用。我们致力于帮助每一位鸟友更好地照顾自己的羽毛小伙伴，记录它们成长的每一个瞬间。", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveCard)
                    .cornerRadius(14)
                    .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 6, x: 0, y: 2)
                    
                    // 核心功能
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("核心功能", comment: ""))
                            .font(.headline)
                            .foregroundColor(themeManager.primaryColor)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            featureRow(icon: "leaf.fill", title: NSLocalizedString("鸟儿档案", comment: ""), description: NSLocalizedString("为每只鸟儿建立专属档案，记录基本信息、健康数据", comment: ""))
                            featureRow(icon: "doc.text.fill", title: NSLocalizedString("成长日志", comment: ""), description: NSLocalizedString("记录体重变化、饮食情况、健康状态等日常信息", comment: ""))
                            featureRow(icon: "bell.fill", title: NSLocalizedString("智能提醒", comment: ""), description: NSLocalizedString("喂食、换羽、体检等重要事项定时提醒", comment: ""))
                            featureRow(icon: "yensign.circle.fill", title: L10n.expense, description: NSLocalizedString("记录养鸟支出，分类统计，掌握花费情况", comment: ""))
                            featureRow(icon: "stethoscope", title: NSLocalizedString("AI智能问诊", comment: ""), description: NSLocalizedString("向AI鸟医咨询养鸟问题，获取专业解答", comment: ""))
                            featureRow(icon: "book.fill", title: L10n.encyclopedia, description: NSLocalizedString("丰富的鸟类知识库，食物安全查询，症状速查", comment: ""))
                            featureRow(icon: "globe.asia.australia.fill", title: NSLocalizedString("鸟友广场", comment: ""), description: NSLocalizedString("分享养鸟心得，寻找走失鸟儿，结识鸟友", comment: ""))
                            featureRow(icon: "sparkles", title: NSLocalizedString("开屏庆生", comment: ""), description: NSLocalizedString("让爱鸟出现在APP启动画面，庆祝特别日子", comment: ""))
                            featureRow(icon: "person.2.fill", title: NSLocalizedString("情侣共享", comment: ""), description: NSLocalizedString("与伴侣共同管理鸟儿，数据实时同步", comment: ""))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveCard)
                    .cornerRadius(14)
                    .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 6, x: 0, y: 2)
                    
                    // 开发团队
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("开发团队", comment: ""))
                            .font(.headline)
                            .foregroundColor(themeManager.primaryColor)
                        
                        Text(NSLocalizedString("鸟鸟王国由一群热爱鸟类的开发者倾心打造。我们相信，每一只鸟儿都值得被用心呵护。如果您有任何建议或反馈，欢迎随时联系我们！", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveCard)
                    .cornerRadius(14)
                    .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 6, x: 0, y: 2)
                    
                    // 联系方式
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("联系我们", comment: ""))
                            .font(.headline)
                            .foregroundColor(themeManager.primaryColor)
                        
                        VStack(spacing: 0) {
                            contactRow(icon: "envelope.fill", title: NSLocalizedString("邮箱", comment: ""), value: "birdkingdom@163.com")
                            Divider().padding(.leading, 50)
                            contactRow(icon: "globe", title: NSLocalizedString("官网", comment: ""), value: "birdkingdom.xyz")
                            Divider().padding(.leading, 50)
                            contactRow(icon: "bubble.left.fill", title: NSLocalizedString("微信公众号", comment: ""), value: NSLocalizedString("鸟鸟王国", comment: ""))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.adaptiveCard)
                    .cornerRadius(14)
                    .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 6, x: 0, y: 2)
                    
                    // 法律信息
                    VStack(spacing: 12) {
                        Button {
                            showUserAgreement = true
                        } label: {
                            Text(L10n.eulaUserAgreement)
                                .font(.subheadline)
                                .foregroundColor(themeManager.primaryColor)
                        }
                        
                        Button {
                            showPrivacyPolicy = true
                        } label: {
                            Text(L10n.eulaPrivacyPolicy)
                                .font(.subheadline)
                                .foregroundColor(themeManager.primaryColor)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    // 版权信息
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("© 2025 鸟鸟王国", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("All Rights Reserved")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 16)
            }
        }
        .themedBackground()
        .themedNavigationBar(title: NSLocalizedString("关于鸟鸟王国", comment: ""))
        .sheet(isPresented: $showUserAgreement) {
            UserAgreementView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeManager.primaryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func contactRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeManager.primaryColor)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 用户鸟儿列表视图
struct UserBirdsListView: View {
    let userId: Int64
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var birds: [Bird] = []
    @State private var isLoading = true
    @State private var selectedBird: Bird? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if birds.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bird")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(NSLocalizedString("暂无鸟儿", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(birds, id: \.id) { bird in
                                BirdPreviewCard(bird: bird)
                                    .onTapGesture {
                                        selectedBird = bird
                                    }
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .themedBackground()
        .themedNavigationBar(title: String(format: NSLocalizedString("%@的鸟儿", comment: ""), userName))
        .onAppear {
            loadBirds()
        }
        .navigationDestination(item: $selectedBird) { bird in
            OtherUserBirdDetailView(bird: bird, isOtherUser: true)
                .hidesTabBar()
        }
    }
    
    private func loadBirds() {
        Task {
            do {
                let userBirds = try await ApiService.shared.getUserBirds(userId: userId)
                await MainActor.run {
                    birds = userBirds
                    isLoading = false
                }
            } catch {
                print("❌ 加载用户鸟儿失败: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 鸟儿预览卡片
struct BirdPreviewCard: View {
    let bird: Bird
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // 鸟儿头像
            if let avatarUrl = bird.avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    default:
                        defaultBirdAvatar
                    }
                }
            } else {
                defaultBirdAvatar
            }
            
            // 鸟儿名字
            Text(bird.nickname)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            // 品种
            Text(bird.species)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3)
    }
    
    private var defaultBirdAvatar: some View {
        Circle()
            .fill(themeManager.primaryColor.opacity(0.15))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "bird.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.primaryColor)
            )
    }
}

// MARK: - 鸟儿详情视图（查看他人的鸟）
struct OtherUserBirdDetailView: View {
    let bird: Bird
    let isOtherUser: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 头像
                    if let avatarUrl = bird.avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            default:
                                defaultBirdAvatar
                            }
                        }
                    } else {
                        defaultBirdAvatar
                    }
                    
                    // 基本信息
                    VStack(spacing: 16) {
                        infoRow(label: L10n.birdName, value: bird.nickname)
                        infoRow(label: L10n.birdSpecies, value: bird.species)
                        if let gender = bird.gender {
                            infoRow(label: L10n.birdGender, value: gender)
                        }
                        if let featherColor = bird.featherColor {
                            infoRow(label: NSLocalizedString("羽毛颜色", comment: ""), value: featherColor)
                        }
                        if let ageMonths = bird.ageMonths {
                            infoRow(label: NSLocalizedString("年龄", comment: ""), value: String(format: NSLocalizedString("%d个月", comment: ""), ageMonths))
                        }
                        if let notes = bird.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("简介", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(notes)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(16)
                    .background(Color.adaptiveCard)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 3)
                    .padding(.horizontal, 16)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .themedBackground()
        .themedNavigationBar(title: bird.nickname)
    }
    
    private var defaultBirdAvatar: some View {
        Circle()
            .fill(themeManager.primaryColor.opacity(0.15))
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "bird.fill")
                    .font(.system(size: 48))
                    .foregroundColor(themeManager.primaryColor)
            )
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - 关注/粉丝列表视图
struct UserFollowListView: View {
    enum ListType {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers: return NSLocalizedString("粉丝", comment: "")
            case .following: return NSLocalizedString("关注", comment: "")
            }
        }
    }
    
    let userId: Int64
    let userName: String
    let listType: ListType
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var users: [UserProfile] = []
    @State private var isLoading = true
    @State private var selectedUser: UserProfile? = nil
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if users.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(String(format: NSLocalizedString("暂无%@", comment: ""), listType.title))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(users, id: \.id) { user in
                            UserRowView(user: user, primaryColor: themeManager.primaryColor)
                                .onTapGesture {
                                    selectedUser = user
                                }
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
        }
        .themedBackground()
        .themedNavigationBar(title: String(format: NSLocalizedString("%1$@的%2$@", comment: ""), userName, listType.title))
        .onAppear {
            loadUsers()
        }
        .navigationDestination(item: $selectedUser) { user in
            UserProfileView(user: user)
                .hidesTabBar()
        }
    }
    
    private func loadUsers() {
        Task {
            do {
                let userList: [UserProfile]
                switch listType {
                case .followers:
                    userList = try await ApiService.shared.getUserFollowers(userId: userId)
                case .following:
                    userList = try await ApiService.shared.getUserFollowing(userId: userId)
                }
                await MainActor.run {
                    users = userList
                    isLoading = false
                }
            } catch {
                print("❌ 加载\(listType.title)列表失败: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 简化用户行视图（用于关注/粉丝列表）
struct SimpleUserRowView: View {
    let user: UserProfile
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            if let avatarUrl = user.avatar, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    default:
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 2) {
                Text(user.nickname)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.adaptiveCard)
        .contentShape(Rectangle())
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(themeManager.primaryColor.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.primaryColor)
            )
    }
}
