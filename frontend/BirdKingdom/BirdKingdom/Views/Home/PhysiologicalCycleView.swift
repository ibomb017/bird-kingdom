import SwiftUI

/// 生理周期追踪主视图 - 类似 Apple Health 月经周期追踪
struct PhysiologicalCycleView: View {
    let bird: Bird
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var offlineService = OfflineDataService.shared
    
    @State private var cycles: [BirdCycleRecord] = []
    @State private var activeCycles: [BirdCycleRecord] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    @State private var selectedCycleType: CycleType = .BATHING
    @State private var loadError: String? = nil  // 用户反馈：错误提示
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    // 是否显示产蛋期（仅母鸟）
    private var showEggLaying: Bool {
        bird.gender == "FEMALE"
    }
    
    var body: some View {
        List {
            // 用户反馈：错误提示
            if let error = loadError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .foregroundColor(.red)
                }
            }
            
            // 日历可视化
            Section {
                calendarSection
            } header: {
                Text(NSLocalizedString("周期日历", comment: ""))
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            // 当前状态卡片
            Section {
                currentStatusSection
            } header: {
                Text(NSLocalizedString("当前状态", comment: ""))
            }
            
            // 周期类型选择
            Section {
                cycleTypePicker
            } header: {
                Text(NSLocalizedString("周期类型", comment: ""))
            }
            
            // 预测信息
            Section(NSLocalizedString("智能预测", comment: "")) {
                predictionSection
            }
            
            // 选中类型的历史记录
            Section(NSLocalizedString("历史记录", comment: "")) {
                 historySection
            }
        }
        .navigationTitle(NSLocalizedString("生理周期", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(primaryColor.opacity(0.08), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(primaryColor)
        .background(Color.adaptiveCard)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundColor(primaryColor)
                }
            }
        }
        .navigationDestination(isPresented: $showAddSheet) {
            AddCycleView(bird: bird, cycleType: selectedCycleType) { newCycle in
                cycles.insert(newCycle, at: 0)
                if newCycle.isActive {
                    activeCycles.append(newCycle)
                }
            }
            .hidesTabBar()
        }
        .task {
            // P1 修复：请求通知权限
            let _ = await CycleReminderService.shared.requestAuthorization()
            
            await loadCycles()
            // 自动设置周期提醒
            CycleReminderService.shared.autoScheduleReminders(
                birdId: bird.id,
                birdName: bird.nickname,
                cycles: cycles
            )
        }
        .hidesTabBar()  // 进入详情页时隐藏底部导航栏
    }
    
    // MARK: - 日历区域
    
    // MARK: - 日历区域
    
    @State private var calendarSelectedDate: Date? = nil
    
    private var calendarSection: some View {
        CycleCalendarView(
            cycles: cycles,
            showEggLaying: true,
            selectedDate: $calendarSelectedDate
        )
        .padding(.vertical, 8)
    }
    
    // MARK: - 当前状态
    
    // MARK: - 当前状态
    
    @ViewBuilder
    private var currentStatusSection: some View {
        if activeCycles.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("当前无异常", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("鸟儿状态良好", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        } else {
            ForEach(activeCycles) { cycle in
                ActiveCycleCard(cycle: cycle, onEnd: {
                    await endCycle(cycle)
                })
            }
        }
    }
    
    // MARK: - 周期类型选择器
    
    // MARK: - 周期类型选择器
    
    private var cycleTypePicker: some View {
        Picker(NSLocalizedString("周期类型", comment: ""), selection: $selectedCycleType) { // Reconstructed Picker with correct label
            if showEggLaying {
                Text(NSLocalizedString("产蛋", comment: "")).tag(CycleType.EGG_LAYING)
            }
            Text(NSLocalizedString("洗澡", comment: "")).tag(CycleType.BATHING)
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets())
        .padding(.vertical, 4)
    }
    

    
    // MARK: - 历史记录
    
    // MARK: - 历史记录
    
    @ViewBuilder
    private var historySection: some View {
        let filteredCycles = cycles.filter { $0.cycleType == selectedCycleType }
        
        if filteredCycles.isEmpty {
            Text("暂无\(selectedCycleType.displayName)记录")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        } else {
            ForEach(filteredCycles) { cycle in
                CycleHistoryRow(cycle: cycle)
            }
        }
    }
    
    // MARK: - 预测信息（使用 CyclePredictionService）
    
    @ViewBuilder
    private var predictionSection: some View {
        let prediction = CyclePredictionService.shared.predict(
            cycles: cycles,
            cycleType: selectedCycleType,
            speciesReference: getSpeciesReferenceRange()
        )
        
        switch prediction.status {
        case .predicted:
            predictedContentView(prediction: prediction)
        case .insufficientData:
            insufficientDataView(prediction: prediction)
        case .noData:
            noDataView()
        case .unreliable:
            unreliableView(prediction: prediction)
        }
    }
    
    /// 有预测结果时的显示
    @ViewBuilder
    private func predictedContentView(prediction: CyclePredictionResult) -> some View {
        // 统计信息
        if let stats = prediction.statistics {
            HStack {
                Label(NSLocalizedString("平均间隔", comment: ""), systemImage: "calendar")
                Spacer()
                Text("\(stats.mean) 天 (±\(Int(stats.stdDev)))")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label(NSLocalizedString("间隔范围", comment: ""), systemImage: "arrow.left.and.right")
                Spacer()
                Text("\(stats.min)-\(stats.max) 天")
                    .foregroundColor(.secondary)
            }
            
            // 变异系数警告
            if stats.cv > 0.15 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("周期间隔波动较大（CV: \(String(format: "%.0f%%", stats.cv * 100))）")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        
        // 置信度显示
        HStack {
            Label(NSLocalizedString("预测置信度", comment: ""), systemImage: "gauge.with.dots.needle.bottom.50percent")
            Spacer()
            Text(prediction.confidence.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(confidenceColor(prediction.confidence).opacity(0.15))
                .foregroundColor(confidenceColor(prediction.confidence))
                .cornerRadius(4)
        }
        
        // 预测来源
        HStack {
            Label(NSLocalizedString("预测来源", comment: ""), systemImage: "info.circle")
            Spacer()
            Text(prediction.source.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        // 预测区间显示
        predictionWindowView(prediction: prediction)
        
        // 换羽期季节性提示 - Removed as Molting is no longer a primary cycle type
    }
    
    /// 预测区间视图
    @ViewBuilder
    private func predictionWindowView(prediction: CyclePredictionResult) -> some View {
        if let earliest = prediction.earliestDate,
           let expected = prediction.expectedDate,
           let latest = prediction.latestDate {
            
            let isPastDue = expected < Date()
            let daysPastDue = prediction.daysPastDue
            
            VStack(alignment: .leading, spacing: 8) {
                // 标题
                HStack {
                    if isPastDue {
                        if daysPastDue > 30 {
                            Label(NSLocalizedString("预测可能需要调整", comment: ""), systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                        } else {
                            Label(NSLocalizedString("可能正在进行", comment: ""), systemImage: "exclamationmark.circle")
                                .foregroundColor(.red)
                        }
                    } else {
                        Label(NSLocalizedString("预计下次", comment: ""), systemImage: "sparkles")
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                
                // 预测区间
                HStack(spacing: 12) {
                    VStack(alignment: .center, spacing: 2) {
                        Text(NSLocalizedString("最早", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(earliest))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text(NSLocalizedString("预期", comment: ""))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(isPastDue ? .red : .primary)
                        Text(formatDate(expected))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isPastDue ? .red : .primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isPastDue ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                    )
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text(NSLocalizedString("最迟", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDate(latest))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 过期警告
                if isPastDue {
                    Text("已过预期 \(daysPastDue) 天")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    if daysPastDue > 30 {
                        Text(NSLocalizedString("已超过预期较长时间，建议确认鸟儿状态或更新记录", comment: ""))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // 低置信度提示
                if prediction.confidence == .low || prediction.confidence == .anomalous {
                    Text(NSLocalizedString("⚠️ 预测仅供参考，请结合实际观察判断", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    /// 换羽期季节性提示 - Removed as Molting is no longer a primary cycle type
    @ViewBuilder
    private func moltingSeasonHint() -> some View {
        EmptyView() // Removed molting season hint as molting is no longer a primary cycle type
    }
    
    /// 当前季节提示文本 - Removed as Molting is no longer a primary cycle type
    private var currentSeasonHint: String {
        "" // Removed molting season hint as molting is no longer a primary cycle type
    }
    
    /// 数据不足时的显示
    @ViewBuilder
    private func insufficientDataView(prediction: CyclePredictionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text(NSLocalizedString("数据不足", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(prediction.reasoning)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 如果有品种参考值，显示参考区间
            if prediction.status == .predicted,
               let earliest = prediction.earliestDate,
               let latest = prediction.latestDate {
                HStack {
                    Label(NSLocalizedString("参考区间", comment: ""), systemImage: "book.closed")
                    Spacer()
                    Text("\(formatDate(earliest)) - \(formatDate(latest))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(NSLocalizedString("⚠️ 基于品种参考值，仅供参考", comment: ""))
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    /// 无数据时的显示
    @ViewBuilder
    private func noDataView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
                Text(NSLocalizedString("暂无预测", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(NSLocalizedString("记录更多周期数据后，系统将自动生成预测", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// 不可靠预测的显示
    @ViewBuilder
    private func unreliableView(prediction: CyclePredictionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(NSLocalizedString("周期不规律", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(prediction.reasoning)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("建议继续观察记录，暂不提供预测", comment: ""))
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    
    /// 置信度对应颜色
    private func confidenceColor(_ confidence: CycleConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .gray
        case .unknown: return .gray
        case .anomalous: return .red
        }
    }
    
    /// 获取品种周期参考范围
    private func getSpeciesReferenceRange() -> (min: Int, max: Int)? {
        switch selectedCycleType {
        case .EGG_LAYING:
            return SpeciesDataService.shared.getIncubationDaysRange(for: bird.species)
        case .BATHING:
            return (1, 14)  // 洗澡周期默认参考值
        }
    }
    
    // MARK: - 数据加载
    
    /// P0 修复：捕获当前 bird.id 防止快速切换鸟时数据污染
    private func loadCycles() async {
        isLoading = true
        let currentBirdId = bird.id  // 捕获当前 bird.id
        
        // 离线时从本地加载
        if !offlineService.isOnline {
            await MainActor.run {
                // P0 修复：确认 bird 未切换
                guard currentBirdId == bird.id else {
                    print("⚠️ 鸟已切换，忽略过期的本地数据")
                    return
                }
                let localCycles = offlineService.getCycles(for: String(bird.id))
                cycles = localCycles.map { $0.toBirdCycleRecord() }
                activeCycles = validateAndFilterActiveCycles(cycles.filter { $0.isActive })
                isLoading = false
                loadError = nil
            }
            return
        }
        
        do {
            async let cyclesTask = ApiService.shared.getCycles(birdId: bird.id)
            async let activeTask = ApiService.shared.getActiveCycles(birdId: bird.id)
            
            let (allCycles, active) = try await (cyclesTask, activeTask)
            await MainActor.run {
                // P0 修复：确认 bird 未切换
                guard currentBirdId == bird.id else {
                    print("⚠️ 鸟已切换，忽略过期的网络数据")
                    return
                }
                cycles = allCycles
                // P1 修复：校验不变量，确保同类型最多一个活跃周期
                activeCycles = validateAndFilterActiveCycles(active)
                isLoading = false
                loadError = nil
                
                // 更新本地缓存
                offlineService.updateCyclesFromServer(allCycles, for: String(bird.id), speciesName: bird.species)
            }
        } catch {
            // 网络失败时尝试从本地加载
            await MainActor.run {
                guard currentBirdId == bird.id else { return }
                let localCycles = offlineService.getCycles(for: String(bird.id))
                if !localCycles.isEmpty {
                    cycles = localCycles.map { $0.toBirdCycleRecord() }
                    activeCycles = validateAndFilterActiveCycles(cycles.filter { $0.isActive })
                    loadError = nil
                } else {
                    loadError = NSLocalizedString("加载周期记录失败，请检查网络连接", comment: "")
                }
                isLoading = false
            }
        }
    }
    
    /// P1 修复：校验不变量 - 同类型最多只能有一个活跃周期
    private func validateAndFilterActiveCycles(_ cycles: [BirdCycleRecord]) -> [BirdCycleRecord] {
        let grouped = Dictionary(grouping: cycles) { $0.cycleType }
        var result: [BirdCycleRecord] = []
        
        for (type, typeCycles) in grouped {
            if typeCycles.count > 1 {
                print("⚠️ 数据异常：\(type.displayName) 存在 \(typeCycles.count) 个活跃周期，仅保留最新一条")
                // 按开始日期排序，保留最新的
                if let newest = typeCycles.sorted(by: { $0.startDate > $1.startDate }).first {
                    result.append(newest)
                }
            } else if let single = typeCycles.first {
                result.append(single)
            }
        }
        
        return result
    }
    
    private func endCycle(_ cycle: BirdCycleRecord) async {
        // 离线时使用本地结束
        if !offlineService.isOnline {
            // 查找对应的本地记录
            let localCycles = offlineService.getCycles(for: String(bird.id))
            if let localCycle = localCycles.first(where: { $0.serverId == Int(cycle.id) || $0.toBirdCycleRecord().startDate == cycle.startDate }) {
                offlineService.endCycle(localId: localCycle.localId, endDate: Date())
                await MainActor.run {
                    if let index = cycles.firstIndex(where: { $0.id == cycle.id }) {
                        var updated = cycles[index]
                        updated.endDate = Date()
                        cycles[index] = updated
                    }
                    activeCycles.removeAll { $0.id == cycle.id }
                }
            }
            return
        }
        
        do {
            let updated = try await ApiService.shared.endCycle(cycleId: cycle.id, endDate: Date())
            await MainActor.run {
                if let index = cycles.firstIndex(where: { $0.id == cycle.id }) {
                    cycles[index] = updated
                }
                activeCycles.removeAll { $0.id == cycle.id }
            }
        } catch {
            print("结束周期失败: \(error)")
        }
    }
    
    // MARK: - 格式化辅助
    
    private func formatDate(_ date: Date) -> String {
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("M月d日", comment: "")
        formatter.timeZone = DateFormatters.chinaTimeZone
        formatter.locale = DateFormatters.posixLocale
        return formatter.string(from: date)
    }
}

// MARK: - 子视图

struct ActiveCycleCard: View {
    let cycle: BirdCycleRecord
    let onEnd: () async -> Void
    
    @State private var isEnding = false
    
    var body: some View {
        HStack {
            Image(systemName: cycle.cycleType.icon)
                .font(.title2)
                .foregroundColor(colorForType(cycle.cycleType))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(cycle.cycleType.displayName)进行中")
                    .font(.headline)
                Text("第 \(cycle.durationDays) 天")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                isEnding = true
                Task {
                    await onEnd()
                    isEnding = false
                }
            } label: {
                Text(isEnding ? "..." : NSLocalizedString("结束", comment: ""))
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(colorForType(cycle.cycleType).opacity(0.1))
                    .foregroundColor(colorForType(cycle.cycleType))
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isEnding)
        }
        .padding(.vertical, 4)
    }
    
    private func colorForType(_ type: CycleType) -> Color {
        switch type {
        case .EGG_LAYING:
            return .pink
        case .BATHING:
            return .blue
        }
    }
}

struct CycleHistoryRow: View {
    let cycle: BirdCycleRecord
    
    var body: some View {
        HStack {
            // P1 BIO-01 修复：异常周期标记
            if cycle.isAnomalous {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(formatDateRange())
                        .font(.body)
                    
                    // P1 BIO-01 修复：显示异常类型
                    if cycle.isAnomalous, let desc = cycle.anomalyDescription {
                        Text("(\(desc))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                if let notes = cycle.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if cycle.isActive {
                    Text(NSLocalizedString("进行中", comment: ""))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else {
                    Text("\(cycle.durationDays) 天")
                        .font(.subheadline)
                        .foregroundColor(cycle.isAnomalous ? .orange : .secondary)
                }
                
                if let eggCount = cycle.eggCount {
                    HStack(spacing: 2) {
                        Label("\(eggCount)", systemImage: "oval.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        // P1 M4-01 修复：显示孵化数及校验
                        if let hatched = cycle.hatchedCount {
                            Text("→ \(hatched)")
                                .font(.caption)
                                .foregroundColor(hatched > eggCount ? .red : .secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func formatDateRange() -> String {
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.timeZone = DateFormatters.chinaTimeZone
        formatter.locale = DateFormatters.posixLocale
        let start = formatter.string(from: cycle.startDate)
        if let end = cycle.endDate {
            return "\(start) - \(formatter.string(from: end))"
        }
        return "\(start) - 至今"
    }
}

// MARK: - 添加周期视图（全屏导航页面）

struct AddCycleView: View {
    let bird: Bird
    let cycleType: CycleType
    let onAdd: (BirdCycleRecord) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var offlineService = OfflineDataService.shared
    
    @State private var selectedType: CycleType
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var isSaving = false
    @State private var showDateError = false
    @State private var dateErrorMessage = ""
    
    init(bird: Bird, cycleType: CycleType, onAdd: @escaping (BirdCycleRecord) -> Void) {
        self.bird = bird
        self.cycleType = cycleType
        self.onAdd = onAdd
        _selectedType = State(initialValue: cycleType)
    }
    
    private var availableTypes: [CycleType] {
        // 母鸟：产蛋 + 洗澡
        if bird.gender == "FEMALE" {
            return [.EGG_LAYING, .BATHING]
        } else {
            // 公鸟/未知：仅洗澡
            return [.BATHING]
        }
    }
    
    /// 日期校验
    private var isDateValid: Bool {
        // 开始日期不能晚于今天
        return startDate <= Date()
    }
    
    var body: some View {
        Form {
            Section(NSLocalizedString("周期类型", comment: "")) {
                Picker(NSLocalizedString("类型", comment: ""), selection: $selectedType) {
                    ForEach(availableTypes, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section {
                DatePicker(NSLocalizedString("开始日期", comment: ""), selection: $startDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            } header: {
                Text(NSLocalizedString("开始日期", comment: ""))
            } footer: {
                if !isDateValid {
                    Text(NSLocalizedString("开始日期不能晚于今天", comment: ""))
                        .foregroundColor(.red)
                }
            }
            
            Section(NSLocalizedString("备注（可选）", comment: "")) {
                TextField(NSLocalizedString("备注", comment: ""), text: $notes)
            }
        }
        .themedNavigationBar(title: NSLocalizedString("开始新周期", comment: ""))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.save) {
                    saveCycle()
                }
                .disabled(isSaving || !isDateValid)
                .foregroundColor(themeManager.primaryColor)
            }
        }
        .alert(NSLocalizedString("日期错误", comment: ""), isPresented: $showDateError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) { }
        } message: {
            Text(dateErrorMessage)
        }
    }
    
    private func saveCycle() {
        // 二次校验日期
        guard isDateValid else {
            dateErrorMessage = NSLocalizedString("开始日期不能晚于今天", comment: "")
            showDateError = true
            return
        }
        
        isSaving = true
        let request = CreateCycleRequest(
            cycleType: selectedType,
            startDate: startDate,
            notes: notes.isEmpty ? nil : notes
        )
        
        // 离线时保存到本地
        if !offlineService.isOnline {
            var localCycle = LocalCycleRecord(
                birdLocalId: String(bird.id),
                cycleType: selectedType,
                startDate: startDate,
                speciesName: bird.species
            )
            localCycle.notes = notes.isEmpty ? nil : notes
            offlineService.addCycle(localCycle)
            
            // 创建一个临时的 BirdCycleRecord 用于 UI 更新
            let tempCycle = localCycle.toBirdCycleRecord()
            onAdd(tempCycle)
            dismiss()
            return
        }
        
        Task {
            do {
                let newCycle = try await ApiService.shared.createCycle(birdId: bird.id, request: request)
                await MainActor.run {
                    onAdd(newCycle)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    dateErrorMessage = NSLocalizedString("保存失败，请重试", comment: "")
                    showDateError = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PhysiologicalCycleView(bird: Bird(
            id: 1,
            nickname: NSLocalizedString("小白", comment: ""),
            species: NSLocalizedString("虎皮鹦鹉", comment: ""),
            gender: "FEMALE",
            hatchDate: nil,
            adoptionDate: nil,
            birthdayType: nil,
            deathDate: nil,
            featherColor: nil,
            source: nil,
            avatarUrl: nil,
            notes: nil,
            medicalHistory: nil,
            fatherInfo: nil,
            motherInfo: nil,
            legRingId: nil,
            ageMonths: 12,
            isDeleted: nil,
            deletedAt: nil,
            isLost: nil,
            lostDate: nil,
            lostLocation: nil,
            lostPostId: nil,
            ownerId: nil,
            ownerName: nil,
            isShared: nil,
            sharedWith: nil,
            shareRole: nil,
            isOwner: nil,
            isCoupleShared: nil
        ))
    }
}
