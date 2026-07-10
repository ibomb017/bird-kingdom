import SwiftUI

struct RecordWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var offlineService = OfflineDataService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    private let inputBirds: [Bird]
    private let preselectedIndex: Int?
    
    @State private var birds: [Bird] = []
    @State private var localBirds: [LocalBird] = []
    @State private var selectedBirdIndex: Int = 0
    @State private var weightText: String = ""
    @State private var recordDate: Date = Date()
    @State private var note: String = ""
    @State private var isSaving: Bool = false
    @State private var isLoadingBirds: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var hasAttemptedSave: Bool = false  // P0 改进：记录是否尝试过保存
    @State private var scrollTarget: FormField? = nil  // P0 改进：用于滚动到未填写的表单项
    
    // 表单字段 ID
    private enum FormField: Hashable {
        case weight
    }
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    init(birds: [Bird] = [], preselectedIndex: Int? = nil) {
        self.inputBirds = birds
        self.preselectedIndex = preselectedIndex
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            Form {
                if isLoadingBirds {
                    Section {
                        ProgressView(NSLocalizedString("加载小鸟列表...", comment: ""))
                    }
                } else if birds.isEmpty {
                    Section {
                        Text(NSLocalizedString("暂无鸟档案，请先添加一只小鸟", comment: ""))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // P0 改进：移除橙色警告框，改用 placeholder 变红提示
                    
                    Section {
                        Picker(NSLocalizedString("选择小鸟", comment: ""), selection: $selectedBirdIndex) {
                            ForEach(birds.indices, id: \.self) { index in
                                Text(birds[index].nickname).tag(index)
                            }
                        }
                        DatePicker(NSLocalizedString("记录时间", comment: ""), selection: $recordDate)
                    }
                    
                    Section {
                        // 体重输入框：标签 + 自定义 placeholder
                        HStack {
                            Text(L10n.weight)
                                .foregroundColor(.primary)
                            ZStack(alignment: .leading) {
                                // 自定义 placeholder：未填写时显示，保存后变红
                                if weightText.isEmpty {
                                    Text(NSLocalizedString("* 请输入体重 (克)", comment: ""))
                                        .foregroundColor(hasAttemptedSave ? .red : .secondary)
                                }
                                TextField("", text: $weightText)
                                    .keyboardType(.decimalPad)
                            }
                        }
                        .id(FormField.weight)  // 添加 ID 用于滚动定位
                        
                        // 体重范围提示（只在异常时显示）
                        if let warning = weightValidationMessage {
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Section(NSLocalizedString("备注（可选）", comment: "")) {
                        TextEditor(text: $note)
                            .frame(minHeight: 80)
                    }
                }
            }
            // P0 改进：监听 scrollTarget 变化，自动滚动到未填写的表单项
            .onChange(of: scrollTarget) { _, target in
                if let target = target {
                    withAnimation {
                        scrollProxy.scrollTo(target, anchor: .center)
                    }
                    // 清除目标，避免重复滚动
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollTarget = nil
                    }
                }
            }
        }  // ScrollViewReader 结束
        .scrollContentBackground(.hidden)
        .themedBackground()
        .themedNavigationBar(title: NSLocalizedString("记录体重", comment: ""))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // P0 改进：保存按钮始终可点击，验证在点击时进行
                Button(L10n.save) { saveWeight() }
                    .fontWeight(.semibold)
                    .foregroundColor(isSaving ? .gray : primaryColor)
                    .disabled(isSaving)
            }
        }
        .task {
            await setupBirds()
        }
        .alert(L10n.hintTitle, isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var weightValidationMessage: String? {
        guard let weight = Double(weightText) else { return nil }
        if weight <= 0 {
            return NSLocalizedString("⚠️ 体重必须大于 0", comment: "")
        }
        if weight > 3000 {
            return NSLocalizedString("⚠️ 体重超过 3kg，请确认输入是否正确", comment: "")
        }
        return nil
    }
    
    private func setupBirds() async {
        if !inputBirds.isEmpty {
            birds = inputBirds
            if let pre = preselectedIndex, birds.indices.contains(pre) {
                selectedBirdIndex = pre
            }
        }
        
        localBirds = offlineService.getAllBirds()
        
        if inputBirds.isEmpty {
            isLoadingBirds = true
            if offlineService.isOnline {
                do {
                    birds = try await ApiService.shared.getBirds()
                } catch {
                    print("加载小鸟失败: \(error)")
                }
            }
            isLoadingBirds = false
        }
    }
    
    private func saveWeight() {
        // P0 改进：标记已尝试保存
        hasAttemptedSave = true
        
        guard AuthService.shared.isLoggedIn else {
            errorMessage = NSLocalizedString("请先登录后再记录体重", comment: "")
            showError = true
            return
        }
        
        // P0 改进：验证必填项并自动滚动
        if weightText.isEmpty {
            scrollTarget = .weight
            return
        }
        
        guard let weight = Double(weightText), weight > 0 else {
            scrollTarget = .weight
            return
        }
        
        guard !birds.isEmpty, selectedBirdIndex < birds.count else {
            errorMessage = NSLocalizedString("请选择一只小鸟", comment: "")
            showError = true
            return
        }
        
        isSaving = true
        
        let selectedBird = birds[selectedBirdIndex]
        let birdId = Int(selectedBird.id)
        
        // 备注内容：如果用户填写了备注则使用，否则留空
        let noteContent = note.isEmpty ? nil : note
        
        print("📝 保存体重: birdId=\(birdId), weight=\(weight)g")
        
        // 判断是否需要离线保存
        if !offlineService.isOnline {
            // 离线模式：保存到本地
            let birdLocalId = "server_\(selectedBird.id)"
            let weightRecord = LocalWeightRecord(birdLocalId: birdLocalId, weight: weight, recordDate: recordDate)
            offlineService.addWeight(weightRecord)
            
            print("📤 离线保存体重记录: birdLocalId=\(birdLocalId)")
            
            isSaving = false
            NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshLogs"), object: nil)
            dismiss()
        } else {
            // 在线模式：直接调用 API
            // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
            var weightData: [String: Any] = [
                "weight": weight,
                "recordDate": DateFormatters.toAPIDateTime(recordDate)
            ]
            
            if let notes = noteContent {
                weightData["notes"] = notes
            }
            
            print("📤 调用 API 保存体重: birdId=\(birdId), data=\(weightData)")
            
            ApiService.shared.addBirdWeight(birdId: birdId, data: weightData) { result in
                switch result {
                case .success(let response):
                    print("✅ 体重保存成功: \(response)")
                    isSaving = false
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshLogs"), object: nil)
                    dismiss()
                case .failure(let error):
                    print("❌ 体重保存失败: \(error)")
                    // 失败时尝试离线保存
                    let birdLocalId = "server_\(selectedBird.id)"
                    let record = LocalWeightRecord(birdLocalId: birdLocalId, weight: weight, recordDate: recordDate)
                    offlineService.addWeight(record, autoSync: true)
                    
                    print("📤 API失败，转为离线保存: birdLocalId=\(birdLocalId)")
                    
                    isSaving = false
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshLogs"), object: nil)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    RecordWeightView()
}
