import SwiftUI

struct WeightTrendFullView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var logs: [BirdLog] = []
    @State private var birds: [Bird] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedBirdIndex: Int = 0
    @State private var selectedRangeIndex: Int = 0
    @State private var showDeleteAlert = false
    @State private var recordToDelete: (birdId: Int64, logId: Int64, date: Date, weight: Double)?
    @State private var speciesWeightMin: Double? = nil
    @State private var speciesWeightMax: Double? = nil
    @State private var speciesWeightCache: [String: (min: Double, max: Double)] = [:]
    @State private var showRecordWeight = false
    
    private var primaryColor: Color { themeManager.primaryColor }
    private let rangeOptions = ["1W", "1M", "3M", "1Y"]
    private let rangeDays = [7, 30, 90, 365]
    
    /// 映射到图表的 TimeRange 枚举
    private var currentTimeRange: WeightTrendChartView.TimeRange {
        switch selectedRangeIndex {
        case 0: return .week
        case 1: return .month
        case 2: return .threeMonths
        case 3: return .year
        default: return .month
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 鸟筛选器
            if !birds.isEmpty {
                birdSelector
            }
            
            // 主内容
            Group {
                if isLoading {
                    UnifiedStateView.loading
                } else if let error = errorMessage {
                    UnifiedStateView.error(error) {
                        Task { await loadData() }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // 时间范围选择器（放在图表上方）
                            timeRangeSelector
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                            
                            // 图表区域
                            chartSection
                                .padding(.horizontal, 16)
                            
                            // 统计卡片
                            if selectedBirdIndex != 0 {
                                statsSection
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                            }
                            
                            // 体重记录列表
                            recordsSection
                                .padding(16)
                        }
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle(NSLocalizedString("体重趋势", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showRecordWeight = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(primaryColor)
                }
            }
        }
        .navigationDestination(isPresented: $showRecordWeight) {
            RecordWeightView(
                birds: birds,
                preselectedIndex: selectedBirdIndex > 0 ? selectedBirdIndex - 1 : nil
            )
            .hidesTabBar()
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedBirdIndex) { _, _ in
            loadSpeciesWeightRange()
        }
        .alert(NSLocalizedString("删除体重记录", comment: ""), isPresented: $showDeleteAlert) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) {
                recordToDelete = nil
            }
            Button(NSLocalizedString("删除", comment: ""), role: .destructive) {
                if let record = recordToDelete {
                    deleteWeightRecord(birdId: record.birdId, logId: record.logId)
                }
            }
        } message: {
            if let record = recordToDelete {
                let formatStr = NSLocalizedString("确定要删除 %1$@ 的体重记录（%2$@g）吗？此操作不可撤销。", comment: "")
                let dateStr = formatFullDate(record.date)
                let weightStr = String(format: "%.1f", record.weight)
                Text(String(format: formatStr, dateStr, weightStr))
            }
        }
        .hidesTabBar()
    }
    
    // MARK: - 鸟选择器（胶囊样式）
    private var birdSelector: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    birdChip(title: NSLocalizedString("全部", comment: ""), isSelected: selectedBirdIndex == 0) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedBirdIndex = 0
                        }
                    }
                    
                    ForEach(Array(birds.enumerated()), id: \.offset) { index, bird in
                        birdChip(title: bird.nickname, isSelected: selectedBirdIndex == index + 1) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedBirdIndex = index + 1
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            
            Divider()
                .opacity(0.3)
        }
    }
    
    private func birdChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? primaryColor : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 时间范围选择器（股票风格分段控件）
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(rangeOptions.enumerated()), id: \.offset) { index, option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRangeIndex = index
                    }
                } label: {
                    Text(option)
                        .font(.system(size: 13, weight: selectedRangeIndex == index ? .bold : .medium))
                        .foregroundColor(selectedRangeIndex == index ? primaryColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if selectedRangeIndex == index {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(primaryColor.opacity(0.12))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - 图表区域
    private var chartSection: some View {
        Group {
            if selectedBirdIndex == 0 {
                // 未选择鸟：提示选择
                VStack(spacing: 12) {
                    Image(systemName: "bird")
                        .font(.system(size: 32))
                        .foregroundStyle(primaryColor.opacity(0.4))
                    Text(NSLocalizedString("选择一只小鸟查看体重趋势", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.adaptiveCard)
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
            } else {
                WeightTrendChartView(
                    weightPoints: filteredDataPoints,
                    speciesWeightMin: speciesWeightMin,
                    speciesWeightMax: speciesWeightMax,
                    primaryColor: primaryColor,
                    timeRange: currentTimeRange,
                    fixedDateRange: (
                        start: Calendar.current.date(byAdding: .day, value: -rangeDays[selectedRangeIndex], to: Date()) ?? Date(),
                        end: Date()
                    )
                )
            }
        }
    }
    
    // MARK: - 统计信息（重新设计）
    private var statsSection: some View {
        HStack(spacing: 10) {
            statItem(
                title: NSLocalizedString("最低", comment: ""),
                value: filteredDataPoints.map(\.weight).min().map { String(format: "%.1f", $0) } ?? "--",
                icon: "arrow.down",
                color: Color(red: 0.2, green: 0.72, blue: 0.45)
            )
            
            statItem(
                title: NSLocalizedString("最高", comment: ""),
                value: filteredDataPoints.map(\.weight).max().map { String(format: "%.1f", $0) } ?? "--",
                icon: "arrow.up",
                color: Color(red: 0.95, green: 0.55, blue: 0.25)
            )
            
            statItem(
                title: NSLocalizedString("均值", comment: ""),
                value: averageWeight,
                icon: "chart.bar",
                color: primaryColor
            )
            
            statItem(
                title: NSLocalizedString("记录", comment: ""),
                value: "\(filteredDataPoints.count)",
                icon: "number",
                color: .secondary
            )
        }
    }
    
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color.opacity(0.7))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.adaptiveCard)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
        )
    }
    
    // MARK: - 体重记录列表（重新设计）
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("体重记录", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !weightRecordsWithBirdNameAndId.isEmpty {
                    Text("共 \(weightRecordsWithBirdNameAndId.count) 条")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            if weightRecordsWithBirdNameAndId.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(NSLocalizedString("暂无记录", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // 按月分组展示
                ForEach(Array(weightRecordsWithBirdNameAndId.prefix(20).enumerated()), id: \.offset) { index, record in
                    recordRow(record: record, index: index)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCard)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func recordRow(record: (birdId: Int64, logId: Int64, birdName: String, date: Date, weight: Double), index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 左侧日期
                VStack(spacing: 0) {
                    Text(formatDayNumber(record.date))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(formatMonthYear(record.date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 36)
                
                // 分割线
                Rectangle()
                    .fill(primaryColor.opacity(0.15))
                    .frame(width: 2, height: 32)
                    .cornerRadius(1)
                
                // 中间信息
                VStack(alignment: .leading, spacing: 2) {
                    if selectedBirdIndex == 0 {
                        Text(record.birdName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(primaryColor)
                    }
                    Text(formatWeekday(record.date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 右侧体重值
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", record.weight))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(isWeightHealthy(record.weight) ? .primary : .red)
                    Text("g")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // 健康指示器
                Circle()
                    .fill(isWeightHealthy(record.weight) ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                    .opacity(0.7)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            
            // 分隔线
            if index < min(weightRecordsWithBirdNameAndId.count, 20) - 1 {
                Divider()
                    .padding(.leading, 50)
            }
        }
    }
    
    private func isWeightHealthy(_ weight: Double) -> Bool {
        guard let min = speciesWeightMin, let max = speciesWeightMax else { return true }
        return weight >= min && weight <= max
    }
    
    // MARK: - 数据计算
    
    private func deleteWeightRecord(birdId: Int64, logId: Int64) {
        Task {
            do {
                try await ApiService.shared.deleteBirdWeight(birdId: birdId, weightId: logId)
                await MainActor.run {
                    logs.removeAll { $0.id == logId }
                    recordToDelete = nil
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                }
            } catch {
                print("删除体重记录失败: \(error)")
            }
        }
    }
    
    private var weightRecordsWithBirdNameAndId: [(birdId: Int64, logId: Int64, birdName: String, date: Date, weight: Double)] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rangeDays[selectedRangeIndex], to: Date()) ?? Date()
        
        let sourceLogs: [BirdLog]
        if selectedBirdIndex == 0 {
            sourceLogs = logs
        } else if selectedBirdIndex > 0, selectedBirdIndex <= birds.count {
            let birdId = birds[selectedBirdIndex - 1].id
            sourceLogs = logs.filter { $0.birdId == birdId }
        } else {
            sourceLogs = logs
        }
        
        let logsWithWeight = sourceLogs
            .filter { $0.logDate >= cutoffDate }
            .compactMap { log -> (birdId: Int64, logId: Int64, birdName: String, date: Date, weight: Double)? in
                guard let w = log.weight else { return nil }
                return (log.birdId, log.id, log.birdName, log.logDate, w)
            }
        
        var latestByBirdDate: [String: (birdId: Int64, logId: Int64, birdName: String, date: Date, weight: Double)] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for item in logsWithWeight {
            let key = "\(item.birdName)_\(dateFormatter.string(from: item.date))"
            if let existing = latestByBirdDate[key] {
                if item.logId > existing.logId {
                    latestByBirdDate[key] = (item.birdId, item.logId, item.birdName, item.date, item.weight)
                }
            } else {
                latestByBirdDate[key] = (item.birdId, item.logId, item.birdName, item.date, item.weight)
            }
        }
        
        return latestByBirdDate.values
            .sorted { $0.date > $1.date }
            .map { (birdId: $0.birdId, logId: $0.logId, birdName: $0.birdName, date: $0.date, weight: $0.weight) }
    }
    
    private var filteredDataPoints: [(date: Date, weight: Double)] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rangeDays[selectedRangeIndex], to: Date()) ?? Date()
        
        let sourceLogs: [BirdLog]
        if selectedBirdIndex == 0 {
            sourceLogs = logs
        } else if selectedBirdIndex > 0, selectedBirdIndex <= birds.count {
            let birdId = birds[selectedBirdIndex - 1].id
            sourceLogs = logs.filter { $0.birdId == birdId }
        } else {
            sourceLogs = logs
        }
        
        let logsWithWeight = sourceLogs
            .filter { $0.logDate >= cutoffDate }
            .compactMap { log -> (id: Int64, date: Date, weight: Double)? in
                guard let w = log.weight else { return nil }
                return (log.id, log.logDate, w)
            }
        
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
            .map { (date: $0.date, weight: $0.weight) }
    }
    
    private var averageWeight: String {
        guard !filteredDataPoints.isEmpty else { return "--" }
        let avg = filteredDataPoints.map { $0.weight }.reduce(0, +) / Double(filteredDataPoints.count)
        return String(format: "%.1f", avg)
    }
    
    // MARK: - 格式化
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月d日", comment: "")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    private func formatDayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: date)
    }
    
    private func formatMonthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = NSLocalizedString("M月", comment: "")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: date)
    }
    
    private func formatWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: date)
    }
    
    // MARK: - 数据加载
    
    private func loadData() async {
        guard AuthService.shared.isLoggedIn else {
            logs = []
            birds = []
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        do {
            async let logsResult = ApiService.shared.getLogs()
            async let birdsResult = ApiService.shared.getBirds()
            
            let (fetchedLogs, fetchedBirds) = try await (logsResult, birdsResult)
            
            let localLogs = OfflineDataService.shared.getAllLogs()
            let localBirds = OfflineDataService.shared.getAllBirds()
            
            let mergedLogs = HomeLogService.shared.mergeLogsWithLocalData(
                serverLogs: fetchedLogs,
                serverBirds: fetchedBirds,
                localLogs: localLogs,
                localBirds: localBirds
            )
            
            await MainActor.run {
                self.logs = mergedLogs
                self.birds = fetchedBirds
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
        
        loadSpeciesWeightRange()
    }
    
    private func loadSpeciesWeightRange() {
        guard selectedBirdIndex > 0, selectedBirdIndex <= birds.count else {
            speciesWeightMin = nil
            speciesWeightMax = nil
            return
        }
        
        let bird = birds[selectedBirdIndex - 1]
        let species = bird.species
        guard !species.isEmpty else {
            speciesWeightMin = nil
            speciesWeightMax = nil
            return
        }
        
        if let cached = speciesWeightCache[species] {
            speciesWeightMin = cached.min
            speciesWeightMax = cached.max
        } else if let range = SpeciesDataService.shared.getWeightRange(for: species) {
            speciesWeightMin = range.min
            speciesWeightMax = range.max
            speciesWeightCache[species] = range
        }
        
        Task {
            do {
                if let speciesInfo = try await ApiService.shared.getSpeciesByName(species) {
                    await MainActor.run {
                        if speciesWeightMin != speciesInfo.weightMin || speciesWeightMax != speciesInfo.weightMax {
                            speciesWeightMin = speciesInfo.weightMin
                            speciesWeightMax = speciesInfo.weightMax
                        }
                        speciesWeightCache[species] = (min: speciesInfo.weightMin, max: speciesInfo.weightMax)
                        SpeciesDataService.shared.updateFromServer(speciesInfo)
                    }
                }
            } catch {
                print("📊 网络获取体重范围失败: \(error.localizedDescription)")
            }
        }
    }
}

// 统计卡片（保留给其他页面使用）
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

#Preview {
    WeightTrendFullView()
}
