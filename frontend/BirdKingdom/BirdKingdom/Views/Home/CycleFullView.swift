import SwiftUI

/// 记录页面 - 产蛋和洗澡记录（与体重趋势页面统一风格）
struct CycleFullView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var cycles: [BirdCycleRecord] = []
    @State private var birds: [Bird] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedBirdIndex: Int = 0
    @State private var showAddRecord = false
    @State private var showDeleteAlert = false
    @State private var recordToDelete: BirdCycleRecord?
    @State private var calendarSelectedDate: Date? = nil
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    private var selectedBird: Bird? {
        guard selectedBirdIndex > 0, selectedBirdIndex <= birds.count else { return nil }
        return birds[selectedBirdIndex - 1]
    }
    
    private var isFemale: Bool {
        selectedBird?.gender == "FEMALE"
    }
    
    private var filteredCycles: [BirdCycleRecord] {
        let baseCycles = cycles
        
        if selectedBirdIndex == 0 {
            return baseCycles
        } else {
            guard selectedBirdIndex > 0, selectedBirdIndex <= birds.count else {
                return baseCycles
            }
            let birdId = birds[selectedBirdIndex - 1].id
            return baseCycles.filter { $0.birdId == birdId }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 鸟筛选器
            if !birds.isEmpty {
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
                
                Divider()
            }
            
            // 内容区域
            Group {
                if isLoading {
                    UnifiedStateView.loading
                } else if let error = errorMessage {
                    UnifiedStateView.error(error) {
                        Task { await loadData() }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 日历视图
                            calendarSection
                                .padding(.horizontal, 16)
                            
                            // 记录列表
                            recordsSection
                                .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle(L10n.healthRecords)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddRecord = true
                } label: {
                    Text(NSLocalizedString("添加", comment: ""))
                        .foregroundColor(primaryColor)
                }
            }
        }
        .sheet(isPresented: $showAddRecord) {
            AddRecordSheet(
                birds: birds,
                preselectedBirdId: selectedBird?.id
            ) { newRecord in
                cycles.insert(newRecord, at: 0)
            }
        }
        .alert(NSLocalizedString("删除记录", comment: ""), isPresented: $showDeleteAlert) {
            Button(L10n.cancel, role: .cancel) {
                recordToDelete = nil
            }
            Button(L10n.delete, role: .destructive) {
                if let record = recordToDelete {
                    deleteRecord(record)
                }
            }
        } message: {
            if let record = recordToDelete {
                Text("确定要删除 \(formatDate(record.startDate)) 的\(record.cycleType.displayName)记录吗？此操作不可撤销。")
            }
        }
        .task {
            await loadData()
        }
        .hidesTabBar()
    }
    
    // MARK: - 日历区域
    
    private var calendarSection: some View {
        Group {
            if selectedBirdIndex == 0 {
                Text(NSLocalizedString("请选择一只小鸟查看日历", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
            } else {
                CycleCalendarView(
                    cycles: filteredCycles,
                    showEggLaying: isFemale,
                    selectedDate: $calendarSelectedDate
                )
            }
        }
    }
    
    // MARK: - 记录列表（支持左滑删除）
    
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("记录列表", comment: ""))
                .font(.headline)
            
            if filteredCycles.isEmpty {
                Text(NSLocalizedString("暂无记录", comment: ""))
                // 恢复默认文本样式
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                // 使用 List 支持 swipeActions
                List {
                    ForEach(filteredCycles.sorted { $0.startDate > $1.startDate }) { record in
                        recordRow(record)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    recordToDelete = record
                                    showDeleteAlert = true
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(min(filteredCycles.count, 5)) * 64)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCard)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
    
    private func recordRow(_ record: BirdCycleRecord) -> some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(record.cycleType == .EGG_LAYING ? Color.pink.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: record.cycleType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(record.cycleType == .EGG_LAYING ? .pink : .blue)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.cycleType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if selectedBirdIndex == 0 {
                        let birdName = birds.first { $0.id == record.birdId }?.nickname ?? L10n.unknownGender
                        Text("· \(birdName)")
                            .font(.caption)
                            .foregroundColor(primaryColor)
                    }
                }
                
                Text(formatDate(record.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 显示备注（如果有）
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
    
    // MARK: - 辅助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月d日", comment: "")
        formatter.timeZone = DateFormatters.chinaTimeZone
        return formatter.string(from: date)
    }
    
    private func loadData() async {
        guard AuthService.shared.isLoggedIn else {
            cycles = []
            birds = []
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBirds = try await ApiService.shared.getBirds()
            birds = fetchedBirds
            
            var allCycles: [BirdCycleRecord] = []
            for bird in fetchedBirds {
                if let birdCycles = try? await ApiService.shared.getCycles(birdId: bird.id) {
                    allCycles.append(contentsOf: birdCycles)
                }
            }
            cycles = allCycles
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func deleteRecord(_ record: BirdCycleRecord) {
        Task {
            do {
                try await ApiService.shared.deleteCycle(cycleId: record.id)
                await MainActor.run {
                    cycles.removeAll { $0.id == record.id }
                    recordToDelete = nil
                }
            } catch {
                print("删除记录失败: \(error)")
            }
        }
    }
}

// MARK: - 添加记录 Sheet（完整表单，带备注）

struct AddRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let birds: [Bird]
    let preselectedBirdId: Int64?
    let onAdd: (BirdCycleRecord) -> Void
    
    @State private var selectedBirdId: Int64?
    @State private var recordDate: Date = Date()
    @State private var selectedType: CycleType = .BATHING
    @State private var notes: String = ""
    @State private var isSaving = false
    
    init(birds: [Bird], preselectedBirdId: Int64? = nil, onAdd: @escaping (BirdCycleRecord) -> Void) {
        self.birds = birds
        self.preselectedBirdId = preselectedBirdId
        self.onAdd = onAdd
        self._selectedBirdId = State(initialValue: preselectedBirdId ?? birds.first?.id)
    }
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    private var selectedBird: Bird? {
        guard let birdId = selectedBirdId else { return nil }
        return birds.first { $0.id == birdId }
    }
    
    private var isFemale: Bool {
        selectedBird?.gender == "FEMALE"
    }
    
    private var canSave: Bool {
        selectedBirdId != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 1. 选择鸟儿
                    Picker(NSLocalizedString("选择鸟儿", comment: ""), selection: $selectedBirdId) {
                        ForEach(birds, id: \.id) { bird in
                            Text(bird.nickname).tag(bird.id as Int64?)
                        }
                    }
                    
                    // 2. 日期选择
                    DatePicker(
                        NSLocalizedString("日期", comment: ""),
                        selection: $recordDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    
                    // 3. 类型选择 (标准列表样式，无图标/形状)
                    Picker(NSLocalizedString("类型", comment: ""), selection: $selectedType) {
                        Text(NSLocalizedString("洗澡", comment: "")).tag(CycleType.BATHING)
                        if isFemale {
                            Text(NSLocalizedString("产蛋", comment: "")).tag(CycleType.EGG_LAYING)
                        }
                    }
                }
                
                // 4. 备注
                Section {
                    TextField(NSLocalizedString("添加备注（可选）", comment: ""), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(NSLocalizedString("备注", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("添加记录", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveRecord()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(L10n.save).fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onChange(of: selectedBirdId) { _, _ in
                if !isFemale {
                    selectedType = .BATHING
                }
            }
        }
    }
    
    private func saveRecord() {
        guard let birdId = selectedBirdId else { return }
        
        isSaving = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                let request = CreateCycleRequest(
                    cycleType: selectedType,
                    startDate: recordDate,
                    notes: notes.isEmpty ? nil : notes
                )
                let newRecord = try await ApiService.shared.createCycle(birdId: birdId, request: request)
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                await MainActor.run {
                    onAdd(newRecord)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    CycleFullView()
}
