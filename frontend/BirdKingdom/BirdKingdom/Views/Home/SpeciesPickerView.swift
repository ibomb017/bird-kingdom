import SwiftUI

/// 品种选择器 - 两级导航（先选分类，再选具体品种）
struct SpeciesPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @Binding var selectedSpecies: String
    @Binding var weightMin: Double?
    @Binding var weightMax: Double?
    
    @State private var categories: [SpeciesCategory] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    UnifiedStateView.loading
                } else if let error = errorMessage {
                    UnifiedStateView.error(error) {
                        loadSpecies()
                    }
                } else {
                    categoryList
                }
            }
            .themedNavigationBar(title: NSLocalizedString("选择品种", comment: ""), onDismiss: { dismiss() })
        }
        .onAppear {
            loadSpecies()
        }
    }
    
    private var categoryList: some View {
        List {
            // 自定义输入选项
            Section {
                NavigationLink {
                    CustomSpeciesInputView(
                        selectedSpecies: $selectedSpecies,
                        weightMin: $weightMin,
                        weightMax: $weightMax,
                        onSelect: { dismiss() }
                    )
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("自定义品种", comment: ""))
                        Spacer()
                        if !selectedSpecies.isEmpty && !isKnownSpecies(selectedSpecies) {
                            Text(selectedSpecies)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // 品种分类
            ForEach(categories) { category in
                Section(header: Text(category.name)) {
                    ForEach(category.species) { species in
                        Button {
                            selectSpecies(species)
                        } label: {
                            HStack {
                                Text(species.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(Int(species.weightMin))-\(Int(species.weightMax))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if selectedSpecies == species.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(primaryColor)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadSpecies() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await ApiService.shared.getSpecies()
                await MainActor.run {
                    categories = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = String(format: NSLocalizedString("加载失败: %@", comment: ""), error.localizedDescription)
                    isLoading = false
                }
            }
        }
    }
    
    private func selectSpecies(_ species: BirdSpecies) {
        selectedSpecies = species.name
        weightMin = species.weightMin
        weightMax = species.weightMax
        dismiss()
    }
    
    private func isKnownSpecies(_ name: String) -> Bool {
        categories.flatMap { $0.species }.contains { $0.name == name }
    }
}

/// 自定义品种输入视图
struct CustomSpeciesInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSpecies: String
    @Binding var weightMin: Double?
    @Binding var weightMax: Double?
    let onSelect: () -> Void
    
    @State private var customName = ""
    @State private var weightMinText = ""
    @State private var weightMaxText = ""
    @FocusState private var isFocused: Bool
    
    private var primaryColor: Color { ThemeManager.shared.primaryColor }
    
    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("输入品种名称", comment: ""))) {
                TextField(NSLocalizedString("例如：文鸟、八哥", comment: ""), text: $customName)
                    .focused($isFocused)
            }
            
            Section(header: Text(NSLocalizedString("健康体重范围（可选）", comment: "")), footer: Text(NSLocalizedString("填写后可在体重趋势图表中显示健康区间", comment: ""))) {
                HStack {
                    TextField(NSLocalizedString("下限", comment: ""), text: $weightMinText)
                        .keyboardType(.decimalPad)
                    Text("~")
                        .foregroundColor(.secondary)
                    TextField(NSLocalizedString("上限", comment: ""), text: $weightMaxText)
                        .keyboardType(.decimalPad)
                    Text(L10n.weightUnit)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button(L10n.confirm) {
                    if !customName.trimmingCharacters(in: .whitespaces).isEmpty {
                        selectedSpecies = customName.trimmingCharacters(in: .whitespaces)
                        // 设置体重范围（如果填写了）
                        if let min = Double(weightMinText), min > 0 {
                            weightMin = min
                        }
                        if let max = Double(weightMaxText), max > 0 {
                            weightMax = max
                        }
                        onSelect()
                    }
                }
                .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                .foregroundColor(customName.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : primaryColor)
            }
        }
        .navigationTitle(NSLocalizedString("自定义品种", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(primaryColor.opacity(0.08), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(primaryColor)
        .background(Color.adaptiveCard)
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    SpeciesPickerView(
        selectedSpecies: .constant(NSLocalizedString("虎皮鹦鹉", comment: "")),
        weightMin: .constant(30),
        weightMax: .constant(45)
    )
}
