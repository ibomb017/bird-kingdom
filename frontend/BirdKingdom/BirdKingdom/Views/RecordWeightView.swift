import SwiftUI

struct RecordWeightView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let inputBirds: [Bird]
    private let preselectedIndex: Int?
    
    @State private var birds: [Bird] = []
    @State private var selectedBirdIndex: Int = 0
    @State private var weightText: String = ""
    @State private var recordDate: Date = Date()
    @State private var note: String = ""
    @State private var isSaving: Bool = false
    @State private var isLoadingBirds: Bool = false
    
    init(birds: [Bird] = [], preselectedIndex: Int? = nil) {
        self.inputBirds = birds
        self.preselectedIndex = preselectedIndex
    }
    
    var body: some View {
        Form {
            if isLoadingBirds {
                Section {
                    ProgressView("加载小鸟列表...")
                }
            } else if birds.isEmpty {
                Section {
                    Text("暂无鸟档案，请先添加一只小鸟")
                        .foregroundColor(.secondary)
                }
            } else {
                Section {
                    Picker("请选择小鸟", selection: $selectedBirdIndex) {
                        ForEach(birds.indices, id: \.self) { index in
                            Text(birds[index].nickname).tag(index)
                        }
                    }
                    DatePicker("记录时间", selection: $recordDate)
                }
                
                Section("体重") {
                    TextField("例如：18.5", text: $weightText)
                        .keyboardType(.decimalPad)
                }
                
                Section("备注（可选）") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                }
            }
        }
        .navigationTitle("记录体重")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { saveWeight() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
        .task {
            await setupBirds()
        }
    }
    
    private var canSave: Bool {
        guard !isSaving else { return false }
        guard !birds.isEmpty else { return false }
        return Double(weightText) != nil
    }
    
    private func setupBirds() async {
        if !inputBirds.isEmpty {
            birds = inputBirds
            if let pre = preselectedIndex, birds.indices.contains(pre) {
                selectedBirdIndex = pre
            }
            return
        }
        isLoadingBirds = true
        do {
            birds = try await ApiService.shared.getBirds()
        } catch {
            print("加载小鸟失败: \(error)")
        }
        isLoadingBirds = false
    }
    
    private func saveWeight() {
        guard canSave else { return }
        isSaving = true
        // TODO: 调用 API 保存体重记录（作为日志或单独表）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        RecordWeightView()
    }
}
