import SwiftUI

/// 日志编辑视图 - 支持从首页右滑编辑进入
struct EditLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    let log: BirdLog
    let onComplete: ((BirdLog) -> Void)?
    
    @State private var logDate: Date
    @State private var weight: String
    @State private var mood: String
    @State private var notes: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccessToast = false
    
    init(log: BirdLog, onComplete: ((BirdLog) -> Void)? = nil) {
        self.log = log
        self.onComplete = onComplete
        _logDate = State(initialValue: log.logDate)
        _weight = State(initialValue: log.weight.map { String(format: "%.1f", $0) } ?? "")
        // 将存储的枚举值转换为中文显示
        _mood = State(initialValue: Self.moodEnumToText(log.mood))
        _notes = State(initialValue: log.notes ?? "")
    }
    
    /// 将心情枚举值转换为中文显示文本
    private static func moodEnumToText(_ mood: String?) -> String {
        guard let mood = mood else { return "" }
        switch mood {
        case "HAPPY": return NSLocalizedString("开心", comment: "")
        case "NORMAL": return NSLocalizedString("正常", comment: "")
        case "QUIET": return NSLocalizedString("安静", comment: "")
        case "ANXIOUS": return NSLocalizedString("焦虑", comment: "")
        default: return mood  // 已经是中文或自定义文本，直接返回
        }
    }
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        Form {
            // MARK: - 小鸟信息
            Section {
                HStack {
                    Image(systemName: "bird.fill")
                        .foregroundColor(primaryColor)
                    Text(NSLocalizedString("小鸟", comment: ""))
                        .fontWeight(.semibold)
                    Spacer()
                    Text(log.birdName)
                        .foregroundColor(.secondary)
                }
                
                DatePicker(NSLocalizedString("记录时间", comment: ""), selection: $logDate)
                    .tint(primaryColor)
            }
            
            // MARK: - 日志内容
            Section {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(primaryColor)
                    Text(NSLocalizedString("日志内容", comment: ""))
                        .fontWeight(.semibold)
                }
                
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
            
            // MARK: - 图片预览（只读）
            if let imageUrls = log.imageUrls, !imageUrls.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("照片记录", comment: ""))
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: NSLocalizedString("%d张", comment: ""), imageUrls.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(imageUrls, id: \.self) { urlString in
                                AsyncImage(url: URL(string: urlString)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    default:
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                ProgressView().scaleEffect(0.6)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // MARK: - 情绪与体重
            Section {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(primaryColor)
                    Text(NSLocalizedString("状态记录", comment: ""))
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Image(systemName: "face.smiling")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    TextField(NSLocalizedString("情绪状态（如：开心、安静、焦虑）", comment: ""), text: $mood)
                }
                
                HStack {
                    Image(systemName: "scalemass")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    TextField(L10n.weight, text: $weight)
                        .keyboardType(.decimalPad)
                    Text(L10n.weightUnit)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(NSLocalizedString("编辑日志", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(L10n.save) {
                    saveLog()
                }
                .disabled(isSubmitting)
                .foregroundColor(isSubmitting ? .gray : themeManager.primaryColor)
                .fontWeight(.semibold)
            }
        }
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(NSLocalizedString("保存中...", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial)
                    .cornerRadius(16)
                }
            }
            
            if showSuccessToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(NSLocalizedString("保存成功", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showSuccessToast)
    }
    
    private func saveLog() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                let weightValue = Double(weight)
                
                try await ApiService.shared.patchLog(
                    id: log.id,
                    logDate: logDate,
                    weight: weightValue,
                    mood: mood.isEmpty ? nil : mood,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessToast = true
                    
                    // 短暂显示成功提示后关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // 构建更新后的日志对象传回上一页
                        let updatedLog = BirdLog(
                            id: log.id,
                            birdId: log.birdId,
                            birdName: log.birdName,
                            logDate: logDate,
                            weight: Double(weight),
                            feedAmount: log.feedAmount,
                            waterAmount: log.waterAmount,
                            mood: mood.isEmpty ? nil : mood,
                            behavior: log.behavior,
                            isMolting: log.isMolting,
                            isBreeding: log.isBreeding,
                            temperature: log.temperature,
                            humidity: log.humidity,
                            isCleaned: log.isCleaned,
                            healthScore: log.healthScore,
                            notes: notes.isEmpty ? nil : notes,
                            createdAt: log.createdAt,
                            updatedAt: Date(),
                            imageUrls: log.imageUrls
                        )
                        
                        onComplete?(updatedLog)
                        dismiss()
                        
                        // 发送刷新通知（作为备份）
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshLogs"), object: nil)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = String(format: NSLocalizedString("保存失败: %@", comment: ""), error.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditLogView(
            log: BirdLog(
                id: 1,
                birdId: 1,
                birdName: NSLocalizedString("测试鸟", comment: ""),
                logDate: Date(),
                weight: 35.5,
                feedAmount: nil,
                waterAmount: nil,
                mood: "HAPPY",
                behavior: nil,
                isMolting: nil,
                isBreeding: nil,
                temperature: nil,
                humidity: nil,
                isCleaned: nil,
                healthScore: nil,
                notes: NSLocalizedString("这是一条测试日志", comment: ""),
                createdAt: Date()
            )
        )
    }
}
