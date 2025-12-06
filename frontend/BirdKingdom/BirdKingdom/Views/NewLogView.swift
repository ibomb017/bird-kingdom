import SwiftUI

struct NewLogView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var birds: [Bird] = []
    @State private var selectedBirdIndex: Int = 0
    @State private var logDate: Date = Date()
    @State private var weightText: String = ""
    @State private var summary: String = ""
    @State private var isSaving: Bool = false
    @State private var isLoadingBirds: Bool = false
    @State private var errorMessage: String?
    
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
                    DatePicker("时间", selection: $logDate)
                }
                
                Section("日志内容") {
                    TextEditor(text: $summary)
                        .frame(minHeight: 120)
                        .overlay(
                            Group {
                                if summary.isEmpty {
                                    Text("记录今天的观察、喂食、精神状态等")
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section("体重（可选）") {
                    TextField("例如：18.5", text: $weightText)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .navigationTitle("写新日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { saveLog() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
        .task {
            await loadBirdsIfNeeded()
        }
    }
    
    private var canSave: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !birds.isEmpty && !isSaving
    }
    
    private func loadBirdsIfNeeded() async {
        guard birds.isEmpty && !isLoadingBirds else { return }
        isLoadingBirds = true
        errorMessage = nil
        do {
            birds = try await ApiService.shared.getBirds()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingBirds = false
    }
    
    private func saveLog() {
        guard canSave else { return }
        isSaving = true
        let bird = birds[selectedBirdIndex]
        let weightValue = Double(weightText)
        let notes = summary.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                _ = try await ApiService.shared.createLog(
                    birdId: bird.id,
                    date: logDate,
                    weight: weightValue,
                    notes: notes
                )
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("创建日志失败: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewLogView()
    }
}
