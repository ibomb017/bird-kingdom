//
//  EncyclopediaView.swift
//  BirdKingdom
//
//  百科页面及相关视图
//

import SwiftUI
import Combine

// MARK: - P0-V04 FIX: 品种收藏管理器（用户隔离）
class SpeciesFavoriteManager: ObservableObject {
    static let shared = SpeciesFavoriteManager()
    
    @Published var favoriteSpeciesIds: Set<Int64> = []
    
    // P0-V04 FIX: 动态生成用户专属 key
    private var userDefaultsKey: String {
        guard let userId = AuthService.shared.currentUser?.id else {
            return "guest_favoriteSpeciesIds"
        }
        return "favoriteSpeciesIds_\(userId)"
    }
    
    private var currentUserId: Int64?
    
    private init() {
        loadFavorites()
        // 监听用户切换
        NotificationCenter.default.addObserver(
            forName: .userDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleUserChange()
        }
    }
    
    // P0-V04 FIX: 用户切换时重新加载收藏
    private func handleUserChange() {
        let newUserId = AuthService.shared.currentUser?.id
        if newUserId != currentUserId {
            currentUserId = newUserId
            loadFavorites()
        }
    }
    
    func isFavorite(_ bird: BirdEncyclopediaDTO) -> Bool {
        favoriteSpeciesIds.contains(bird.id)
    }
    
    func toggleFavorite(_ bird: BirdEncyclopediaDTO) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        if favoriteSpeciesIds.contains(bird.id) {
            favoriteSpeciesIds.remove(bird.id)
        } else {
            favoriteSpeciesIds.insert(bird.id)
        }
        saveFavorites()
    }
    
    private func saveFavorites() {
        let ids = favoriteSpeciesIds.map { String($0) }
        UserDefaults.standard.set(ids, forKey: userDefaultsKey)
    }
    
    func loadFavorites() {
        currentUserId = AuthService.shared.currentUser?.id
        if let ids = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            favoriteSpeciesIds = Set(ids.compactMap { Int64($0) })
        } else {
            favoriteSpeciesIds = []
        }
    }
}

// MARK: - P0-V01 FIX: 视图状态枚举
enum EncyclopediaViewState: Equatable {
    case idle
    case loading
    case loaded(isCacheStale: Bool)
    case error(String)
    
    static func == (lhs: EncyclopediaViewState, rhs: EncyclopediaViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.loaded(let l), .loaded(let r)):
            return l == r
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - 百科数据ViewModel（重构版）
class EncyclopediaViewModel: ObservableObject {
    // P0-V01 FIX: 使用状态枚举替代多个布尔值
    @Published var state: EncyclopediaViewState = .idle
    @Published var birds: [BirdEncyclopediaDTO] = []
    @Published var categories: [String] = []
    @Published var searchResults: [BirdEncyclopediaDTO]? = nil
    @Published var isSearching = false
    
    // P0-R01 FIX: 使用 Repository 层
    private let repository = EncyclopediaRepository.shared
    
    // P0-N02 FIX: 搜索任务管理
    private var searchTask: Task<Void, Never>?
    private let searchDebounceInterval: UInt64 = 300_000_000 // 300ms
    
    // 自定义分类排序
    private let categoryOrder = [NSLocalizedString("小型鹦鹉", comment: ""), NSLocalizedString("中型鹦鹉", comment: ""), NSLocalizedString("大型鹦鹉", comment: ""), NSLocalizedString("雀类", comment: ""), L10n.other]
    
    init() {
        // 不在 init 中加载数据，等 onAppear 时调用 loadData()
    }
    
    func loadData() {
        // 防止重复加载
        if case .loading = state { return }
        
        // 有数据时后台刷新
        if !birds.isEmpty {
            Task { await refreshInBackground() }
            return
        }
        
        state = .loading
        
        Task {
            await fetchData(forceRefresh: false)
        }
    }
    
    // P0-R02 FIX: 强制刷新真正绕过缓存
    func forceRefresh() async {
        await MainActor.run { self.state = .loading }
        await fetchData(forceRefresh: true)
    }
    
    // P0-R01 FIX: 使用 Repository 获取数据
    private func fetchData(forceRefresh: Bool) async {
        do {
            let fetchedBirds = try await repository.getBirds(forceRefresh: forceRefresh)
            let fetchedCategories = try await repository.getCategories(forceRefresh: forceRefresh)
            let isStale = repository.isCacheStale  // 在 MainActor 外部读取
            
            await MainActor.run {
                self.birds = fetchedBirds
                self.categories = self.sortCategories(fetchedCategories, birds: fetchedBirds)
                self.state = .loaded(isCacheStale: isStale)
            }
        } catch {
            await MainActor.run {
                if self.birds.isEmpty {
                    self.state = .error(error.localizedDescription)
                } else {
                    // 有缓存数据时不显示错误
                    self.state = .loaded(isCacheStale: true)
                }
            }
        }
    }
    
    private func refreshInBackground() async {
        do {
            let fetchedBirds = try await repository.getBirds(forceRefresh: true)
            let fetchedCategories = try await repository.getCategories(forceRefresh: true)
            
            await MainActor.run {
                self.birds = fetchedBirds
                self.categories = self.sortCategories(fetchedCategories, birds: fetchedBirds)
                self.state = .loaded(isCacheStale: false)
            }
        } catch {
            print("百科后台刷新失败: \(error)")
        }
    }
    
    // 从缓存加载初始数据
    private func loadFromCache() async {
        do {
            let cachedBirds = try await repository.getBirds(forceRefresh: false)
            let cachedCategories = try await repository.getCategories(forceRefresh: false)
            let isStale = repository.isCacheStale  // 在 MainActor 外部读取
            
            await MainActor.run {
                if !cachedBirds.isEmpty {
                    self.birds = cachedBirds
                    self.categories = self.sortCategories(cachedCategories, birds: cachedBirds)
                    self.state = .loaded(isCacheStale: isStale)
                }
            }
        } catch {
            // 缓存加载失败静默处理
            print("📖 缓存加载失败: \(error)")
        }
    }
    
    // 分类排序逻辑
    private func sortCategories(_ categories: [String], birds: [BirdEncyclopediaDTO]) -> [String] {
        categories.sorted { cat1, cat2 in
            let index1 = categoryOrder.firstIndex(of: cat1) ?? 999
            let index2 = categoryOrder.firstIndex(of: cat2) ?? 999
            if index1 != index2 {
                return index1 < index2
            }
            let count1 = birds.filter { $0.category == cat1 }.count
            let count2 = birds.filter { $0.category == cat2 }.count
            return count1 > count2
        }
    }
    
    // P0-N02 FIX: 搜索带防抖和取消
    func searchBirds(keyword: String) {
        guard !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = nil
            isSearching = false
            return
        }
        
        // 取消之前的搜索任务
        searchTask?.cancel()
        isSearching = true
        
        searchTask = Task {
            // 防抖延迟
            try? await Task.sleep(nanoseconds: searchDebounceInterval)
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await repository.searchBirds(keyword: keyword)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.searchResults = nil
                    self.isSearching = false
                }
            }
        }
    }
    
    // 清除搜索结果
    func clearSearch() {
        searchTask?.cancel()
        searchResults = nil
        isSearching = false
    }
    
    func birdsForCategory(_ category: String) -> [BirdEncyclopediaDTO] {
        let filtered = birds.filter { $0.category == category }
        // 小型鹦鹉分类：桃脸牡丹鹦鹉排第一
        if category == NSLocalizedString("小型鹦鹉", comment: "") {
            return filtered.sorted { bird1, bird2 in
                if bird1.name == NSLocalizedString("桃脸牡丹鹦鹉", comment: "") { return true }
                if bird2.name == NSLocalizedString("桃脸牡丹鹦鹉", comment: "") { return false }
                return bird1.name < bird2.name
            }
        }
        return filtered
    }
    
    // P0-V01 FIX: 便捷计算属性
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }
    
    var isCacheStale: Bool {
        if case .loaded(let stale) = state { return stale }
        return false
    }
}

// MARK: - 百科页面
struct EncyclopediaView: View {
    @State private var selectedMode = 0
    @State private var selectedBird: BirdEncyclopediaDTO? = nil
    @State private var showBirdDetail = false
    // B-001 FIX: 添加鸟类百科搜索功能
    @State private var birdSearchText = ""
    // P3-01: 品种收藏管理
    @ObservedObject var favoriteManager = SpeciesFavoriteManager.shared
    // 百科数据ViewModel
    @StateObject private var viewModel = EncyclopediaViewModel()
    
    private let modes = [L10n.smartDiagnosis, L10n.encyclopedia, L10n.foodQuery, L10n.symptomQuery, L10n.voiceRecognition]
    private let modeIcons = ["stethoscope", "book.fill", "leaf.fill", "cross.case.fill", "waveform"]
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏（简洁下划线风格）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(0..<modes.count, id: \.self) { index in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMode = index
                            }
                        } label: {
                            VStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: modeIcons[index])
                                        .font(.system(size: 13))
                                    Text(modes[index])
                                        .font(.system(size: 14, weight: selectedMode == index ? .semibold : .regular))
                                }
                                .foregroundColor(selectedMode == index ? .primary : .secondary)
                                
                                // 下划线指示器
                                Rectangle()
                                    .fill(selectedMode == index ? themeManager.primaryColor : Color.clear)
                                    .frame(height: 2)
                                    .cornerRadius(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
            .background(Color.adaptiveCard)
            
            // 内容区域（支持左右滑动）
            TabView(selection: $selectedMode) {
                    // 智能问诊
                    AIConsultView()
                        .tag(0)
                    
                    // 鸟类百科
                    birdEncyclopediaScrollView
                        .tag(1)
                    
                    // 食物查询
                    foodQueryScrollView
                        .tag(2)
                    
                    // 症状查询
                    symptomQueryScrollView
                        .tag(3)
                    
                    // 语音识别
                    voiceRecognitionView
                        .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedMode)
            }
            .background(themeManager.backgroundSecondary) // Use theme backgroundSecondary
            .ignoresSafeArea(.keyboard, edges: .bottom) // Prevent navigation bar from shifting up on keyboard pop-up
        .navigationDestination(item: $selectedBird) { bird in
            BirdEncyclopediaDetailView(bird: bird)
                .hidesTabBar()
        }
        .onAppear {
            if viewModel.birds.isEmpty {
                viewModel.loadData()
            }
        }
    }
    
    // MARK: - 各页面的ScrollView（解决滑动冲突 + 键盘收起）
    private var birdEncyclopediaScrollView: some View {
        ScrollView {
            birdEncyclopediaView
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)  // 滑动时交互式收起键盘
        .onTapGesture { hideKeyboard() }  // 点击空白处收起键盘
    }
    
    private var foodQueryScrollView: some View {
        ScrollView {
            FoodQueryView()
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { hideKeyboard() }
    }
    
    private var symptomQueryScrollView: some View {
        ScrollView {
            SymptomQueryView()
                .padding(.top, 4)
                .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { hideKeyboard() }
    }
    
    // MARK: - 语音识别视图
    @State private var showVoiceRecognition = false
    
    private var voiceRecognitionView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            
            // 顶部图标
            ZStack {
                Circle()
                    .fill(themeManager.primaryColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(themeManager.primaryColor)
            }
            
            Text(NSLocalizedString("鸟类语音识别", comment: ""))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.textPrimary)
            
            Text(NSLocalizedString("基于MFCC特征提取与CNN深度学习模型\n在设备本地完成识别，无需联网", comment: ""))
                .font(.subheadline)
                .foregroundColor(themeManager.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // 功能特点
            VStack(spacing: 12) {
                featureRow(icon: "mic.fill", text: NSLocalizedString("实时录音，2-10秒即可识别", comment: ""))
                featureRow(icon: "cpu", text: NSLocalizedString("端侧CNN推理，约32ms完成", comment: ""))
                featureRow(icon: "bird.fill", text: String(format: NSLocalizedString("支持识别%d种常见鸟类", comment: ""), BirdVoiceRecognitionService.supportedSpecies.count))
                featureRow(icon: "lock.shield.fill", text: NSLocalizedString("音频仅在本地处理，保护隐私", comment: ""))
            }
            .padding(.top, 10)
            
            Spacer()
            
            // 开始识别按钮
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                showVoiceRecognition = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                    Text(NSLocalizedString("开始识别", comment: ""))
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [themeManager.primaryColor, themeManager.primaryColor.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 8, y: 4)
                )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .fullScreenCover(isPresented: $showVoiceRecognition) {
            BirdVoiceRecognitionView()
                .environmentObject(themeManager)
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeManager.primaryColor)
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
                .foregroundColor(themeManager.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 60)
    }
    
    // MARK: - 鸟类百科视图
    private var birdEncyclopediaView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // B-002 FIX: 搜索框（调用后端模糊搜索API）
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(NSLocalizedString("搜索鸟类品种...", comment: ""), text: $birdSearchText)
                        .font(.subheadline)
                        .submitLabel(.search)
                        .onSubmit {
                            hideKeyboard()
                        }
                        .onChange(of: birdSearchText) { newValue in
                            // B-002 FIX: 防抖搜索，调用后端API
                            if newValue.isEmpty {
                                viewModel.clearSearch()
                            } else {
                                viewModel.searchBirds(keyword: newValue)
                            }
                        }
                    if viewModel.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !birdSearchText.isEmpty {
                        Button {
                            birdSearchText = ""
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.adaptiveCard)
                .cornerRadius(12)
                
                if !birdSearchText.isEmpty {
                    Button(L10n.cancel) {
                        birdSearchText = ""
                        viewModel.clearSearch()
                        hideKeyboard()
                    }
                    .foregroundColor(themeManager.primaryColor)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: birdSearchText.isEmpty)
            
            if viewModel.isLoading {
                UnifiedStateView.loading
                    .padding(.top, 50)
            } else if let error = viewModel.errorMessage {
                UnifiedStateView.error(error) {
                    viewModel.loadData()
                }
                .padding(.top, 50)
            } else {
                // B-002 FIX: 如果有搜索结果，显示搜索结果；否则按分类显示
                if let searchResults = viewModel.searchResults, !birdSearchText.isEmpty {
                    // 显示后端模糊搜索结果
                    if searchResults.isEmpty {
                        UnifiedStateView.noResults
                            .padding(.vertical, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(themeManager.primaryColor)
                                Text(NSLocalizedString("搜索结果", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(themeManager.textPrimary)
                                Spacer()
                                Text(String(format: NSLocalizedString("%d 种", comment: ""), searchResults.count))
                                    .font(.caption)
                                    .foregroundColor(themeManager.textSecondary)
                            }
                            .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(searchResults) { bird in
                                    Button {
                                        selectedBird = bird
                                    } label: {
                                        birdCard(bird: bird)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                } else {
                    // 按分类显示鸟类
                    ForEach(viewModel.categories, id: \.self) { category in
                        let birdsInCategory = viewModel.birdsForCategory(category)
                    if !birdsInCategory.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            // 分类标题
                            HStack {
                                Image(systemName: iconForCategory(category))
                                    .foregroundColor(themeManager.primaryColor)
                                Text(category)
                                    .font(.headline)
                                    .foregroundColor(themeManager.textPrimary)
                                Spacer()
                                Text(String(format: NSLocalizedString("%d 种", comment: ""), birdsInCategory.count))
                                    .font(.caption)
                                    .foregroundColor(themeManager.textSecondary)
                            }
                            .padding(.horizontal, 4)
                            
                            // 该分类下的鸟类
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(birdsInCategory) { bird in
                                    Button {
                                        selectedBird = bird
                                    } label: {
                                        birdCard(bird: bird)
                                    }
                                    .buttonStyle(ScaleButtonStyle()) // Use new Native Scale Button Style
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    }
                }
            }
        }
    }
    
    // 根据分类名称返回图标
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case NSLocalizedString("大型鹦鹉", comment: ""):
            return "bird.fill"
        case NSLocalizedString("中型鹦鹉", comment: ""):
            return "bird"
        case NSLocalizedString("小型鹦鹉", comment: ""):
            return "leaf.fill"
        case NSLocalizedString("雀类", comment: ""):
            return "leaf.circle.fill"
        default:
            return "pawprint.fill"
        }
    }
    
    // 鸟类卡片（Native Style）
    private var birdCardRef: some View { EmptyView() } // Placeholder for reference
    
    private func birdCard(bird: BirdEncyclopediaDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // B-003 FIX: 图片加载添加重试机制，使用 1:1 比例
            GeometryReader { geometry in
                let size = geometry.size.width
                if let imageUrl = bird.imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                    RetryableAsyncImage(url: url, size: size) {
                        defaultBirdBackground(size: size)
                    }
                } else {
                    defaultBirdBackground(size: size)
                }
            }
            .aspectRatio(1, contentMode: .fit) // 强制 1:1 比例
            
            // 下方信息
            VStack(alignment: .leading, spacing: 6) {
                Text(bird.name)
                    .font(.headline)
                    .foregroundColor(themeManager.textPrimary)
                    .lineLimit(1)
                
                if let scientificName = bird.scientificName {
                    Text(scientificName)
                        .font(.caption)
                        .foregroundColor(themeManager.textSecondary)
                        .italic()
                        .lineLimit(1)
                }
                
                // Tags
                if let tags = bird.tags, !tags.isEmpty {
                    HStack {
                        ForEach(tags.prefix(1), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeManager.primaryColorBackground)
                                .foregroundColor(themeManager.primaryColor)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeManager.cardBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func defaultBirdBackground(size: CGFloat) -> some View {
        Rectangle()
            .fill(themeManager.primaryColor.opacity(0.1))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "bird.fill")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(themeManager.primaryColor.opacity(0.3))
            )
    }
}

// Native Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - B-003 FIX + P1-UI02 FIX: 可重试的异步图片加载组件
struct RetryableAsyncImage<Placeholder: View>: View {
    let url: URL
    let size: CGFloat
    let placeholder: () -> Placeholder
    
    @State private var retryCount = 0
    // P1-UI02 FIX: 使用 retryToken 而非 UUID 来触发重试
    @State private var retryToken = 0
    private let maxRetries = 3
    
    // P1-UI02 FIX: 基于 retryToken 生成带参数的 URL
    private var effectiveURL: URL {
        guard retryCount > 0 else { return url }
        // 添加查询参数触发缓存刷新
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "_retry", value: "\(retryToken)"))
        components?.queryItems = queryItems
        return components?.url ?? url
    }
    
    var body: some View {
        AsyncImage(url: effectiveURL, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            case .failure:
                ZStack {
                    placeholder()
                    if retryCount < maxRetries {
                        Button {
                            retryCount += 1
                            retryToken = Int.random(in: 1000...9999)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 24))
                                Text(NSLocalizedString("点击重试", comment: ""))
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                        }
                    } else {
                        Text(NSLocalizedString("加载失败", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
            case .empty:
                ZStack {
                    placeholder()
                    ProgressView()
                        .scaleEffect(0.8)
                }
            @unknown default:
                placeholder()
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 鸟类百科详情视图（使用API数据）
struct BirdEncyclopediaDetailView: View {
    let bird: BirdEncyclopediaDTO
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 头部信息卡片
                headerCard
                
                // 基本信息
                if bird.scientificName != nil || bird.habitat != nil || bird.lifespan != nil || bird.priceMin != nil {
                    infoSection(title: NSLocalizedString("基本信息", comment: ""), icon: "info.circle.fill") {
                        if let scientificName = bird.scientificName {
                            infoRow(label: NSLocalizedString("学名", comment: ""), value: scientificName)
                        }
                        if let habitat = bird.habitat {
                            infoRow(label: NSLocalizedString("分布", comment: ""), value: habitat)
                        }
                        if let lifespan = bird.lifespan {
                            infoRow(label: NSLocalizedString("寿命", comment: ""), value: "\(lifespan)年")
                        }
                        if let category = bird.category {
                            infoRow(label: NSLocalizedString("分类", comment: ""), value: category)
                        }
                        if let priceRange = bird.priceRangeText {
                            infoRow(label: NSLocalizedString("参考价格", comment: ""), value: priceRange)
                        }
                    }
                }
                
                // 饲养建议
                if let feedingTips = bird.feedingTips, !feedingTips.isEmpty {
                    infoSection(title: NSLocalizedString("饲养建议", comment: ""), icon: "leaf.fill") {
                        Text(feedingTips)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 标签
                if let tags = bird.tags, !tags.isEmpty {
                    infoSection(title: NSLocalizedString("特点标签", comment: ""), icon: "tag.fill") {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(themeManager.primaryColor.opacity(0.15))
                                    .foregroundColor(themeManager.primaryColor)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .themedNavigationBar(title: bird.name)
    }
    
    // 头部卡片
    private var headerCard: some View {
        VStack(spacing: 16) {
            // 图片或默认图标
            if let imageUrl = bird.imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        defaultHeaderIcon
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    case .failure:
                        defaultHeaderIcon
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                defaultHeaderIcon
            }
            
            // 名称
            Text(bird.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let scientificName = bird.scientificName {
                Text(scientificName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // 描述
            if let description = bird.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(themeManager.backgroundColor.opacity(0.5))
        .cornerRadius(16)
    }
    
    private var defaultHeaderIcon: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [themeManager.gradientColors[0].opacity(0.25), themeManager.gradientColors[1].opacity(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "bird.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(
                        LinearGradient(
                            colors: themeManager.gradientColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
    
    // 信息区块
    private func infoSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(themeManager.primaryColor)
                Text(title)
                    .font(.headline)
            }
            
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(themeManager.backgroundColor.opacity(0.5))
        .cornerRadius(14)
    }
    
    // 信息行
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
