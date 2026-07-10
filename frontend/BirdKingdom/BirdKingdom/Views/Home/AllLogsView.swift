import SwiftUI
import Combine

struct AllLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var logs: [BirdLog] = []
    @State private var birds: [Bird] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedBirdIndex: Int = 0  // 0 = 全部
    @State private var showDeleteAlert = false
    @State private var logToDelete: BirdLog?
    @State private var showNewLog = false
    @State private var editingLog: BirdLog?  // 编辑日志
    
    // 图片查看状态（移到父视图级别避免 lazy container 警告）
    @State private var showFullScreenImages = false
    @State private var selectedImageUrls: [String] = []
    @State private var selectedImageIndex = 0
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        VStack(spacing: 0) {
            // 鸟筛选器
            if !birds.isEmpty {
                filterView
                Divider()
            }
            
            // 日志列表
            logsListView
        }
        .themedBackground()
        .navigationTitle(L10n.allLogs)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewLog = true
                } label: {
                    Text(L10n.writeLog)
                        .foregroundColor(primaryColor)
                }
            }
        }
        .navigationDestination(isPresented: $showNewLog) {
            NewLogView(preselectedBirdId: selectedBirdIndex > 0 && selectedBirdIndex <= birds.count ? birds[selectedBirdIndex - 1].id : nil)
            .hidesTabBar()
        }
        .navigationDestination(isPresented: $showFullScreenImages) {
            FullScreenImageViewer_URLs(
                imageURLs: selectedImageUrls,
                initialIndex: selectedImageIndex,
                isPresented: $showFullScreenImages
            )
            .hidesTabBar()
        }
        .navigationDestination(item: $editingLog) { log in
            EditLogView(log: log) { updatedLog in
                // 立即更新列表
                if let index = logs.firstIndex(where: { $0.id == updatedLog.id }) {
                    logs[index] = updatedLog
                }
                Task { await loadData() }
            }
            .hidesTabBar()
        }
        .onAppear {
            // 首次加载数据
            Task { await loadData() }
        }
        // Fix: 当从写日志页面返回时（showNewLog 从 true 变为 false），刷新数据
        .onChange(of: showNewLog) { newValue in
            if !newValue {
                // 写日志页面关闭后，延迟一小段时间让本地数据保存完成，然后刷新
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    await loadData()
                }
            }
        }
        .alert(L10n.deleteLog, isPresented: $showDeleteAlert) {
            Button(L10n.cancel, role: .cancel) {
                logToDelete = nil
            }
            Button(L10n.delete, role: .destructive) {
                if let log = logToDelete {
                    deleteLog(log)
                }
            }
        } message: {
            Text(L10n.deleteLogConfirm)
        }
        // 监听日志刷新通知（写完新日志后自动刷新）
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshLogs"))) { _ in
            Task { await loadData() }
        }
        .hidesTabBar()  // 进入详情页时隐藏底部导航栏
    }
    
    // MARK: - Subviews
    
    private var filterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(
                    title: L10n.all,
                    isSelected: selectedBirdIndex == 0,
                    onTap: { selectedBirdIndex = 0 }
                )
                
                ForEach(Array(birds.enumerated()), id: \.offset) { index, bird in
                    FilterChip(
                        title: bird.nickname,
                        isSelected: selectedBirdIndex == index + 1,
                        onTap: { selectedBirdIndex = index + 1 }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(themeManager.backgroundColor.opacity(0.3))
    }
    
    private var logsListView: some View {
        Group {
            if isLoading {
                UnifiedStateView.loading
            } else if let error = errorMessage {
                UnifiedStateView.error(error) {
                    Task { await loadData() }
                }
            } else if filteredLogs.isEmpty {
                EmptyLogsView()
            } else {
                List {
                    ForEach(sortedDateKeys, id: \.self) { date in
                        Section {
                            ForEach(groupedLogs[date] ?? []) { log in
                                TimelineLogRow(
                                    log: log,
                                    onImageTap: { urls, index in
                                        selectedImageUrls = urls
                                        selectedImageIndex = index
                                        showFullScreenImages = true
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // 删除按钮
                                    Button(role: .destructive) {
                                        logToDelete = log
                                        showDeleteAlert = true
                                    } label: {
                                        Label(L10n.delete, systemImage: "trash")
                                    }
                                    
                                    // 编辑按钮（仅服务器日志可编辑）
                                    if log.id > 0 {
                                        Button {
                                            editingLog = log
                                        } label: {
                                            Label(L10n.edit, systemImage: "pencil")
                                        }
                                        .tint(themeManager.primaryColor)
                                    }
                                }
                            }
                        } header: {
                            Text(formatDateLabel(date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private func deleteLog(_ log: BirdLog) {
        // 立即从本地列表中移除，提供即时反馈
        withAnimation(.easeOut(duration: 0.25)) {
            logs.removeAll { $0.id == log.id }
        }
        logToDelete = nil
        
        // P0 重构：使用 HomeLogService 统一处理本地日志查找
        if HomeLogService.shared.isLocalLog(log) {
            // 本地日志：通过 HomeLogService 查找对应的 localLog
            if let localLog = HomeLogService.shared.findLocalLog(
                byDisplayId: log.id,
                in: OfflineDataService.shared.localLogs
            ) {
                OfflineDataService.shared.deleteLogByLocalId(localLog.localId)
                print("✅ 本地日志已删除: \(localLog.localId)")
            } else {
                print("⚠️ 未找到对应的本地日志 ID: \(log.id)")
            }
            return
        }
        
        // 服务器日志：调用 API 删除
        Task {
            do {
                try await ApiService.shared.deleteLog(id: log.id)
                print("✅ 服务器日志删除成功")
            } catch {
                print("❌ 删除日志失败: \(error)")
                // 如果删除失败，重新加载数据恢复
                await loadData()
            }
        }
    }
    
    private var filteredLogs: [BirdLog] {
        // 首先过滤掉只有体重没有内容的日志（这些只显示在体重趋势中）
        let contentLogs = logs.filter { $0.hasContent }
        let sortedLogs = contentLogs.sorted { $0.logDate > $1.logDate }
        
        // 如果选中了"全部" (0)，直接返回排序后的完整列表
        if selectedBirdIndex == 0 {
            return sortedLogs
        }
        
        // 确保索引在有效范围内
        guard selectedBirdIndex > 0, selectedBirdIndex <= birds.count else {
            return sortedLogs
        }
        
        // 获取选中鸟的 ID
        let birdIndex = selectedBirdIndex - 1
        let birdId = birds[birdIndex].id
        
        // 过滤并返回
        return sortedLogs.filter { $0.birdId == birdId }
    }
    
    private var groupedLogs: [Date: [BirdLog]] {
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        return Dictionary(grouping: filteredLogs) { log in
            DateFormatters.startOfDay(log.logDate)
        }
    }
    
    private var sortedDateKeys: [Date] {
        groupedLogs.keys.sorted { $0 > $1 }
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        return DateFormatters.dateLabel(for: date)
    }
    
    private func loadData() async {
        guard AuthService.shared.isLoggedIn else {
            logs = []
            birds = []
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 始终获取本地数据作为基础
        let localLogs = OfflineDataService.shared.localLogs
        let localBirds = OfflineDataService.shared.localBirds
        
        var fetchedLogs: [BirdLog] = []
        var fetchedBirds: [Bird] = []
        
        do {
            async let logsResult = ApiService.shared.getLogs()
            async let birdsResult = ApiService.shared.getBirds()
            
            (fetchedLogs, fetchedBirds) = try await (logsResult, birdsResult)
        } catch {
            print("⚠️ AllLogsView: API 获取失败，使用本地数据: \(error.localizedDescription)")
            // API 失败时不设置 errorMessage，让页面显示本地数据
        }
        
        // P0 关键修复：无论 API 成功与否，都合并本地日志
        // 确保用户的离线日志始终可见
        logs = HomeLogService.shared.mergeLogsWithLocalData(
            serverLogs: fetchedLogs,
            serverBirds: fetchedBirds,
            localLogs: localLogs,
            localBirds: localBirds
        )
        birds = fetchedBirds
        
        isLoading = false
    }
}

// 筛选芯片
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? themeManager.primaryColor : Color.gray.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}

// 时间线日志行
struct TimelineLogRow: View {
    let log: BirdLog
    var onImageTap: (([String], Int) -> Void)? = nil  // 回调：图片URLs 和 点击的索引
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间线
            VStack(spacing: 0) {
                Circle()
                    .fill(themeManager.primaryColor)
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(themeManager.primaryColor.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)
            
            // 日志卡片
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(log.birdName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.primaryColor)
                    
                    Spacer()
                    
                    Text(formatTime(log.logDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 日志内容直接显示（不要前面的点）
                Text(log.summary)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.85))
                
                // 图片缩略图区域
                if let imageUrls = log.imageUrls, !imageUrls.isEmpty {
                    logImageThumbnails(imageUrls: imageUrls)
                }
                
                // 体重显示在下面的小标签
                if let weight = log.weight {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", weight))g")
                            .font(.caption)
                    }
                    .foregroundColor(themeManager.primaryColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeManager.primaryColor.opacity(0.08))
                    .shadow(color: themeManager.primaryColor.opacity(0.06), radius: 4, x: 0, y: 2)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private func logImageThumbnails(imageUrls: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(imageUrls.prefix(4).enumerated()), id: \.offset) { index, urlString in
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: AppConfig.applyCDN(to: urlString))) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    )
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 60, height: 60)
                        
                        if index == 3 && imageUrls.count > 4 {
                            Text("+\(imageUrls.count - 4)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(4)
                        }
                    }
                    .onTapGesture {
                        onImageTap?(imageUrls, index)
                    }
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        return date.displayTimeString
    }
}

#Preview {
    AllLogsView()
}
