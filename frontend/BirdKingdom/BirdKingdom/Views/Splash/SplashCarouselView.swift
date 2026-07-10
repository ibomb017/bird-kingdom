import SwiftUI
import Combine

/// 开屏轮播视图
/// 在 App 启动时展示用户购买的开屏图片
struct SplashCarouselView: View {
    let images: [SplashService.SplashImage]
    @Binding var isPresented: Bool
    
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State private var remainingTime: Double = 0
    
    private let displayDuration: Double = 2.5 // 每张图片展示时长
    
    var body: some View {
        ZStack {
            // 黑色背景
            Color.black
                .ignoresSafeArea()
            
            // 轮播图片
            if !images.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        SplashImageView(imageUrl: image.url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
            
            // UI 叠加层
            VStack {
                // 顶部：左边倒计时，右边跳过按钮
                HStack {
                    // 左上角倒计时
                    countdownView
                    
                    Spacer()
                    
                    // 右上角跳过按钮
                    skipButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // 底部：页码指示器和 App 名称
                VStack(spacing: 16) {
                    // 页码指示器
                    if images.count > 1 {
                        pageIndicator
                    }
                    
                    // App 名称
                    Text(NSLocalizedString("鸟鸟王国", comment: ""))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - 左上角倒计时
    
    private var countdownView: some View {
        Text("\(Int(ceil(remainingTime)))s")
            .font(.system(size: 14, weight: .medium))
            .monospacedDigit()
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
    }
    
    // MARK: - 右上角跳过按钮
    
    private var skipButton: some View {
        Button {
            skip()
        } label: {
            Text(NSLocalizedString("跳过", comment: ""))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
        }
    }
    
    // MARK: - 进度条
    
    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<images.count, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // 背景
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                        
                        // 进度
                        Capsule()
                            .fill(Color.adaptiveCard)
                            .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 40)
    }
    
    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentIndex {
            return totalWidth // 已播放完的全满
        } else if index == currentIndex {
            // 当前播放的图片，根据剩余时间计算进度
            let elapsed = displayDuration - remainingTime
            let progress = elapsed / displayDuration
            return totalWidth * CGFloat(min(max(progress, 0), 1))
        } else {
            return 0 // 未播放的空
        }
    }
    
    // MARK: - 页码指示器
    
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<images.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    // MARK: - 定时器
    
    private func startTimer() {
        remainingTime = displayDuration * Double(images.count - currentIndex)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            remainingTime -= 0.1
            
            if remainingTime <= 0 {
                skip()
                return
            }
            
            // 检查是否需要切换到下一张
            let totalElapsed = displayDuration * Double(images.count) - remainingTime
            let newIndex = Int(totalElapsed / displayDuration)
            
            if newIndex < images.count && newIndex != currentIndex {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = newIndex
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func skip() {
        stopTimer()
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - 单张图片视图

struct SplashImageView: View {
    let imageUrl: String
    @State private var cachedImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    private let imageCache = SplashImageCache.shared
    
    var body: some View {
        Group {
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            } else if loadFailed {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(NSLocalizedString("图片加载失败", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // 先检查缓存
        if let cached = imageCache.getImage(for: imageUrl) {
            cachedImage = cached
            isLoading = false
            return
        }
        
        // 从网络加载
        guard let url = URL(string: imageUrl) else {
            loadFailed = true
            isLoading = false
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    imageCache.setImage(image, for: imageUrl)
                    await MainActor.run {
                        cachedImage = image
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        loadFailed = true
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    loadFailed = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 图片缓存管理器

class SplashImageCache {
    static let shared = SplashImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // 创建缓存目录
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("SplashImages")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 设置内存缓存限制
        cache.countLimit = 20
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    /// 获取缓存的图片
    func getImage(for url: String) -> UIImage? {
        // 先检查内存缓存
        if let image = cache.object(forKey: url as NSString) {
            return image
        }
        
        // 再检查磁盘缓存
        let fileURL = cacheFileURL(for: url)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: url as NSString)
            return image
        }
        
        return nil
    }
    
    /// 缓存图片
    func setImage(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
        
        // 异步写入磁盘
        DispatchQueue.global(qos: .background).async {
            if let data = image.jpegData(compressionQuality: 0.8) {
                let fileURL = self.cacheFileURL(for: url)
                try? data.write(to: fileURL)
            }
        }
    }
    
    /// 预加载图片
    func preloadImages(_ urls: [String]) async {
        for url in urls {
            if getImage(for: url) != nil {
                continue // 已缓存
            }
            
            guard let imageURL = URL(string: url) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    setImage(image, for: url)
                }
            } catch {
                print("❌ 预加载图片失败: \(url), \(error)")
            }
        }
    }
    
    private func cacheFileURL(for url: String) -> URL {
        let fileName = url.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        return cacheDirectory.appendingPathComponent(fileName)
    }
    
    /// 清理过期缓存（7天前）
    func cleanupOldCache() {
        DispatchQueue.global(qos: .background).async {
            let threshold = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            guard let files = try? self.fileManager.contentsOfDirectory(
                at: self.cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }
            
            for file in files {
                if let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                   let modDate = attrs.contentModificationDate,
                   modDate < threshold {
                    try? self.fileManager.removeItem(at: file)
                }
            }
        }
    }
}

// MARK: - App 启动管理器

class SplashLaunchManager: ObservableObject {
    static let shared = SplashLaunchManager()
    
    @Published var showSplash = false
    @Published var splashImages: [SplashService.SplashImage] = []
    @Published var isPreloading = false
    @Published var isCheckingConfig = true  // 标记是否正在检查配置
    
    /// VIP 用户是否选择显示广告（默认不显示，即去除广告）
    @Published var vipShowAds: Bool {
        didSet {
            UserDefaults.standard.set(vipShowAds, forKey: "vip_show_ads")
        }
    }
    
    private let imageCache = SplashImageCache.shared
    private var hasChecked = false  // 防止重复检查
    
    private init() {
        // 读取 VIP 用户的广告偏好（默认 false，即去除广告）
        self.vipShowAds = UserDefaults.standard.bool(forKey: "vip_show_ads")
        
        // 启动时清理过期缓存
        imageCache.cleanupOldCache()
        
        // ✅ P0修复：启动时重试未完成的支付确认
        retryPendingPaymentsOnLaunch()
        
        // 立即开始检查开屏配置
        checkLaunchConfig()
    }
    
    /// 启动时重试未完成的支付（异步执行，不阻塞启动）
    private func retryPendingPaymentsOnLaunch() {
        Task {
            // 延迟 2 秒再执行，确保网络和认证服务已就绪
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            // 1. 重试开屏庆生待同步支付
            await SplashService.shared.retryPendingPayments()
            
            // 2. 重试 VIP 待同步订单
            await retryPendingVipPurchases()
        }
    }
    
    /// 重试 VIP 待同步订单
    private func retryPendingVipPurchases() async {
        var pendingList = UserDefaults.standard.array(forKey: "pendingVipPurchases") as? [[String: Any]] ?? []
        
        guard !pendingList.isEmpty else { return }
        guard AuthService.shared.isLoggedIn else {
            print("⚠️ VIP 待同步订单重试：用户未登录，跳过")
            return
        }
        
        print("🔄 检测到 \(pendingList.count) 个 VIP 待同步订单，开始重试...")
        
        var successfulIndices: [Int] = []
        
        for (index, purchase) in pendingList.enumerated() {
            guard let vipType = purchase["vipType"] as? String else { continue }
            
            let duration = purchase["duration"] as? Int
            let txId = purchase["originalTransactionId"] as? String
            let productId = purchase["productId"] as? String
            let purchaseDateMs = purchase["purchaseDate"] as? Int64
            
            // 构建交易信息
            let txInfo: (originalTransactionId: String, productId: String, purchaseDate: Int64)? = {
                if let txId = txId, let productId = productId, let purchaseDateMs = purchaseDateMs {
                    return (txId, productId, purchaseDateMs)
                }
                return nil
            }()
            
            do {
                let response = try await ApiService.shared.purchaseVip(
                    vipType: vipType,
                    duration: duration,
                    transactionInfo: txInfo
                )
                
                if response.success {
                    successfulIndices.append(index)
                    print("✅ VIP 待同步订单重试成功: vipType=\(vipType)")
                } else {
                    print("⚠️ VIP 待同步订单重试失败: \(response.message)")
                }
            } catch {
                print("⚠️ VIP 待同步订单重试错误: \(error.localizedDescription)")
            }
        }
        
        // 移除成功的记录（从后往前删除避免索引错乱）
        for index in successfulIndices.reversed() {
            pendingList.remove(at: index)
        }
        
        UserDefaults.standard.set(pendingList, forKey: "pendingVipPurchases")
        
        if !successfulIndices.isEmpty {
            print("✅ 已移除 \(successfulIndices.count) 个成功同步的 VIP 订单")
            // 刷新用户信息
            try? await AuthService.shared.fetchCurrentUser()
        }
    }
    
    /// 切换 VIP 广告显示状态
    func toggleVipAds() {
        vipShowAds.toggle()
    }
    
    /// 检查并加载开屏配置
    func checkLaunchConfig() {
        // 防止重复检查
        guard !hasChecked else { return }
        hasChecked = true
        
        Task {
            defer {
                Task { @MainActor in
                    self.isCheckingConfig = false
                }
            }
            
            // ✅ VIP 用户默认跳过广告（除非用户选择显示）
            if let user = AuthService.shared.currentUser, user.isVipValid {
                if !vipShowAds {
                    print("✅ VIP 用户已去除广告，跳过开屏展示")
                    return
                }
            }
            
            do {
                let config = try await SplashService.shared.getLaunchConfig()
                
                if config.hasSplash && !config.images.isEmpty {
                    // 预加载第一张图片（确保快速展示）
                    let firstImageUrl = config.images[0].url
                    await preloadFirstImage(firstImageUrl)
                    
                    await MainActor.run {
                        self.splashImages = config.images
                        self.showSplash = true
                    }
                    
                    // 后台预加载其他图片
                    let otherUrls = config.images.dropFirst().map { $0.url }
                    await imageCache.preloadImages(Array(otherUrls))
                }
            } catch {
                print("❌ 获取启动配置失败: \(error)")
                // 失败时不展示开屏
            }
        }
    }
    
    /// 预加载第一张图片
    private func preloadFirstImage(_ url: String) async {
        if imageCache.getImage(for: url) != nil {
            return // 已缓存
        }
        
        guard let imageURL = URL(string: url) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            if let image = UIImage(data: data) {
                imageCache.setImage(image, for: url)
            }
        } catch {
            print("❌ 预加载第一张图片失败: \(error)")
        }
    }
}

#Preview {
    SplashCarouselView(
        images: [
            SplashService.SplashImage(imageUrl: "https://via.placeholder.com/1080x1920/FF6B6B/FFFFFF?text=Happy+Birthday", userId: 1),
            SplashService.SplashImage(imageUrl: "https://via.placeholder.com/1080x1920/4ECDC4/FFFFFF?text=Congratulations", userId: 2),
            SplashService.SplashImage(imageUrl: "https://via.placeholder.com/1080x1920/45B7D1/FFFFFF?text=Best+Wishes", userId: 3)
        ],
        isPresented: .constant(true)
    )
}
