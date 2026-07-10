import SwiftUI
import UserNotifications

// P0 修复（问题8）：统一视图状态枚举，避免状态竞争
enum BirdListViewState: Equatable {
    case loading           // 加载中（首次加载）
    case empty             // 无数据（空状态）
    case loaded            // 数据就绪
    case refreshing        // 刷新中（有数据时的刷新）
    case error(String)     // 错误状态
    
    static func == (lhs: BirdListViewState, rhs: BirdListViewState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.empty, .empty), (.loaded, .loaded), (.refreshing, .refreshing):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

struct BirdListView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var offlineService = OfflineDataService.shared
    @ObservedObject var expenseService = ExpenseService.shared
    @State private var birds: [Bird] = []
    @State private var logs: [BirdLog] = []
    @State private var localLogs: [LocalBirdLog] = []  // 本地离线日志
    @State private var reminders: [Reminder] = []
    
    // P0 修复（问题8）：使用统一的 ViewState 替代分散的状态变量
    @State private var viewState: BirdListViewState = .loading
    @State private var isLoading: Bool = false  // 保留兼容性，将逐步迁移
    @State private var errorMessage: String?
    
    // 当前选中的鸟ID，nil 表示未选中任何鸟
    @State private var selectedBirdId: Int64? = nil
    // P0 修复（问题9）：filteredLogs 缓存，避免在 body 中重复计算
    @State private var cachedFilteredLogs: [BirdLog] = []
    // 闪烁修复：缓存排序后的鸟列表，避免每次渲染重新计算
    @State private var cachedSortedBirds: [Bird] = []
    
    // 提醒相关
    @State private var showAddReminder: Bool = false
    @State private var editingReminder: Reminder? = nil
    // 登录提示
    @State private var showLoginSheet: Bool = false
    @State private var showAddBird: Bool = false
    // 支出相关
    @State private var showExpenseList: Bool = false
    @State private var showAddExpense: Bool = false
    
    // 日志编辑相关（右滑编辑功能）
    @State private var editingLog: BirdLog? = nil
    @State private var viewingLog: BirdLog? = nil  // 查看日志详情
    @State private var showDeleteLogAlert: Bool = false
    @State private var logToDelete: BirdLog? = nil
    
    // 同步冲突相关
    @State private var showSyncConflictAlert: Bool = false
    @State private var syncConflictMessage: String = ""

    @State private var navigateToAllBirds = false
    @State private var navigateToAllLogs = false
    @State private var navigateToWeightTrend = false
    @State private var navigateToCycleView = false  // 生理周期导航
    @State private var cycles: [BirdCycleRecord] = []  // 生理周期数据
    @State private var cycleCalendarSelectedDate: Date? = nil  // 日历选中日期
    @State private var selectedLostBird: Bird? = nil
    
    // 品种健康体重范围（用于体重趋势图）
    @State private var speciesWeightMin: Double? = nil
    @State private var speciesWeightMax: Double? = nil
    
    // 重举修复 #5: 添加 loadingTask 防止数据加载竞态条件
    @State private var loadingTask: Task<Void, Never>?
    
    // 修复首页鸟不显示问题: 添加首次加载完成标记，防止 onReceive 在首次渲染时触发重复加载
    @State private var hasCompletedInitialLoad = false
    
    // 重举修复 #9: 品种缓存移至 SpeciesDataService 单例，避免 View 重建时丢失
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // 离线/错误提示横幅（非阻塞）
                    if let errorMessage = errorMessage {
                        offlineErrorBanner(message: errorMessage)
                    }
                    
                    // 我的鸟舍 - 整个模块包裹在白色卡片内
                    sectionCard(title: NSLocalizedString("我的鸟舍", comment: ""), icon: "house.fill") {
                        navigateToAllBirds = true
                    } content: {
                        if birds.isEmpty {
                            Button {
                                if authService.isLoggedIn {
                                    showAddBird = true
                                } else {
                                    showLoginSheet = true
                                }
                            } label: {
                                emptyBirdContent
                            }
                            .buttonStyle(.plain)
                        } else {
                            birdCards
                        }
                    }

                    // 日志 - 整个模块包裹在白色卡片内
                    sectionCard(title: NSLocalizedString("日志", comment: ""), icon: "book.fill") {
                        navigateToAllLogs = true
                    } content: {
                        logsContent
                    }

                    // 体重趋势 - 整个模块包裹在白色卡片内
                    sectionCard(title: L10n.weightRecord, icon: "chart.line.uptrend.xyaxis") {
                        navigateToWeightTrend = true
                    } content: {
                        weightTrendContent
                    }
                    
                    // 记录（产蛋、洗澡）- 整个模块包裹在白色卡片内
                    sectionCard(title: L10n.healthRecords, icon: "calendar") {
                        navigateToCycleView = true
                    } content: {
                        cycleCalendarContent
                    }
                    
                    // 支出管理 - 整个模块包裹在白色卡片内
                    sectionCard(title: L10n.expense, icon: "yensign.circle.fill") {
                        showExpenseList = true
                    } content: {
                        expenseContent
                    }

                    // 近期提醒 - 整个模块包裹在白色卡片内
                    sectionCardWithAdd(title: NSLocalizedString("近期提醒", comment: ""), icon: "bell.fill") {
                        showAddReminder = true
                    } content: {
                        remindersContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .refreshable {
                await loadDataAsync()
            }
            
            // 首次加载时的加载指示器（覆盖层，不阻塞 UI 结构）
            if isLoading && birds.isEmpty {
                VStack {
                    ProgressView(L10n.loading)
                        .padding(20)
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
            }
        }
        .background(themeManager.pageBackgroundGradient)
        .task {
            // 只在首次加载时调用，避免重复加载
            await loadOnAppearIfNeeded()
            await expenseService.refresh()  // 获取支出列表和统计
            // 初始加载周期数据
            if let birdId = selectedBirdId {
                loadCyclesForBird(birdId)
            }
        }
        .onChange(of: authService.isLoggedIn) { _ in
            // 登录状态改变时重新加载数据
            Task {
                await loadDataAsync()
                await expenseService.refresh()  // 获取支出列表和统计
            }
        }
        .onChange(of: selectedBirdId) { newBirdId in
            // 当选中鸟变化时，加载该品种的体重范围
            loadSpeciesWeightRangeForBird()
            // P0 修复（问题9）：异步更新 filteredLogs 缓存，避免在 body 中重复计算
            updateCachedFilteredLogs()
            // 加载周期数据
            if let birdId = newBirdId {
                loadCyclesForBird(birdId)
            } else {
                cycles = []
            }
        }
        .onChange(of: logs.count) { _ in
            // P0 修复（问题9）：日志数据变化时更新缓存
            updateCachedFilteredLogs()
        }
        .onChange(of: localLogs.count) { _ in
            // P0 修复（问题9）：本地日志变化时更新缓存
            updateCachedFilteredLogs()
        }
        .onChange(of: birds.count) { _ in
            // 闪烁修复：鸟儿数量变化时更新排序缓存
            updateCachedSortedBirds()
            // 安全检查：如果选中的鸟已被删除，自动取消选中
            if let selectedId = selectedBirdId, !birds.contains(where: { $0.id == selectedId }) {
                selectedBirdId = nil
            }
        }
        .navigationDestination(isPresented: $showAddReminder) {
            ReminderFormView { title, time, repeatDays in
                addReminder(title: title, time: time, repeatDays: repeatDays)
            }
            .hidesTabBar()
        }
        .navigationDestination(item: $editingReminder) { reminder in
            ReminderFormView(editingReminder: reminder) { title, time, repeatDays in
                updateReminder(reminder, title: title, time: time, repeatDays: repeatDays)
            }
            .hidesTabBar()
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .navigationDestination(isPresented: $showAddBird) {
            AddBirdView()
                .hidesTabBar()
        }
        .navigationDestination(isPresented: $navigateToAllBirds) {
            AllBirdsView()
        }
        .navigationDestination(isPresented: $navigateToAllLogs) {
            AllLogsView()
        }
        .navigationDestination(isPresented: $navigateToWeightTrend) {
            WeightTrendFullView()
        }
        .navigationDestination(isPresented: $navigateToCycleView) {
            CycleFullView()
        }
        .navigationDestination(item: $selectedLostBird) { bird in
            LostBirdView(bird: bird) {
                // 找到鸟儿后的回调
                markBirdAsFound(bird)
            }
            .hidesTabBar()
        }
        .navigationDestination(isPresented: $showExpenseList) {
            ExpenseListView()
        }
        .navigationDestination(isPresented: $showAddExpense) {
            AddExpenseView()
        }
        // 新增：日志编辑跳转
        .navigationDestination(item: $editingLog) { log in
            EditLogView(log: log) { updatedLog in
                // 立即更新本地数据，无需等待网络请求
                Task { @MainActor in
                    if let index = logs.firstIndex(where: { $0.id == updatedLog.id }) {
                        logs[index] = updatedLog
                        updateCachedFilteredLogs()
                    }
                    // 后台静默刷新确保一致性
                    await loadDataAsync()
                }
            }
            .hidesTabBar()
        }
        // 新增：日志详情查看
        .navigationDestination(item: $viewingLog) { log in
            LogDetailView(
                log: log,
                onEdit: { updatedLog in
                    // 编辑后更新本地数据
                    Task { @MainActor in
                        if let index = logs.firstIndex(where: { $0.id == updatedLog.id }) {
                            logs[index] = updatedLog
                            updateCachedFilteredLogs()
                        }
                        await loadDataAsync()
                    }
                },
                onDelete: {
                    // 删除日志
                    deleteLog(log)
                }
            )
            .hidesTabBar()
        }
        // 新增：日志删除确认弹窗
        .alert(NSLocalizedString("确认删除日志？", comment: ""), isPresented: $showDeleteLogAlert, presenting: logToDelete) { log in
            Button(L10n.delete, role: .destructive) {
                deleteLog(log)
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: { log in
            Text(NSLocalizedString("删除后无法恢复，确定要删除这条日志吗？", comment: ""))
        }

        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBirds"))) { _ in
            // 收到刷新通知时重新加载数据
            Task {
                await loadDataAsync()
            }
        }
        .onReceive(offlineService.$pendingSyncCount) { _ in
            // 待同步数量变化时刷新本地日志列表
            localLogs = offlineService.localLogs
        }
        .onReceive(offlineService.$isSyncing) { syncing in
            // 同步完成后刷新数据（只有在首次加载完成后才响应）
            if !syncing && hasCompletedInitialLoad {
                Task {
                    await loadDataAsync()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SyncConflictDetected"))) { notification in
            // 收到同步冲突通知时显示提示
            if let nickname = notification.userInfo?["nickname"] as? String {
                syncConflictMessage = "「\(nickname)」的数据已被其他设备修改，请下拉刷新获取最新数据"
                showSyncConflictAlert = true
            }
        }
        .alert(NSLocalizedString("同步冲突", comment: ""), isPresented: $showSyncConflictAlert) {
            Button(NSLocalizedString("刷新数据", comment: "")) {
                Task { await loadDataAsync() }
            }
            Button(NSLocalizedString("稍后处理", comment: ""), role: .cancel) { }
        } message: {
            Text(syncConflictMessage)
        }
    }
    
    // 标记鸟儿已找到
    private func markBirdAsFound(_ bird: Bird) {
        // 先保存原始状态以便回滚
        guard let index = birds.firstIndex(where: { $0.id == bird.id }) else { return }
        let originalBird = birds[index]
        
        // 乐观更新本地数据
        var updatedBird = originalBird
        updatedBird.isLost = false
        updatedBird.lostDate = nil
        updatedBird.lostLocation = nil
        updatedBird.lostPostId = nil
        birds[index] = updatedBird
        
        // 闪烁修复：更新后刷新缓存
        updateCachedSortedBirds()
        
        // 调用后端API更新鸟儿状态
        Task {
            do {
                try await ApiService.shared.updateBirdLostStatus(birdId: bird.id, isLost: false)
                print("✅ 鸟儿 \(bird.nickname) 已标记为找到")
            } catch {
                // API 失败：回滚状态
                await MainActor.run {
                    if let idx = birds.firstIndex(where: { $0.id == bird.id }) {
                        birds[idx] = originalBird
                        updateCachedSortedBirds()
                    }
                    ToastManager.shared.showError(NSLocalizedString("操作失败，请检查网络后重试", comment: ""))
                }
                print("❌ 更新鸟儿状态失败: \(error)")
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
    }
    
    private func sectionHeaderWithAction<Action: View>(title: String, @ViewBuilder action: () -> Action) -> some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            action()
        }
    }
    
    // MARK: - 统一的模块卡片组件（标题在卡片内）
    
    // MARK: - 统一的模块卡片组件（标题在卡片内）
    
    /// 带标题的模块卡片，整个卡片可点击跳转
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        onTitleTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: onTitleTap) {
            VStack(alignment: .leading, spacing: 16) {
                // 标题行
                HStack(spacing: 12) {
                    // 图标背景
                    ZStack {
                        Circle()
                            .fill(themeManager.primaryColor.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.primaryColor)
                    }
                    
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                // 内容区域
                content()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.adaptiveCard)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(CardButtonStyle())
    }
    
    /// 卡片按钮样式 - 点击时有轻微缩放反馈
    private struct CardButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        }
    }
    
    /// 带添加按钮的模块卡片
    private func sectionCardWithAdd<Content: View>(
        title: String,
        icon: String,
        onAddTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行带添加按钮
            HStack(spacing: 12) {
                // 图标背景
                ZStack {
                    Circle()
                        .fill(themeManager.primaryColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.primaryColor)
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onAddTap) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(themeManager.primaryColor)
                                .shadow(color: themeManager.primaryColor.opacity(0.4), radius: 4, x: 0, y: 2)
                        )
                }
            }
            
            // 内容区域
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.adaptiveCard)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
        )
    }
    
    // 错误提示横幅（非阻塞）- 高级设计
    private func offlineErrorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            // 图标容器
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "wifi.slash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("网络连接失败", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(NSLocalizedString("下拉刷新重试", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                Task { await loadDataAsync() }
            } label: {
                Text(L10n.retry)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(themeManager.primaryColor)
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.adaptiveCard)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    // 空状态内容（简化版，用于卡片内）
    private var emptyBirdContent: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeManager.primaryColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: authService.isLoggedIn ? "plus" : "person.crop.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(themeManager.primaryColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(authService.isLoggedIn ? NSLocalizedString("还没有任何鸟档案", comment: "") : NSLocalizedString("登录后管理你的小鸟", comment: ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text(authService.isLoggedIn ? NSLocalizedString("点击添加你的第一只鸟", comment: "") : NSLocalizedString("登录后添加小鸟、记录日志", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 8)
    }

    private var birdCards: some View {
        // 闪烁修复：使用缓存的排序鸟列表，避免每次渲染重新计算导致闪烁
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(cachedSortedBirds, id: \.id) { bird in
                    BirdCardView(
                        themeManager: themeManager,
                        bird: bird,
                        isSelected: selectedBirdId == bird.id,
                        onTap: {
                            // 如果是丢失的鸟儿，打开丢失模式视图
                            if bird.isLost == true {
                                selectedLostBird = bird
                            } else {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if selectedBirdId == bird.id {
                                        // 再次点击同一只鸟，取消选中
                                        selectedBirdId = nil
                                    } else {
                                        selectedBirdId = bird.id
                                    }
                                }
                            }
                        },
                        onMarkFound: bird.isLost == true ? {
                            // 长按标记找到
                            markBirdAsFound(bird)
                        } : nil
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .frame(height: 165)
    }
    
    // 独立的鸟卡片视图组件（重新设计版本）
    private struct BirdCardView: View {
        @ObservedObject var themeManager: ThemeManager
        let bird: Bird
        let isSelected: Bool
        let onTap: () -> Void
        let onMarkFound: (() -> Void)?  // 长按标记找到的回调
        
        @State private var showFoundAlert = false  // 显示找到确认弹窗
        
        private let cardWidth: CGFloat = 120
        private let cardHeight: CGFloat = 150
        
        // 计算年龄文本（优先使用 ageMonths，否则从日期计算）
        private var calculatedAgeText: String {
            // 如果已故，强制根据死亡日期计算寿命
            if bird.isDead, let deathDate = bird.deathDate {
                let birthDate: Date?
                if bird.birthdayType == "ADOPTION" {
                    birthDate = bird.adoptionDate
                } else {
                    birthDate = bird.hatchDate
                }
                
                guard let start = birthDate else { return "" }
                
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day], from: start, to: deathDate)
                
                if let years = components.year, years >= 1 {
                    if let months = components.month, months > 0 {
                        return "\(years)岁\(months)个月"
                    }
                    return "\(years)岁"
                } else if let months = components.month, months > 0 {
                    return "\(months)个月"
                } else if let days = components.day {
                    return "\(max(1, days))天"
                }
                return ""
            }
            
            // 首先尝试使用 ageMonths
            if !bird.ageText.isEmpty {
                return bird.ageText
            }
            
            // 如果 ageMonths 为空，尝试从日期计算
            // 优先根据 birthdayType，如果没有则尝试 hatchDate，再没有则 adoptionDate
            var date: Date?
            if bird.birthdayType == "ADOPTION" {
                date = bird.adoptionDate ?? bird.hatchDate
            } else {
                date = bird.hatchDate ?? bird.adoptionDate
            }
            
            guard let birthDate = date else { return NSLocalizedString("无生日数据", comment: "") }
            
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: now)
            
            if let years = components.year, years >= 1 {
                if let months = components.month, months > 0 {
                    return "\(years)岁\(months)个月"
                }
                return "\(years)岁"
            } else if let months = components.month, months > 0 {
                return "\(months)个月"
            } else if let days = components.day, days > 0 {
                return "\(days)天"
            } else {
                return NSLocalizedString("刚出生", comment: "")
            }
        }
        
        private var defaultBirdIcon: some View {
            ZStack {
                LinearGradient(
                    colors: themeManager.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Image("bird")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        
        var body: some View {
            Button(action: onTap) {
                ZStack {
                    // 背景：头像占满整个卡片
                    if let avatarUrl = bird.avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .saturation(bird.isDead ? 0.3 : 1.0)
                                    .opacity(bird.isDead ? 0.8 : 1.0)
                            default:
                                defaultBirdIcon
                            }
                        }
                    } else {
                        defaultBirdIcon
                    }
                    
                    // 渐变遮罩（让左上角文字更易读）
                    LinearGradient(
                        colors: [.black.opacity(0.45), .black.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // 状态遮罩
                    if bird.isDead {
                        Color.black.opacity(0.4)
                    } else if bird.isLost == true {
                        Color.black.opacity(0.35)
                    }
                    
                    // 状态图标（已故/走失）
                    if bird.isDead {
                        VStack(spacing: 4) {
                            Image(systemName: "cross.fill")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        }
                    } else if bird.isLost == true {
                        VStack(spacing: 4) {
                            Image(systemName: "heart.slash.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text(NSLocalizedString("走失", comment: ""))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // 文字信息层 - 左上角显示名字和年龄
                    VStack {
                        // 顶部信息
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                // 名字
                                HStack(spacing: 3) {
                                    Text(bird.nickname)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                                
                                // 年龄 - 显示在名字下方（所有状态都显示）
                                let ageStr = calculatedAgeText
                                if !ageStr.isEmpty {
                                    Text(ageStr)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 14)
                        .padding(.leading, 26)
                        .padding(.trailing, 10)
                        
                        Spacer()
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected ? themeManager.primaryColor : Color.clear,
                            lineWidth: isSelected ? 3 : 0
                        )
                )
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.25 : 0.12),
                    radius: isSelected ? 10 : 5,
                    x: 0,
                    y: isSelected ? 5 : 3
                )
                .scaleEffect(isSelected ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .contextMenu {
                // 只有丢失的鸟儿才显示"找到了"选项
                if bird.isLost == true {
                    Button {
                        showFoundAlert = true
                    } label: {
                        Label(NSLocalizedString("找到了！", comment: ""), systemImage: "checkmark.circle.fill")
                    }
                }
            }
            .alert(NSLocalizedString("确认找到", comment: ""), isPresented: $showFoundAlert) {
                Button(L10n.cancel, role: .cancel) { }
                Button(NSLocalizedString("确认找到", comment: "")) {
                    onMarkFound?()
                }
            } message: {
                Text("太好了！\(bird.nickname)回来了！\n确认后将取消丢失模式")
            }
        }
    }

    // 当前选中的鸟
    private var selectedBird: Bird? {
        guard let birdId = selectedBirdId else { return nil }
        return birds.first { $0.id == birdId }
    }
    
    // 根据选中的鸟过滤后的日志：未选中时显示全部日志，合并服务器日志和本地未同步日志
    // P0 重构：使用 HomeLogService 统一处理日志合并逻辑，避免与 AllLogsView 代码重复
    private var filteredLogs: [BirdLog] {
        // 使用 HomeLogService 合并服务器日志和本地未同步日志
        let mergedLogs = HomeLogService.shared.mergeLogsWithLocalData(
            serverLogs: logs,
            serverBirds: birds,
            localLogs: localLogs,
            localBirds: offlineService.localBirds
        )
        
        // 按选中的鸟过滤
        let birdFilteredLogs = HomeLogService.shared.filterLogs(mergedLogs, byBirdId: selectedBird?.id)
        
        // 过滤掉只有体重没有内容的日志（这些只显示在体重趋势中）
        return birdFilteredLogs.filter { $0.hasContent }
    }
    
    /// P0 修复（问题9）：更新缓存的 filteredLogs，在后台计算后更新到主线程
    private func updateCachedFilteredLogs() {
        // 直接同步更新，因为计算量不大且需要保持响应性
        cachedFilteredLogs = filteredLogs
    }
    
    /// 闪烁修复：更新缓存的排序鸟列表
    private func updateCachedSortedBirds() {
        // 已故的鸟放到后面，活着的在前
        cachedSortedBirds = birds.sorted { bird1, bird2 in
            if bird1.isDead != bird2.isDead {
                return !bird1.isDead
            }
            return bird1.id < bird2.id
        }
    }

    // MARK: - 日志预览

    @ViewBuilder
    private var logsContent: some View {
        // 闪烁修复：使用缓存的日志数据而非实时计算
        if cachedFilteredLogs.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "book")
                    .foregroundColor(Color.secondary)
                Text(NSLocalizedString("暂无日志记录", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            // 横向滚动日志卡片（点击查看详情）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(cachedFilteredLogs.prefix(10))) { log in
                        Button {
                            viewingLog = log  // 点击打开详情页，而不是编辑页
                        } label: {
                            LogCardRowView(log: log, themeManager: themeManager)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -20) // 抵消外层 padding，让卡片可以出血
            .padding(.horizontal, 20)  // 恢复内容 padding
        }
    }

    // 日志卡片组件（横向滚动）- 小红书/Instagram 风格
    private struct LogCardRowView: View {
        let log: BirdLog
        @ObservedObject var themeManager: ThemeManager
        
        // 卡片尺寸
        private let cardWidth: CGFloat = 180
        private let cardHeight: CGFloat = 220
        
        private var firstImageUrl: String? {
            log.imageUrls?.first
        }
        
        private var hasImage: Bool {
            firstImageUrl != nil
        }
        
        private var imageCount: Int {
            log.imageUrls?.count ?? 0
        }
        
        var body: some View {
            if hasImage {
                // 有图片：图片为主的卡片风格
                imageCardStyle
            } else {
                // 纯文字：简洁卡片风格
                textCardStyle
            }
        }
        
        // MARK: - 图片卡片样式（类似小红书）
        private var imageCardStyle: some View {
            ZStack(alignment: .bottom) {
                // 图片背景（全卡片）
                if let imageUrl = firstImageUrl, let url = URL(string: AppConfig.applyCDN(to: imageUrl)) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardWidth, height: cardHeight)
                                .clipped()
                        default:
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [themeManager.primaryColor.opacity(0.3), themeManager.primaryColor.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                }
                
                // 底部渐变遮罩 + 文字
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    
                    // 文字内容
                    if !log.summary.isEmpty {
                        Text(log.summary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    
                    // 底部信息行
                    HStack(spacing: 6) {
                        // 鸟名
                        Text(log.birdName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Circle()
                            .fill(.white.opacity(0.5))
                            .frame(width: 3, height: 3)
                        
                        // 时间
                        Text(formatLogTime(log.logDate))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        // 图片数量
                        if imageCount > 1 {
                            HStack(spacing: 2) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 10))
                                Text("\(imageCount)")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            // 待同步标记
            .overlay(alignment: .topTrailing) {
                if log.id < 0 {
                    syncingBadge
                }
            }
        }
        
        // MARK: - 纯文字卡片样式
        private var textCardStyle: some View {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部装饰线
                RoundedRectangle(cornerRadius: 2)
                    .fill(themeManager.primaryColor)
                    .frame(width: 30, height: 4)
                    .padding(.bottom, 10)
                
                // 文字内容
                Text(log.summary.isEmpty ? NSLocalizedString("无文字记录", comment: "") : log.summary)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(log.summary.isEmpty ? .secondary : .primary)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 8)
                
                // 底部固定信息区域
                VStack(alignment: .leading, spacing: 6) {
                    // 第一行：鸟名 + 时间
                    HStack(spacing: 6) {
                        // 鸟名标签
                        Text(log.birdName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(themeManager.primaryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(themeManager.primaryColor.opacity(0.12))
                            )
                        
                        Spacer()
                        
                        // 时间
                        Text(formatLogTime(log.logDate))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // 第二行：体重（始终显示，无体重时显示占位）
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 10))
                        if let weight = log.weight {
                            Text("\(String(format: "%.0f", weight))g")
                                .font(.system(size: 12, weight: .medium))
                        } else {
                            Text(NSLocalizedString("未记录", comment: ""))
                                .font(.system(size: 12))
                        }
                    }
                    .foregroundColor(log.weight != nil ? themeManager.primaryColor.opacity(0.8) : .secondary.opacity(0.5))
                }
            }
            .padding(14)
            .frame(width: cardWidth, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptiveCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.primaryColor.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            // 待同步标记
            .overlay(alignment: .topTrailing) {
                if log.id < 0 {
                    syncingBadge
                }
            }
        }
        
        // 同步中标记
        private var syncingBadge: some View {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(5)
                .background(
                    Circle()
                        .fill(Color.orange)
                )
                .padding(8)
        }
        
        private func formatLogTime(_ date: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.locale = Locale(identifier: "zh_CN")
            if abs(date.timeIntervalSinceNow) < 60 * 60 * 24 {
                return formatter.localizedString(for: date, relativeTo: Date())
            } else {
                let fmt = DateFormatter()
                fmt.dateFormat = "M/d"
                return fmt.string(from: date)
            }
        }
    }

    
    // 计算每天最新的体重数据点（按 id 最大为准）
    // 首页显示：最近 7 条记录，不受时间限制
    private var weightDisplayPoints: [(date: Date, weight: Double)] {
        guard let bird = selectedBird else { return [] }
        
        // 使用 birdId 匹配
        let sourceLogs = logs.filter { $0.birdId == bird.id }
        
        let logsWithWeight = sourceLogs.compactMap { log -> (id: Int64, date: Date, weight: Double)? in
            guard let w = log.weight else { return nil }
            return (log.id, log.logDate, w)
        }
        
        // 按日期分组，每组取 id 最大的那条
        var latestByDate: [String: (date: Date, weight: Double, id: Int64)] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for item in logsWithWeight {
            let key = dateFormatter.string(from: item.date)
            if let existing = latestByDate[key] {
                if item.id > existing.id {
                    latestByDate[key] = (item.date, item.weight, item.id)
                }
            } else {
                latestByDate[key] = (item.date, item.weight, item.id)
            }
        }
        
        // 首页显示：仅显示最近 7 天的数据，不包含更早的数据
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today)! // 包括今天共7天
        
        let result = latestByDate.values
            .filter { $0.date >= sevenDaysAgo } // 仅保留最近7天内的数据
            .sorted { $0.date < $1.date }       // 按日期升序排列
            .map { (date: $0.date, weight: $0.weight) }
        
        return result
    }
    
    // MARK: - 体重趋势预览

    @ViewBuilder
    private var weightTrendContent: some View {
        if !authService.isLoggedIn || selectedBird == nil {
            // 未登录或未选中状态
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color.secondary)
                Text(NSLocalizedString("请选择一只小鸟查看体重趋势", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            // 有数据状态 - 首页紧凑模式
            WeightTrendChartView(
                weightPoints: weightDisplayPoints,
                speciesWeightMin: speciesWeightMin,
                speciesWeightMax: speciesWeightMax,
                primaryColor: themeManager.primaryColor,
                timeRange: .week,
                showHeader: false,
                showCard: false,
                showLegend: false,
                isCompact: true,
                fixedDateRange: (
                    start: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                    end: Date()
                )
            )
        }
    }

    // MARK: - 近期提醒

    @ViewBuilder
    private var remindersContent: some View {
        if reminders.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .foregroundColor(Color.secondary)
                Text(NSLocalizedString("暂无提醒", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            // 按距离当前时间的差值排序：最近要响的在上面
            let now = Date()
            let sortedReminders = reminders.sorted { r1, r2 in
                let diff1 = timeUntilNextTrigger(r1.timeDescription, from: now)
                let diff2 = timeUntilNextTrigger(r2.timeDescription, from: now)
                return diff1 < diff2
            }
            
            // 简化显示：VStack 列表
            VStack(spacing: 8) {
                ForEach(sortedReminders.prefix(5)) { reminder in
                    ReminderRowView(
                        themeManager: themeManager,
                        reminder: reminder,
                        onTap: { editingReminder = reminder },
                        onToggle: { toggleReminderEnabled(reminder, enabled: $0) }
                    )
                }
            }
        }
    }
    
    // MARK: - 记录日历预览（产蛋、洗澡）
    
    @ViewBuilder
    private var cycleCalendarContent: some View {
        // 未登录或未选中任何鸟时显示提示
        if !authService.isLoggedIn || selectedBird == nil {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundColor(Color.secondary)
                Text(NSLocalizedString("请选择一只小鸟查看记录日历", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            // 显示日历，根据性别决定是否显示产蛋
            CycleCalendarView(
                cycles: cycles,
                showEggLaying: selectedBird?.gender == "FEMALE",
                selectedDate: $cycleCalendarSelectedDate
            )
            .frame(minHeight: cycles.isEmpty ? 80 : 280)
        }
    }
    
    private func loadCyclesForBird(_ birdId: Int64) {
        Task {
            do {
                cycles = try await ApiService.shared.getCycles(birdId: birdId)
            } catch {
                print("加载周期失败: \(error)")
                cycles = []
            }
        }
    }
    
    // MARK: - 支出预览卡片
    
    // 计算选中鸟的累计支出（包括多选关联的 + 本地未同步的）
    // P0 功能改进：多鸟支出按数量平均分摊
    private var selectedBirdExpense: Double {
        // 计算服务器支出
        var serverExpense = 0.0
        var localExpenseAmount = 0.0
        
        if let bird = selectedBird {
            // Bug #3 修复 + P0 分摊改进：优先用 birdId 筛选，兼容 birdName 匹配
            serverExpense = expenseService.expenses
                .compactMap { expense -> Double? in
                    // 检查是否匹配当前鸟
                    var isMatch = false
                    var birdCount = 1  // 该支出关联的鸟的数量
                    
                    // 优先使用 birdId 匹配（稳定，不受改名影响）
                    if let expenseBirdId = expense.birdId, expenseBirdId == bird.id {
                        isMatch = true
                        birdCount = 1  // 单选模式，只关联一只鸟
                    }
                    // 兼容旧数据：用 birdName 匹配（支持多选，用"、"分隔）
                    else if let birdName = expense.birdName {
                        let names = birdName.components(separatedBy: "、")
                        if names.contains(bird.nickname) {
                            isMatch = true
                            birdCount = names.count  // 多选模式，按鸟的数量分摊
                        }
                    }
                    
                    // 如果匹配，返回分摊后的金额
                    return isMatch ? expense.amount / Double(birdCount) : nil
                }
                .reduce(0, +)
            
            // P0 修复 + 分摊改进：本地未同步的支出也需要按鸟进行筛选并分摊
            localExpenseAmount = expenseService.localExpenses
                .compactMap { expense -> Double? in
                    guard expense.needsSync && !expense.isDeleted else { return nil }
                    
                    var isMatch = false
                    var birdCount = 1
                    
                    // 优先使用 birdId 匹配
                    if let expenseBirdId = expense.birdId, expenseBirdId == Int(bird.id) {
                        isMatch = true
                        birdCount = 1
                    }
                    // 兼容 birdName 匹配
                    else if let birdName = expense.birdName {
                        let names = birdName.components(separatedBy: "、")
                        if names.contains(bird.nickname) {
                            isMatch = true
                            birdCount = names.count
                        }
                    }
                    
                    return isMatch ? expense.amount / Double(birdCount) : nil
                }
                .reduce(0, +)
        } else {
            // 未选中鸟时显示总支出（不分摊）
            serverExpense = expenseService.totalExpense
            
            // 本地未同步的支出也计入总额
            localExpenseAmount = expenseService.localExpenses
                .filter { $0.needsSync && !$0.isDeleted }
                .reduce(0) { $0 + $1.amount }
        }
        
        return serverExpense + localExpenseAmount
    }
    
    // 待同步支出数量
    private var pendingExpenseCount: Int {
        expenseService.localExpenses.filter { $0.needsSync && !$0.isDeleted }.count
    }
    @ViewBuilder
    private var expenseContent: some View {
        if authService.isLoggedIn {
            // 已登录：显示支出数据
            HStack(spacing: 16) {
                if let bird = selectedBird {
                    // 选中鸟：左侧显示该鸟支出，右侧显示本月支出
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(bird.nickname)支出")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(ExpenseService.formatAmount(selectedBirdExpense))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(NSLocalizedString("本月", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(ExpenseService.formatAmount(expenseService.monthlyExpense))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                } else {
                    // 未选中鸟：显示本月支出（包含待同步）
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(NSLocalizedString("本月支出", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if pendingExpenseCount > 0 {
                                Text("📤\(pendingExpenseCount)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        Text("¥\(ExpenseService.formatAmount(expenseService.monthlyExpense))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryColor)
                    }
                    
                    Spacer()
                }
                
                // 添加按钮
                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.primaryColor)
                }
            }
        } else {
            // 未登录：显示暂无支出
            HStack(spacing: 10) {
                Image(systemName: "yensign.circle")
                    .foregroundColor(Color.secondary)
                Text(NSLocalizedString("暂无支出记录", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // 计算距离下次触发的时间（分钟）
    // FIX: 正确处理跨天和重复日期
    private func timeUntilNextTrigger(_ description: String, from now: Date) -> Int {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotalMinutes = currentHour * 60 + currentMinute
        let currentWeekday = calendar.component(.weekday, from: now)  // 1=周日, 2=周一...
        
        // 解析提醒时间 - 支持多种格式
        // 格式1: "每天 09:00"
        // 格式2: "周一周三 14:30"
        // 格式3: "09:00"
        let components = description.components(separatedBy: " ")
        guard let timeString = components.last else { return Int.max }
        let parts = timeString.components(separatedBy: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return Int.max }
        
        let reminderTotalMinutes = hour * 60 + minute
        
        // 解析重复日期
        var repeatWeekdays: [Int] = []
        if components.count > 1 {
            let daysPart = components[0]
            let weekdayMap: [String: Int] = [
                NSLocalizedString("周日", comment: ""): 1, NSLocalizedString("周一", comment: ""): 2, NSLocalizedString("周二", comment: ""): 3, NSLocalizedString("周三", comment: ""): 4,
                NSLocalizedString("周四", comment: ""): 5, NSLocalizedString("周五", comment: ""): 6, NSLocalizedString("周六", comment: ""): 7
            ]
            for (name, weekday) in weekdayMap {
                if daysPart.contains(name) {
                    repeatWeekdays.append(weekday)
                }
            }
            // "每天"表示所有日期
            if daysPart.contains(L10n.daily) {
                repeatWeekdays = [1, 2, 3, 4, 5, 6, 7]
            }
        }
        
        // 计算时间差
        var diff = reminderTotalMinutes - currentTotalMinutes
        
        // 如果有重复日期限制
        if !repeatWeekdays.isEmpty {
            // 检查今天是否在重复日期中
            if repeatWeekdays.contains(currentWeekday) {
                // 今天可以触发
                if diff < 0 {
                    // 今天时间已过，找下一个重复日
                    let daysUntilNext = findDaysUntilNextRepeat(from: currentWeekday, repeatDays: repeatWeekdays)
                    diff = daysUntilNext * 24 * 60 + reminderTotalMinutes - currentTotalMinutes
                    if reminderTotalMinutes <= currentTotalMinutes {
                        diff += 24 * 60
                    }
                }
            } else {
                // 今天不在重复日期中，找下一个重复日
                let daysUntilNext = findDaysUntilNextRepeat(from: currentWeekday, repeatDays: repeatWeekdays)
                diff = (daysUntilNext - 1) * 24 * 60 + (24 * 60 - currentTotalMinutes) + reminderTotalMinutes
            }
        } else {
            // 无重复限制，按普通逻辑处理
            if diff < 0 {
                diff += 24 * 60  // 时间已过，算到明天
            }
        }
        
        return diff
    }
    
    /// 找到从当前weekday到下一个重复日的天数
    private func findDaysUntilNextRepeat(from currentWeekday: Int, repeatDays: [Int]) -> Int {
        let sortedDays = repeatDays.sorted()
        
        // 找今天之后的第一个重复日
        for day in sortedDays {
            if day > currentWeekday {
                return day - currentWeekday
            }
        }
        
        // 没找到，回到下周第一个重复日
        if let firstDay = sortedDays.first {
            return 7 - currentWeekday + firstDay
        }
        
        return 7  // 默认一周后
    }
    
    // 提醒行视图 - 使用原生 swipeActions 实现稳定滑动删除
    private struct ReminderRowView: View {
        @ObservedObject var themeManager: ThemeManager
        let reminder: Reminder
        let onTap: () -> Void
        let onToggle: (Bool) -> Void
        
        var body: some View {
            HStack(spacing: 14) {
                // 提醒内容
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(reminder.enabled ? .primary : Color.gray)
                        .lineLimit(1)
                    Text(reminder.timeDescription)
                        .font(.system(size: 13))
                        .foregroundColor(reminder.enabled ? Color.secondary : Color.gray)
                }
                
                Spacer()
                
                // Toggle 开关
                Toggle("", isOn: Binding(
                    get: { reminder.enabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .tint(themeManager.primaryColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.adaptiveCard)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
    
    private func toggleReminderEnabled(_ reminder: Reminder, enabled: Bool) {
        Task {
            do {
                let updated = try await ApiService.shared.toggleReminder(id: reminder.id)
                await MainActor.run {
                    if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                        reminders[index] = updated
                    }
                    // 启用/禁用通知
                    if updated.enabled {
                        // 重新设置通知
                        if let time = parseTimeFromDescription(reminder.timeDescription) {
                            let repeatDays = parseRepeatDaysFromDescription(reminder.timeDescription)
                            scheduleNotifications(title: reminder.title, time: time, repeatDays: repeatDays, id: reminder.id)
                        }
                    } else {
                        cancelNotifications(id: reminder.id)
                    }
                }
            } catch {
                print("切换提醒状态失败: \(error)")
                await MainActor.run {
                    ToastManager.shared.showError(NSLocalizedString("切换提醒失败，请重试", comment: ""))
                }
            }
        }
    }
    
    // MARK: - 提醒操作
    
    private func addReminder(title: String, time: Date, repeatDays: RepeatDays) {
        let timeDescription = formatReminderTime(time: time, repeatDays: repeatDays)
        print("⏰ 添加提醒: \(title), 时间: \(timeDescription), 重复: \(repeatDays.displayText)")
        
        Task {
            do {
                let newReminder = try await ApiService.shared.createReminder(
                    title: title,
                    timeDescription: timeDescription,
                    reminderType: repeatDays.displayText,
                    enabled: true
                )
                print("✅ 提醒创建成功: ID=\(newReminder.id), 标题=\(newReminder.title)")
                await MainActor.run {
                    reminders.append(newReminder)
                    print("✅ 提醒已添加到列表，当前提醒数量: \(reminders.count)")
                    // 设置本地通知
                    scheduleNotifications(title: title, time: time, repeatDays: repeatDays, id: newReminder.id)
                }
            } catch {
                print("❌ 创建提醒失败: \(error)")
                await MainActor.run {
                    ToastManager.shared.showError(NSLocalizedString("创建提醒失败，请重试", comment: ""))
                }
            }
        }
    }
    
    private func updateReminder(_ reminder: Reminder, title: String, time: Date, repeatDays: RepeatDays) {
        let timeDescription = formatReminderTime(time: time, repeatDays: repeatDays)
        
        Task {
            do {
                let updated = try await ApiService.shared.updateReminder(
                    id: reminder.id,
                    title: title,
                    timeDescription: timeDescription,
                    reminderType: repeatDays.displayText,
                    enabled: reminder.enabled
                )
                await MainActor.run {
                    if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                        reminders[index] = updated
                    }
                    // 更新本地通知
                    cancelNotifications(id: reminder.id)
                    if reminder.enabled {
                        scheduleNotifications(title: title, time: time, repeatDays: repeatDays, id: reminder.id)
                    }
                }
            } catch {
                print("更新提醒失败: \(error)")
                await MainActor.run {
                    ToastManager.shared.showError(NSLocalizedString("更新提醒失败，请重试", comment: ""))
                }
            }
        }
    }
    
    private func deleteReminder(_ reminder: Reminder) {
        Task {
            do {
                try await ApiService.shared.deleteReminder(id: reminder.id)
                await MainActor.run {
                    withAnimation {
                        reminders.removeAll { $0.id == reminder.id }
                    }
                    // 取消本地通知
                    cancelNotifications(id: reminder.id)
                }
            } catch {
                print("删除提醒失败: \(error)")
                await MainActor.run {
                    ToastManager.shared.showError(NSLocalizedString("删除提醒失败，请重试", comment: ""))
                }
            }
        }
    }
    
    // 从 timeDescription 解析时间
    private func parseTimeFromDescription(_ description: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let components = description.components(separatedBy: " ")
        if let timeString = components.last, let date = formatter.date(from: timeString) {
            return date
        }
        return nil
    }
    
    // 从 timeDescription 解析重复日期
    private func parseRepeatDaysFromDescription(_ description: String) -> RepeatDays {
        var days = RepeatDays()
        if description.contains(L10n.daily) {
            days.sunday = true
            days.monday = true
            days.tuesday = true
            days.wednesday = true
            days.thursday = true
            days.friday = true
            days.saturday = true
        } else {
            if description.contains(NSLocalizedString("周日", comment: "")) { days.sunday = true }
            if description.contains(NSLocalizedString("周一", comment: "")) { days.monday = true }
            if description.contains(NSLocalizedString("周二", comment: "")) { days.tuesday = true }
            if description.contains(NSLocalizedString("周三", comment: "")) { days.wednesday = true }
            if description.contains(NSLocalizedString("周四", comment: "")) { days.thursday = true }
            if description.contains(NSLocalizedString("周五", comment: "")) { days.friday = true }
            if description.contains(NSLocalizedString("周六", comment: "")) { days.saturday = true }
        }
        return days
    }
    
    private func formatReminderTime(time: Date, repeatDays: RepeatDays) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: time)
        
        if repeatDays.isEmpty {
            return timeString  // 仅一次，只显示时间
        } else {
            return "\(repeatDays.displayText) \(timeString)"
        }
    }
    
    // MARK: - 本地通知
    
    private func scheduleNotifications(title: String, time: Date, repeatDays: RepeatDays, id: Int64) {
        Task {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: time)
            let minute = calendar.component(.minute, from: time)
            
            if repeatDays.isEmpty {
                // 仅一次：使用完整日期时间
                var notificationTime = time
                // 如果时间已过，设置为明天
                if time <= Date() {
                    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: time) {
                        notificationTime = tomorrow
                    }
                }
                
                do {
                    try await NotificationService.shared.scheduleReminder(
                        id: "reminder_\(id)_once",
                        title: NSLocalizedString("🔔 鸟王国提醒", comment: ""),
                        body: title,
                        date: notificationTime,
                        repeats: false
                    )
                    print("✅ 已设置一次性提醒: \(title) at \(notificationTime)")
                } catch {
                    print("❌ 设置提醒失败: \(error)")
                }
            } else {
                // 重复：为每个选中的星期几创建一个通知
                for weekday in repeatDays.selectedWeekdays {
                    // 计算下一个该星期几的日期
                    var dateComponents = DateComponents()
                    dateComponents.hour = hour
                    dateComponents.minute = minute
                    dateComponents.weekday = weekday
                    
                    if let nextDate = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .nextTime) {
                        do {
                            try await NotificationService.shared.scheduleReminder(
                                id: "reminder_\(id)_\(weekday)",
                                title: NSLocalizedString("🔔 鸟王国提醒", comment: ""),
                                body: title,
                                date: nextDate,
                                repeats: true
                            )
                            print("✅ 已设置重复提醒: \(title) on weekday \(weekday)")
                        } catch {
                            print("❌ 设置重复提醒失败: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func cancelNotifications(id: Int64) {
        // 取消所有可能的通知 ID
        var identifiers = ["reminder_\(id)_once"]
        for weekday in 1...7 {
            identifiers.append("reminder_\(id)_\(weekday)")
        }
        
        for identifier in identifiers {
            NotificationService.shared.cancelReminder(id: identifier)
        }
        print("❌ 已取消提醒 ID: \(id)")
    }
    
    /// 检查并自动禁用已过期的一次性提醒
    /// 如果提醒是不重复的（一次性），且提醒时间已过，则自动关闭开关
    private func checkAndDisableExpiredReminders() async {
        let now = Date()
        let calendar = Calendar.current
        
        for reminder in reminders {
            // 只处理启用状态的提醒
            guard reminder.enabled else { continue }
            
            // 解析重复日期
            let repeatDays = parseRepeatDaysFromDescription(reminder.timeDescription)
            
            // 跳过重复提醒（每日/每周重复的不需要自动禁用）
            guard repeatDays.isEmpty else { continue }
            
            // 解析提醒时间
            guard let reminderTime = parseTimeFromDescription(reminder.timeDescription) else { continue }
            
            // 获取今天的提醒时间
            let reminderHour = calendar.component(.hour, from: reminderTime)
            let reminderMinute = calendar.component(.minute, from: reminderTime)
            
            var todayReminderComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayReminderComponents.hour = reminderHour
            todayReminderComponents.minute = reminderMinute
            
            guard let todayReminderDate = calendar.date(from: todayReminderComponents) else { continue }
            
            // 如果今天的提醒时间已过，自动禁用该提醒
            if todayReminderDate < now {
                print("⏰ 检测到一次性提醒已过期: \(reminder.title), 自动禁用")
                
                // 调用API禁用提醒
                do {
                    let updated = try await ApiService.shared.toggleReminder(id: reminder.id)
                    await MainActor.run {
                        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                            reminders[index] = updated
                        }
                        // 取消本地通知
                        cancelNotifications(id: reminder.id)
                    }
                    print("✅ 已自动禁用过期提醒: \(reminder.title)")
                } catch {
                    print("❌ 自动禁用过期提醒失败: \(error)")
                }
            }
        }
    }

    // MARK: - 日志操作
    
    private func deleteLog(_ log: BirdLog) {
        // 检查是否是本地未同步日志（负数ID表示本地日志）
        if log.id <= 0 {
            // 本地日志：需要在 OfflineDataService 中标记为已删除
            let matchingLocalLog = offlineService.localLogs.first { localLog in
                let localIdHash = Int64(truncatingIfNeeded: localLog.localId.hashValue)
                let negativeId = localIdHash < 0 ? localIdHash : -abs(localIdHash)
                return negativeId == log.id
            }
            
            if let localLog = matchingLocalLog {
                offlineService.deleteLogByLocalId(localLog.localId)
                Task { @MainActor in
                    logs.removeAll { $0.id == log.id }
                    updateCachedFilteredLogs()
                    print("✅ 本地日志已删除: \(localLog.localId)")
                }
            } else {
                print("⚠️ 未找到对应的本地日志 ID: \(log.id)")
            }
            return
        }
        
        // 服务器日志：调用 API 删除
        Task {
            do {
                try await ApiService.shared.deleteLog(id: log.id)
                await MainActor.run {
                    // 从列表中移除
                    logs.removeAll { $0.id == log.id }
                    // 更新缓存
                    updateCachedFilteredLogs()
                    // 提示
                    print("✅ 日志已删除: \(log.id)")
                }
            } catch {
                print("❌ 删除日志失败: \(error)")
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadOnAppearIfNeeded() async {
        // 先从本地缓存快速加载，提升首屏速度
        if birds.isEmpty {
            let localBirds = offlineService.getAllBirds()
            if !localBirds.isEmpty {
                await MainActor.run {
                    self.birds = localBirds.map { localBird in
                        // Bug #5 修复：用 localId hash 或 serverId，避免所有离线鸟 ID 都为 0
                        let birdId: Int64 = if let serverId = localBird.serverId {
                            Int64(serverId)
                        } else {
                            Int64(abs(localBird.localId.hashValue) % Int.max)
                        }
                        return Bird(
                            id: birdId,
                            nickname: localBird.nickname,
                            species: localBird.species,
                            gender: localBird.gender,
                            featherColor: localBird.featherColor,
                            source: nil,
                            avatarUrl: localBird.avatarUrl,
                            notes: localBird.notes,
                            ageMonths: nil
                        )
                    }
                    // 闪烁修复：快速加载后立即更新缓存
                    updateCachedSortedBirds()
                    print("⚡ 快速加载本地缓存: \(self.birds.count) 只鸟儿")
                }
            }
        }
        
        // 后台从服务器刷新最新数据
        guard !isLoading else { return }
        await loadDataAsync()
        
        // 标记首次加载完成
        await MainActor.run {
            hasCompletedInitialLoad = true
        }
    }

    private func loadBirds() {
        Task {
            await loadDataAsync()
        }
    }

    /// 重举修复 #5: 加载数据时取消之前的请求，防止竞态条件
    private func loadDataAsync() async {
        // 重举修复 #5: 取消之前的加载任务，防止多个请求同时进行导致数据错乱
        loadingTask?.cancel()
        
        // 未登录时显示空数据
        guard authService.isLoggedIn else {
            await MainActor.run {
                self.birds = []
                self.logs = []
                self.localLogs = []
                self.reminders = []
                self.isLoading = false
                // 闪烁修复：清空时也更新缓存
                updateCachedSortedBirds()
                updateCachedFilteredLogs()
            }
            return
        }
        
        // 重举修复 #5: 创建新的加载任务并保存引用
        loadingTask = Task {
            await loadFromServer()
        }
        await loadingTask?.value
    }
    
    /// 加载选中鸟儿品种的健康体重范围（先显示缓存，后台刷新最新数据）
    /// 重举修复 #9: 使用 SpeciesDataService 单例管理缓存，避免 View 重建时丢失
    private func loadSpeciesWeightRangeForBird() {
        // 取消之前的加载任务（防抖）
        speciesLoadTask?.cancel()
        
        guard let bird = selectedBird else {
            speciesWeightMin = nil
            speciesWeightMax = nil
            return
        }
        
        let species = bird.species
        
        // 重举修复 #9: 使用 SpeciesDataService 单例缓存（会话期间持久化）
        // 1. 先用单例内存缓存快速显示
        if let cached = SpeciesDataService.shared.getCachedWeightRange(for: species) {
            speciesWeightMin = cached.min
            speciesWeightMax = cached.max
            // 不 return，继续后台刷新
        }
        // 2. 或用 Core Data 本地缓存显示（离线可用）
        else if let localRange = SpeciesDataService.shared.getWeightRange(for: species) {
            speciesWeightMin = localRange.min
            speciesWeightMax = localRange.max
            SpeciesDataService.shared.setCachedWeightRange(for: species, min: localRange.min, max: localRange.max)
            // 不 return，继续后台刷新
        }
        
        // 3. 后台从网络获取最新数据并更新缓存
        speciesLoadTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                if let speciesInfo = try await ApiService.shared.getSpeciesByName(species) {
                    await MainActor.run {
                        // 只有数据有变化时才更新（避免闪烁）
                        if speciesWeightMin != speciesInfo.weightMin || speciesWeightMax != speciesInfo.weightMax {
                            speciesWeightMin = speciesInfo.weightMin
                            speciesWeightMax = speciesInfo.weightMax
                            print("📊 体重范围已更新: \(species) = \(speciesInfo.weightMin)-\(speciesInfo.weightMax)g")
                        }
                        // 重举修复 #9: 更新单例缓存
                        SpeciesDataService.shared.setCachedWeightRange(for: species, min: speciesInfo.weightMin, max: speciesInfo.weightMax)
                        // 更新本地Core Data缓存
                        SpeciesDataService.shared.updateFromServer(speciesInfo)
                    }
                } else {
                    await MainActor.run {
                        // 网络返回 404，说明该品种没有健康范围数据
                        if speciesWeightMin == nil {
                            speciesWeightMin = nil
                            speciesWeightMax = nil
                        }
                    }
                }
            } catch {
                // 网络失败时保留已有缓存数据，不做任何操作
                print("📊 网络获取体重范围失败，使用缓存: \(error.localizedDescription)")
            }
        }
    }
    
    // 品种加载任务（用于防抖取消）
    @State private var speciesLoadTask: Task<Void, Never>?
    
    /// 加载鸟儿、日志等数据
    private func loadFromServer() async {
        isLoading = true
        errorMessage = nil
        
        // 如果离线，先加载本地数据
        if !offlineService.isOnline {
            await MainActor.run {
                // 从本地缓存加载鸟儿数据
                let localBirds = offlineService.getAllBirds()
                self.birds = localBirds.map { localBird in
                    Bird(
                        id: Int64(localBird.serverId ?? 0),
                        nickname: localBird.nickname,
                        species: localBird.species,
                        gender: localBird.gender,
                        hatchDate: localBird.hatchDate,
                        adoptionDate: localBird.adoptionDate,
                        birthdayType: localBird.birthdayType,
                        deathDate: localBird.deathDate,
                        featherColor: localBird.featherColor,
                        source: nil,
                        avatarUrl: localBird.avatarUrl,
                        notes: localBird.notes,
                        ageMonths: nil,
                        isLost: localBird.isLost,
                        lostDate: localBird.lostDate,
                        lostLocation: localBird.lostLocation
                    )
                }
                // 加载本地日志缓存
                self.localLogs = offlineService.localLogs
                self.isLoading = false
                // 闪烁修复：离线模式也更新缓存
                updateCachedSortedBirds()
                updateCachedFilteredLogs()
                print("📴 离线模式：加载了 \(self.birds.count) 只本地鸟儿，\(self.localLogs.count) 条本地日志")
            }
            return
        }
        
        // 独立加载每个数据源，防止一个失败导致全部失败
        var loadedBirds: [Bird] = []
        var loadedLogs: [BirdLog] = []
        var loadedReminders: [Reminder] = []
        
        // 加载鸟儿
        do {
            loadedBirds = try await ApiService.shared.getBirds()
            print("✅ 加载鸟儿成功: \(loadedBirds.count) 只")
        } catch {
            print("❌ 加载鸟儿失败: \(error)")
            if let decodingError = error as? DecodingError {
                Self.printDecodingError(decodingError, label: NSLocalizedString("鸟儿", comment: ""))
            }
        }
        
        // 加载日志
        do {
            loadedLogs = try await ApiService.shared.getLogs()
            print("✅ 加载日志成功: \(loadedLogs.count) 条")
        } catch {
            print("❌ 加载日志失败: \(error)")
            if let decodingError = error as? DecodingError {
                Self.printDecodingError(decodingError, label: NSLocalizedString("日志", comment: ""))
            }
        }
        
        // 加载提醒
        do {
            loadedReminders = try await ApiService.shared.getReminders()
            print("✅ 加载提醒成功: \(loadedReminders.count) 条")
        } catch {
            print("❌ 加载提醒失败: \(error)")
            if let decodingError = error as? DecodingError {
                Self.printDecodingError(decodingError, label: L10n.reminder)
            }
        }
        
        // 检查任务是否被取消，防止已取消的任务覆盖最新数据
        guard !Task.isCancelled else {
            print("⚠️ loadFromServer 任务被取消，跳过 UI 更新")
            return
        }
        
        // 更新UI：无论API是否返回数据，都需要更新状态（用户可能没有鸟）
        await MainActor.run {
            // Bug #1/#2 修复：合并服务器数据和本地待同步数据
            let serverBirdIds = Set(loadedBirds.map { Int($0.id) })
            
            let pendingLocalBirds = offlineService.getAllBirds()
                .filter { localBird in
                    if localBird.serverId == nil {
                        return true
                    }
                    return !serverBirdIds.contains(localBird.serverId!)
                }
                .map { localBird in
                    Bird(
                        id: localBird.serverId.map { Int64($0) } ?? Int64(abs(localBird.localId.hashValue) % Int.max),
                        nickname: localBird.nickname,
                        species: localBird.species,
                        gender: localBird.gender,
                        hatchDate: localBird.hatchDate,
                        adoptionDate: localBird.adoptionDate,
                        birthdayType: localBird.birthdayType,
                        deathDate: localBird.deathDate,
                        featherColor: localBird.featherColor,
                        source: nil,
                        avatarUrl: localBird.avatarUrl,
                        notes: localBird.notes,
                        ageMonths: nil,
                        isLost: localBird.isLost,
                        lostDate: localBird.lostDate,
                        lostLocation: localBird.lostLocation
                    )
                }
            
            // 合并服务器鸟儿 + 本地待同步鸟儿
            self.birds = loadedBirds + pendingLocalBirds
            print("🐦 首页 birds 数组更新: \(self.birds.count) 只 (服务器: \(loadedBirds.count), 本地: \(pendingLocalBirds.count))")
            self.logs = loadedLogs
            self.reminders = loadedReminders
            self.localLogs = offlineService.localLogs
            self.isLoading = false
            self.errorMessage = nil  // 清除错误，因为至少鸟儿加载成功了
            
            // 同步服务器数据到本地缓存
            let birdDTOs = loadedBirds.map { bird -> BirdDTO in
                var dto = BirdDTO()
                dto.id = Int(bird.id)
                dto.nickname = bird.nickname
                dto.species = bird.species
                dto.gender = bird.gender
                dto.avatarUrl = bird.avatarUrl
                dto.notes = bird.notes
                dto.isDeleted = bird.isDeleted
                return dto
            }
            offlineService.updateBirdsFromServer(birdDTOs)
            print("✅ 已同步 \(loadedBirds.count) 只服务器鸟儿 + \(pendingLocalBirds.count) 只待同步本地鸟儿")
            // 闪烁修复：同时更新两个缓存
            updateCachedSortedBirds()
            updateCachedFilteredLogs()
        }
        
        // 检查并自动禁用已过期的一次性提醒（在MainActor.run外部调用）
        await checkAndDisableExpiredReminders()
    }

    // MARK: - Helpers

    private func formatLogTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: time)
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // MARK: - 调试辅助
    private static func printDecodingError(_ error: DecodingError, label: String) {
        switch error {
        case .keyNotFound(let key, let context):
            print("  ↳ \(label)缺少字段: \(key.stringValue), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .typeMismatch(let type, let context):
            print("  ↳ \(label)类型不匹配: 期望 \(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .valueNotFound(let type, let context):
            print("  ↳ \(label)值为空: 期望 \(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .dataCorrupted(let context):
            print("  ↳ \(label)数据损坏: \(context.debugDescription)")
        @unknown default:
            print("  ↳ \(label)未知解码错误")
        }
    }
}
