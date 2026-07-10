//
//  BirdKingdomApp.swift
//  BirdKingdom
//
//  Created by 陈丽倩 on 2025/12/6.
//

import SwiftUI
import UserNotifications
import CoreLocation
import PhotosUI
import AVKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.birdkingdom", category: "App")

@main
struct BirdKingdomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var universalLinkHandler = UniversalLinkHandler.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                // 颜色模式由 ThemeManager 控制（黑客黑主题使用深色模式）
                // Universal Links 支持：处理从网页跳转到 App 的链接
                .onOpenURL { url in
                    logger.info("🔗 onOpenURL 收到链接: \(url.absoluteString)")
                    universalLinkHandler.handleSceneURL(url)
                }
                .environmentObject(universalLinkHandler)
        }
    }
}

// App代理，用于处理通知
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        logger.info("🚀 App 启动中...")
        
        // Bug #2 修复：启动时清除 Badge
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = self
        
        // 请求通知权限
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
        
        // 定位权限延迟请求（用户首次使用定位功能时再请求）
        // LocationService.shared.requestPermission() // 移除启动时请求，改为按需请求
        
        // 初始化导航栏主题
        ThemeManager.shared.updateNavigationBarAppearance()
        
        // 强制初始化 AuthService，确保登录状态被加载
        Task { @MainActor in
            _ = AuthService.shared
            logger.info("🚀 AuthService 已初始化，登录状态: \(AuthService.shared.isLoggedIn)")
        }
        
        // 初始化 SpeciesDataService，确保品种 Seed Database 被加载
        Task { @MainActor in
            _ = SpeciesDataService.shared
            logger.info("🚀 SpeciesDataService 已初始化，品种数据已预加载")
        }
        
        // 初始化 StoreManager，预加载 App Store 产品列表
        // 这样用户进入支付页面时产品已经可用
        Task { @MainActor in
            _ = StoreManager.shared
            logger.info("🚀 StoreManager 已初始化，正在预加载 App Store 产品...")
        }
        
        // 🔥 全局键盘隐藏手势：点击空白处自动收起键盘
        setupGlobalKeyboardDismissGesture()
        
        return true
    }
    
    // MARK: - 全局键盘隐藏手势配置
    /// 在整个 App 的 Window 级别添加点击手势，点击空白处自动收起键盘
    /// 该手势不会影响按钮、列表等交互元素的正常响应
    private func setupGlobalKeyboardDismissGesture() {
        // 延迟执行，确保 window 已创建
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                logger.warning("⚠️ 无法获取主窗口，全局键盘隐藏手势未配置")
                return
            }
            
            // 创建点击手势
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboardGesture))
            
            // 关键设置：不取消视图中的触摸事件，确保按钮等元素正常响应
            tapGesture.cancelsTouchesInView = false
            
            // 添加到 window
            window.addGestureRecognizer(tapGesture)
            
            logger.info("✅ 全局键盘隐藏手势已配置")
        }
    }
    
    @objc private func dismissKeyboardGesture() {
        // 发送全局隐藏键盘指令
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Bug #2 修复：App 进入前台时清除 Badge
    func applicationWillEnterForeground(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
        // 清除通知中心里的所有已送达通知
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // Bug #2 修复：App 变为活跃状态时也清除 Badge
    func applicationDidBecomeActive(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
        // 清除通知中心里的所有已送达通知
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // 在前台时也显示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 用户在 App 内时，只显示 banner 和声音，不设置 badge（红点）
        // banner 会自动消失，不会留在通知中心
        completionHandler([.banner, .sound])
        
        // 立即清除刚送达的通知（因为用户已在 App 内，不需要保留）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }
    
    // 用户点击通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Bug #2 修复：点击通知时清除 Badge 和通知中心
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        let identifier = response.notification.request.identifier
        print("用户点击了通知: \(identifier)")
        
        // 根据通知类型跳转到相应页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if identifier.hasPrefix("reminder_") || identifier.hasPrefix("feeding_") || 
               identifier.hasPrefix("checkup_") || identifier.hasPrefix("molting_") ||
               identifier.hasPrefix("bath_") || identifier.hasPrefix("custom_") {
                // 提醒类通知：跳转到首页（提醒区域）
                NotificationCenter.default.post(name: NSNotification.Name("OpenReminders"), object: nil)
            } else {
                // 其他通知：默认跳转到首页
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Universal Links 处理
    /// 处理从网页跳转到 App 的 Universal Links
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        logger.info("🔗 AppDelegate 收到 Universal Link activity")
        
        // 检查是否是网页链接类型
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            logger.warning("🔗 不是有效的 Universal Link")
            return false
        }
        
        logger.info("🔗 处理 Universal Link: \(url.absoluteString)")
        return UniversalLinkHandler.shared.handleUniversalLink(url)
    }
}

// MARK: - 图片缓存管理器
class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // 设置内存缓存限制
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // 设置磁盘缓存目录
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func image(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        
        // 1. 先检查内存缓存
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        // 2. 检查磁盘缓存
        let filePath = cacheDirectory.appendingPathComponent(key.hash.description)
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            // 加载到内存缓存
            cache.setObject(image, forKey: key)
            return image
        }
        
        return nil
    }
    
    func store(_ image: UIImage, for url: URL) {
        let key = url.absoluteString as NSString
        
        // 存入内存缓存
        cache.setObject(image, forKey: key)
        
        // 异步存入磁盘缓存
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let filePath = self.cacheDirectory.appendingPathComponent(key.hash.description)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: filePath)
            }
        }
    }
}

// MARK: - 带缓存的异步图片加载（使用 ImageLoader）
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let size: ImageSize
    let content: (AsyncImagePhase) -> Content
    
    @StateObject private var loader = ImageLoader()
    
    init(url: URL?, size: ImageSize = .medium, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.size = size
        self.content = content
    }
    
    private var phase: AsyncImagePhase {
        if let image = loader.image {
            return .success(Image(uiImage: image))
        } else if loader.loadFailed {
            return .failure(URLError(.cannotLoadFromNetwork))
        } else if loader.isLoading {
            return .empty
        } else if url == nil {
            return .failure(URLError(.badURL))
        } else {
            return .empty
        }
    }
    
    var body: some View {
        content(phase)
            .onAppear {
                if let url = url {
                    loader.load(from: url.absoluteString, size: size)
                }
            }
            .onDisappear {
                loader.cancel()
            }
    }
}

// MARK: - 滚动预加载修饰符
extension View {
    func preloadImages(_ urls: [String], size: ImageSize = .medium) -> some View {
        self.onAppear {
            ImagePreloader.shared.preload(urls, size: size)
        }
    }
}

// MARK: - TabBar 可见性管理器
/// 使用引用计数机制管理 TabBar 可见性
/// 当嵌套导航时（如 BirdDetailView -> PhysiologicalCycleView），
/// 每层详情页都会调用 hide()，但只有全部返回后才显示 TabBar
class TabBarVisibilityManager: ObservableObject {
    static let shared = TabBarVisibilityManager()
    @Published var isVisible: Bool = true
    
    /// 隐藏计数器：记录有多少层视图需要隐藏 TabBar
    private var hideCount: Int = 0
    private let lock = NSLock()
    
    private init() {}
    
    /// 请求隐藏 TabBar（引用计数 +1）
    func hide() {
        lock.lock()
        hideCount += 1
        let shouldHide = hideCount > 0
        lock.unlock()
        
        DispatchQueue.main.async {
            if shouldHide && self.isVisible {
                self.isVisible = false
            }
        }
    }
    
    /// 请求显示 TabBar（引用计数 -1，只有计数为0时才真正显示）
    func show() {
        lock.lock()
        hideCount = max(0, hideCount - 1)
        let shouldShow = hideCount == 0
        lock.unlock()
        
        DispatchQueue.main.async {
            if shouldShow && !self.isVisible {
                self.isVisible = true
            }
        }
    }
    
    /// 强制重置状态（用于调试或异常恢复）
    func reset() {
        lock.lock()
        hideCount = 0
        lock.unlock()
        
        DispatchQueue.main.async {
            self.isVisible = true
        }
    }
}

// MARK: - 自定义 TabBar 替代原生 TabView（解决 iOS 26.1 玻璃态白边 bug）
struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var splashManager = SplashLaunchManager.shared
    @ObservedObject private var tabBarVisibility = TabBarVisibilityManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    @ObservedObject private var nearbyService = NearbyFindBirdService.shared
    @State private var showNearbyFindBirdAlert = false
    
    init() {
        // 隐藏原生 TabBar
        UITabBar.appearance().isHidden = true
        
        // 初始化导航栏主题
        ThemeManager.shared.updateNavigationBarAppearance()
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景色穿透整个屏幕
            Color(.systemBackground).ignoresSafeArea()
            
            // 页面内容切换（每个页面用 NavigationStack 包裹以支持返回手势）
            Group {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        BirdListView()
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: tabBarVisibility.isVisible ? 49 : 0)
                            }
                    }
                case 1:
                    NavigationStack {
                        EncyclopediaView()
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: tabBarVisibility.isVisible ? 49 : 0)
                            }
                    }
                case 2:
                    NavigationStack {
                        ForumView()
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: tabBarVisibility.isVisible ? 49 : 0)
                            }
                    }
                case 3:
                    NavigationStack {
                        ProfileView()
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: tabBarVisibility.isVisible ? 49 : 0)
                            }
                    }
                default:
                    NavigationStack {
                        BirdListView()
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: tabBarVisibility.isVisible ? 49 : 0)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 自定义底部导航栏（根据可见性状态显示/隐藏）
            if tabBarVisibility.isVisible {
                customTabBar
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenReminders"))) { _ in
            selectedTab = 0
        }
        // Universal Links 处理：收到帖子链接时切换到广场 Tab
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPostFromUniversalLink"))) { notification in
            if let postId = notification.userInfo?["postId"] as? Int64 {
                print("🔗 MainTabView 收到 Universal Link，切换到广场 Tab，帖子 ID: \(postId)")
                // 切换到广场 Tab
                selectedTab = 2
            }
        }
        .onChange(of: themeManager.currentTheme) { _, _ in
            themeManager.updateNavigationBarAppearance()
        }
        .id("\(themeManager.currentTheme.rawValue)_\(langManager.current.rawValue)")
        .environment(\.locale, Locale(identifier: langManager.current.rawValue == "zh" ? "zh-Hans" : langManager.current.rawValue))
        .preferredColorScheme(themeManager.isDarkTheme ? .dark : nil)  // 黑客黑主题强制深色模式
        .withToast()
        .fullScreenCover(isPresented: $splashManager.showSplash) {
            SplashCarouselView(
                images: splashManager.splashImages,
                isPresented: $splashManager.showSplash
            )
        }
        // 附近寻鸟帖提醒
        .onAppear {
            nearbyService.startPolling()
        }
        .onChange(of: nearbyService.alertPost?.id) { _, newId in
            if newId != nil {
                showNearbyFindBirdAlert = true
            }
        }
        .alert("🚨 附近有鸟儿走失", isPresented: $showNearbyFindBirdAlert) {
            Button("查看详情") {
                if let post = nearbyService.alertPost {
                    nearbyService.markAlerted(post.id)
                    // 切换到广场Tab
                    selectedTab = 2
                    // 通知ForumView打开该帖子
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenNearbyFindBirdPost"),
                            object: nil,
                            userInfo: ["postId": post.id]
                        )
                    }
                }
            }
            Button("知道了", role: .cancel) {
                if let post = nearbyService.alertPost {
                    nearbyService.markAlerted(post.id)
                }
            }
        } message: {
            if let post = nearbyService.alertPost {
                let birdName = post.birdName ?? "小鸟"
                let location = post.locationName ?? "附近"
                Text("您附近10公里内有人发布了寻鸟帖\n\n🐦 鸟儿：\(birdName)\n📍 位置：\(location)\n\n如果您看到了这只鸟儿，请帮忙联系失主！")
            } else {
                Text("附近有鸟儿走失，请查看详情")
            }
        }
    }
    
    // MARK: - 自定义底部导航栏
    private var customTabBar: some View {
        HStack(spacing: 0) {
            CustomTabItem(icon: "house.fill", title: L10n.tabHome, isSelected: selectedTab == 0, primaryColor: themeManager.primaryColor) {
                if selectedTab != 0 {
                    HapticFeedback.selection()
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedTab = 0
                    }
                }
            }
            CustomTabItem(icon: "book.fill", title: L10n.tabEncyclopedia, isSelected: selectedTab == 1, primaryColor: themeManager.primaryColor) {
                if selectedTab != 1 {
                    HapticFeedback.selection()
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedTab = 1
                    }
                }
            }
            CustomTabItem(icon: "bubble.left.and.bubble.right.fill", title: L10n.tabForum, isSelected: selectedTab == 2, primaryColor: themeManager.primaryColor) {
                if selectedTab != 2 {
                    HapticFeedback.selection()
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedTab = 2
                    }
                }
            }
            CustomTabItem(icon: "person.fill", title: L10n.tabProfile, isSelected: selectedTab == 3, primaryColor: themeManager.primaryColor) {
                if selectedTab != 3 {
                    HapticFeedback.selection()
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedTab = 3
                    }
                }
            }
        }
        .frame(height: 50)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - 单个 Tab 项（苹果风格）
struct CustomTabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let primaryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? primaryColor : Color.gray.opacity(0.6))
                    .scaleEffect(isSelected ? 1.0 : 0.95)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? primaryColor : Color.gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

