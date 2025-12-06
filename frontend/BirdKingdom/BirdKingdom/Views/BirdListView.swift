import SwiftUI
import UserNotifications

// MARK: - 森林主题配色
private enum ForestTheme {
    // 主色调 - 复古森林绿
    static let primary = Color(red: 0.25, green: 0.42, blue: 0.35)
    // 浅绿色背景
    static let lightGreen = Color(red: 0.92, green: 0.95, blue: 0.93)
    // 卡片背景
    static let cardBackground = Color(red: 0.97, green: 0.98, blue: 0.97)
    // 次要文字
    static let secondaryText = Color(red: 0.4, green: 0.5, blue: 0.45)
    // 强调色 - 暖棕色
    static let accent = Color(red: 0.55, green: 0.45, blue: 0.35)
    // 禁用状态
    static let disabled = Color(red: 0.7, green: 0.72, blue: 0.7)
}

struct BirdListView: View {
    @State private var birds: [Bird] = []
    @State private var logs: [BirdLog] = []
    @State private var reminders: [Reminder] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    // 当前选中的鸟索引，nil 表示未选中任何鸟
    @State private var selectedIndex: Int? = nil
    // 提醒相关
    @State private var showAddReminder: Bool = false
    @State private var editingReminder: Reminder? = nil

    @State private var navigateToAllBirds = false
    @State private var navigateToAllLogs = false
    @State private var navigateToWeightTrend = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else if let errorMessage = errorMessage {
                VStack(spacing: 12) {
                    Text("加载失败")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadBirds()
                    }
                }
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 我的鸟舍
                        sectionHeaderWithAction(title: "我的鸟舍") {
                            Button("查看全部") {
                                navigateToAllBirds = true
                            }
                            .font(.subheadline)
                            .foregroundColor(ForestTheme.primary)
                        }

                        if birds.isEmpty {
                            emptyStateCard
                        } else {
                            birdCards
                        }

                        // 日志
                        sectionHeaderWithAction(title: "日志") {
                            Button("查看全部") {
                                navigateToAllLogs = true
                            }
                            .font(.subheadline)
                            .foregroundColor(ForestTheme.primary)
                        }
                        logsSection

                        // 体重趋势
                        sectionHeaderWithAction(title: "体重趋势") {
                            Button("查看全部") {
                                navigateToWeightTrend = true
                            }
                            .font(.subheadline)
                            .foregroundColor(ForestTheme.primary)
                        }
                        weightTrendPreview

                        // 近期提醒
                        sectionHeaderWithAction(title: "近期提醒") {
                            Button {
                                showAddReminder = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(ForestTheme.primary)
                            }
                        }
                        remindersSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await loadDataAsync()
                }
            }
        }
        .background(Color.white)
        .task {
            await loadOnAppearIfNeeded()
        }
        .onAppear {
            Task {
                await loadDataAsync()
            }
        }
        .sheet(isPresented: $showAddReminder) {
            ReminderFormView { title, time, repeatDays in
                addReminder(title: title, time: time, repeatDays: repeatDays)
            }
        }
        .sheet(item: $editingReminder) { reminder in
            ReminderFormView(editingReminder: reminder) { title, time, repeatDays in
                updateReminder(reminder, title: title, time: time, repeatDays: repeatDays)
            }
        }
        .fullScreenCover(isPresented: $navigateToAllBirds) {
            NavigationStack {
                AllBirdsView()
            }
        }
        .fullScreenCover(isPresented: $navigateToAllLogs) {
            NavigationStack {
                AllLogsView()
            }
        }
        .fullScreenCover(isPresented: $navigateToWeightTrend) {
            NavigationStack {
                WeightTrendFullView()
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

    private var emptyStateCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(ForestTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ForestTheme.primary.opacity(0.1), lineWidth: 1)
                )

            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ForestTheme.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .foregroundColor(ForestTheme.primary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("还没有任何鸟档案")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text("点击这里添加你的第一只鸟")
                        .font(.system(size: 14))
                        .foregroundColor(ForestTheme.secondaryText)
                }
                Spacer()
            }
            .padding(16)
        }
        .frame(height: 100)
    }

    private var birdCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(birds.enumerated()), id: \.offset) { index, bird in
                    BirdCardView(
                        bird: bird,
                        isSelected: selectedIndex == index,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if selectedIndex == index {
                                    // 再次点击同一只鸟，取消选中
                                    selectedIndex = nil
                                } else {
                                    selectedIndex = index
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 180)
        }
    }
    
    // 独立的鸟卡片视图组件
    private struct BirdCardView: View {
        let bird: Bird
        let isSelected: Bool
        let onTap: () -> Void
        
        private var defaultBirdIcon: some View {
            Image(systemName: "bird.fill")
                .font(.system(size: 36))
                .foregroundColor(.white)
        }
        
        var body: some View {
            Button(action: onTap) {
                ZStack {
                    // 背景卡片 - 已故小鸟使用灰色调
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: bird.isDead
                                    ? (isSelected 
                                        ? [Color(red: 0.35, green: 0.35, blue: 0.38), Color(red: 0.28, green: 0.28, blue: 0.30)]
                                        : [Color(red: 0.45, green: 0.45, blue: 0.47), Color(red: 0.38, green: 0.38, blue: 0.40)])
                                    : (isSelected
                                        ? [Color(red: 0.08, green: 0.50, blue: 0.40), Color(red: 0.18, green: 0.60, blue: 0.45)]
                                        : [Color(red: 0.15, green: 0.38, blue: 0.32), Color(red: 0.22, green: 0.48, blue: 0.38)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // 已故小鸟的装饰边框
                    if bird.isDead {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    
                    // 内容
                    VStack(spacing: 0) {
                        // 头像区域 - 放大占据更多空间
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(isSelected ? 0.22 : 0.10))
                            
                            // 使用真实头像或默认图标
                            if let avatarUrl = bird.avatarUrl, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    default:
                                        defaultBirdIcon
                                    }
                                }
                            } else {
                                defaultBirdIcon
                            }
                            
                            // 已故标识
                            if bird.isDead {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 70, height: 70)
                                
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        
                        Spacer()
                        
                        // 鸟名和品种
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(bird.nickname)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                // 已故小鸟的纪念标识
                                if bird.isDead {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(Color.white.opacity(0.7))
                                }
                            }
                            
                            if bird.isDead {
                                // 显示纪念文字
                                Text("永远怀念")
                                    .font(.caption2)
                                    .foregroundColor(Color.white.opacity(0.7))
                                    .italic()
                            } else {
                                Text("\(bird.species) · \(bird.ageText)")
                                    .font(.caption)
                                    .foregroundColor(Color.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
                .frame(width: 130, height: 170)
                .scaleEffect(isSelected ? 1.06 : 1.0)
                .opacity(isSelected ? 1.0 : 0.75)
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.25 : 0.1),
                    radius: isSelected ? 8 : 3,
                    x: 0,
                    y: isSelected ? 5 : 2
                )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.25), value: isSelected)
        }
    }

    // 当前选中的鸟
    private var selectedBird: Bird? {
        guard let index = selectedIndex, birds.indices.contains(index) else { return nil }
        return birds[index]
    }
    
    // 根据选中的鸟过滤后的日志：未选中时显示全部日志
    private var filteredLogs: [BirdLog] {
        guard let bird = selectedBird else {
            // 未选中任何鸟，按时间顺序显示全部日志
            return logs.sorted { $0.logDate > $1.logDate }
        }
        return logs.filter { $0.birdName == bird.nickname }.sorted { $0.logDate > $1.logDate }
    }

    // MARK: - 日志预览

    @ViewBuilder
    private var logsSection: some View {
        if filteredLogs.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "book")
                    .foregroundColor(ForestTheme.secondaryText)
                Text("暂无日志记录")
                    .font(.system(size: 14))
                    .foregroundColor(ForestTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ForestTheme.cardBackground)
            )
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filteredLogs) { log in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ForestTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(ForestTheme.primary.opacity(0.1), lineWidth: 1)
                                )
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(log.birdName)
                                        .font(.headline)
                                        .foregroundColor(ForestTheme.primary)
                                    Spacer()
                                    Text(formatLogTime(log.logDate))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(log.summary)
                                    .font(.subheadline)
                                    .foregroundColor(.primary.opacity(0.85))
                                    .lineLimit(2)
                                if let weight = log.weight {
                                    HStack(spacing: 4) {
                                        Image(systemName: "scalemass")
                                            .font(.caption2)
                                            .foregroundColor(ForestTheme.primary)
                                        Text("\(String(format: "%.1f", weight)) g")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(ForestTheme.primary)
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .frame(width: 260, height: 130)
                    }
                }
            }
        }
    }

    // MARK: - 体重趋势预览

    private var weightTrendPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(ForestTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ForestTheme.primary.opacity(0.1), lineWidth: 1)
                )

            // 未选中任何鸟时显示提示
            if selectedBird == nil {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(ForestTheme.primary.opacity(0.5))
                    Text("请先选择一只小鸟")
                        .font(.subheadline)
                        .foregroundColor(ForestTheme.secondaryText)
                    Text("点击上方卡片查看体重趋势")
                        .font(.caption)
                        .foregroundColor(ForestTheme.secondaryText.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                weightChartContent
            }
        }
        .frame(height: 150)
    }
    
    // 计算每天最新的体重数据点（按 id 最大为准）
    private var weightDisplayPoints: [(date: Date, weight: Double)] {
        guard let bird = selectedBird else { return [] }
        let sourceLogs = logs.filter { $0.birdName == bird.nickname }
        
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
        
        return latestByDate.values
            .sorted { $0.date < $1.date }
            .suffix(6)
            .map { (date: $0.date, weight: $0.weight) }
    }
    
    @ViewBuilder
    private var weightChartContent: some View {
        let displayPoints = weightDisplayPoints
        
        if displayPoints.count < 2 {
            VStack(spacing: 8) {
                Text("暂无足够体重数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("记录至少 2 条体重即可查看趋势")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                let weights = displayPoints.map { $0.weight }
                let minWeight = weights.min() ?? 0
                let maxWeight = weights.max() ?? 0
                let padding = max((maxWeight - minWeight) * 0.1, 5)
                let lowerBound = max(minWeight - padding, 0)
                let upperBound = maxWeight + padding
                let range = max(upperBound - lowerBound, 1)
                
                let yTicks: [Double] = stride(from: 0, through: 3, by: 1).map { idx in
                    lowerBound + range * (Double(3 - idx) / 3.0)
                }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let leadingInset: CGFloat = 48
                let bottomInset: CGFloat = 28
                let topInset: CGFloat = 12
                let trailingInset: CGFloat = 16
                let plotWidth = width - leadingInset - trailingInset
                let plotHeight = height - topInset - bottomInset
                
                ZStack {
                    // 轴线
                    Path { path in
                        path.move(to: CGPoint(x: leadingInset, y: topInset))
                        path.addLine(to: CGPoint(x: leadingInset, y: height - bottomInset))
                        path.move(to: CGPoint(x: leadingInset, y: height - bottomInset))
                        path.addLine(to: CGPoint(x: width - trailingInset, y: height - bottomInset))
                    }
                    .stroke(ForestTheme.primary.opacity(0.5), lineWidth: 1)
                    
                    // Y 刻度
                    ForEach(Array(yTicks.enumerated()), id: \.offset) { _, value in
                        let normalized = (value - lowerBound) / range
                        let y = topInset + plotHeight * (1 - CGFloat(normalized))
                        
                        Path { path in
                            path.move(to: CGPoint(x: leadingInset, y: y))
                            path.addLine(to: CGPoint(x: width - trailingInset, y: y))
                        }
                        .stroke(ForestTheme.primary.opacity(0.15), lineWidth: 1)
                        
                        Text("\(Int(value.rounded()))g")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: leadingInset - 8, alignment: .trailing)
                            .position(x: (leadingInset - 8) / 2, y: y)
                    }
                    
                    // 折线
                    Path { path in
                        for (index, point) in displayPoints.enumerated() {
                            let t = CGFloat(index) / CGFloat(max(displayPoints.count - 1, 1))
                            let x = leadingInset + plotWidth * t
                            let normalizedY = (point.weight - lowerBound) / range
                            let y = topInset + plotHeight * (1 - CGFloat(normalizedY))
                            let cgPoint = CGPoint(x: x, y: y)
                            if index == 0 {
                                path.move(to: cgPoint)
                            } else {
                                path.addLine(to: cgPoint)
                            }
                        }
                    }
                    .stroke(ForestTheme.primary, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    
                    // X 轴日期标签
                    VStack {
                        Spacer()
                        HStack {
                            ForEach(Array(displayPoints.enumerated()), id: \.offset) { _, point in
                                Text(formatShortDate(point.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .frame(width: plotWidth)
                        .padding(.leading, leadingInset)
                        .padding(.trailing, trailingInset)
                        .padding(.bottom, 4)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - 近期提醒

    @ViewBuilder
    private var remindersSection: some View {
        if reminders.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "bell")
                    .foregroundColor(ForestTheme.secondaryText)
                Text("暂无提醒")
                    .font(.system(size: 14))
                    .foregroundColor(ForestTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ForestTheme.cardBackground)
            )
        } else {
            // 按距离当前时间的差值排序：最近要响的在上面
            let now = Date()
            let sortedReminders = reminders.sorted { r1, r2 in
                let diff1 = timeUntilNextTrigger(r1.timeDescription, from: now)
                let diff2 = timeUntilNextTrigger(r2.timeDescription, from: now)
                return diff1 < diff2
            }
            
            // 使用 VStack 避免 List 的裁剪问题
            VStack(spacing: 8) {
                ForEach(sortedReminders) { reminder in
                    ReminderCardView(
                        reminder: reminder,
                        onTap: { editingReminder = reminder },
                        onToggle: { toggleReminderEnabled(reminder, enabled: $0) },
                        onDelete: { deleteReminder(reminder) }
                    )
                }
            }
        }
    }
    
    // 计算距离下次触发的时间（分钟）
    private func timeUntilNextTrigger(_ description: String, from now: Date) -> Int {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotalMinutes = currentHour * 60 + currentMinute
        
        // 解析提醒时间
        let components = description.components(separatedBy: " ")
        guard let timeString = components.last else { return Int.max }
        let parts = timeString.components(separatedBy: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return Int.max }
        
        let reminderTotalMinutes = hour * 60 + minute
        
        // 计算时间差
        var diff = reminderTotalMinutes - currentTotalMinutes
        if diff < 0 {
            // 如果时间已过，算到明天
            diff += 24 * 60
        }
        
        return diff
    }
    
    // 提醒卡片视图 - 支持滑动删除
    private struct ReminderCardView: View {
        let reminder: Reminder
        let onTap: () -> Void
        let onToggle: (Bool) -> Void
        let onDelete: () -> Void
        
        @State private var isPressed = false
        @State private var offset: CGFloat = 0
        @State private var showDelete = false
        
        var body: some View {
            ZStack(alignment: .trailing) {
                // 删除按钮背景
                if showDelete {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                onDelete()
                            }
                        }) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.white)
                                .frame(width: 70, height: 54)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                }
                
                // 主卡片
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(reminder.enabled ? .primary : ForestTheme.disabled)
                            .lineLimit(1)
                        Text(reminder.timeDescription)
                            .font(.system(size: 13))
                            .foregroundColor(reminder.enabled ? ForestTheme.secondaryText : ForestTheme.disabled)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { reminder.enabled },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .tint(ForestTheme.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isPressed ? Color(uiColor: .systemGray5) : (reminder.enabled ? ForestTheme.cardBackground : Color(white: 0.96)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(reminder.enabled ? ForestTheme.primary.opacity(0.15) : Color.clear, lineWidth: 1)
                )
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                if value.translation.width < -50 {
                                    offset = -80
                                    showDelete = true
                                } else {
                                    offset = 0
                                    showDelete = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if showDelete {
                        withAnimation {
                            offset = 0
                            showDelete = false
                        }
                    } else {
                        onTap()
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.1)
                        .onChanged { _ in
                            withAnimation(.easeInOut(duration: 0.08)) {
                                isPressed = true
                            }
                        }
                )
                .onChange(of: isPressed) { newValue in
                    if newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = false
                            }
                        }
                    }
                }
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
            }
        }
    }
    
    // MARK: - 提醒操作
    
    private func addReminder(title: String, time: Date, repeatDays: RepeatDays) {
        let timeDescription = formatReminderTime(time: time, repeatDays: repeatDays)
        
        Task {
            do {
                let newReminder = try await ApiService.shared.createReminder(
                    title: title,
                    timeDescription: timeDescription,
                    reminderType: repeatDays.displayText,
                    enabled: true
                )
                await MainActor.run {
                    reminders.append(newReminder)
                    // 设置本地通知
                    scheduleNotifications(title: title, time: time, repeatDays: repeatDays, id: newReminder.id)
                }
            } catch {
                print("创建提醒失败: \(error)")
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
        if description.contains("每天") {
            days.sunday = true
            days.monday = true
            days.tuesday = true
            days.wednesday = true
            days.thursday = true
            days.friday = true
            days.saturday = true
        } else {
            if description.contains("周日") { days.sunday = true }
            if description.contains("周一") { days.monday = true }
            if description.contains("周二") { days.tuesday = true }
            if description.contains("周三") { days.wednesday = true }
            if description.contains("周四") { days.thursday = true }
            if description.contains("周五") { days.friday = true }
            if description.contains("周六") { days.saturday = true }
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
                        title: "🔔 鸟王国提醒",
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
                                title: "🔔 鸟王国提醒",
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

    private func loadOnAppearIfNeeded() async {
        guard birds.isEmpty && !isLoading else { return }
        await loadDataAsync()
    }

    private func loadBirds() {
        Task {
            await loadDataAsync()
        }
    }

    private func loadDataAsync() async {
        isLoading = true
        errorMessage = nil
        do {
            async let birdsResult = ApiService.shared.getBirds()
            async let logsResult = ApiService.shared.getLogs()
            async let remindersResult = ApiService.shared.getReminders()

            let (birds, logs, reminders) = try await (birdsResult, logsResult, remindersResult)
            await MainActor.run {
                self.birds = birds
                self.logs = logs
                self.reminders = reminders
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Helpers

    private func formatLogTime(_ time: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let logDay = calendar.startOfDay(for: time)

        if logDay == today {
            let h = calendar.component(.hour, from: time)
            let m = calendar.component(.minute, from: time)
            let hh = String(format: "%02d", h)
            let mm = String(format: "%02d", m)
            return "今天 \(hh):\(mm)"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           logDay == yesterday {
            return "昨天"
        }

        let month = calendar.component(.month, from: time)
        let day = calendar.component(.day, from: time)
        return "\(month)/\(day)"
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}
