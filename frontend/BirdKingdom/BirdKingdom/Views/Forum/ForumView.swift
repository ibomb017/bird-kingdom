//
//  ForumView.swift
//  BirdKingdom
//
//  广场页面及相关视图
//

import SwiftUI
import PhotosUI
import AVKit
import Combine
import CoreLocation

// MARK: - 广场页面
struct ForumView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var locationService = LocationService.shared
    @ObservedObject var socialService = SocialService.shared
    @State private var selectedTab = 2
    @State private var showCreatePost = false
    @State private var showLoginAlert = false
    @State private var showLoginSheet = false
    @State private var showSearch = false
    @State private var showLocationPicker = false
    @State private var searchText = ""
    @State private var isSearchFocused = false  // 搜索框是否聚焦
    @State private var searchHistory: [String] = []  // 搜索历史
    @State private var selectedSort = NSLocalizedString("综合排序", comment: "")
    @State private var selectedRange = NSLocalizedString(NSLocalizedString("附近", comment: ""), comment: "") // 附近/同城/全国 - 仅影响"附近"标签页
    @State private var isLoading = false
    @State private var hasLoadedInitialData = false  // Fix #3: 防重复加载标志
    @State private var isLoadingPosts = false  // Fix #3: 防止并发请求
    @State private var loadingTask: Task<Void, Never>?  // Fix A7: Task 取消机制
    @State private var requestVersion = 0  // Fix #12: 请求版本号，防止旧数据覆盖
    
    // 帖子数据
    @State private var allPosts: [ForumPost] = ForumPost.samplePosts
    @State private var followingPosts: [ForumPost] = []
    @State private var nearbyPosts: [ForumPost] = []
    @State private var recommendedPosts: [ForumPost] = []
    
    // 热门搜索关键词（从后端动态获取）
    @State private var hotKeywords: [String] = []
    
    // Universal Links 状态
    @State private var universalLinkPostId: Int64?
    @State private var universalLinkPost: ForumPost?
    @State private var universalLinkNavigationActive = false
    
    // 根据选择的范围筛选附近帖子 - Fix #3: 优化性能，减少日志
    private var filteredNearbyPosts: [ForumPost] {
        // 定位权限检查
        if locationService.authorizationStatus == .denied || 
           locationService.authorizationStatus == .restricted {
            return []
        }
        
        guard let _ = locationService.currentLocation else {
            return nearbyPosts
        }
        
        // 获取距离限制（公里）
        let maxDistance: Double
        switch selectedRange {
        case NSLocalizedString("附近", comment: ""):
            maxDistance = 3.0
        case NSLocalizedString("同城", comment: ""):
            maxDistance = 50.0
        case NSLocalizedString("全国", comment: ""):
            maxDistance = 5000.0
        default:
            return nearbyPosts
        }
        
        // 筛选在范围内的帖子
        return nearbyPosts.filter { post in
            guard let postLat = post.latitude, let postLng = post.longitude else {
                return selectedRange == NSLocalizedString("全国", comment: "")
            }
            
            let distanceKm = locationService.distanceTo(latitude: postLat, longitude: postLng) ?? Double.infinity
            return distanceKm <= maxDistance
        }
    }
    
    private let tabs = [NSLocalizedString("关注", comment: ""), NSLocalizedString("附近", comment: ""), NSLocalizedString("推荐", comment: "")]
    private let sortOptions = [NSLocalizedString("最热", comment: ""), NSLocalizedString("最新", comment: "")]  // 小红书风格排序
    @State private var selectedSearchSort = NSLocalizedString("最热", comment: "")  // 搜索时的排序
    @State private var selectedMediaFilter = NSLocalizedString("全部", comment: "")  // 媒体类型筛选
    private let mediaFilterOptions = [NSLocalizedString("全部", comment: ""), NSLocalizedString("图文", comment: ""), NSLocalizedString("视频", comment: "")]
    @ObservedObject var themeManager = ThemeManager.shared
    
    // 导航栏高度（用于内容避让）
    private var navigationBarHeight: CGFloat {
        let headerHeight: CGFloat = 44
        let tabBarHeight: CGFloat = 44
        let searchBarHeight: CGFloat = showSearch ? 56 : 0
        return headerHeight + tabBarHeight + searchBarHeight
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 后台发布进度条
            PublishProgressBar()
            
            // 顶部导航栏（普通白色背景）
            VStack(spacing: 0) {
                headerView
                if showSearch {
                    searchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                    
                    // 搜索筛选条（有搜索内容时显示）
                    if !searchText.isEmpty {
                        searchFilterBar
                            .transition(.opacity)
                    }
                }
                tabBar
            }
            .background(Color.adaptiveCard)
            .overlay(alignment: .bottom) {
                Divider().opacity(0.3) // 极细分割线
            }
            
            // 内容主体层 - 帖子列表
            ZStack {
                Color(.systemBackground)
                postsListView
                
                // 发帖按钮（悬浮在右下角）
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        createPostButton
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        // 发帖按钮 - 使用 navigationDestination 支持左滑返回
        .navigationDestination(isPresented: $showCreatePost) {
            CreatePostView { newPost in
                // 添加到所有列表
                allPosts.insert(newPost, at: 0)
                recommendedPosts.insert(newPost, at: 0)
                nearbyPosts.insert(newPost, at: 0)
            }
            .hidesTabBar()
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(selectedRange: $selectedRange)
        }
        .alert(NSLocalizedString("请先登录", comment: ""), isPresented: $showLoginAlert) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("去登录", comment: "")) {
                showLoginSheet = true
            }
        } message: {
            Text(NSLocalizedString("登录后才能发布帖子，快去登录吧～", comment: ""))
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .onAppear {
            // Fix #3: 防止重复加载
            guard !hasLoadedInitialData else { return }
            hasLoadedInitialData = true
            loadInitialData()
            // Fix #22: 不再在 onAppear 时自动请求定位权限
            // 定位权限改为仅在切换到「附近」Tab 时请求，符合 Apple 隐私指南
        }
        // Fix #22: 仅在用户主动切换到「附近」Tab 时请求定位权限
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 1 { // 附近 Tab
                // 仅在未授权时请求，已授权则开始定位
                if locationService.authorizationStatus == .notDetermined {
                    locationService.requestPermission()
                } else if locationService.authorizationStatus == .authorizedWhenInUse || 
                          locationService.authorizationStatus == .authorizedAlways {
                    locationService.startLocating()
                }
            }
        }
        // Fix A7: 页面销毁时取消未完成的 Task
        .onDisappear {
            loadingTask?.cancel()
            loadingTask = nil
        }
        // Fix #12: 监听帖子删除通知
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PostDeleted"))) { notification in
            if let postId = notification.userInfo?["postId"] as? Int64 {
                recommendedPosts.removeAll { $0.id == postId }
                nearbyPosts.removeAll { $0.id == postId }
                followingPosts.removeAll { $0.id == postId }
                allPosts.removeAll { $0.id == postId }
            }
        }
        // Universal Links 处理：收到帖子链接时自动导航到帖子详情
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPostFromUniversalLink"))) { notification in
            if let postId = notification.userInfo?["postId"] as? Int64 {
                print("🔗 ForumView 收到 Universal Link，帖子 ID: \(postId)")
                universalLinkPostId = postId
                universalLinkNavigationActive = true
                // 从服务器加载这个帖子的详情
                loadPostFromUniversalLink(postId: postId)
            }
        }
        // Universal Links 导航目标
        .navigationDestination(isPresented: $universalLinkNavigationActive) {
            if let post = universalLinkPost {
                PostDetailView(post: post, primaryColor: themeManager.primaryColor)
                    .hidesTabBar()
            } else if let postId = universalLinkPostId {
                // 加载中状态
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(NSLocalizedString("加载帖子中...", comment: ""))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    loadPostFromUniversalLink(postId: postId)
                }
            }
        }
    }
    
    // MARK: - 顶部导航栏
    private var headerView: some View {
        HStack(spacing: 12) {
            // 位置选择 - 只在"附近"标签页显示
            if selectedTab == 1 {
                Button {
                    showLocationPicker = true
                } label: {
                    HStack(spacing: 4) {
                        if locationService.isLocating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 13))
                        }
                        Text(selectedRange)
                            .font(.subheadline)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(themeManager.primaryColor)
                }
            }
            
            Spacer()
            
            // 排序选择
            Menu {
                ForEach(sortOptions, id: \.self) { option in
                    Button {
                        selectedSort = option
                    } label: {
                        HStack {
                            Text(option)
                            if selectedSort == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedSort)
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(14)
            }
            
            // 搜索按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSearch.toggle()
                    if !showSearch {
                        searchText = ""
                    }
                }
            } label: {
                Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(themeManager.primaryColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    // MARK: - 搜索栏
    @FocusState private var searchFieldFocused: Bool
    @State private var searchSuggestions: [String] = []  // 实时联想建议
    @State private var debounceTask: Task<Void, Never>? = nil  // 防抖任务
    
    private var searchBar: some View {
        VStack(spacing: 0) {
            // 搜索输入框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField(NSLocalizedString("搜索帖子、用户、鸟名、品种...", comment: ""), text: $searchText)
                    .font(.subheadline)
                    .focused($searchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        // 提交搜索时保存到历史
                        saveSearchHistory(searchText)
                        searchFieldFocused = false
                        searchSuggestions = []
                    }
                    .onChange(of: searchText) { _, newValue in
                        // 输入防抖处理（300ms）
                        debounceTask?.cancel()
                        if !newValue.isEmpty {
                            debounceTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        updateSearchSuggestions(for: newValue)
                                    }
                                }
                            }
                        } else {
                            searchSuggestions = []
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchSuggestions = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // 搜索建议面板
            if searchFieldFocused {
                if searchText.isEmpty {
                    // 无输入时显示历史和热门
                    searchSuggestionsPanel
                } else if !searchSuggestions.isEmpty {
                    // 有输入时显示实时联想
                    realTimeSuggestionsPanel
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            loadSearchHistory()
        }
    }
    
    // MARK: - 实时联想建议面板
    private var realTimeSuggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(searchSuggestions.prefix(6), id: \.self) { suggestion in
                Button {
                    searchText = suggestion
                    saveSearchHistory(suggestion)
                    searchFieldFocused = false
                    searchSuggestions = []
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 高亮匹配部分
                        highlightedSuggestion(suggestion, keyword: searchText)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.adaptiveCard)
        .transition(.opacity)
    }
    
    // 高亮联想词中的匹配部分
    private func highlightedSuggestion(_ suggestion: String, keyword: String) -> some View {
        let lowercasedSuggestion = suggestion.lowercased()
        let lowercasedKeyword = keyword.lowercased()
        
        if let range = lowercasedSuggestion.range(of: lowercasedKeyword) {
            let before = String(suggestion[suggestion.startIndex..<range.lowerBound])
            let match = String(suggestion[range])
            let after = String(suggestion[range.upperBound...])
            
            return (Text(before).foregroundColor(.primary) +
                   Text(match).foregroundColor(themeManager.primaryColor).fontWeight(.semibold) +
                   Text(after).foregroundColor(.primary))
                .font(.subheadline)
        } else {
            return Text(suggestion)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    // 更新实时联想建议
    private func updateSearchSuggestions(for keyword: String) {
        let lowercasedKeyword = keyword.lowercased()
        var suggestions: [String] = []
        
        // 1. 从历史记录中匹配
        let historyMatches = searchHistory.filter { $0.lowercased().contains(lowercasedKeyword) }
        suggestions.append(contentsOf: historyMatches.prefix(2))
        
        // 2. 从热门关键词中匹配
        let hotMatches = hotSearchKeywords.filter { $0.lowercased().contains(lowercasedKeyword) }
        suggestions.append(contentsOf: hotMatches.prefix(2))
        
        // 3. 根据输入延伸相关词（鹦鹉领域）
        let relatedKeywords = getRelatedKeywords(for: lowercasedKeyword)
        suggestions.append(contentsOf: relatedKeywords.prefix(3))
        
        // 去重并限制数量
        searchSuggestions = Array(Set(suggestions)).sorted().prefix(6).map { $0 }
    }
    
    // 获取相关延伸关键词
    private func getRelatedKeywords(for keyword: String) -> [String] {
        let keywordExtensions: [String: [String]] = [
            NSLocalizedString("虎皮", comment: ""): [NSLocalizedString("虎皮鹦鹉饲养", comment: ""), NSLocalizedString("虎皮鹦鹉笼具", comment: ""), NSLocalizedString("虎皮鹦鹉食物", comment: ""), NSLocalizedString("虎皮鹦鹉训练", comment: "")],
            NSLocalizedString("玄凤", comment: ""): [NSLocalizedString("玄凤鹦鹉饲养", comment: ""), NSLocalizedString("玄凤鹦鹉说话", comment: ""), NSLocalizedString("玄凤鹦鹉配色", comment: ""), NSLocalizedString("玄凤鹦鹉训练", comment: "")],
            NSLocalizedString("牡丹", comment: ""): [NSLocalizedString("牡丹鹦鹉饲养", comment: ""), NSLocalizedString("牡丹鹦鹉配对", comment: ""), NSLocalizedString("牡丹鹦鹉繁殖", comment: "")],
            NSLocalizedString("金刚", comment: ""): [NSLocalizedString("金刚鹦鹉饲养", comment: ""), NSLocalizedString("金刚鹦鹉价格", comment: ""), NSLocalizedString("金刚鹦鹉寿命", comment: "")],
            NSLocalizedString("灰鹦鹉", comment: ""): [NSLocalizedString("灰鹦鹉说话", comment: ""), NSLocalizedString("灰鹦鹉饲养", comment: ""), NSLocalizedString("灰鹦鹉价格", comment: "")],
            NSLocalizedString("小太阳", comment: ""): [NSLocalizedString("小太阳饲养", comment: ""), NSLocalizedString("小太阳训练", comment: ""), NSLocalizedString("小太阳互动", comment: "")],
            NSLocalizedString("和尚", comment: ""): [NSLocalizedString("和尚鹦鹉饲养", comment: ""), NSLocalizedString("和尚鹦鹉说话", comment: ""), NSLocalizedString("和尚鹦鹉训练", comment: "")],
            NSLocalizedString("断奶", comment: ""): [NSLocalizedString("鹦鹉断奶时间", comment: ""), NSLocalizedString("断奶食物", comment: ""), NSLocalizedString("断奶注意事项", comment: "")],
            NSLocalizedString("饲养", comment: ""): [NSLocalizedString("新手饲养", comment: ""), NSLocalizedString("饲养注意事项", comment: ""), NSLocalizedString("饲养环境", comment: "")],
            NSLocalizedString("训练", comment: ""): [NSLocalizedString("说话训练", comment: ""), NSLocalizedString("飞行训练", comment: ""), NSLocalizedString("互动训练", comment: "")],
            NSLocalizedString("生病", comment: ""): [NSLocalizedString("鹦鹉生病症状", comment: ""), NSLocalizedString("生病怎么办", comment: ""), NSLocalizedString("常见疾病", comment: "")],
            NSLocalizedString("笼具", comment: ""): [NSLocalizedString("鸟笼推荐", comment: ""), NSLocalizedString("笼具选择", comment: ""), NSLocalizedString("站架推荐", comment: "")]
        ]
        
        for (key, extensions) in keywordExtensions {
            if keyword.contains(key) || key.contains(keyword) {
                return extensions
            }
        }
        
        return []
    }
    
    // MARK: - 搜索筛选条（小红书风格）
    private var searchFilterBar: some View {
        HStack(spacing: 12) {
            // 排序方式选择
            HStack(spacing: 4) {
                ForEach(sortOptions, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSearchSort = option
                        }
                    } label: {
                        Text(option)
                            .font(.caption)
                            .fontWeight(selectedSearchSort == option ? .semibold : .regular)
                            .foregroundColor(selectedSearchSort == option ? themeManager.primaryColor : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selectedSearchSort == option ?
                                themeManager.primaryColor.opacity(0.12) :
                                Color.clear
                            )
                            .cornerRadius(12)
                    }
                }
            }
            
            Divider()
                .frame(height: 16)
            
            // 媒体类型筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(mediaFilterOptions, id: \.self) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMediaFilter = option
                            }
                        } label: {
                            HStack(spacing: 3) {
                                if option == NSLocalizedString("图文", comment: "") {
                                    Image(systemName: "photo")
                                        .font(.caption2)
                                } else if option == NSLocalizedString("视频", comment: "") {
                                    Image(systemName: "play.rectangle")
                                        .font(.caption2)
                                }
                                Text(option)
                                    .font(.caption)
                            }
                            .fontWeight(selectedMediaFilter == option ? .semibold : .regular)
                            .foregroundColor(selectedMediaFilter == option ? themeManager.primaryColor : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                selectedMediaFilter == option ?
                                themeManager.primaryColor.opacity(0.12) :
                                Color.clear
                            )
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.adaptiveCard)
    }
    
    // MARK: - 搜索建议面板（历史 + 热门）
    private var searchSuggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 搜索历史
            if !searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(NSLocalizedString("搜索历史", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button {
                            clearSearchHistory()
                        } label: {
                            Text(NSLocalizedString("清空", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 历史标签流式布局
                    FlowLayout(spacing: 8) {
                        ForEach(searchHistory, id: \.self) { keyword in
                            Button {
                                searchText = keyword
                                saveSearchHistory(keyword)
                                searchFieldFocused = false
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption2)
                                    Text(keyword)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(14)
                            }
                        }
                    }
                }
            }
            
            // 热门搜索（仅在成功加载到后端数据时显示）
            if !hotKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("热门搜索", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(hotKeywords, id: \.self) { keyword in
                            Button {
                                searchText = keyword
                                saveSearchHistory(keyword)
                                searchFieldFocused = false
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text(keyword)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(themeManager.primaryColor.opacity(0.1))
                                .foregroundColor(themeManager.primaryColor)
                                .cornerRadius(14)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.adaptiveCard)
        .transition(.opacity)
    }
    
    // 热门搜索关键词（直接使用从后端获取的，API失败则为空，不显示热搜区域）
    private var hotSearchKeywords: [String] {
        hotKeywords
    }
    
    // MARK: - 搜索历史管理
    private func loadSearchHistory() {
        // 加载本地搜索历史
        if let history = UserDefaults.standard.stringArray(forKey: "ForumSearchHistory") {
            searchHistory = history
        }
        
        // 从后端加载热门搜索关键词
        loadHotKeywords()
    }
    
    // 从后端加载热门搜索关键词
    private func loadHotKeywords() {
        Task {
            do {
                let keywords = try await ApiService.shared.getHotSearchKeywords(limit: 10)
                await MainActor.run {
                    if !keywords.isEmpty {
                        hotKeywords = keywords
                        print("🔥 热门搜索词加载成功: \(keywords)")
                    }
                }
            } catch {
                // 静默失败，使用默认关键词
                print("⚠️ 热门搜索词加载失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveSearchHistory(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // 移除重复项
        searchHistory.removeAll { $0 == trimmed }
        // 插入到开头
        searchHistory.insert(trimmed, at: 0)
        // 最多保留10条
        if searchHistory.count > 10 {
            searchHistory = Array(searchHistory.prefix(10))
        }
        // 保存到 UserDefaults
        UserDefaults.standard.set(searchHistory, forKey: "ForumSearchHistory")
    }
    
    private func clearSearchHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: "ForumSearchHistory")
    }
    
    // MARK: - Tab 标签栏
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tabs[index])
                            .font(.system(size: 15))
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? themeManager.primaryColor : .gray)
                        
                        // 下划线指示器
                        Rectangle()
                            .fill(selectedTab == index ? themeManager.primaryColor : Color.clear)
                            .frame(width: 24, height: 3)
                            .cornerRadius(1.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - 帖子列表（支持左右滑动切换）
    private var postsListView: some View {
        TabView(selection: $selectedTab) {
            // 关注页面
            postContentView(posts: followingPosts, tabIndex: 0)
                .tag(0)
            
            // 附近页面 - 使用筛选后的帖子
            postContentView(posts: filteredNearbyPosts, tabIndex: 1)
                .tag(1)
            
            // 推荐页面
            postContentView(posts: recommendedPosts, tabIndex: 2)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }
    
    // 单个标签页的内容 - Fix A4: 缓存 filteredPosts 结果避免重复计算
    private func postContentView(posts: [ForumPost], tabIndex: Int) -> some View {
        // Fix A4: 预先计算过滤结果，避免在 body 中多次调用
        let filtered = filteredPosts(posts)
        let videoPosts = filtered.filter { $0.mediaType == "VIDEO" }
        let isSearching = !searchText.isEmpty
        
        return Group {
            if isLoading {
                // 加载中
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(NSLocalizedString("加载中...", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                // 空状态
                if isSearching {
                    // 搜索无结果时的友好提示
                    searchEmptyStateView
                } else {
                    emptyStateViewFor(tabIndex: tabIndex)
                }
            } else {
                // 帖子列表
                ScrollView {
                    VStack(spacing: 0) {
                        // 搜索结果计数（仅在搜索时显示）
                        if isSearching {
                            searchResultHeader(count: filtered.count)
                        }
                        
                        // 瀑布流布局（小红书风格）
                        WaterfallGrid(posts: filtered, videoPosts: videoPosts, primaryColor: themeManager.primaryColor, backgroundColor: themeManager.backgroundColor, keyword: searchText)
                            .padding(.horizontal, 10)
                            .padding(.top, 8)
                            .padding(.bottom, 80)
                    }
                }
                .refreshable {
                    await refreshPosts()
                }
            }
        }
    }
    
    // MARK: - 搜索结果头部（显示结果数量）
    private func searchResultHeader(count: Int) -> some View {
        HStack {
            Text(NSLocalizedString("找到 ", comment: ""))
                .foregroundColor(.secondary)
            + Text("\(count)")
                .foregroundColor(themeManager.primaryColor)
                .fontWeight(.semibold)
            + Text(NSLocalizedString(" 条相关内容", comment: ""))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - 搜索无结果状态视图
    private var searchEmptyStateView: some View {
        VStack(spacing: 20) {
            // 空状态图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.gray.opacity(0.4))
            
            VStack(spacing: 8) {
                Text(String(format: NSLocalizedString("没有找到「%@」相关内容", comment: ""), searchText))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(NSLocalizedString("换个关键词试试吧", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // 推荐搜索词
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("试试搜索", comment: ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                FlowLayout(spacing: 8) {
                    ForEach(getRecommendedKeywords(for: searchText), id: \.self) { keyword in
                        Button {
                            searchText = keyword
                            saveSearchHistory(keyword)
                        } label: {
                            Text(keyword)
                                .font(.caption)
                                .foregroundColor(themeManager.primaryColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(themeManager.primaryColor.opacity(0.1))
                                .cornerRadius(14)
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // 获取推荐搜索词（根据当前搜索词推荐相关词）
    private func getRecommendedKeywords(for keyword: String) -> [String] {
        // 基于输入词推荐相关热门词
        let lowercased = keyword.lowercased()
        var recommendations: [String] = []
        
        // 品种相关推荐
        if lowercased.contains(NSLocalizedString("鹦鹉", comment: "")) || lowercased.contains(NSLocalizedString("鸟", comment: "")) {
            recommendations = [NSLocalizedString("虎皮鹦鹉", comment: ""), NSLocalizedString("玄凤鹦鹉", comment: ""), NSLocalizedString("小太阳", comment: ""), NSLocalizedString("牡丹鹦鹉", comment: ""), NSLocalizedString("金刚鹦鹉", comment: "")]
        } else if lowercased.contains(NSLocalizedString("饲养", comment: "")) || lowercased.contains(NSLocalizedString("养", comment: "")) {
            recommendations = [NSLocalizedString("新手饲养", comment: ""), NSLocalizedString("饲养攻略", comment: ""), NSLocalizedString("饲养注意事项", comment: "")]
        } else if lowercased.contains(NSLocalizedString("生病", comment: "")) || lowercased.contains(NSLocalizedString("病", comment: "")) {
            recommendations = [NSLocalizedString("常见疾病", comment: ""), NSLocalizedString("病症判断", comment: ""), NSLocalizedString("养护建议", comment: "")]
        } else {
            // 默认推荐热门搜索词
            recommendations = hotSearchKeywords.prefix(5).map { $0 }
        }
        
        return recommendations
    }
    
    
    // 过滤和排序帖子 - 小红书风格全面搜索
    private func filteredPosts(_ posts: [ForumPost]) -> [ForumPost] {
        var result = posts
        
        // 搜索过滤 - 支持多字段搜索（像小红书一样）
        if !searchText.isEmpty {
            let keyword = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            
            result = result.filter { post in
                // 1. 搜索帖子内容
                if post.content.lowercased().contains(keyword) {
                    return true
                }
                
                // 2. 搜索作者昵称
                if post.authorName.lowercased().contains(keyword) {
                    return true
                }
                
                // 3. 搜索鸟的名字（寻鸟帖）
                if let birdName = post.birdName, birdName.lowercased().contains(keyword) {
                    return true
                }
                
                // 4. 搜索鸟的品种
                if let birdSpecies = post.birdSpecies, birdSpecies.lowercased().contains(keyword) {
                    return true
                }
                
                // 5. 搜索位置名称
                if let locationName = post.locationName, locationName.lowercased().contains(keyword) {
                    return true
                }
                
                // 6. 搜索丢失地点（寻鸟帖）
                if let lostLocation = post.lostLocation, lostLocation.lowercased().contains(keyword) {
                    return true
                }
                
                // 7. 搜索关联鸟儿信息（JSON 数组中的名字和品种）
                if let birdsInfo = post.birdsInfo, birdsInfo.lowercased().contains(keyword) {
                    return true
                }
                
                return false
            }
            
            // 搜索时应用媒体类型筛选
            if selectedMediaFilter == NSLocalizedString("图文", comment: "") {
                result = result.filter { $0.mediaType == "IMAGE" }
            } else if selectedMediaFilter == NSLocalizedString("视频", comment: "") {
                result = result.filter { $0.mediaType == "VIDEO" }
            }
            
            // 搜索时应用排序
            if selectedSearchSort == NSLocalizedString("最新", comment: "") {
                // 最新排序：按时间倒序
                return result
            } else {
                // 最热排序：按互动权重（点赞×3 + 评论×2）
                return result.sorted { 
                    ($0.likeCount * 3 + $0.commentCount * 2) > ($1.likeCount * 3 + $1.commentCount * 2)
                }
            }
        }
        
        // 非搜索时的排序
        switch selectedSort {
        case NSLocalizedString("最新", comment: ""):
            return result
        case NSLocalizedString("最热", comment: ""):
            return result.sorted { 
                ($0.likeCount * 3 + $0.commentCount * 2) > ($1.likeCount * 3 + $1.commentCount * 2)
            }
        default:
            return result
        }
    }
    
    // 空状态视图（根据标签页）- Fix A8: 添加定位权限拒绝引导
    private func emptyStateViewFor(tabIndex: Int) -> some View {
        VStack(spacing: 16) {
            // Fix A8: 附近Tab + 定位被拒绝时显示特殊引导
            if tabIndex == 1 && (locationService.authorizationStatus == .denied ||
                                  locationService.authorizationStatus == .restricted) {
                Image(systemName: "location.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.orange.opacity(0.5))
                
                Text(NSLocalizedString("需要定位权限", comment: ""))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(NSLocalizedString("开启定位权限后，可以查看附近的鸟友动态", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(NSLocalizedString("去设置", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(themeManager.primaryColor)
                        .cornerRadius(20)
                }
                .padding(.top, 8)
            } else {
                // 原有逻辑
                Image(systemName: emptyStateIconFor(tabIndex: tabIndex))
                    .font(.system(size: 50))
                    .foregroundColor(themeManager.primaryColor.opacity(0.3))
                
                Text(emptyStateTitleFor(tabIndex: tabIndex))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(emptyStateSubtitleFor(tabIndex: tabIndex))
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                if tabIndex == 0 && !authService.isLoggedIn {
                    Button {
                        showLoginSheet = true
                    } label: {
                        Text(NSLocalizedString("去登录", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(themeManager.primaryColor)
                            .cornerRadius(20)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func emptyStateIconFor(tabIndex: Int) -> String {
        switch tabIndex {
        case 0: return "person.2"
        case 1: return "location.slash"
        default: return "doc.text"
        }
    }
    
    private func emptyStateTitleFor(tabIndex: Int) -> String {
        if !searchText.isEmpty {
            return NSLocalizedString("未找到相关内容", comment: "")
        }
        switch tabIndex {
        case 0: return authService.isLoggedIn ? NSLocalizedString("还没有关注的人", comment: "") : NSLocalizedString("登录后查看关注", comment: "")
        case 1: return NSLocalizedString("附近暂无动态", comment: "")
        default: return NSLocalizedString("暂无推荐内容", comment: "")
        }
    }
    
    private func emptyStateSubtitleFor(tabIndex: Int) -> String {
        if !searchText.isEmpty {
            return NSLocalizedString("换个关键词试试吧", comment: "")
        }
        switch tabIndex {
        case 0: return authService.isLoggedIn ? NSLocalizedString("去发现更多有趣的鸟友吧", comment: "") : NSLocalizedString("登录后可以关注其他鸟友", comment: "")
        case 1: return NSLocalizedString("成为第一个分享的人吧", comment: "")
        default: return NSLocalizedString("下拉刷新试试", comment: "")
        }
    }
    
    // MARK: - 发帖按钮
    @State private var showPostMenu = false
    @State private var showFindBirdPost = false
    
    private var createPostButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    // 展开的菜单
                    if showPostMenu {
                        // 寻鸟按钮
                        Button {
                            showPostMenu = false
                            if authService.isLoggedIn {
                                showFindBirdPost = true
                            } else {
                                showLoginAlert = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                Text(NSLocalizedString("寻鸟", comment: ""))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.85, green: 0.35, blue: 0.35))
                            .cornerRadius(20)
                            .shadow(color: Color.red.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .transition(.scale.combined(with: .opacity))
                        
                        // 发帖按钮
                        Button {
                            showPostMenu = false
                            if authService.isLoggedIn {
                                showCreatePost = true
                            } else {
                                showLoginAlert = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 14))
                                Text(NSLocalizedString("发帖", comment: ""))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(themeManager.primaryColor)
                            .cornerRadius(20)
                            .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 主按钮
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPostMenu.toggle()
                        }
                    } label: {
                        Image(systemName: showPostMenu ? "xmark" : "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [themeManager.primaryColor, Color(red: 0.35, green: 0.55, blue: 0.45)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(28)
                            .shadow(color: themeManager.primaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
                            .rotationEffect(.degrees(showPostMenu ? 45 : 0))
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationDestination(isPresented: $showFindBirdPost) {
            CreateFindBirdPostView(
                onPost: { newPost in
                    // 寻鸟帖子只添加到附近列表
                    allPosts.insert(newPost, at: 0)
                    nearbyPosts.insert(newPost, at: 0)
                },
                onBirdMarkedLost: { birdId, lostDate, lostLocation in
                    // 标记鸟儿为丢失状态
                    markBirdAsLost(birdId: birdId, lostDate: lostDate, lostLocation: lostLocation)
                }
            )
            .hidesTabBar()
        }
    }
    
    // MARK: - 数据加载
    private func loadInitialData() {
        // 先从缓存加载（立即显示）
        loadFromCache()
        
        // Fix A7: 保存 Task 引用，以便 onDisappear 时取消
        loadingTask = Task {
            await loadPostsFromServer()
        }
    }
    
    /// 从本地缓存加载帖子
    private func loadFromCache() {
        // 加载推荐帖子缓存
        if let cachedRecommended = PostCacheService.shared.getCachedRecommendedPosts() {
            let posts = cachedRecommended.map { ForumPost.from(dto: $0) }
            recommendedPosts = posts
            allPosts = posts
            
            // 同步缓存中的点赞/收藏状态到 SocialService
            syncSocialStateFromPosts(posts)
            print("📱 从缓存加载推荐帖子: \(posts.count) 条")
        }
        
        // 加载附近帖子缓存
        if let cachedNearby = PostCacheService.shared.getCachedNearbyPosts() {
            let posts = cachedNearby.map { ForumPost.from(dto: $0) }
            nearbyPosts = posts
            syncSocialStateFromPosts(posts)
            print("📱 从缓存加载附近帖子: \(posts.count) 条")
        }
        
        // 加载关注帖子缓存
        if let cachedFollowing = PostCacheService.shared.getCachedFollowingPosts() {
            let posts = cachedFollowing.map { ForumPost.from(dto: $0) }
            followingPosts = posts
            syncSocialStateFromPosts(posts)
            print("📱 从缓存加载关注帖子: \(posts.count) 条")
        }
    }
    
    /// 从帖子列表同步点赞/收藏状态到 SocialService
    private func syncSocialStateFromPosts(_ posts: [ForumPost]) {
        let likedIds = Set(posts.filter { $0.isLiked }.map { $0.id })
        let favoritedIds = Set(posts.filter { $0.isFavorited }.map { $0.id })
        socialService.likedPostIds.formUnion(likedIds)
        socialService.favoritePostIds.formUnion(favoritedIds)
    }
    
    /// 标记鸟儿为丢失状态
    private func markBirdAsLost(birdId: Int64, lostDate: String, lostLocation: String) {
        Task {
            do {
                // 调用后端API更新鸟儿丢失状态
                try await ApiService.shared.updateBirdLostStatus(birdId: birdId, isLost: true, lostDate: lostDate, lostLocation: lostLocation)
                print("✅ 鸟儿 \(birdId) 已标记为丢失状态")
            } catch {
                print("❌ 标记鸟儿丢失状态失败: \(error)")
            }
        }
    }
    
    // Fix #3: 添加防并发保护 + Fix #12: 版本号检查防止旧数据覆盖
    private func loadPostsFromServer() async {
        // 防止并发请求
        guard !isLoadingPosts else { return }
        
        // Fix #12: 记录当前请求版本
        requestVersion += 1
        let currentVersion = requestVersion
        
        await MainActor.run { isLoadingPosts = true }
        defer { Task { @MainActor in isLoadingPosts = false } }
        
        do {
            // 使用推荐排序获取帖子（后端已实现综合热度算法）
            let page = try await ApiService.shared.getPosts(page: 0, size: 50, sort: "recommended")
            
            let serverPosts = page.content.map { ForumPost.from(dto: $0) }
            
            // Fix B2: 将版本检查和所有状态更新放在同一个 MainActor.run 块中，消除 TOCTOU 竞态
            let shouldUpdate = await MainActor.run { () -> Bool in
                // 版本号检查
                guard currentVersion == requestVersion else {
                    print("⚠️ 忽略旧请求结果 (version: \(currentVersion), current: \(requestVersion))")
                    return false
                }
                
                // 缓存到本地
                PostCacheService.shared.cacheRecommendedPosts(page.content)
                
                // 更新 SocialService 中的点赞/收藏状态
                let likedIds = Set(serverPosts.filter { $0.isLiked }.map { $0.id })
                let favoritedIds = Set(serverPosts.filter { $0.isFavorited }.map { $0.id })
                socialService.likedPostIds.formUnion(likedIds)
                socialService.favoritePostIds.formUnion(favoritedIds)
                
                let notLikedIds = Set(serverPosts.filter { !$0.isLiked }.map { $0.id })
                let notFavoritedIds = Set(serverPosts.filter { !$0.isFavorited }.map { $0.id })
                socialService.likedPostIds.subtract(notLikedIds)
                socialService.favoritePostIds.subtract(notFavoritedIds)
                
                // 同步帖子状态到 PostStore
                PostStore.shared.syncFromPosts(serverPosts)
                
                allPosts = serverPosts
                recommendedPosts = serverPosts
                
                // 附近：寻鸟帖子置顶 + 普通帖子
                let findBirdPosts = serverPosts.filter { $0.postType == .findBird }
                let normalPosts = serverPosts.filter { $0.postType == .normal }
                nearbyPosts = findBirdPosts + normalPosts
                
                // 缓存附近帖子
                let nearbyDTOs = nearbyPosts.map { $0.toDTO() }
                PostCacheService.shared.cacheNearbyPosts(nearbyDTOs)
                
                return true
            }
            
            guard shouldUpdate else { return }
            
            // 预加载帖子图片到本地缓存
            preloadPostImages(serverPosts)
            
            // 异步加载关注用户的帖子（需要登录）
            if authService.isLoggedIn {
                await loadFollowingPosts()
            }
        } catch {
            print("加载帖子失败: \(error)")
            // 网络失败时不清空数据，保留缓存的内容
            // 只有在缓存也为空时才显示空状态
            if recommendedPosts.isEmpty {
                print("⚠️ 网络失败且无缓存")
            } else {
                print("📱 网络失败，使用缓存数据")
            }
        }
    }
    
    private func loadFollowingPosts() async {
        do {
            let page = try await ApiService.shared.getFollowingPosts(page: 0, size: 30)
            let posts = page.content.map { ForumPost.from(dto: $0) }
            
            // 缓存关注帖子
            PostCacheService.shared.cacheFollowingPosts(page.content)
            
            await MainActor.run {
                followingPosts = posts
            }
        } catch {
            print("加载关注帖子失败: \(error)")
            // 网络失败时保留缓存数据
        }
    }
    
    // Fix A6: 添加并发保护
    private func refreshPosts() async {
        guard !isLoadingPosts else { return }  // 如果已在加载，直接返回
        isLoading = true
        await loadPostsFromServer()
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// 预加载帖子图片到本地缓存
    private func preloadPostImages(_ posts: [ForumPost]) {
        var imageURLs: [String] = []
        var videoURLs: [String] = []
        
        for post in posts {
            // 收集图片URL
            imageURLs.append(contentsOf: post.images)
            
            // 收集用户头像
            if let avatarUrl = post.authorAvatar, !avatarUrl.isEmpty {
                imageURLs.append(avatarUrl)
            }
            
            // 收集视频封面
            if let coverUrl = post.videoCover, !coverUrl.isEmpty {
                imageURLs.append(coverUrl)
            }
            
            // 收集视频URL（仅WiFi下预加载）
            if let videoUrl = post.videoUrl, !videoUrl.isEmpty {
                videoURLs.append(videoUrl)
            }
        }
        
        // 预加载图片到缓存
        for urlString in imageURLs {
            Task {
                await ImageCacheService.shared.loadImage(from: urlString)
            }
        }
    }
    
    // MARK: - Universal Links 帖子加载
    /// 从 Universal Link 加载帖子详情
    private func loadPostFromUniversalLink(postId: Int64) {
        // 先检查是否已经在本地数据中
        if let existingPost = allPosts.first(where: { $0.id == postId }) ??
           recommendedPosts.first(where: { $0.id == postId }) ??
           nearbyPosts.first(where: { $0.id == postId }) {
            universalLinkPost = existingPost
            universalLinkNavigationActive = true
            return
        }
        
        // 从服务器加载
        Task {
            do {
                let postDTO = try await ApiService.shared.getPost(postId: postId)
                let post = ForumPost.from(dto: postDTO)
                await MainActor.run {
                    universalLinkPost = post
                    universalLinkNavigationActive = true
                    print("🔗 成功从服务器加载帖子: \(post.id)")
                }
            } catch {
                print("🔗 加载帖子失败: \(error)")
                await MainActor.run {
                    // 加载失败，关闭导航
                    universalLinkNavigationActive = false
                    universalLinkPostId = nil
                    universalLinkPost = nil
                }
            }
        }
    }
}

// MARK: - 位置选择视图
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationService = LocationService.shared
    @Binding var selectedRange: String
    
    @ObservedObject var themeManager = ThemeManager.shared
    private let ranges = [
        (NSLocalizedString("附近", comment: ""), "location.fill", NSLocalizedString("当前位置3公里内", comment: ""), 3.0),
        (NSLocalizedString("同城", comment: ""), "building.2.fill", NSLocalizedString("同一城市的鸟友", comment: ""), 50.0),
        (NSLocalizedString("全国", comment: ""), "map.fill", NSLocalizedString("全国各地的鸟友", comment: ""), -1.0),
    ]
    
    var body: some View {
        NavigationStack {
            List {
                // 当前位置
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.backgroundColor.opacity(0.6))
                                .frame(width: 44, height: 44)
                            
                            if locationService.isLocating {
                                ProgressView()
                            } else {
                                Image(systemName: "location.fill")
                                    .foregroundColor(themeManager.primaryColor)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("当前位置", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if locationService.isLocating {
                                Text(NSLocalizedString("正在获取位置...", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let error = locationService.locationError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text(locationService.fullAddress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            locationService.refreshLocation()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                                .foregroundColor(themeManager.primaryColor)
                        }
                        .disabled(locationService.isLocating)
                    }
                    .padding(.vertical, 4)
                    
                    // 定位权限提示
                    if locationService.authorizationStatus == .denied {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("请在系统设置中开启定位权限", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(NSLocalizedString("去设置", comment: "")) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(themeManager.primaryColor)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(NSLocalizedString("我的位置", comment: ""))
                }
                
                // 范围选择
                Section {
                    ForEach(ranges, id: \.0) { range in
                        Button {
                            selectedRange = range.0
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: range.1)
                                    .font(.title3)
                                    .foregroundColor(themeManager.primaryColor)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(range.0)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text(range.2)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedRange == range.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.primaryColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("选择范围", comment: ""))
                } footer: {
                    Text(NSLocalizedString("选择范围后，将只显示该范围内的帖子", comment: ""))
                }
            }
            .scrollContentBackground(.hidden)
            .themedNavigationBarWithDone(title: NSLocalizedString("位置设置", comment: "")) {
                dismiss()
            }
        }
    }
}

// MARK: - 瀑布流布局（小红书风格）- Fix #17: 优化性能，缓存列分配结果
struct WaterfallGrid: View {
    let posts: [ForumPost]
    let videoPosts: [ForumPost]
    let primaryColor: Color
    let backgroundColor: Color
    var keyword: String = ""
    let spacing: CGFloat = 10
    
    // Fix #17: 缓存列分配结果，避免每帧重新计算
    @State private var cachedColumns: (left: [ForumPost], right: [ForumPost])?
    @State private var lastPostIds: [Int64] = []
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width - 20 // padding
        let columnWidth = (screenWidth - spacing) / 2
        
        // Fix A2: 使用已缓存的列，如果未缓存则实时计算（但不在此更新缓存）
        let columns = cachedColumns ?? distributePostsByHeight(columnWidth: columnWidth)
        
        HStack(alignment: .top, spacing: spacing) {
            // 左列
            LazyVStack(spacing: spacing) {
                ForEach(columns.left) { post in
                    PostCard(post: post, primaryColor: primaryColor, backgroundColor: backgroundColor, keyword: keyword, allVideoPosts: videoPosts, columnWidth: columnWidth)
                }
            }
            .frame(width: columnWidth)
            
            // 右列
            LazyVStack(spacing: spacing) {
                ForEach(columns.right) { post in
                    PostCard(post: post, primaryColor: primaryColor, backgroundColor: backgroundColor, keyword: keyword, allVideoPosts: videoPosts, columnWidth: columnWidth)
                }
            }
            .frame(width: columnWidth)
        }
        .onChange(of: posts.map { $0.id }) { _, newIds in
            // 帖子列表变化时重新计算缓存
            if newIds != lastPostIds {
                lastPostIds = newIds
                cachedColumns = distributePostsByHeight(columnWidth: columnWidth)
            }
        }
        // Fix A2: 仅在 onAppear 中初始化缓存，不在 body 调用链中修改 @State
        .onAppear {
            if cachedColumns == nil {
                lastPostIds = posts.map { $0.id }
                cachedColumns = distributePostsByHeight(columnWidth: columnWidth)
            }
        }
    }
    
    /// 根据预估高度分配帖子到左右两列，使两列高度尽量均匀，同时避免帖子密度失衡（全在一侧）
    private func distributePostsByHeight(columnWidth: CGFloat) -> (left: [ForumPost], right: [ForumPost]) {
        var leftColumn: [ForumPost] = []
        var rightColumn: [ForumPost] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        
        for post in posts {
            let estimatedHeight = estimatePostHeight(post, columnWidth: columnWidth)
            
            // 限制卡片堆积：如果一列的数量比另一列多了2个以上，强制分配到较少的那一列，以防视觉上"全在右边或左边"
            if leftColumn.count > rightColumn.count + 1 {
                rightColumn.append(post)
                rightHeight += estimatedHeight + spacing
            } else if rightColumn.count > leftColumn.count + 1 {
                leftColumn.append(post)
                leftHeight += estimatedHeight + spacing
            } else {
                // 追求高度平衡：将帖子放到当前预估高度较短的那一列
                if leftHeight <= rightHeight {
                    leftColumn.append(post)
                    leftHeight += estimatedHeight + spacing
                } else {
                    rightColumn.append(post)
                    rightHeight += estimatedHeight + spacing
                }
            }
        }
        
        return (leftColumn, rightColumn)
    }
    
    /// 极其精准地预估帖子卡片高度，确保贪心分配极其均匀
    private func estimatePostHeight(_ post: ForumPost, columnWidth: CGFloat) -> CGFloat {
        // 1. 图片高度（默认使用 1.25 的 4:5比例，寻鸟启事由于其固定设计使用 1.1）
        var imageHeight: CGFloat = 0
        if post.postType == .findBird {
            imageHeight = columnWidth * 1.1 // 寻鸟卡片无论是否有图，UI均渲染占位背板 1.1 比例
        } else {
            let hasMedia = !post.images.isEmpty || post.mediaType == "VIDEO"
            imageHeight = hasMedia ? columnWidth * 1.25 : 0
        }
        
        // 2. 文字区域高度估算
        let contentLength = post.content.count
        let lineHeight: CGFloat = 18
        // 按照当前字体13估算每行字符容量（约等于）
        let charsPerLine = Int(columnWidth / 13) 
        
        // 提取UI代码中真实的 lineLimit
        var maxLines = 6
        if post.postType == .findBird {
            maxLines = 2
        } else {
            let hasMedia = !post.images.isEmpty || post.mediaType == "VIDEO"
            maxLines = hasMedia ? 2 : 6
        }
        
        let safeCharsPerLine = max(charsPerLine, 1)
        let textLines = max(1, (contentLength + safeCharsPerLine - 1) / safeCharsPerLine)
        let estimatedLines = min(maxLines, textLines)
        let textHeight = CGFloat(estimatedLines) * lineHeight
        
        // 3. 作者信息栏行的高度 (头像通常 18，Padding 上下)
        let authorHeight: CGFloat = 36
        
        // 4. 其他结构和 Padding 补偿
        var extraPadding: CGFloat = 24 // 基础垂直 padding
        if post.postType == .findBird {
            extraPadding += 60 // 寻鸟标签、悬赏金额标签、鸟名信息等
        } else {
            if let locationName = post.locationName, !locationName.isEmpty {
                extraPadding += 20 // 带有位置标签时的额外高度补偿
            }
        }
        
        return imageHeight + textHeight + authorHeight + extraPadding
    }
}

// MARK: - 帖子卡片
struct PostCard: View {
    let post: ForumPost
    let primaryColor: Color
    let backgroundColor: Color
    let keyword: String
    let allVideoPosts: [ForumPost] // 所有视频帖子，用于滑动切换
    let columnWidth: CGFloat?
    @ObservedObject var socialService = SocialService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var postStore = PostStore.shared  // Fix #18: 从 PostStore 获取状态
    @State private var showDetail = false
    @State private var showVideoPlayer = false
    
    private let urgentColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    // Fix #18: 从 PostStore 获取 likeCount，确保状态同步
    private var likeCount: Int {
        postStore.getLikeCount(postId: post.id)
    }
    
    init(post: ForumPost, primaryColor: Color, backgroundColor: Color? = nil, keyword: String = "", allVideoPosts: [ForumPost] = [], columnWidth: CGFloat? = nil) {
        self.post = post
        self.primaryColor = primaryColor
        self.backgroundColor = backgroundColor ?? primaryColor.opacity(0.15)
        self.keyword = keyword
        self.allVideoPosts = allVideoPosts
        self.columnWidth = columnWidth
        // Fix A1: 移除 init 中的 Task，改到 onAppear 中执行
    }
    
    // 获取图片比例 - 使用4:5竖向比例（类似小红书风格）
    private var imageRatio: CGFloat {
        return 1.25  // 4:5比例，更适合展示图片内容
    }
    
    // 卡片内容（提取为独立视图，供 NavigationLink 和 Button 共用）
    private var cardContent: some View {
        Group {
            if post.postType == .findBird {
                findBirdCardView
            } else {
                normalPostCardView
            }
        }
        // Fix A1: 在 onAppear 中同步 PostStore，而非 init
        .onAppear {
            if postStore.getLikeCount(postId: post.id) == 0 && post.likeCount > 0 {
                postStore.setLikeCount(postId: post.id, count: post.likeCount)
            }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            if post.mediaType == "VIDEO" {
                // 视频帖子
                NavigationLink {
                    VideoFeedView(
                        posts: allVideoPosts.isEmpty ? [post] : allVideoPosts,
                        initialIndex: allVideoPosts.firstIndex(where: { $0.id == post.id }) ?? 0,
                        primaryColor: primaryColor
                    )
                    .hidesTabBar()
                } label: {
                    cardContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // 图片/文字帖子：使用 NavigationLink 支持原生左划返回
                NavigationLink {
                    PostDetailView(post: post, primaryColor: primaryColor)
                } label: {
                    cardContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: columnWidth ?? 180)
        .contentShape(Rectangle())
        // P2-08: UGC合规 - 举报和拉黑（暂时禁用，后续版本添加）
        // .contextMenu {
        //     Button(role: .destructive) {
        //         // 暂时使用默认原因
        //         socialService.reportPost(postId: post.id, reason: "用户举报")
        //     } label: {
        //         Label("举报帖子", systemImage: "exclamationmark.bubble")
        //     }
        //     
        //     Button(role: .destructive) {
        //         socialService.blockUser(userId: post.authorId)
        //     } label: {
        //         Label("拉黑作者", systemImage: "person.slash")
        //     }
        // }
    }
    
    // MARK: - 寻鸟启事卡片（简约高级设计）
    private var findBirdCardView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片区域
            ZStack(alignment: .topLeading) {
                // 背景图片或占位
                if let imageUrl = post.images.first, !imageUrl.isEmpty {
                    CachedAsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: columnWidth ?? 180, height: (columnWidth ?? 180) * 1.1)
                                .clipped()
                        case .empty:
                            // 加载中 - 显示占位符和加载指示器
                            Rectangle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: columnWidth ?? 180, height: (columnWidth ?? 180) * 1.1)
                                .overlay(
                                    VStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                        Text(NSLocalizedString("加载中...", comment: ""))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        case .failure(_):
                            findBirdPlaceholder
                        @unknown default:
                            findBirdPlaceholder
                        }
                    }
                } else {
                    findBirdPlaceholder
                }
                
                // 顶部状态标签
                HStack {
                    // 寻鸟标签
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.adaptiveCard)
                            .frame(width: 6, height: 6)
                        Text(NSLocalizedString("寻鸟", comment: ""))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.9, green: 0.3, blue: 0.3))
                    )
                    
                    Spacer()
                    
                    // 悬赏金额
                    if let reward = post.reward, !reward.isEmpty {
                        Text("¥\(reward)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.95))
                            )
                    }
                }
                .padding(8)
            }
            .frame(height: (columnWidth ?? 180) * 1.1)
            .clipped()
            
            // 内容区域
            VStack(alignment: .leading, spacing: 8) {
                // 鸟名和品种
                HStack(spacing: 6) {
                    if let birdName = post.birdName {
                        Text(birdName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    if let species = post.birdSpecies {
                        Text(species)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(4)
                    }
                }
                
                // 走失地点
                if let location = post.lostLocation {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                        Text(location)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
                
                // 描述
                HighlightedText(
                    post.content,
                    highlight: keyword,
                    highlightColor: .yellow,
                    font: .system(size: 12),
                    baseColor: .secondary,
                    lineLimit: 2
                )
                
                // 底部信息
                HStack {
                    // 发布者
                    HStack(spacing: 4) {
                        if let avatarUrl = post.authorAvatar, !avatarUrl.isEmpty, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                            CachedAsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 16, height: 16)
                                        .clipShape(Circle())
                                default:
                                    defaultAvatarSmall
                                }
                            }
                        } else {
                            defaultAvatarSmall
                        }
                        
                        Text(post.authorName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 时间
                    Text(post.timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
        }
        .background(Color.adaptiveCard)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
    
    // 寻鸟占位图
    private var findBirdPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.94, blue: 0.94),
                        Color(red: 0.95, green: 0.90, blue: 0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: columnWidth ?? 180, height: (columnWidth ?? 180) * 1.1)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "bird")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(Color(red: 0.85, green: 0.6, blue: 0.6))
                    
                    if let birdName = post.birdName {
                        Text(birdName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.7, green: 0.4, blue: 0.4))
                    }
                }
            )
    }
    
    // 判断帖子是否有媒体内容（图片或视频）
    private var hasMediaContent: Bool {
        !post.images.isEmpty || post.mediaType == "VIDEO"
    }
    
    // MARK: - 普通帖子卡片（小红书风格）
    private var normalPostCardView: some View {
        let cardWidth = columnWidth ?? 180
        let birds = post.associatedBirds
        
        return VStack(alignment: .leading, spacing: 0) {
            // 图片区域 - 只有有图片或视频时才显示
            if hasMediaContent {
                imageSection
                    .frame(width: cardWidth)
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 8) {
                // 内容文字
                HighlightedText(
                    post.content,
                    highlight: keyword,
                    highlightColor: .yellow,
                    font: .system(size: 13, weight: .medium),
                    baseColor: .primary,
                    lineLimit: hasMediaContent ? 2 : 6
                )
                
                // 标签与时间行 (第一行辅助信息：包括关联鸟、普通位置、发布时间)
                let showTags = !birds.isEmpty || (post.locationName != nil && !post.locationName!.isEmpty)
                if showTags {
                    HStack(spacing: 4) {
                        // 关联鸟儿标签
                        if !birds.isEmpty {
                            HStack(spacing: 2) {
                                Image("bird")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 8, height: 8)
                                    .foregroundColor(primaryColor)
                                
                                Text(birds.count == 1 ? birds[0].name : "\(birds[0].name)...")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(primaryColor)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .background(primaryColor.opacity(0.08))
                            .cornerRadius(6)
                        }
                        
                        // 位置信息标签
                        if let locationName = post.locationName, !locationName.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 8))
                                Text(locationName)
                                    .font(.system(size: 8, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .background(Color.adaptiveCard.opacity(0.5))
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                        
                        // 发布时间 (居右侧微弱显示)
                        Text(post.timeAgo)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                
                // 作者信息行与点赞 (第二行核心交互：完全对照小红书)
                HStack(spacing: 0) {
                    // 用户头像与昵称
                    HStack(spacing: 4) {
                        if let avatarUrl = post.authorAvatar, !avatarUrl.isEmpty {
                            CachedAsyncImage(url: URL(string: AppConfig.applyCDN(to: avatarUrl))) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 16, height: 16)
                                        .clipShape(Circle())
                                case .failure(_), .empty:
                                    defaultAvatarView
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            defaultAvatarView
                        }
                        
                        // 用户名（限制最大字符数，防止挤压点赞）
                        let displayName = post.authorName.count > 8
                            ? String(post.authorName.prefix(8)) + "..."
                            : post.authorName
                        Text(displayName)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // 点赞数
                    HStack(spacing: 3) {
                        Image(systemName: socialService.isLiked(postId: post.id) ? "heart.fill" : "heart")
                            .font(.system(size: 10))
                            .foregroundColor(socialService.isLiked(postId: post.id) ? .red : .secondary)
                        Text(formatCount(likeCount))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .frame(width: cardWidth)
        .background(Color.adaptiveCard)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
    
    // 默认头像视图
    private var defaultAvatarView: some View {
        Circle()
            .fill(backgroundColor.opacity(0.8))
            .frame(width: 18, height: 18)
            .overlay(
                Text(String(post.authorName.prefix(1)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(primaryColor)
            )
    }
    
    // 小尺寸默认头像（用于底部信息栏）
    private var defaultAvatarSmall: some View {
        Circle()
            .fill(primaryColor.opacity(0.15))
            .frame(width: 16, height: 16)
            .overlay(
                Text(String(post.authorName.prefix(1)))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(primaryColor)
            )
    }
    
    // 获取封面图URL
    private var coverImageURL: String? {
        if post.mediaType == "VIDEO" {
            // 视频帖子：优先使用视频封面，否则使用第一张图片
            return post.videoCover ?? post.images.first
        } else {
            // 图片帖子：使用第一张图片
            return post.images.first
        }
    }
    
    // 图片/视频区域 - 小红书风格
    private var imageSection: some View {
        let width = columnWidth ?? 180
        let imageHeight = width * imageRatio
        // 最大高度限制：避免超长图片让卡片变得太长（最多1.6倍宽度）
        let maxImageHeight = width * 1.6
        
        return ZStack(alignment: .topTrailing) {
            // 视频帖子 - 使用视频封面
            if post.mediaType == "VIDEO" {
                // 视频封面图
                if let coverURL = coverImageURL, !coverURL.isEmpty {
                    CachedAsyncImage(url: URL(string: coverURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: min(imageHeight, maxImageHeight))
                                .clipped()
                        case .failure(_):
                            // 加载失败时显示渐变背景
                            placeholderGradient
                                .frame(width: width, height: min(imageHeight, maxImageHeight))
                        case .empty:
                            // 加载中显示占位
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: width, height: min(imageHeight, maxImageHeight))
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.7)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: width, height: min(imageHeight, maxImageHeight))
                    .cornerRadius(8)
                } else {
                    // 没有封面时显示渐变背景
                    placeholderGradient
                        .frame(width: width, height: min(imageHeight, maxImageHeight))
                        .cornerRadius(8)
                }
                
                // 右上角视频小图标（小红书风格）
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                    )
                    .padding(6)
            }
            // 图片帖子 - 使用第一张图片作为封面
            else if !post.images.isEmpty {
                let firstImageURL = post.images.first ?? ""
                
                CachedAsyncImage(url: URL(string: firstImageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: min(imageHeight, maxImageHeight))
                            .clipped()
                    case .failure(_):
                        // 加载失败显示占位
                        RoundedRectangle(cornerRadius: 8)
                            .fill(backgroundColor.opacity(0.5))
                            .frame(width: width, height: min(imageHeight, maxImageHeight))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(primaryColor)
                            )
                    case .empty:
                        // 加载中
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: width, height: min(imageHeight, maxImageHeight))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: width, height: min(imageHeight, maxImageHeight))
                .cornerRadius(8)
                
                // 右上角多图小图标（小红书风格）
                if post.images.count > 1 {
                    Image(systemName: "square.fill.on.square.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(6)
                }
            }
            // 无图片/视频时显示图标
            else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(post.postType == .findBird ? Color.red.opacity(0.06) : backgroundColor.opacity(0.5))
                    .frame(width: width, height: min(imageHeight, maxImageHeight))
                    .overlay(
                        Group {
                            if post.postType == .findBird {
                                Image("bird")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .opacity(0.5)
                            } else {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 28))
                                    .foregroundColor(primaryColor.opacity(0.25))
                            }
                        }
                    )
            }
        }
    }
    
    // 占位渐变背景
    private var placeholderGradient: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: Double(post.id % 10) / 10.0, saturation: 0.2, brightness: 0.95),
                        Color(hue: Double((post.id + 3) % 10) / 10.0, saturation: 0.25, brightness: 0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    // 格式化视频时长
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // 互动栏
    private var interactionBar: some View {
        HStack(spacing: 16) {
            // 点赞按钮
            Button {
                withAnimation(.spring(response: 0.3)) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    socialService.toggleLike(postId: post.id)
                    // likeCount 会自动从 PostStore 更新，无需手动修改
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: socialService.isLiked(postId: post.id) ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundColor(socialService.isLiked(postId: post.id) ? .red : .gray)
                    Text(formatCount(likeCount))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            
            // 评论
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.caption)
                Text(formatCount(post.commentCount))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    // 格式化数字显示
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fw", Double(count) / 10000)
        } else if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }
    
    // 格式化距离显示
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1 {
            return "\(Int(distance * 1000))m"
        } else if distance < 10 {
            return String(format: "%.1fkm", distance)
        } else {
            return "\(Int(distance))km"
        }
    }
}

// MARK: - 视频播放器控制器（用于AVPlayer）
class VideoPlayerController: NSObject, ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isReady = false
    @Published var loadError: String?
    
    private var playerItemObservation: NSKeyValueObservation?
    
    func setupPlayer(url: URL) {
        // 清理之前的播放器
        cleanup()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = false
        
        // 监听播放器状态
        playerItemObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.isReady = true
                    self?.loadError = nil
                case .failed:
                    self?.isReady = false
                    self?.loadError = item.error?.localizedDescription ?? NSLocalizedString("播放失败", comment: "")
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        // 循环播放
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    private func cleanup() {
        playerItemObservation?.invalidate()
        playerItemObservation = nil
        player?.pause()
        player = nil
        isPlaying = false
        isReady = false
        loadError = nil
    }
    
    deinit {
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AVPlayer视图包装器
struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
}

// MARK: - 视频Feed（支持上下滑动）
struct VideoFeedView: View {
    let posts: [ForumPost]
    let initialIndex: Int
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var scrolledId: Int?
    
    init(posts: [ForumPost], initialIndex: Int, primaryColor: Color) {
        self.posts = posts
        self.initialIndex = initialIndex
        self.primaryColor = primaryColor
        self._scrolledId = State(initialValue: initialIndex)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.offset) { index, post in
                            VideoPlayerView(
                                post: post,
                                isActive: index == (scrolledId ?? initialIndex),
                                primaryColor: primaryColor,
                                onDismiss: { dismiss() }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(index)
                        }
                    }
                }
                .scrollPosition(id: $scrolledId)
                .scrollTargetBehavior(.paging)
                .onAppear {
                    // 延迟到下一帧以避开 ScrollView 初始偏置 reset 覆盖 scrolledId
                    DispatchQueue.main.async {
                        scrolledId = initialIndex
                        proxy.scrollTo(initialIndex, anchor: .top)
                    }
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()  // 全屏，视频延伸到导航栏区域
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(.visible, for: .navigationBar)  // 确保 toolbar 可见
        .toolbarBackground(Color.clear, for: .navigationBar)  // 完全透明背景
        .toolbarColorScheme(.dark, for: .navigationBar)   // 白色图标
    }
}

// MARK: - 启用原生返回手势的 ViewModifier
struct EnableSwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SwipeBackEnabler())
    }
}

// UIViewControllerRepresentable 来启用原生返回手势
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = SwipeBackEnablerController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

class SwipeBackEnablerController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 确保导航控制器的滑动返回手势可用
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}

extension View {
    func enableSwipeBack() -> some View {
        modifier(EnableSwipeBackModifier())
    }
}

// MARK: - 小红书/抖音风格视频播放器
struct VideoPlayerView: View {
    let post: ForumPost
    let isActive: Bool
    let primaryColor: Color
    let onDismiss: (() -> Void)?
    @ObservedObject var socialService = SocialService.shared
    @ObservedObject var authService = AuthService.shared
    @StateObject private var playerController = VideoPlayerController()
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var favoriteCount: Int
    @State private var isLiked: Bool
    @State private var isFavorited: Bool
    @State private var isFollowing: Bool
    @State private var showComments = false
    @State private var showPlayButton = false
    @State private var showShareSheet = false
    @State private var showLoginAlert = false
    @State private var showSelfFollowAlert = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    // 示例视频URL（用于演示，使用可靠的MP4视频源）
    private let sampleVideoURLs = [
        // Google公开MP4测试视频（短小精悍，加载快）
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4"
    ]
    
    @State private var videoLoadError: String? = nil
    @State private var isVideoLoading = true
    
    init(post: ForumPost, isActive: Bool, primaryColor: Color, onDismiss: (() -> Void)? = nil) {
        self.post = post
        self.isActive = isActive
        self.primaryColor = primaryColor
        self.onDismiss = onDismiss
        self._likeCount = State(initialValue: post.likeCount)
        self._commentCount = State(initialValue: post.commentCount)
        self._favoriteCount = State(initialValue: post.favoriteCount)
        // 优先从 SocialService 读取状态（更准确），否则使用帖子自带的状态
        let socialService = SocialService.shared
        self._isLiked = State(initialValue: socialService.likedPostIds.contains(post.id) || post.isLiked)
        self._isFavorited = State(initialValue: socialService.favoritePostIds.contains(post.id) || post.isFavorited)
        self._isFollowing = State(initialValue: socialService.followingUserIds.contains(post.authorId))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 黑色背景
                Color.black.ignoresSafeArea()
                
                // 视频播放层
                if let error = videoLoadError {
                    // 加载失败显示错误信息 - 优雅的毛玻璃风格
                    ZStack {
                        // 渐变背景
                        LinearGradient(
                            colors: [primaryColor.opacity(0.3), Color.black.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        VStack(spacing: 24) {
                            // 圆形图标背景
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "video.slash.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            VStack(spacing: 8) {
                                Text(NSLocalizedString("视频暂时无法播放", comment: ""))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            
                            // 重试按钮
                            Button {
                                videoLoadError = nil
                                isVideoLoading = true
                                loadVideo()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text(NSLocalizedString("重新加载", comment: ""))
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(primaryColor)
                                )
                            }
                            .padding(.top, 8)
                        }
                    }
                } else if playerController.player != nil && !isVideoLoading {
                    VideoPlayerLayerView(player: playerController.player)
                        .ignoresSafeArea()
                } else {
                    // 加载中 - 优雅的动画样式
                    ZStack {
                        LinearGradient(
                            colors: [primaryColor.opacity(0.2), Color.black.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                                    .frame(width: 60, height: 60)
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.3)
                            }
                            
                            Text(NSLocalizedString("加载中...", comment: ""))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                // 点击暂停/播放（只覆盖中间区域，避免遮挡顶部导航栏和右侧按钮）
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geo.size.width - 80, height: geo.size.height - 150) // 右侧留80pt，顶部留150pt
                        .offset(y: 100) // 向下偏移，避开顶部导航栏
                        .onTapGesture {
                            playerController.togglePlayPause()
                            showPlayButton = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                showPlayButton = false
                            }
                        }
                }
                
                // 播放/暂停图标（短暂显示）
                if showPlayButton {
                    Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8))
                        .transition(.opacity)
                }
                
                // 顶部右侧菜单（三个点）- 放在 safeAreaInset 之后确保可点击
                VStack {
                    HStack {
                        Spacer()
                        
                        // 三个点菜单
                        Menu {
                            Button { showShareSheet = true } label: {
                                Label(NSLocalizedString("分享", comment: ""), systemImage: "square.and.arrow.up")
                            }
                            if authService.currentUser?.id == post.authorId {
                                Button(role: .destructive) { showDeleteAlert = true } label: {
                                    Label(NSLocalizedString("删除", comment: ""), systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 16)
                    
                    Spacer()
                }
                .padding(.top, 8)  // 与导航栏返回按钮对齐
                .zIndex(200)  // 确保在最上层
                
                // 右侧互动栏
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // 作者头像（使用真实头像）
                        VStack(spacing: 0) {
                            if let avatarUrl = post.authorAvatar, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 52, height: 52)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    default:
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 52, height: 52)
                                            .overlay(
                                                Text(String(post.authorName.prefix(1)))
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            )
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    }
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Text(String(post.authorName.prefix(1)))
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            }
                            
                            // 关注按钮
                            if !isFollowing {
                                Button {
                                    if !authService.isLoggedIn {
                                        showLoginAlert = true
                                        return
                                    }
                                    // 检查是否关注自己
                                    if let currentUserId = authService.currentUser?.id, currentUserId == post.authorId {
                                        showSelfFollowAlert = true
                                        return
                                    }
                                    Task {
                                        do {
                                            let result = try await ApiService.shared.toggleFollow(userId: post.authorId)
                                            await MainActor.run {
                                                isFollowing = result["isFollowing"] ?? false
                                            }
                                        } catch {
                                            print("关注失败: \(error)")
                                        }
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 20, height: 20)
                                        .background(primaryColor)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                }
                                .offset(y: -10)
                            }
                        }
                        
                        // 点赞
                        VStack(spacing: 6) {
                            Button {
                                print("❤️ 点赞按钮被点击，postId: \(post.id), 登录状态: \(authService.isLoggedIn)")
                                if !authService.isLoggedIn {
                                    showLoginAlert = true
                                    return
                                }
                                Task {
                                    do {
                                        print("❤️ 正在调用点赞API...")
                                        let result = try await ApiService.shared.togglePostLike(postId: post.id)
                                        print("❤️ 点赞API返回: \(result)")
                                        await MainActor.run {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                let newLiked = result["isLiked"] ?? false
                                                if newLiked != isLiked {
                                                    likeCount += newLiked ? 1 : -1
                                                    isLiked = newLiked
                                                    // 同步到 SocialService
                                                    if newLiked {
                                                        socialService.likedPostIds.insert(post.id)
                                                    } else {
                                                        socialService.likedPostIds.remove(post.id)
                                                    }
                                                }
                                            }
                                        }
                                    } catch {
                                        print("❤️ 点赞失败: \(error)")
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(isLiked ? Color(red: 1, green: 0.3, blue: 0.4) : .white)
                                        .scaleEffect(isLiked ? 1.1 : 1.0)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            Text(formatCount(likeCount))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        // 评论
                        VStack(spacing: 6) {
                            Button {
                                print("💬 评论按钮被点击")
                                showComments = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "bubble.right")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            Text(formatCount(commentCount))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        // 收藏
                        VStack(spacing: 6) {
                            Button {
                                print("⭐ 收藏按钮被点击，postId: \(post.id), 登录状态: \(authService.isLoggedIn)")
                                if !authService.isLoggedIn {
                                    showLoginAlert = true
                                    return
                                }
                                Task {
                                    do {
                                        print("⭐ 正在调用收藏API...")
                                        let result = try await ApiService.shared.togglePostFavorite(postId: post.id)
                                        print("⭐ 收藏API返回: \(result)")
                                        await MainActor.run {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                let newFavorited = result["isFavorited"] ?? false
                                                if newFavorited != isFavorited {
                                                    // 确保收藏数不会变成负数
                                                    if newFavorited {
                                                        favoriteCount += 1
                                                    } else {
                                                        favoriteCount = max(0, favoriteCount - 1)
                                                    }
                                                    isFavorited = newFavorited
                                                    // 同步到 SocialService
                                                    if newFavorited {
                                                        socialService.favoritePostIds.insert(post.id)
                                                    } else {
                                                        socialService.favoritePostIds.remove(post.id)
                                                    }
                                                }
                                            }
                                        }
                                    } catch {
                                        print("⭐ 收藏失败: \(error)")
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: isFavorited ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(isFavorited ? Color(red: 1, green: 0.85, blue: 0.3) : .white)
                                        .scaleEffect(isFavorited ? 1.1 : 1.0)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            Text(formatCount(favoriteCount))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 120)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .zIndex(10) // 确保右侧互动栏在最上层
                
                // 底部信息栏
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // 作者信息
                        HStack(spacing: 8) {
                            Text("@\(post.authorName)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1)
                            
                            if !isFollowing {
                                Button {
                                    if !authService.isLoggedIn {
                                        showLoginAlert = true
                                        return
                                    }
                                    // 检查是否关注自己
                                    if let currentUserId = authService.currentUser?.id, currentUserId == post.authorId {
                                        showSelfFollowAlert = true
                                        return
                                    }
                                    Task {
                                        do {
                                            let result = try await ApiService.shared.toggleFollow(userId: post.authorId)
                                            await MainActor.run {
                                                isFollowing = result["isFollowing"] ?? false
                                            }
                                        } catch {
                                            print("关注失败: \(error)")
                                        }
                                    }
                                } label: {
                                    Text(NSLocalizedString("关注", comment: ""))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .stroke(Color.white, lineWidth: 1)
                                        )
                                }
                            } else {
                                Text(NSLocalizedString("已关注", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        // 内容
                        Text(post.content)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.5), radius: 1)
                            .padding(.trailing, 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // 初始化关注状态
            isFollowing = socialService.isFollowing(userId: post.authorId)
            
            // 只有处于激活状态才加载视频
            if isActive {
                loadVideo()
            }
        }
        .onDisappear {
            playerController.pause()
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                loadVideo()
            } else {
                playerController.pause()
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsSheetView(post: post, primaryColor: primaryColor)
        }
        .sheet(isPresented: $showShareSheet) {
            PostShareSheet(post: post)
        }
        .alert(NSLocalizedString("需要登录", comment: ""), isPresented: $showLoginAlert) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("去登录", comment: "")) {
                // 这里可以触发登录流程
            }
        } message: {
            Text(NSLocalizedString("请先登录后再进行此操作", comment: ""))
        }
        .alert(NSLocalizedString("无法关注", comment: ""), isPresented: $showSelfFollowAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("你不能关注自己哦", comment: ""))
        }
        .alert(NSLocalizedString("删除帖子", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("删除", comment: ""), role: .destructive) {
                deletePost()
            }
        } message: {
            Text(NSLocalizedString("确定要删除这条帖子吗？此操作不可撤销。", comment: ""))
        }
    }
    
    // 删除帖子
    private func deletePost() {
        isDeleting = true
        Task {
            do {
                try await ApiService.shared.deletePost(postId: post.id)
                await MainActor.run {
                    isDeleting = false
                    // 即刻从「我的帖子」和「我的收藏」列表中移除
                    SocialService.shared.removeMyPostImmediately(postId: post.id)
                    SocialService.shared.removeFavoriteImmediately(postId: post.id)
                    // 发送帖子删除通知（给广场页面用）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PostDeleted"),
                        object: nil,
                        userInfo: ["postId": post.id]
                    )
                    if let onDismiss = onDismiss {
                        onDismiss()
                    }
                }
            } catch {
                print("删除帖子失败: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
    
    // 加载视频
    private func loadVideo() {
        // 优先使用帖子的视频URL，否则使用示例视频
        let videoURLString = post.videoUrl ?? sampleVideoURLs[Int(post.id) % sampleVideoURLs.count]
        
        guard let url = URL(string: videoURLString) else {
            videoLoadError = NSLocalizedString("无效的视频地址", comment: "")
            isVideoLoading = false
            return
        }
        
        // 检查URL是否可访问
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.videoLoadError = String(format: NSLocalizedString("网络错误: %@", comment: ""), error.localizedDescription)
                    self.isVideoLoading = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    // 非HTTP响应，可能是本地文件，直接尝试播放
                    self.setupAndPlayVideo(url: url)
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    self.setupAndPlayVideo(url: url)
                } else {
                    self.videoLoadError = String(format: NSLocalizedString("视频不可用 (状态码: %d)", comment: ""), httpResponse.statusCode)
                    self.isVideoLoading = false
                }
            }
        }.resume()
    }
    
    private func setupAndPlayVideo(url: URL) {
        playerController.setupPlayer(url: url)
        
        // 延迟一点开始播放，确保播放器准备好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isVideoLoading = false
            self.playerController.play()
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fw", Double(count) / 10000)
        } else if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - 分享Sheet（保留用于向后兼容）
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 帖子分享Sheet（支持 LinkPresentation 预览卡片）
// 使用 PostShareService.swift 中的 PostShareSheet

// MARK: - 评论弹窗
struct CommentsSheetView: View {
    let post: ForumPost
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @State private var commentText = ""
    @State private var comments: [PostComment] = []
    @State private var isLoading = true
    @State private var isSending = false
    @State private var showLoginAlert = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 评论列表
                if isLoading {
                    ProgressView(NSLocalizedString("加载评论中...", comment: ""))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(NSLocalizedString("暂无评论", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("快来发表第一条评论吧", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            // 小红书风格评论布局
                            ForEach(comments.filter { $0.parentId == nil }) { comment in
                                CommentWithRepliesView(
                                    comment: comment,
                                    primaryColor: primaryColor,
                                    postAuthorId: post.authorId
                                ) { replyTarget in
                                    // 弹窗模式暂不支持回复，关闭后跳转详情页
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Divider()
                
                // 评论输入框
                HStack(spacing: 12) {
                    TextField(NSLocalizedString("说点什么...", comment: ""), text: $commentText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button(NSLocalizedString("完成", comment: "")) {
                                    isInputFocused = false
                                }
                                .foregroundColor(primaryColor)
                            }
                        }
                    
                    Button {
                        sendComment()
                    } label: {
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(commentText.isEmpty ? .gray : primaryColor)
                        }
                    }
                    .disabled(commentText.isEmpty || isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.adaptiveCard)
            }
            .background(Color.adaptiveCard)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(format: NSLocalizedString("%d 条评论", comment: ""), comments.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(primaryColor.opacity(0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .tint(primaryColor)
            // 移除右上角叉号，用户可以下滑关闭弹窗
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            loadComments()
        }
        .alert(NSLocalizedString("请先登录", comment: ""), isPresented: $showLoginAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        }
    }
    
    // 加载评论
    private func loadComments() {
        Task {
            do {
                let page = try await ApiService.shared.getComments(postId: post.id)
                // 使用 PostComment.from(dto:) 方法正确处理嵌套回复
                let loadedComments = page.content.map { PostComment.from(dto: $0) }
                await MainActor.run {
                    comments = loadedComments
                    isLoading = false
                }
            } catch {
                print("加载评论失败: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    // 发送评论
    private func sendComment() {
        guard authService.isLoggedIn else {
            showLoginAlert = true
            return
        }
        
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSending = true
        let content = commentText
        
        Task {
            do {
                let dto = try await ApiService.shared.addComment(postId: post.id, content: content)
                let newComment = PostComment(
                    id: dto.id,
                    authorId: dto.authorId ?? 0,
                    authorName: dto.authorName ?? authService.currentUser?.nickname ?? NSLocalizedString("用户", comment: ""),
                    authorAvatar: dto.authorAvatar ?? authService.currentUser?.avatarUrl,
                    content: dto.content,
                    likeCount: 0,
                    timeAgo: NSLocalizedString("刚刚", comment: ""),
                    isLiked: false
                )
                await MainActor.run {
                    comments.insert(newComment, at: 0)
                    commentText = ""
                    isSending = false
                }
            } catch {
                print("发送评论失败: \(error)")
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
}

// MARK: - 帖子详情页
struct PostDetailView: View {
    let post: ForumPost
    let primaryColor: Color
    @ObservedObject var socialService = SocialService.shared
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var postStore = PostStore.shared  // Fix E1: 使用 PostStore
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var comments: [PostComment] = []
    @State private var isLoadingComments = true
    @State private var isSendingComment = false
    @State private var replyingToComment: PostComment? = nil  // 正在回复的评论
    @State private var showShareSheet = false
    @State private var selectedImageIndex = 0
    @State private var showImageViewer = false
    @State private var showAuthorProfile = false
    @State private var showLoginAlert = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    // 举报功能
    @State private var showReportSheet = false
    @State private var selectedReportType: ReportType = .other
    @State private var reportDescription = ""
    @State private var isReporting = false
    @State private var showReportSuccessAlert = false
    @State private var showReportErrorAlert = false
    @State private var reportErrorMessage = ""
    @FocusState private var isCommentInputFocused: Bool  // 控制评论输入框键盘
    
    // Fix E1: 从 PostStore 获取 likeCount，确保状态一致
    private var likeCount: Int {
        postStore.getLikeCount(postId: post.id)
    }
    
    private let urgentColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    // 从帖子创建用户资料（初始值为0，实际数据从API加载）
    private var authorProfile: UserProfile {
        UserProfile(
            id: post.authorId,
            nickname: post.authorName,
            avatar: post.authorAvatar,
            bio: nil,
            birdCount: 0,
            postCount: 0,
            followerCount: 0,
            followingCount: 0
        )
    }
    
    init(post: ForumPost, primaryColor: Color) {
        self.post = post
        self.primaryColor = primaryColor
        // Fix E1: 确保 PostStore 有初始值
    }
    
    // 导航栏作者头像视图
    private var authorAvatarView: some View {
        Group {
            if let avatarUrl = post.authorAvatar, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    default:
                        defaultAuthorAvatar
                    }
                }
            } else {
                defaultAuthorAvatar
            }
        }
    }
    
    private var defaultAuthorAvatar: some View {
        Circle()
            .fill(primaryColor.opacity(0.1))
            .frame(width: 32, height: 32)
            .overlay(
                Image("bird")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(primaryColor.opacity(0.5))
            )
    }
    
    // 导航栏右上角三点菜单（分享/关注/举报）
    private var trailingMenuContent: some View {
        Menu {
            // 分享
            Button { showShareSheet = true } label: {
                Label(NSLocalizedString("分享", comment: ""), systemImage: "square.and.arrow.up")
            }
            
            // 非自己的帖子才显示关注和举报
            if authService.currentUser?.id != post.authorId {
                // 关注/取消关注
                Button {
                    if authService.isLoggedIn {
                        withAnimation(.spring(response: 0.3)) {
                            socialService.toggleFollow(userId: post.authorId)
                        }
                    } else {
                        showLoginAlert = true
                    }
                } label: {
                    let isFollowing = socialService.isFollowing(userId: post.authorId)
                    Label(isFollowing ? NSLocalizedString("取消关注", comment: "") : NSLocalizedString("关注作者", comment: ""), systemImage: isFollowing ? "person.badge.minus" : "person.badge.plus")
                }
                
                // 举报
                Button {
                    if authService.isLoggedIn {
                        showReportSheet = true
                    } else {
                        showLoginAlert = true
                    }
                } label: {
                    Label(NSLocalizedString("举报", comment: ""), systemImage: "exclamationmark.triangle")
                }
            }
            
            // 自己的帖子显示删除
            if authService.currentUser?.id == post.authorId {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label(NSLocalizedString("删除", comment: ""), systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
        }
    }
    
    // 主内容视图
    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    imageSection
                    contentSection.padding(.horizontal, 16)
                    if post.postType == .findBird {
                        findBirdDetailSection.padding(.horizontal, 16)
                    }
                    Divider().padding(.vertical, 8)
                    commentsSection.padding(.horizontal, 16)
                }
                .padding(.bottom, 80)
            }
            bottomBar
        }
    }
    
    // 导航栏标题视图
    private var principalToolbarContent: some View {
        Button { showAuthorProfile = true } label: {
            HStack(spacing: 8) {
                authorAvatarView
                Text(post.authorName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
    }
    
    var body: some View {
        mainContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(themeManager.primaryColor.opacity(0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .tint(themeManager.primaryColor)
            .background(Color.adaptiveCard)
            .toolbar {
                ToolbarItem(placement: .principal) { principalToolbarContent }
                ToolbarItem(placement: .navigationBarTrailing) { trailingMenuContent }
            }
            .navigationDestination(isPresented: $showAuthorProfile) {
                UserProfileView(user: authorProfile)
                    .hidesTabBar()
            }
            .sheet(isPresented: $showShareSheet) {
                PostShareSheet(post: post)
            }
            .alert(NSLocalizedString("请先登录", comment: ""), isPresented: $showLoginAlert) {
                Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
            }
            .alert(NSLocalizedString("删除帖子", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("删除", comment: ""), role: .destructive) {
                deletePost()
            }
        } message: {
            Text(NSLocalizedString("确定要删除这条帖子吗？此操作不可撤销。", comment: ""))
        }
        .sheet(isPresented: $showReportSheet) {
            ReportPostSheet(
                post: post,
                selectedType: $selectedReportType,
                description: $reportDescription,
                isReporting: $isReporting,
                onSubmit: submitReport
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(NSLocalizedString("举报成功", comment: ""), isPresented: $showReportSuccessAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("感谢您的反馈，我们会尽快处理。", comment: ""))
        }
        .alert(NSLocalizedString("举报失败", comment: ""), isPresented: $showReportErrorAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(reportErrorMessage)
        }
        .onAppear {
            // Fix E1: 确保 PostStore 有该帖子的状态
            if postStore.getLikeCount(postId: post.id) == 0 && post.likeCount > 0 {
                postStore.setLikeCount(postId: post.id, count: post.likeCount)
            }
            loadComments()
            // 隐藏底部 TabBar
            TabBarVisibilityManager.shared.hide()
        }
        .onDisappear {
            // 显示底部 TabBar
            TabBarVisibilityManager.shared.show()
        }
    }
    
    // 删除帖子 - Fix #12: 删除成功后发送通知
    private func deletePost() {
        isDeleting = true
        Task {
            do {
                try await ApiService.shared.deletePost(postId: post.id)
                await MainActor.run {
                    isDeleting = false
                    // 即刻从「我的帖子」和「我的收藏」列表中移除
                    SocialService.shared.removeMyPostImmediately(postId: post.id)
                    SocialService.shared.removeFavoriteImmediately(postId: post.id)
                    // Fix #12: 发送帖子删除通知（给广场页面用）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PostDeleted"),
                        object: nil,
                        userInfo: ["postId": post.id]
                    )
                    dismiss()
                }
            } catch {
                print("删除帖子失败: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }
    
    // 提交举报
    private func submitReport() {
        isReporting = true
        Task {
            do {
                _ = try await ApiService.shared.reportPost(
                    postId: post.id,
                    type: selectedReportType.rawValue,
                    reason: selectedReportType.description,
                    description: reportDescription.isEmpty ? nil : reportDescription
                )
                await MainActor.run {
                    isReporting = false
                    showReportSheet = false
                    showReportSuccessAlert = true
                    // 重置表单
                    selectedReportType = .other
                    reportDescription = ""
                }
            } catch {
                await MainActor.run {
                    isReporting = false
                    if let apiError = error as? ApiError {
                        switch apiError {
                        case .serverError(let message):
                            reportErrorMessage = message
                        default:
                            reportErrorMessage = NSLocalizedString("举报失败，请稍后重试", comment: "")
                        }
                    } else {
                        reportErrorMessage = NSLocalizedString("网络错误，请检查网络连接", comment: "")
                    }
                    showReportSheet = false
                    showReportErrorAlert = true
                }
            }
        }
    }
    
    // 加载评论
    private func loadComments() {
        Task {
            do {
                let page = try await ApiService.shared.getComments(postId: post.id)
                // 使用 PostComment.from(dto:) 方法正确处理嵌套回复
                let loadedComments = page.content.map { PostComment.from(dto: $0) }
                await MainActor.run {
                    comments = loadedComments
                    isLoadingComments = false
                }
            } catch {
                print("加载评论失败: \(error)")
                await MainActor.run {
                    isLoadingComments = false
                }
            }
        }
    }
    
    // 图片区域 - 支持多图浏览
    private var imageSection: some View {
        VStack(spacing: 0) {
            if post.images.isEmpty {
                // 只有寻鸟帖才显示无图占位，普通帖子不显示
                if post.postType == .findBird {
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(urgentColor.opacity(0.1))
                            .aspectRatio(1.0, contentMode: .fit)
                            .overlay(
                                VStack(spacing: 12) {
                                    Image("bird")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .opacity(0.5)
                                    
                                    if let birdName = post.birdName {
                                        Text(birdName)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(urgentColor.opacity(0.6))
                                    }
                                }
                            )
                        
                        findBirdBadge
                    }
                }
                // 普通帖子无图片时不显示任何内容
            } else {
                // 有图片时显示图片网格
                ZStack(alignment: .topLeading) {
                    imageGrid
                    
                    // 寻鸟标签
                    if post.postType == .findBird {
                        findBirdBadge
                    }
                }
            }
        }
    }
    
    // 寻鸟标签
    private var findBirdBadge: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(NSLocalizedString("寻鸟启事", comment: ""))
                    .fontWeight(.bold)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(urgentColor)
            .cornerRadius(8)
            
            if let reward = post.reward {
                Text(String(format: NSLocalizedString("悬赏 %@", comment: ""), reward))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
        }
        .padding(16)
    }
    
    // 图片轮播（填满屏幕宽度，按比例显示完整图片）
    private var imageGrid: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        return VStack(spacing: 0) {
            TabView(selection: $selectedImageIndex) {
                ForEach(post.images.indices, id: \.self) { index in
                    let imageUrl = post.images[index]
                    GeometryReader { geo in
                        CachedAsyncImage(url: URL(string: imageUrl), size: .large) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedImageIndex = index
                                        showImageViewer = true
                                    }
                            case .failure:
                                imagePlaceholder(index: index)
                                    .frame(width: geo.size.width, height: geo.size.height)
                            case .empty:
                                // 加载中占位符
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .overlay(
                                        ProgressView()
                                            .tint(primaryColor)
                                    )
                            @unknown default:
                                imagePlaceholder(index: index)
                                    .frame(width: geo.size.width, height: geo.size.height)
                            }
                        }
                    }
                    .tag(index)
                }
            }
            .frame(width: screenWidth, height: screenWidth)
            .tabViewStyle(.page(indexDisplayMode: post.images.count > 1 ? .always : .never))
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            FullScreenImageGallery(
                imageURLs: post.images.compactMap { URL(string: $0) },
                currentIndex: $selectedImageIndex,
                onDismiss: { showImageViewer = false }
            )
            .ignoresSafeArea()
        }
    }
    
    // 图片占位符
    private func imagePlaceholder(index: Int) -> some View {
        Rectangle()
            .fill(post.postType == .findBird ? urgentColor.opacity(0.1) : primaryColor.opacity(0.1))
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(post.postType == .findBird ? urgentColor.opacity(0.4) : primaryColor.opacity(0.4))
                    Text(String(format: NSLocalizedString("图片 %d", comment: ""), index + 1))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
    
    // 内容区域
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 发布时间
            Text(post.timeAgo)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 正文
            Text(post.content)
                .font(.body)
                .lineSpacing(6)
            
            // 关联鸟儿卡片（支持多只）
            let birds = post.associatedBirds
            if post.postType == .normal, !birds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image("bird")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("关联鸟儿", comment: ""))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(primaryColor)
                        Spacer()
                    }
                    
                    ForEach(birds) { bird in
                        HStack(spacing: 12) {
                            // 鸟儿头像
                            if let avatar = bird.avatar {
                                CachedAsyncImage(url: URL(string: avatar)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    default:
                                        defaultBirdAvatarSmall
                                    }
                                }
                            } else {
                                defaultBirdAvatarSmall
                            }
                            
                            // 鸟儿信息
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bird.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !bird.species.isEmpty {
                                    Text(bird.species)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "leaf.fill")
                                .font(.caption)
                                .foregroundColor(primaryColor.opacity(0.6))
                        }
                        .padding(10)
                        .background(primaryColor.opacity(0.08))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showAuthorProfile) {
            UserProfileView(user: authorProfile)
                .hidesTabBar()
        }
    }
    
    // 默认鸟儿头像（小）
    private var defaultBirdAvatarSmall: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(primaryColor.opacity(0.15))
            .frame(width: 44, height: 44)
            .overlay(
                Image("bird")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(primaryColor.opacity(0.5))
            )
    }
    
    // 寻鸟详细信息
    private var findBirdDetailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏 - 简洁样式
            Text(NSLocalizedString("寻鸟信息", comment: ""))
                .font(.headline)
                .fontWeight(.bold)
            
            // 信息列表 - 简洁样式
            VStack(alignment: .leading, spacing: 12) {
                if let birdName = post.birdName {
                    simpleInfoRow(title: NSLocalizedString("鸟儿名字", comment: ""), value: birdName)
                }
                if let species = post.birdSpecies {
                    simpleInfoRow(title: NSLocalizedString("鸟儿品种", comment: ""), value: species)
                }
                if let location = post.lostLocation {
                    simpleInfoRow(title: NSLocalizedString("走失地点", comment: ""), value: location)
                }
                if let phone = post.contactPhone {
                    simpleInfoRow(title: NSLocalizedString("联系电话", comment: ""), value: phone)
                }
                if let reward = post.reward {
                    simpleInfoRow(title: NSLocalizedString("悬赏金额", comment: ""), value: "¥\(reward)")
                }
            }
            .padding(16)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
            
            // 帮助按钮 - 改进样式
            HStack(spacing: 12) {
                Button {
                    callPhoneNumber()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                        Text(NSLocalizedString("联系失主", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [urgentColor, urgentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: urgentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(post.contactPhone == nil)
                
                Button {
                    shareToWeChat()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .font(.system(size: 16))
                        Text(NSLocalizedString("帮忙转发", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(urgentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.adaptiveCard)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(urgentColor, lineWidth: 2)
                    )
                    .shadow(color: urgentColor.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
        }
    }
    
    private func infoRow(icon: String, title: String, value: String, isPhone: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(urgentColor)
                .frame(width: 20)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(isPhone ? .semibold : .regular)
                .foregroundColor(isPhone ? urgentColor : .primary)
        }
    }
    
    // 现代化信息行 - 左对齐，更美观
    private func modernInfoRow(icon: String, title: String, value: String, color: Color, isHighlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // 文字信息 - 左对齐
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(isHighlight ? .bold : .medium)
                    .foregroundColor(isHighlight ? color : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
    
    // 评论区
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("评论", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(comments.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            if isLoadingComments {
                ProgressView(NSLocalizedString("加载评论中...", comment: ""))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title)
                        .foregroundColor(.gray.opacity(0.3))
                    Text(NSLocalizedString("暂无评论，快来抢沙发～", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                // 小红书风格评论布局
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(comments.filter { $0.parentId == nil }) { comment in
                        CommentWithRepliesView(
                            comment: comment,
                            primaryColor: primaryColor,
                            postAuthorId: post.authorId
                        ) { replyTarget in
                            replyingToComment = replyTarget
                            commentText = ""
                        }
                    }
                }
            }
        }
    }
    
    // 底部互动栏
    private var bottomBar: some View {
        VStack(spacing: 0) {
            // 回复提示条
            if let replyComment = replyingToComment {
                HStack {
                    Text(String(format: NSLocalizedString("回复 @%@", comment: ""), replyComment.authorName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        replyingToComment = nil
                        commentText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGray6))
            }
            
            HStack(spacing: 16) {
                // 评论输入框
                HStack {
                    TextField(replyingToComment != nil ? "回复 @\(replyingToComment!.authorName)..." : NSLocalizedString("说点什么...", comment: ""), text: $commentText)
                        .font(.subheadline)
                        .focused($isCommentInputFocused)
                    
                    if !commentText.isEmpty {
                        Button {
                            submitComment()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(primaryColor)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(20)
            
            // 点赞
            Button {
                withAnimation(.spring(response: 0.3)) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    socialService.toggleLike(postId: post.id)
                    // likeCount 会自动从 PostStore 更新
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: socialService.isLiked(postId: post.id) ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(socialService.isLiked(postId: post.id) ? .red : .gray)
                    Text("\(likeCount)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // 收藏
            Button {
                withAnimation(.spring(response: 0.3)) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    socialService.toggleFavorite(postId: post.id)
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: socialService.isFavorited(postId: post.id) ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundColor(socialService.isFavorited(postId: post.id) ? primaryColor : .gray)
                    Text(socialService.isFavorited(postId: post.id) ? NSLocalizedString("已收藏", comment: "") : NSLocalizedString("收藏", comment: ""))
                        .font(.caption2)
                        .foregroundColor(socialService.isFavorited(postId: post.id) ? primaryColor : .gray)
                }
            }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.adaptiveCard)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
    }
    
    // 简洁的信息行
    private func simpleInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    // 提交评论
    private func submitComment() {
        guard authService.isLoggedIn else {
            showLoginAlert = true
            return
        }
        
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        isSendingComment = true
        
        // 获取回复的评论ID（如果有）
        let parentId = replyingToComment?.id
        
        Task {
            do {
                // 调用后端API添加评论（传递parentId实现回复）
                let commentDTO = try await ApiService.shared.addComment(
                    postId: post.id,
                    content: content,
                    parentId: parentId
                )
                
                // 转换为本地模型
                let newComment = PostComment(
                    id: commentDTO.id,
                    authorId: commentDTO.authorId ?? 0,
                    authorName: commentDTO.authorName ?? authService.currentUser?.nickname ?? NSLocalizedString("用户", comment: ""),
                    authorAvatar: commentDTO.authorAvatar ?? authService.currentUser?.avatarUrl,
                    content: commentDTO.content,
                    likeCount: 0,
                    timeAgo: NSLocalizedString("刚刚", comment: ""),
                    isLiked: false,
                    parentId: parentId,
                    replyToName: replyingToComment?.authorName
                )
                
                await MainActor.run {
                    if let parentId = parentId {
                        // 回复评论：添加到主评论的replies数组
                        if let parentIndex = comments.firstIndex(where: { $0.id == parentId }) {
                            comments[parentIndex].replies.append(newComment)
                        } else {
                            // 如果是回复的回复，找到最顶层的主评论
                            for i in 0..<comments.count {
                                if comments[i].replies.contains(where: { $0.id == parentId }) {
                                    comments[i].replies.append(newComment)
                                    break
                                }
                            }
                        }
                    } else {
                        // 主评论：插入到列表开头
                        comments.insert(newComment, at: 0)
                    }
                    commentText = ""
                    replyingToComment = nil  // 清除回复状态
                    isSendingComment = false
                    isCommentInputFocused = false  // 收起键盘
                }
            } catch {
                print("发送评论失败: \(error)")
                await MainActor.run {
                    isSendingComment = false
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 拨打电话
    private func callPhoneNumber() {
        guard let phoneNumber = post.contactPhone else { return }
        
        // 清理电话号码（移除空格、横线等）
        let cleanedNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        if let url = URL(string: "tel://\(cleanedNumber)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // 分享到微信（使用 LinkPresentation 预览卡片）
    private func shareToWeChat() {
        // 使用新的分享服务，支持预览卡片
        PostShareService.shared.sharePost(post)
    }
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    let maxCount: Int
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                if parent.images.count < parent.maxCount {
                    parent.images.append(image)
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - 评论数据模型
struct PostComment: Identifiable {
    let id: Int64
    let localId = UUID() // 本地唯一标识
    let authorId: Int64
    let authorName: String
    let authorAvatar: String?
    let content: String
    let timeAgo: String
    var likeCount: Int
    var isLiked: Bool
    let parentId: Int64?       // 父评论ID
    let replyToName: String?   // 回复的用户名（用于 @显示）
    var replies: [PostComment] // 回复列表（只有第一层）
    
    init(id: Int64 = 0, authorId: Int64 = 0, authorName: String, authorAvatar: String? = nil, content: String, likeCount: Int, timeAgo: String, isLiked: Bool = false, parentId: Int64? = nil, replyToName: String? = nil, replies: [PostComment] = []) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.content = content
        self.timeAgo = timeAgo
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.parentId = parentId
        self.replyToName = replyToName
        self.replies = replies
    }
    
    // 从 DTO 创建（包含回复）
    static func from(dto: CommentDTO) -> PostComment {
        // 递归处理回复
        let replies = (dto.replies ?? []).map { PostComment.from(dto: $0) }
        
        // 计算相对时间：优先使用后端返回的 timeAgo，否则根据 createdAt 计算
        let timeAgoText = dto.timeAgo ?? Self.formatRelativeTime(from: dto.createdAt)
        
        return PostComment(
            id: dto.id,
            authorId: dto.authorId ?? 0,
            authorName: dto.authorName ?? NSLocalizedString("用户", comment: ""),
            authorAvatar: dto.authorAvatar,
            content: dto.content,
            likeCount: dto.likeCount ?? 0,
            timeAgo: timeAgoText,
            isLiked: dto.isLiked ?? false,
            parentId: dto.parentId,
            replyToName: dto.parentAuthorName,  // 使用父评论作者名
            replies: replies
        )
    }
    
    /// 根据 createdAt 字符串计算相对时间（小红书风格）
    /// 规则：刚刚 -> X分钟前 -> X小时前 -> 昨天 HH:mm -> X天前 -> MM月dd日 -> YYYY年MM月dd日
    private static func formatRelativeTime(from createdAtString: String?) -> String {
        guard let createdAtString = createdAtString else { return NSLocalizedString("刚刚", comment: "") }
        
        // 尝试解析日期字符串（支持多种格式）
        let date = parseDate(createdAtString)
        guard let createdAt = date else { return NSLocalizedString("刚刚", comment: "") }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute, .hour, .day, .year], from: createdAt, to: now)
        
        let seconds = components.second ?? 0
        let minutes = components.minute ?? 0
        let hours = components.hour ?? 0
        let days = components.day ?? 0
        let years = components.year ?? 0
        
        // 未来时间显示"刚刚"
        if createdAt > now {
            return NSLocalizedString("刚刚", comment: "")
        }
        
        // 1分钟内
        if days == 0 && hours == 0 && minutes == 0 {
            return NSLocalizedString("刚刚", comment: "")
        }
        
        // 1小时内
        if days == 0 && hours == 0 {
            return String(format: NSLocalizedString("%d分钟前", comment: ""), minutes)
        }
        
        // 24小时内（今天）
        if days == 0 {
            return String(format: NSLocalizedString("%d小时前", comment: ""), hours)
        }
        
        // 昨天
        if days == 1 {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return String(format: NSLocalizedString("昨天 %@", comment: ""), formatter.string(from: createdAt))
        }
        
        // 7天内
        if days <= 7 {
            return String(format: NSLocalizedString("%d天前", comment: ""), days)
        }
        
        // 今年内
        if years == 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = NSLocalizedString("M月d日", comment: "")
            return formatter.string(from: createdAt)
        }
        
        // 往年
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月d日", comment: "")
        return formatter.string(from: createdAt)
    }
    
    /// 解析日期字符串（支持多种格式）
    private static func parseDate(_ dateString: String) -> Date? {
        // ISO 8601 带毫秒
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // ISO 8601 无毫秒
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // 常见日期格式
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    static let sampleComments: [PostComment] = []
}

// MARK: - 小红书风格评论组件（一级+二级嵌套）
struct CommentWithRepliesView: View {
    let comment: PostComment
    let primaryColor: Color
    let postAuthorId: Int64?
    let onReply: (PostComment) -> Void
    
    @State private var isExpanded = false  // 是否展开全部回复
    @State private var showDeleteAlert = false
    @State private var commentToDelete: PostComment? = nil
    @ObservedObject var authService = AuthService.shared
    
    // 默认显示的回复数量
    private let defaultVisibleReplies = 2
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 一级评论（无缩进，独立模块）
            CommentRow(
                comment: comment,
                primaryColor: primaryColor,
                postAuthorId: postAuthorId,
                isReply: false,
                onDelete: { deleteComment(comment) }
            ) { replyTarget in
                onReply(replyTarget)
            }
            
            // 二级评论区域（有缩进）
            if !comment.replies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // 显示回复（根据展开状态）
                    let visibleReplies = isExpanded ? comment.replies : Array(comment.replies.prefix(defaultVisibleReplies))
                    
                    ForEach(visibleReplies) { reply in
                        CommentRow(
                            comment: reply,
                            primaryColor: primaryColor,
                            postAuthorId: postAuthorId,
                            isReply: true,
                            parentAuthorName: comment.authorName,  // 传递一级评论作者名
                            onDelete: { deleteComment(reply) }
                        ) { replyTarget in
                            onReply(replyTarget)
                        }
                    }
                    
                    // 展开更多回复按钮
                    if comment.replies.count > defaultVisibleReplies && !isExpanded {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(String(format: NSLocalizedString("展开%d条回复", comment: ""), comment.replies.count - defaultVisibleReplies))
                                    .font(.caption)
                                    .foregroundColor(primaryColor)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(primaryColor)
                            }
                            .padding(.vertical, 8)
                            .padding(.leading, 44) // 对齐二级评论
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 收起按钮
                    if isExpanded && comment.replies.count > defaultVisibleReplies {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("收起", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.up")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.leading, 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 44) // 二级评论整体缩进（对齐一级评论头像右边）
            }
            
            // 分隔线
            Divider()
                .padding(.top, 8)
        }
        .alert(NSLocalizedString("删除评论", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("删除", comment: ""), role: .destructive) {
                performDelete()
            }
        } message: {
            Text(NSLocalizedString("确定要删除这条评论吗？", comment: ""))
        }
    }
    
    private func deleteComment(_ comment: PostComment) {
        commentToDelete = comment
        showDeleteAlert = true
    }
    
    private func performDelete() {
        guard let comment = commentToDelete else { return }
        Task {
            do {
                try await ApiService.shared.deleteComment(commentId: comment.id)
                // 通知刷新评论列表
                NotificationCenter.default.post(name: NSNotification.Name("RefreshComments"), object: nil)
            } catch {
                print("删除评论失败: \(error)")
            }
        }
    }
}

// MARK: - 评论行
struct CommentRow: View {
    let comment: PostComment
    let primaryColor: Color
    let postAuthorId: Int64?  // 帖子作者ID，用于判断情侣特效
    let isReply: Bool         // 是否是回复（二级评论）
    let onDelete: (() -> Void)?  // 删除评论回调
    let onReply: ((PostComment) -> Void)?  // 回复评论回调
    let parentAuthorName: String?  // 一级评论作者名（用于判断是否显示@）
    @ObservedObject var socialService = SocialService.shared
    @ObservedObject var authService = AuthService.shared
    @State private var likeCount: Int
    @State private var showUserProfile = false  // 显示用户详情
    
    private let coupleColor = Color(red: 1.0, green: 0.4, blue: 0.6) // 粉红色情侣特效
    
    // 是否是自己的评论（可删除）
    private var isOwnComment: Bool {
        authService.currentUser?.id == comment.authorId
    }
    
    // 是否需要显示@用户名（只有三级及以上评论才显示，二级评论不显示）
    private var shouldShowAtMention: Bool {
        guard isReply, let replyToName = comment.replyToName else { return false }
        // 如果回复的是一级评论作者，不显示@
        if let parentAuthorName = parentAuthorName, replyToName == parentAuthorName {
            return false
        }
        // 否则显示@（回复的是其他二级评论）
        return true
    }
    
    init(comment: PostComment, primaryColor: Color, postAuthorId: Int64? = nil, isReply: Bool = false, parentAuthorName: String? = nil, onDelete: (() -> Void)? = nil, onReply: ((PostComment) -> Void)? = nil) {
        self.comment = comment
        self.primaryColor = primaryColor
        self.postAuthorId = postAuthorId
        self.isReply = isReply
        self.parentAuthorName = parentAuthorName
        self.onDelete = onDelete
        self.onReply = onReply
        self._likeCount = State(initialValue: comment.likeCount)
    }
    
    // 评论者的用户资料
    private var commentAuthorProfile: UserProfile {
        UserProfile(
            id: comment.authorId,
            nickname: comment.authorName,
            avatar: comment.authorAvatar,
            bio: nil,
            birdCount: 0,
            postCount: 0,
            followerCount: 0,
            followingCount: 0
        )
    }
    
    private var isLiked: Bool {
        socialService.isCommentLiked(commentId: comment.id)
    }
    
    // 判断评论者是否是帖子作者的情侣伴侣
    private var isCoupleComment: Bool {
        guard let postAuthorId = postAuthorId,
              let currentUser = authService.currentUser,
              currentUser.couplePartnerId != nil else {
            return false
        }
        // 如果当前用户是帖子作者，检查评论者是否是自己的伴侣
        if currentUser.id == postAuthorId {
            return comment.authorId == currentUser.couplePartnerId
        }
        // 如果当前用户是评论者，检查帖子作者是否是自己的伴侣
        if comment.authorId == currentUser.id {
            return postAuthorId == currentUser.couplePartnerId
        }
        return false
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 用户头像 - 可点击查看用户详情
            Button {
                showUserProfile = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarUrl = comment.authorAvatar, !avatarUrl.isEmpty {
                        CachedAsyncImage(url: URL(string: AppConfig.applyCDN(to: avatarUrl))) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(isCoupleComment ? coupleColor : Color.clear, lineWidth: 2)
                                    )
                            case .failure(_), .empty:
                                Circle()
                                    .fill(isCoupleComment ? coupleColor.opacity(0.2) : primaryColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(comment.authorName.prefix(1)))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(isCoupleComment ? coupleColor : primaryColor)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // 无头像时显示首字母
                        Circle()
                            .fill(isCoupleComment ? coupleColor.opacity(0.2) : primaryColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(comment.authorName.prefix(1)))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(isCoupleComment ? coupleColor : primaryColor)
                            )
                    }
                    
                    // 情侣特效标识
                    if isCoupleComment {
                        Text("💕")
                            .font(.system(size: 10))
                            .offset(x: 4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(comment.authorName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isCoupleComment ? coupleColor : .primary)
                    
                    // 情侣标签
                    if isCoupleComment {
                        Text(NSLocalizedString("💕伴侣", comment: ""))
                            .font(.system(size: 9))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(coupleColor)
                            .cornerRadius(4)
                    }
                    
                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 评论内容（只有三级及以上评论才显示@用户名，二级评论不显示）
                if shouldShowAtMention, let replyToName = comment.replyToName {
                    // 三级及以上评论：显示 @用户名
                    (Text("@\(replyToName) ")
                        .font(.subheadline)
                        .foregroundColor(primaryColor) +
                    Text(comment.content)
                        .font(.subheadline)
                        .foregroundColor(.primary))
                } else {
                    Text(comment.content)
                        .font(.subheadline)
                }
                
                // 点赞按钮
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        let wasLiked = isLiked
                        socialService.toggleCommentLike(commentId: comment.id)
                        likeCount += wasLiked ? -1 : 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.caption2)
                        Text("\(likeCount)")
                            .font(.caption2)
                    }
                    .foregroundColor(isLiked ? (isCoupleComment ? coupleColor : .red) : .gray)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            isCoupleComment ?
            // 情侣评论背景 - 使用负边距让背景延伸到全屏宽度
            // 二级评论需要额外的负边距来补偿外层的 .padding(.leading, 44)
            coupleColor.opacity(0.05)
                .padding(.horizontal, -16)  // 补偿水平内边距
                .padding(.leading, isReply ? -44 : 0)  // 二级评论额外补偿左侧缩进
            : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击评论触发回复
            onReply?(comment)
        }
        // 长按删除自己的评论
        .contextMenu {
            if isOwnComment {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label(NSLocalizedString("删除评论", comment: ""), systemImage: "trash")
                }
            }
            
            Button {
                onReply?(comment)
            } label: {
                Label(NSLocalizedString("回复", comment: ""), systemImage: "arrowshape.turn.up.left")
            }
        }
        .navigationDestination(isPresented: $showUserProfile) {
            UserProfileView(user: commentAuthorProfile)
                .hidesTabBar()
        }
    }
}

// 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - 帖子类型
enum PostType: String {
    case normal = "普通"
    case findBird = "寻鸟"
    
    var displayName: String {
        switch self {
        case .normal: return NSLocalizedString("普通", comment: "")
        case .findBird: return NSLocalizedString("寻鸟", comment: "")
        }
    }
}

// MARK: - 帖子数据模型 - Fix #6: 使用稳定的 localId
struct ForumPost: Identifiable, Equatable {
    let id: Int64 // 后端ID
    // Fix #6: 基于服务器 ID 派生 localId，确保刷新时稳定
    var localId: String { "post_\(id)" }
    let authorId: Int64 // 作者ID
    let authorName: String
    let authorAvatar: String?
    let content: String
    let images: [String] // 支持最多9张图片
    let imageIcon: String // 无图片时显示的图标
    var likeCount: Int
    var commentCount: Int
    var favoriteCount: Int
    let timeAgo: String
    let distance: Double?
    let postType: PostType
    var isLiked: Bool
    var isFavorited: Bool
    
    // 视频相关字段
    let mediaType: String // IMAGE, VIDEO
    let videoUrl: String?
    let videoCover: String?
    let videoDuration: Int?
    
    // 关联的鸟儿
    let birdId: Int64?
    
    // 位置信息
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    
    // 寻鸟专属字段
    let birdName: String?
    let birdSpecies: String?
    let birdAvatar: String?
    let birdsInfo: String?  // 多个鸟儿信息JSON数组
    let lostLocation: String?
    let contactPhone: String?
    let reward: String?
    let isFound: Bool
    
    init(id: Int64 = 0, authorId: Int64 = 0, authorName: String, authorAvatar: String?, content: String, images: [String] = [], imageIcon: String, likeCount: Int, commentCount: Int, favoriteCount: Int = 0, timeAgo: String, distance: Double?, postType: PostType = .normal, isLiked: Bool = false, isFavorited: Bool = false, mediaType: String = "IMAGE", videoUrl: String? = nil, videoCover: String? = nil, videoDuration: Int? = nil, birdId: Int64? = nil, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil, birdName: String? = nil, birdSpecies: String? = nil, birdAvatar: String? = nil, birdsInfo: String? = nil, lostLocation: String? = nil, contactPhone: String? = nil, reward: String? = nil, isFound: Bool = false) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.content = content
        self.images = images
        self.imageIcon = imageIcon
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.favoriteCount = favoriteCount
        self.timeAgo = timeAgo
        self.distance = distance
        self.postType = postType
        self.isLiked = isLiked
        self.isFavorited = isFavorited
        self.mediaType = mediaType
        self.videoUrl = videoUrl
        self.videoCover = videoCover
        self.videoDuration = videoDuration
        self.birdId = birdId
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.birdName = birdName
        self.birdSpecies = birdSpecies
        self.birdAvatar = birdAvatar
        self.birdsInfo = birdsInfo
        self.lostLocation = lostLocation
        self.contactPhone = contactPhone
        self.reward = reward
        self.isFound = isFound
    }
    
    // 从 DTO 创建
    static func from(dto: ForumPostDTO) -> ForumPost {
        // 计算相对时间：优先使用后端返回的 timeAgo，否则根据 createdAt 计算
        let timeAgoText = dto.timeAgo ?? Self.formatRelativeTime(from: dto.createdAt)
        
        return ForumPost(
            id: dto.id,
            authorId: dto.authorId ?? 0,
            authorName: dto.authorName ?? NSLocalizedString("用户", comment: ""),
            authorAvatar: dto.authorAvatar,
            content: dto.content,
            images: dto.images ?? [],
            imageIcon: dto.postType == "FIND_BIRD" ? "magnifyingglass" : (dto.mediaType == "VIDEO" ? "play.circle" : "text.bubble"),
            likeCount: dto.likeCount ?? 0,
            commentCount: dto.commentCount ?? 0,
            favoriteCount: dto.favoriteCount ?? 0,
            timeAgo: timeAgoText,
            distance: dto.distance,
            postType: dto.postType == "FIND_BIRD" ? .findBird : .normal,
            isLiked: dto.isLiked ?? false,
            isFavorited: dto.isFavorited ?? false,
            mediaType: dto.mediaType ?? "IMAGE",
            videoUrl: dto.videoUrl,
            videoCover: dto.videoCover,
            videoDuration: dto.videoDuration,
            birdId: dto.birdId,
            latitude: dto.latitude,
            longitude: dto.longitude,
            locationName: dto.locationName,
            birdName: dto.birdName,
            birdSpecies: dto.birdSpecies,
            birdAvatar: dto.birdAvatar,
            birdsInfo: dto.birdsInfo,
            lostLocation: dto.lostLocation,
            contactPhone: dto.contactPhone,
            reward: dto.reward,
            isFound: dto.isFound ?? false
        )
    }
    
    // 转换为 DTO（用于缓存）
    func toDTO() -> ForumPostDTO {
        ForumPostDTO(
            id: id,
            authorId: authorId,
            authorName: authorName,
            authorAvatar: authorAvatar,
            content: content,
            postType: postType == .findBird ? "FIND_BIRD" : "NORMAL",
            mediaType: mediaType,
            images: images,
            videoUrl: videoUrl,
            videoCover: videoCover,
            videoDuration: videoDuration,
            likeCount: likeCount,
            commentCount: commentCount,
            favoriteCount: favoriteCount,
            viewCount: 0,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            distance: distance,
            birdId: birdId,
            birdName: birdName,
            birdSpecies: birdSpecies,
            birdAvatar: birdAvatar,
            birdsInfo: birdsInfo,
            lostLocation: lostLocation,
            contactPhone: contactPhone,
            reward: reward,
            isFound: isFound,
            isLiked: isLiked,
            isFavorited: isFavorited,
            isFollowing: false,
            createdAt: nil,
            timeAgo: timeAgo
        )
    }
    
    // 解析多个关联鸟儿信息
    struct AssociatedBird: Identifiable {
        let id: Int64
        let name: String
        let species: String
        let avatar: String?
    }
    
    var associatedBirds: [AssociatedBird] {
        guard let birdsInfoStr = birdsInfo, !birdsInfoStr.isEmpty else {
            // 如果没有 birdsInfo，使用单个鸟的兼容字段
            if let birdId = birdId, let name = birdName, !name.isEmpty {
                return [AssociatedBird(id: birdId, name: name, species: birdSpecies ?? "", avatar: birdAvatar)]
            }
            return []
        }
        
        // 解析 JSON 数组
        guard let data = birdsInfoStr.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        return jsonArray.compactMap { dict -> AssociatedBird? in
            guard let id = dict["id"] as? Int64 ?? (dict["id"] as? Int).map({ Int64($0) }),
                  let name = dict["name"] as? String else {
                return nil
            }
            return AssociatedBird(
                id: id,
                name: name,
                species: dict["species"] as? String ?? "",
                avatar: (dict["avatar"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            )
        }
    }
    
    /// 根据 createdAt 字符串计算相对时间（小红书风格）
    /// 规则：刚刚 -> X分钟前 -> X小时前 -> 昨天 HH:mm -> X天前 -> MM月dd日 -> YYYY年MM月dd日
    private static func formatRelativeTime(from createdAtString: String?) -> String {
        guard let createdAtString = createdAtString else { return NSLocalizedString("刚刚", comment: "") }
        
        // 尝试解析日期字符串（支持多种格式）
        let date = parseDate(createdAtString)
        guard let createdAt = date else { return NSLocalizedString("刚刚", comment: "") }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute, .hour, .day, .year], from: createdAt, to: now)
        
        let minutes = components.minute ?? 0
        let hours = components.hour ?? 0
        let days = components.day ?? 0
        let years = components.year ?? 0
        
        // 未来时间显示"刚刚"
        if createdAt > now {
            return NSLocalizedString("刚刚", comment: "")
        }
        
        // 1分钟内
        if days == 0 && hours == 0 && minutes == 0 {
            return NSLocalizedString("刚刚", comment: "")
        }
        
        // 1小时内
        if days == 0 && hours == 0 {
            return String(format: NSLocalizedString("%d分钟前", comment: ""), minutes)
        }
        
        // 24小时内（今天）
        if days == 0 {
            return String(format: NSLocalizedString("%d小时前", comment: ""), hours)
        }
        
        // 昨天
        if days == 1 {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return String(format: NSLocalizedString("昨天 %@", comment: ""), formatter.string(from: createdAt))
        }
        
        // 7天内
        if days <= 7 {
            return String(format: NSLocalizedString("%d天前", comment: ""), days)
        }
        
        // 今年内
        if years == 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = NSLocalizedString("M月d日", comment: "")
            return formatter.string(from: createdAt)
        }
        
        // 往年
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月d日", comment: "")
        return formatter.string(from: createdAt)
    }
    
    /// 解析日期字符串（支持多种格式）
    private static func parseDate(_ dateString: String) -> Date? {
        // ISO 8601 带毫秒
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // ISO 8601 无毫秒
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // 常见日期格式
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    // 空数据
    static let samplePosts: [ForumPost] = []
}

// Fix A9: 优化 Equatable 实现，仅比较影响 UI 渲染的关键字段
extension ForumPost {
    static func == (lhs: ForumPost, rhs: ForumPost) -> Bool {
        // 仅比较会影响 UI 渲染的字段，减少不必要的 Diff 计算
        lhs.id == rhs.id &&
        lhs.likeCount == rhs.likeCount &&
        lhs.commentCount == rhs.commentCount &&
        lhs.favoriteCount == rhs.favoriteCount &&
        lhs.isLiked == rhs.isLiked &&
        lhs.isFavorited == rhs.isFavorited &&
        lhs.isFound == rhs.isFound &&
        lhs.content == rhs.content
    }
}

// MARK: - 发帖视图
struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var locationService = LocationService.shared
    
    @State private var content = ""
    @State private var selectedBirdIds: Set<Int64> = []  // 多选关联的鸟儿ID
    @State private var myBirds: [Bird] = []  // 用户的鸟儿列表
    @State private var isPosting = false
    @State private var showSuccess = false
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var selectedVideoData: Data? = nil
    @State private var selectedVideoThumbnail: UIImage? = nil
    @State private var mediaType: String = "IMAGE" // IMAGE or VIDEO
    @State private var showCoverPicker = false
    @State private var videoFrames: [UIImage] = [] // 视频帧列表
    @State private var selectedCoverIndex: Int = 0 // 选中的封面帧索引
    @State private var customCover: UIImage? = nil // 用户选择的封面
    
    // 定位相关
    @State private var useLocation = true  // 是否使用定位
    @State private var showLocationPicker = false  // 显示位置选择
    @State private var customLocationName = ""  // 手动输入的位置名称
    @State private var useCurrentLocation = true  // 使用当前定位还是手动输入
    @State private var customLatitude: Double? = nil  // 手动选择的纬度
    @State private var customLongitude: Double? = nil  // 手动选择的经度
    
    // 错误提示
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 键盘控制
    @FocusState private var isTextEditorFocused: Bool
    
    let onPost: (ForumPost) -> Void
    
    @ObservedObject var themeManager = ThemeManager.shared
    private let maxLength = 500
    private let maxImages = 9
    
    private var canPost: Bool {
        !content.isEmpty && !isPosting
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 内容输入
                    contentInputSection
                    
                    Divider()
                        .padding(.vertical, 12)
                    
                    // 媒体类型选择
                    mediaSelectionSection
                    
                    Divider()
                        .padding(.vertical, 12)
                    
                    // 关联鸟儿
                    birdSelectionSection
                    
                    Divider()
                        .padding(.vertical, 12)
                    
                    // 位置信息
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(themeManager.primaryColor)
                            Text(NSLocalizedString("添加位置", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Toggle("", isOn: $useLocation)
                                .labelsHidden()
                                .tint(themeManager.primaryColor)
                        }
                        .padding(.horizontal, 16)
                        
                        if useLocation {
                            // 位置选择
                            HStack(spacing: 12) {
                                // 使用当前定位
                                Button {
                                    useCurrentLocation = true
                                    showLocationPicker = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: useCurrentLocation ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Image(systemName: "location.circle.fill")
                                            .font(.caption)
                                        if locationService.isLocating {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Text(useCurrentLocation && !customLocationName.isEmpty ? customLocationName : locationService.shortAddress)
                                                .font(.caption)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(useCurrentLocation ? themeManager.primaryColor.opacity(0.15) : Color(uiColor: .systemGray6))
                                    .foregroundColor(useCurrentLocation ? themeManager.primaryColor : .secondary)
                                    .cornerRadius(16)
                                }
                                
                                // 手动输入
                                Button {
                                    useCurrentLocation = false
                                    showLocationPicker = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: !useCurrentLocation ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                        Text(!useCurrentLocation && !customLocationName.isEmpty ? customLocationName : NSLocalizedString("手动输入", comment: ""))
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(!useCurrentLocation ? themeManager.primaryColor.opacity(0.15) : Color(uiColor: .systemGray6))
                                    .foregroundColor(!useCurrentLocation ? themeManager.primaryColor : .secondary)
                                    .cornerRadius(16)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // 发布按钮（放在滚动区域内，确保能看到）
                    Button {
                        postContent()
                    } label: {
                        HStack {
                            if isPosting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(NSLocalizedString("发布", comment: ""))
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canPost ? themeManager.primaryColor : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(!canPost || isPosting)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
                .contentShape(Rectangle()) // 让整个区域可点击
                .onTapGesture {
                    isTextEditorFocused = false
                }
            }
            .scrollDismissesKeyboard(.interactively)  // 滑动时键盘可交互式隐藏，但不会立即消失
            .themedNavigationBar(title: NSLocalizedString("发布帖子", comment: ""))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("发布", comment: "")) {
                        postContent()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryColor)
                    .disabled(!canPost)
                }
            }
        }
        .onAppear {
            // 自动获取定位
            locationService.startLocating()
            // 刷新位置信息
            locationService.refreshLocation()
            // 加载用户的鸟儿列表
            loadMyBirds()
        }
        .alert(NSLocalizedString("发布成功", comment: ""), isPresented: $showSuccess) {
                Button(NSLocalizedString("确定", comment: "")) { dismiss() }
            } message: {
                Text(NSLocalizedString("你的帖子已发布到广场", comment: ""))
            }
            .alert(NSLocalizedString("发布失败", comment: ""), isPresented: $showError) {
                Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(images: $selectedImages, maxCount: maxImages)
            }
            .onChange(of: selectedItems) { newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                if selectedImages.count < maxImages {
                                    // P1-02: 图片大小校验与自动压缩
                                    let maxImageSize = 10 * 1024 * 1024 // 10MB
                                    if data.count > maxImageSize {
                                        // 需要压缩
                                        if let compressedImage = compressImage(image, maxSizeBytes: maxImageSize) {
                                            selectedImages.append(compressedImage)
                                            print("📷 图片已压缩: \(data.count / 1024)KB → \(compressedImage.jpegData(compressionQuality: 0.8)?.count ?? 0 / 1024)KB")
                                        } else {
                                            selectedImages.append(image)
                                        }
                                    } else {
                                        selectedImages.append(image)
                                    }
                                }
                            }
                        }
                    }
                    await MainActor.run {
                        selectedItems = []
                    }
                }
            }
            .onChange(of: selectedVideoItem) { newItem in
                Task {
                    if let item = newItem {
                        // P1-01: 获取视频格式信息
                        let supportedTypes = item.supportedContentTypes
                        let isValidFormat = supportedTypes.contains { type in
                            type.identifier.contains("mpeg4") || 
                            type.identifier.contains("quicktime") ||
                            type.identifier.contains("mp4") ||
                            type.identifier.contains("mov")
                        }
                        
                        if !isValidFormat {
                            await MainActor.run {
                                errorMessage = NSLocalizedString("仅支持MP4/MOV格式视频", comment: "")
                                showError = true
                                selectedVideoItem = nil
                            }
                            return
                        }
                        
                        // 加载视频数据
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            let maxVideoSize = 200 * 1024 * 1024 // 200MB
                            
                            // P1-01: 视频大小校验与自动压缩
                            var finalData = data
                            if data.count > maxVideoSize {
                                print("🎬 视频需要压缩: \(data.count / 1024 / 1024)MB > 200MB")
                                // 尝试压缩视频
                                if let compressedData = await compressVideo(data: data, maxSizeBytes: maxVideoSize) {
                                    finalData = compressedData
                                    print("🎬 视频已压缩: \(data.count / 1024 / 1024)MB → \(compressedData.count / 1024 / 1024)MB")
                                } else {
                                    await MainActor.run {
                                        errorMessage = NSLocalizedString("视频过大且压缩失败，请选择小于200MB的视频", comment: "")
                                        showError = true
                                        selectedVideoItem = nil
                                    }
                                    return
                                }
                            }
                            
                            await MainActor.run {
                                selectedVideoData = finalData
                            }
                            
                            // 提取视频帧
                            let frames = await extractVideoFrames(from: finalData)
                            await MainActor.run {
                                videoFrames = frames
                                if let firstFrame = frames.first {
                                    selectedVideoThumbnail = firstFrame
                                    customCover = firstFrame
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCoverPicker) {
                VideoCoverPickerView(
                    frames: videoFrames,
                    selectedIndex: $selectedCoverIndex,
                    onSelect: { image in
                        customCover = image
                        showCoverPicker = false
                    },
                    primaryColor: themeManager.primaryColor
                )
            }
            .sheet(isPresented: $showLocationPicker) {
                MapLocationPickerView(useCurrentLocation: useCurrentLocation) { location in
                    customLocationName = location.address
                    customLatitude = location.coordinate.latitude
                    customLongitude = location.coordinate.longitude
                    print("📍 地图选择位置: \(location.address), 坐标: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    showLocationPicker = false
                }
            }
    }
    
    // 从视频数据中提取帧
    private func extractVideoFrames(from data: Data) async -> [UIImage] {
        // 将数据写入临时文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        do {
            try data.write(to: tempURL)
        } catch {
            print("写入临时文件失败: \(error)")
            return []
        }
        
        let asset = AVAsset(url: tempURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 400)
        
        var frames: [UIImage] = []
        
        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            // 提取8个均匀分布的帧
            let frameCount = 8
            for i in 0..<frameCount {
                let time = CMTime(seconds: durationSeconds * Double(i) / Double(frameCount), preferredTimescale: 600)
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    frames.append(UIImage(cgImage: cgImage))
                } catch {
                    print("提取帧失败: \(error)")
                }
            }
        } catch {
            print("获取视频时长失败: \(error)")
        }
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempURL)
        
        return frames
    }
    
    // P1-02: 图片压缩函数
    private func compressImage(_ image: UIImage, maxSizeBytes: Int) -> UIImage? {
        var compression: CGFloat = 1.0
        let minCompression: CGFloat = 0.1
        let step: CGFloat = 0.1
        
        // 首先尝试降低JPEG质量
        while compression > minCompression {
            if let data = image.jpegData(compressionQuality: compression) {
                if data.count <= maxSizeBytes {
                    return UIImage(data: data) ?? image
                }
            }
            compression -= step
        }
        
        // 如果还是太大，缩小尺寸
        var scale: CGFloat = 1.0
        var currentImage = image
        
        while scale > 0.1 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                
                if let data = resizedImage.jpegData(compressionQuality: 0.7) {
                    if data.count <= maxSizeBytes {
                        return resizedImage
                    }
                }
                currentImage = resizedImage
            } else {
                UIGraphicsEndImageContext()
            }
            scale -= 0.1
        }
        
        return currentImage
    }
    
    // P1-01: 视频压缩函数
    private func compressVideo(data: Data, maxSizeBytes: Int) async -> Data? {
        // 将数据写入临时文件
        let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_input.mp4")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_output.mp4")
        
        do {
            try data.write(to: inputURL)
        } catch {
            print("写入临时视频文件失败: \(error)")
            return nil
        }
        
        // 使用 AVAssetExportSession 压缩视频
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            print("创建导出会话失败")
            try? FileManager.default.removeItem(at: inputURL)
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        // 清理输入文件
        try? FileManager.default.removeItem(at: inputURL)
        
        if exportSession.status == .completed {
            do {
                let compressedData = try Data(contentsOf: outputURL)
                try? FileManager.default.removeItem(at: outputURL)
                
                // 检查压缩后是否满足大小要求
                if compressedData.count <= maxSizeBytes {
                    return compressedData
                } else {
                    // 如果中等质量还是太大，尝试更低质量
                    return await compressVideoLowQuality(inputData: data, maxSizeBytes: maxSizeBytes)
                }
            } catch {
                print("读取压缩视频失败: \(error)")
                try? FileManager.default.removeItem(at: outputURL)
                return nil
            }
        } else {
            print("视频压缩失败: \(String(describing: exportSession.error))")
            try? FileManager.default.removeItem(at: outputURL)
            return nil
        }
    }
    
    // 低质量视频压缩（备用）
    private func compressVideoLowQuality(inputData: Data, maxSizeBytes: Int) async -> Data? {
        let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_input2.mp4")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_output2.mp4")
        
        do {
            try inputData.write(to: inputURL)
        } catch {
            return nil
        }
        
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetLowQuality) else {
            try? FileManager.default.removeItem(at: inputURL)
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        try? FileManager.default.removeItem(at: inputURL)
        
        if exportSession.status == .completed {
            do {
                let compressedData = try Data(contentsOf: outputURL)
                try? FileManager.default.removeItem(at: outputURL)
                return compressedData.count <= maxSizeBytes ? compressedData : nil
            } catch {
                try? FileManager.default.removeItem(at: outputURL)
                return nil
            }
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        return nil
    }
    
    // 内容输入区域
    private var contentInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                UserAvatarView(avatarUrl: authService.currentUser?.avatarUrl, size: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(authService.currentUser?.nickname ?? NSLocalizedString("用户", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(NSLocalizedString("发布到广场", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            TextEditor(text: $content)
                .frame(minHeight: 150)
                .padding(.horizontal, 12)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($isTextEditorFocused)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(NSLocalizedString("完成", comment: "")) {
                            isTextEditorFocused = false
                        }
                        .foregroundColor(themeManager.primaryColor)
                    }
                }
            
            HStack {
                Spacer()
                Text("\(content.count)/\(maxLength)")
                    .font(.caption)
                    .foregroundColor(content.count > maxLength ? .red : .secondary)
            }
            .padding(.horizontal, 16)
        }
    }
    
    // 媒体选择区域
    private var mediaSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            mediaTypeToggle
            
            if mediaType == "IMAGE" {
                imagePickerSection
            }
            
            if mediaType == "VIDEO" {
                videoPickerSection
            }
        }
    }
    
    private var mediaTypeToggle: some View {
        HStack(spacing: 16) {
            Button {
                mediaType = "IMAGE"
                selectedVideoItem = nil
                selectedVideoData = nil
                selectedVideoThumbnail = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: mediaType == "IMAGE" ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(mediaType == "IMAGE" ? themeManager.primaryColor : .gray)
                    Image(systemName: "photo.fill")
                    Text(NSLocalizedString("图片", comment: ""))
                }
                .font(.subheadline)
                .foregroundColor(mediaType == "IMAGE" ? themeManager.primaryColor : .secondary)
            }
            
            Button {
                mediaType = "VIDEO"
                selectedImages = []
                selectedItems = []
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: mediaType == "VIDEO" ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(mediaType == "VIDEO" ? themeManager.primaryColor : .gray)
                    Image(systemName: "video.fill")
                    Text(NSLocalizedString("视频", comment: ""))
                }
                .font(.subheadline)
                .foregroundColor(mediaType == "VIDEO" ? themeManager.primaryColor : .secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("添加图片", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(selectedImages.count)/\(maxImages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // 使用可拖拽排序的图片网格
            DraggableImageGrid(
                images: $selectedImages,
                maxImages: maxImages,
                primaryColor: themeManager.primaryColor,
                selectedItems: $selectedItems
            )
        }
    }
    
    private func imagePreviewItem(index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: selectedImages[index])
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Button {
                selectedImages.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .offset(x: 6, y: -6)
        }
    }
    
    private var addImageButton: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: maxImages - selectedImages.count,
            matching: .images
        ) {
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                Text(NSLocalizedString("添加", comment: ""))
                    .font(.caption)
            }
            .foregroundColor(themeManager.primaryColor)
            .frame(width: 80, height: 80)
            .background(themeManager.primaryColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var videoPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("添加视频", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(selectedVideoThumbnail != nil ? "1/1" : "0/1")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            HStack(spacing: 12) {
                if let thumbnail = customCover ?? selectedVideoThumbnail {
                    videoPreviewItem(thumbnail: thumbnail)
                } else {
                    addVideoButton
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func videoPreviewItem(thumbnail: UIImage) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                        )
                }
                
                Button {
                    selectedVideoItem = nil
                    selectedVideoData = nil
                    selectedVideoThumbnail = nil
                    customCover = nil
                    videoFrames = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .offset(x: 6, y: -6)
            }
            
            Button {
                showCoverPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.caption)
                    Text(NSLocalizedString("选择封面", comment: ""))
                        .font(.caption)
                }
                .foregroundColor(themeManager.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.primaryColor.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var addVideoButton: some View {
        PhotosPicker(
            selection: $selectedVideoItem,
            matching: .videos
        ) {
            VStack(spacing: 6) {
                Image(systemName: "video.badge.plus")
                    .font(.title2)
                Text(NSLocalizedString("添加视频", comment: ""))
                    .font(.caption)
            }
            .foregroundColor(themeManager.primaryColor)
            .frame(width: 120, height: 160)
            .background(themeManager.primaryColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // 关联鸟儿选择区域
    private var birdSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image("bird")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(NSLocalizedString("关联我的鸟儿", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !selectedBirdIds.isEmpty {
                    Text(String(format: NSLocalizedString("%d只", comment: ""), selectedBirdIds.count))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(themeManager.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
                
                Text(NSLocalizedString("可多选", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    let availableBirds = myBirds.filter { $0.isLost != true && !$0.isDead }
                    
                    if availableBirds.isEmpty {
                        Text(NSLocalizedString("暂无可关联的鸟儿", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(availableBirds, id: \.id) { bird in
                            birdSelectionButton(bird: bird)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func birdSelectionButton(bird: Bird) -> some View {
        let isSelected = selectedBirdIds.contains(bird.id)
        return Button {
            if isSelected {
                selectedBirdIds.remove(bird.id)
            } else {
                selectedBirdIds.insert(bird.id)
            }
        } label: {
            HStack(spacing: 6) {
                BirdAvatarView(avatarUrl: bird.avatarUrl, size: 24, isDead: false)
                Text(bird.nickname)
                    .font(.caption)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? themeManager.primaryColor : Color(uiColor: .systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
    
    private func loadMyBirds() {
        Task {
            do {
                let birds = try await ApiService.shared.getMyBirds()
                await MainActor.run {
                    self.myBirds = birds
                }
            } catch {
                print("加载鸟儿列表失败: \(error)")
            }
        }
    }
    
    // P2-11: 防止重复发布
    @State private var lastPostContent: String = ""
    @State private var lastPostTime: Date = .distantPast
    @State private var currentRequestId: String?  // Fix #29: 幂等性请求ID
    
    private func postContent() {
        // P2-11: 重复发布防抖（3秒内相同内容不允许发布）
        let now = Date()
        if content == lastPostContent && now.timeIntervalSince(lastPostTime) < 3 {
            errorMessage = NSLocalizedString("请勿重复发布相同内容", comment: "")
            showError = true
            return
        }
        
        // 防止后台已有发布任务
        if BackgroundPostService.shared.isPublishing {
            errorMessage = NSLocalizedString("已有帖子正在发布中，请稍后再试", comment: "")
            showError = true
            return
        }
        
        // 获取位置信息 - 优先使用地图选择的位置，否则使用当前定位
        var latitude: Double? = nil
        var longitude: Double? = nil
        var locationName: String? = nil
        
        if useLocation {
            if !customLocationName.isEmpty && customLatitude != nil && customLongitude != nil {
                // 使用地图选择的位置
                latitude = customLatitude
                longitude = customLongitude
                locationName = customLocationName
            } else {
                // 使用当前定位
                latitude = locationService.currentLocation?.coordinate.latitude
                longitude = locationService.currentLocation?.coordinate.longitude
                locationName = locationService.fullAddress
            }
        }
        
        // 记录发布状态
        lastPostContent = content
        lastPostTime = now
        
        // 准备发布数据
        let birdIdsArray = Array(selectedBirdIds)
        
        // 使用后台服务发布
        BackgroundPostService.shared.publishPost(
            content: content,
            images: selectedImages,
            videoData: selectedVideoData,
            videoThumbnail: selectedVideoThumbnail,
            customCover: customCover,
            mediaType: mediaType,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            birdIds: birdIdsArray.isEmpty ? nil : birdIdsArray
        )
        
        // 立即关闭发布页面，用户可以继续浏览
        dismiss()
    }
}

// MARK: - 视频封面选择器
struct VideoCoverPickerView: View {
    let frames: [UIImage]
    @Binding var selectedIndex: Int
    let onSelect: (UIImage) -> Void
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 预览区域
                if selectedIndex < frames.count {
                    Image(uiImage: frames[selectedIndex])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                Text(NSLocalizedString("选择视频封面", comment: ""))
                    .font(.headline)
                
                Text(NSLocalizedString("滑动选择一帧作为视频封面", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 帧选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(frames.indices, id: \.self) { index in
                            Button {
                                selectedIndex = index
                            } label: {
                                Image(uiImage: frames[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 70, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIndex == index ? primaryColor : Color.clear, lineWidth: 3)
                                    )
                                    .overlay(
                                        selectedIndex == index ?
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(primaryColor)
                                            .background(Circle().fill(.white))
                                            .offset(x: 25, y: -40)
                                        : nil
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 确认按钮
                Button {
                    if selectedIndex < frames.count {
                        onSelect(frames[selectedIndex])
                    }
                } label: {
                    Text(NSLocalizedString("使用此封面", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(primaryColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .themedNavigationBarWithActions(
                title: NSLocalizedString("选择封面", comment: ""),
                onCancel: { dismiss() },
                onSave: {
                    if selectedIndex < frames.count {
                        onSelect(frames[selectedIndex])
                    }
                }
            )
        }
    }
}

// MARK: - 位置输入视图
struct LocationInputView: View {
    @Binding var locationName: String
    let onConfirm: () -> Void
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText = ""
    
    // 常用位置建议
    private let suggestions = [
        NSLocalizedString("家里", comment: ""), NSLocalizedString("公司", comment: ""), NSLocalizedString("公园", comment: ""), NSLocalizedString("宠物店", comment: ""), NSLocalizedString("宠物医院", comment: ""), NSLocalizedString("小区", comment: ""), NSLocalizedString("学校", comment: ""), NSLocalizedString("商场", comment: "")
    ]
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("输入位置名称", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField(NSLocalizedString("例如：北京市朝阳区xxx小区", comment: ""), text: $inputText)
                        .padding()
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // 快捷选择
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("快捷选择", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    inputText = suggestion
                                } label: {
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(inputText == suggestion ? primaryColor.opacity(0.15) : Color(uiColor: .systemGray6))
                                        .foregroundColor(inputText == suggestion ? primaryColor : .primary)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // 确认按钮
                Button {
                    locationName = inputText
                    onConfirm()
                } label: {
                    Text(NSLocalizedString("确认", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!inputText.isEmpty ? primaryColor : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(inputText.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .themedNavigationBarWithActions(
                title: NSLocalizedString("输入位置", comment: ""),
                onCancel: { dismiss() },
                onSave: {
                    locationName = inputText
                    onConfirm()
                },
                saveDisabled: inputText.isEmpty
            )
        }
        .onAppear {
            inputText = locationName
        }
    }
}

// MARK: - 寻鸟发帖视图
struct CreateFindBirdPostView: View {
    struct SelectedImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var locationService = LocationService.shared
    
    @State private var birdName = ""
    @State private var birdSpecies = ""
    @State private var description = ""
    @State private var contactPhone = ""
    @State private var reward = ""
    @State private var isPosting = false
    @State private var showSuccess = false
    @State private var selectedImages: [SelectedImage] = []
    @State private var pickedImages: [UIImage] = []
    @State private var showImagePicker = false
    
    // 位置相关
    @State private var useCurrentLocation = true  // 使用当前定位还是手动输入
    @State private var customLocationName = ""  // 手动输入的位置名称
    @State private var showLocationPicker = false
    @State private var customLatitude: Double? = nil  // 手动选择的纬度
    @State private var customLongitude: Double? = nil  // 手动选择的经度
    
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    
    // 关联鸟儿
    @State private var selectedBirdId: Int64? = nil  // 关联的鸟儿ID
    @State private var myBirds: [Bird] = []  // 我的鸟儿列表
    
    // 品种选择（使用统一的 SpeciesPickerView）
    @State private var showSpeciesPicker = false
    @State private var weightMin: Double? = nil  // SpeciesPickerView 需要
    @State private var weightMax: Double? = nil  // SpeciesPickerView 需要
    
    let onPost: (ForumPost) -> Void
    let onBirdMarkedLost: ((Int64, String, String) -> Void)?  // 回调：标记鸟儿丢失 (birdId, lostDate, lostLocation)
    
    init(onPost: @escaping (ForumPost) -> Void, onBirdMarkedLost: ((Int64, String, String) -> Void)? = nil) {
        self.onPost = onPost
        self.onBirdMarkedLost = onBirdMarkedLost
    }
    
    private let urgentColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    @ObservedObject var themeManager = ThemeManager.shared
    
    // 移除 canPost 计算属性，改为点击时校验

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    imagePickerSection
                    birdAssociationSection
                    locationSection
                    birdInfoInputSection
                    contactSection
                    rewardSection
                    postButtonSection
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)  // 滑动时交互式收起键盘
            .onTapGesture { hideKeyboard() }  // 点击空白处收起键盘
            .themedNavigationBar(title: NSLocalizedString("寻鸟启事", comment: ""))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("发布", comment: "")) {
                        postFindBird()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeManager.shared.primaryColor)
                    .disabled(isPosting)
                }
            }
        }
        .alert(NSLocalizedString("发布成功", comment: ""), isPresented: $showSuccess) {
                Button(NSLocalizedString("确定", comment: "")) { dismiss() }
            } message: {
                Text(NSLocalizedString("寻鸟启事已发布，将推送给附近10公里内的鸟友", comment: ""))
            }
        .alert(NSLocalizedString("信息不完整", comment: ""), isPresented: $showValidationError) {
            Button(NSLocalizedString("知道了", comment: ""), role: .cancel) { }
        } message: {
            Text(validationErrorMessage)
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            for img in pickedImages {
                if selectedImages.count < 9 {
                    selectedImages.append(SelectedImage(image: img))
                }
            }
            pickedImages.removeAll()
        }) {
            ImagePicker(images: $pickedImages, maxCount: 9 - selectedImages.count)
        }
        .sheet(isPresented: $showLocationPicker) {
            MapLocationPickerView(useCurrentLocation: useCurrentLocation) { location in
                customLocationName = location.address
                customLatitude = location.coordinate.latitude
                customLongitude = location.coordinate.longitude
                showLocationPicker = false
            }
        }
        .onAppear {
            // 开始定位
            locationService.startLocating()
            // 加载我的鸟儿列表
            loadMyBirds()
        }
    }
    
    private func loadMyBirds() {
        Task {
            do {
                let birds = try await ApiService.shared.getMyBirds()
                await MainActor.run {
                    myBirds = birds
                }
            } catch {
                print("加载鸟儿列表失败: \(error)")
            }
        }
    }
    
    private func sectionTitle(_ title: String, required: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            if required {
                Text("*")
                    .foregroundColor(urgentColor)
            }
        }
    }
    
    // MARK: - 拆分的子视图
    
    @ViewBuilder
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(NSLocalizedString("鸟儿照片", comment: ""), required: true)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(selectedImages) { selectedImage in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: selectedImage.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Button {
                                if let index = selectedImages.firstIndex(where: { $0.id == selectedImage.id }) {
                                    selectedImages.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                    
                    if selectedImages.count < 9 {
                        Button {
                            showImagePicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title2)
                                Text(NSLocalizedString("添加照片", comment: ""))
                                    .font(.caption)
                            }
                            .foregroundColor(urgentColor)
                            .frame(width: 100, height: 100)
                            .background(urgentColor.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(urgentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }
                    }
                }
            }
            
            Text(NSLocalizedString("上传清晰的鸟儿照片，帮助大家识别", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var birdAssociationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionTitle(NSLocalizedString("关联我的鸟儿", comment: ""), required: false)
                Text(NSLocalizedString("可选", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if myBirds.isEmpty {
                Text(NSLocalizedString("暂无可关联的鸟儿", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button {
                            selectedBirdId = nil
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "nosign")
                                    .font(.title2)
                                    .foregroundColor(selectedBirdId == nil ? .white : .secondary)
                                Text(NSLocalizedString("不关联", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(selectedBirdId == nil ? .white : .secondary)
                            }
                            .frame(width: 80, height: 80)
                            .background(selectedBirdId == nil ? urgentColor : Color(uiColor: .systemGray6))
                            .cornerRadius(12)
                        }
                        
                        ForEach(myBirds) { bird in
                            birdSelectionButton(for: bird)
                        }
                    }
                }
            }
            
            Text(NSLocalizedString("关联后将自动标记该鸟儿为「丢失」状态", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func birdSelectionButton(for bird: Bird) -> some View {
        Button {
            selectedBirdId = bird.id
            birdName = bird.nickname
            birdSpecies = bird.species
        } label: {
            VStack(spacing: 8) {
                if let avatarUrl = bird.avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "bird.fill").font(.title2)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "bird.fill")
                        .font(.title2)
                        .foregroundColor(selectedBirdId == bird.id ? .white : urgentColor)
                }
                
                Text(bird.nickname)
                    .font(.caption)
                    .foregroundColor(selectedBirdId == bird.id ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 80)
            .background(selectedBirdId == bird.id ? urgentColor : Color(uiColor: .systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(NSLocalizedString("走失地点", comment: ""), required: true)
            
            HStack(spacing: 12) {
                Button {
                    useCurrentLocation = true
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text(NSLocalizedString("当前定位", comment: ""))
                    }
                    .font(.subheadline)
                    .foregroundColor(useCurrentLocation ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(useCurrentLocation ? urgentColor : Color(uiColor: .systemGray6))
                    .cornerRadius(20)
                }
                
                Button {
                    useCurrentLocation = false
                    showLocationPicker = true
                } label: {
                    HStack {
                        Image(systemName: "map")
                        Text(NSLocalizedString("手动选择", comment: ""))
                    }
                    .font(.subheadline)
                    .foregroundColor(!useCurrentLocation ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(!useCurrentLocation ? urgentColor : Color(uiColor: .systemGray6))
                    .cornerRadius(20)
                }
            }
            
            locationDisplayRow
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var locationDisplayRow: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(urgentColor)
            
            if useCurrentLocation {
                if locationService.isLocating {
                    ProgressView().scaleEffect(0.8)
                    Text(NSLocalizedString("正在获取位置...", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let error = locationService.locationError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                } else {
                    Text(locationService.fullAddress.isEmpty ? NSLocalizedString("无法获取位置", comment: "") : locationService.fullAddress)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            } else {
                Text(customLocationName.isEmpty ? NSLocalizedString("请选择位置", comment: "") : customLocationName)
                    .font(.subheadline)
                    .foregroundColor(customLocationName.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var birdInfoInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(NSLocalizedString("鸟儿信息", comment: ""), required: true)
            
            inputField(title: NSLocalizedString("鸟儿名字", comment: ""), placeholder: NSLocalizedString("如：小黄", comment: ""), text: $birdName, required: true)
            
            speciesPickerField
            descriptionField
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var speciesPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(NSLocalizedString("鸟儿品种", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("*")
                    .font(.subheadline)
                    .foregroundColor(urgentColor)
            }
            
            Button {
                showSpeciesPicker = true
            } label: {
                HStack {
                    Text(birdSpecies.isEmpty ? NSLocalizedString("点击选择品种", comment: "") : birdSpecies)
                        .foregroundColor(birdSpecies.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .padding(12)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showSpeciesPicker) {
            SpeciesPickerView(
                selectedSpecies: $birdSpecies,
                weightMin: $weightMin,
                weightMax: $weightMax
            )
        }
    }
    
    @ViewBuilder
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(NSLocalizedString("外观特征", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("*")
                    .font(.subheadline)
                    .foregroundColor(urgentColor)
            }
            
            TextEditor(text: $description)
                .frame(minHeight: 100)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
                .overlay(
                    Group {
                        if description.isEmpty {
                            Text(NSLocalizedString("描述鸟儿的颜色、体型、特殊标记等特征...", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.leading, 14)
                                .padding(.top, 18)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
    
    @ViewBuilder
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(NSLocalizedString("联系方式", comment: ""), required: true)
            
            inputField(title: NSLocalizedString("联系电话", comment: ""), placeholder: NSLocalizedString("方便鸟友联系您", comment: ""), text: $contactPhone, keyboardType: .phonePad, required: true)
            
            Text(NSLocalizedString("电话将部分隐藏显示，保护您的隐私", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var rewardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionTitle(NSLocalizedString("悬赏金额", comment: ""), required: false)
                Text(NSLocalizedString("可选", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("¥")
                    .font(.title3)
                    .foregroundColor(.secondary)
                TextField(NSLocalizedString("输入金额", comment: ""), text: $reward)
                    .font(.title3)
                    .keyboardType(.numberPad)
            }
            .padding(12)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(10)
            
            Text(NSLocalizedString("设置悬赏可以提高帖子曝光度和响应速度", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var postButtonSection: some View {
        Button {
            postFindBird()
        } label: {
            HStack {
                if isPosting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "megaphone.fill")
                    Text(NSLocalizedString("立即发布寻鸟启事", comment: ""))
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(urgentColor)
            .cornerRadius(14)
        }
        .disabled(isPosting)
    }
    
    private func inputField(title: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, required: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if required {
                    Text("*")
                        .font(.subheadline)
                        .foregroundColor(urgentColor)
                }
            }
            
            TextField(placeholder, text: text)
                .font(.subheadline)
                .padding(12)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
                .keyboardType(keyboardType)
        }
    }
    
    private func postFindBird() {
        // 校验必填项
        var missingFields: [String] = []
        
        // 1. 校验图片
        if selectedImages.isEmpty {
            missingFields.append(NSLocalizedString("鸟儿照片 (至少一张)", comment: ""))
        }
        
        // 2. 校验位置
        var hasLocation = false
        if useCurrentLocation {
            hasLocation = !locationService.fullAddress.isEmpty && locationService.locationError == nil
        } else {
            hasLocation = !customLocationName.isEmpty
        }
        if !hasLocation {
            missingFields.append(NSLocalizedString("走失地点", comment: ""))
        }
        
        // 3. 校验鸟儿信息
        if birdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missingFields.append(NSLocalizedString("鸟儿名字", comment: ""))
        }
        
        if birdSpecies.isEmpty {
            missingFields.append(NSLocalizedString("鸟儿品种", comment: ""))
        }
        
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missingFields.append(NSLocalizedString("外观特征", comment: ""))
        }
        
        // 4. 校验联系方式
        if contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missingFields.append(NSLocalizedString("联系电话", comment: ""))
        }
        
        if !missingFields.isEmpty {
            validationErrorMessage = NSLocalizedString("请完善以下必填信息：\n\n", comment: "") + missingFields.map { "• " + $0 }.joined(separator: "\n")
            showValidationError = true
            return
        }
        
        isPosting = true
        
        // 获取位置信息
        let lostLocationText = useCurrentLocation ? locationService.fullAddress : customLocationName
        let rewardText = reward.isEmpty ? nil : String(format: NSLocalizedString("%@元", comment: ""), reward)
        
        Task {
            do {
                // 先上传图片到OSS并压缩图片
                var imageUrls: [String] = []
                for selectedImg in selectedImages {
                    let maxSizeBytes = 10 * 1024 * 1024 // 10MB max size
                    let compressedImage = compressImage(selectedImg.image, maxSizeBytes: maxSizeBytes) ?? selectedImg.image
                    let url = try await ApiService.shared.uploadPostImage(image: compressedImage)
                    imageUrls.append(url)
                }
                
                // 调用后端API创建帖子
                let lat = useCurrentLocation ? locationService.currentLocation?.coordinate.latitude : customLatitude
                let lng = useCurrentLocation ? locationService.currentLocation?.coordinate.longitude : customLongitude
                
                let postDTO = try await ApiService.shared.createPost(
                    content: description,
                    postType: "FIND_BIRD",
                    images: imageUrls,
                    latitude: lat,
                    longitude: lng,
                    locationName: lostLocationText,
                    birdId: selectedBirdId,
                    birdName: birdName,
                    birdSpecies: birdSpecies,
                    lostLocation: lostLocationText,
                    contactPhone: contactPhone,
                    reward: rewardText
                )
                
                // 转换为ForumPost并回调
                let newPost = ForumPost.from(dto: postDTO)
                
                await MainActor.run {
                    onPost(newPost)
                    // 同时更新「我的帖子」列表，确保在 Profile 页面能立即看到新帖子
                    SocialService.shared.insertNewPost(postDTO)
                    
                    // 如果关联了鸟儿，标记为丢失状态
                    if let birdId = selectedBirdId {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let lostDateStr = dateFormatter.string(from: Date())
                        onBirdMarkedLost?(birdId, lostDateStr, lostLocationText)
                    }
                    
                    isPosting = false
                    showSuccess = true
                }
            } catch {
                print("❌ 发布寻鸟帖子失败: \(error)")
                await MainActor.run {
                    isPosting = false
                    validationErrorMessage = String(format: NSLocalizedString("发布失败：%@", comment: ""), error.localizedDescription)
                    showValidationError = true
                }
            }
        }
    }
    
    // P1-02: 寻鸟帖子图片压缩函数
    private func compressImage(_ image: UIImage, maxSizeBytes: Int) -> UIImage? {
        var compression: CGFloat = 1.0
        let minCompression: CGFloat = 0.1
        let step: CGFloat = 0.1
        
        // 首先尝试降低JPEG质量
        while compression > minCompression {
            if let data = image.jpegData(compressionQuality: compression) {
                if data.count <= maxSizeBytes {
                    return UIImage(data: data) ?? image
                }
            }
            compression -= step
        }
        
        // 如果还是太大，缩小尺寸
        var scale: CGFloat = 1.0
        var currentImage = image
        
        while scale > 0.1 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                
                if let data = resizedImage.jpegData(compressionQuality: 0.7) {
                    if data.count <= maxSizeBytes {
                        return resizedImage
                    }
                }
                currentImage = resizedImage
            } else {
                UIGraphicsEndImageContext()
            }
            scale -= 0.1
        }
        
        return currentImage
    }
}

// MARK: - 可缩放的全屏图片查看器
struct ZoomableImageViewer: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // 黑色背景
            Color.black.ignoresSafeArea()
            
            // 图片轮播
            TabView(selection: $selectedIndex) {
                ForEach(images.indices, id: \.self) { index in
                    ZoomableImage(imageUrl: images[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            
            // 关闭按钮
            VStack {
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(.leading, 16)
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // 图片计数
                    if images.count > 1 {
                        Text("\(selectedIndex + 1) / \(images.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                            .padding(.trailing, 16)
                            .padding(.top, 50)
                    }
                }
                Spacer()
            }
        }
        .statusBar(hidden: true)
    }
}

// 单张可缩放图片
struct ZoomableImage: View {
    let imageUrl: String
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            if let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = min(max(newScale, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale <= 1.0 {
                                            withAnimation(.spring()) {
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .gesture(
                                // 只在放大时启用拖拽手势，避免阻止TabView滑动切换
                                scale > 1.0 ?
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                                : nil
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                        lastScale = 2.5
                                    }
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.5))
                            Text(NSLocalizedString("图片加载失败", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    case .empty:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
}

// MARK: - 毛玻璃效果组件
struct VisualEffectBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - 举报类型枚举
enum ReportType: String, CaseIterable, Identifiable {
    case spam = "SPAM"
    case inappropriate = "INAPPROPRIATE"
    case harassment = "HARASSMENT"
    case fraud = "FRAUD"
    case violence = "VIOLENCE"
    case copyright = "COPYRIGHT"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .spam: return NSLocalizedString("垃圾广告", comment: "")
        case .inappropriate: return NSLocalizedString("不当内容", comment: "")
        case .harassment: return NSLocalizedString("骚扰辱骂", comment: "")
        case .fraud: return NSLocalizedString("虚假信息/诈骗", comment: "")
        case .violence: return NSLocalizedString("暴力血腥", comment: "")
        case .copyright: return NSLocalizedString("侵权内容", comment: "")
        case .other: return NSLocalizedString("其他", comment: "")
        }
    }
    
    var description: String {
        switch self {
        case .spam: return NSLocalizedString("垃圾广告或营销信息", comment: "")
        case .inappropriate: return NSLocalizedString("含有不当内容或违规信息", comment: "")
        case .harassment: return NSLocalizedString("言语骚扰或人身攻击", comment: "")
        case .fraud: return NSLocalizedString("虚假信息或疑似诈骗", comment: "")
        case .violence: return NSLocalizedString("含有暴力或血腥内容", comment: "")
        case .copyright: return NSLocalizedString("侵犯他人著作权或知识产权", comment: "")
        case .other: return NSLocalizedString("其他违规内容", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .spam: return "megaphone"
        case .inappropriate: return "exclamationmark.circle"
        case .harassment: return "person.2.slash"
        case .fraud: return "shield.slash"
        case .violence: return "bolt.slash"
        case .copyright: return "doc.badge.ellipsis"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - 举报帖子Sheet
struct ReportPostSheet: View {
    let post: ForumPost
    @Binding var selectedType: ReportType
    @Binding var description: String
    @Binding var isReporting: Bool
    let onSubmit: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 标题
                HStack {
                    Text(NSLocalizedString("举报帖子", comment: ""))
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                // 提示文字
                HStack {
                    Text(NSLocalizedString("请选择举报原因，我们会尽快处理", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // 举报类型列表
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(ReportType.allCases) { type in
                            ReportTypeRow(
                                type: type,
                                isSelected: selectedType == type,
                                onTap: { selectedType = type }
                            )
                        }
                        
                        // 补充说明
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("补充说明（可选）", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $description)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(uiColor: .systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                
                // 底部按钮
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Text(NSLocalizedString("取消", comment: ""))
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(uiColor: .systemGray5))
                                .cornerRadius(12)
                        }
                        
                        Button {
                            onSubmit()
                        } label: {
                            HStack(spacing: 8) {
                                if isReporting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isReporting ? NSLocalizedString("提交中...", comment: "") : NSLocalizedString("提交举报", comment: ""))
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeManager.primaryColor)
                            .cornerRadius(12)
                        }
                        .disabled(isReporting)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.adaptiveCard)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 举报类型行
struct ReportTypeRow: View {
    let type: ReportType
    let isSelected: Bool
    let onTap: () -> Void
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? themeManager.primaryColor : .secondary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? themeManager.primaryColor : Color.gray.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeManager.primaryColor.opacity(0.08) : Color(uiColor: .systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? themeManager.primaryColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
