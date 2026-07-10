import SwiftUI
import PhotosUI

struct NewLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var offlineService = OfflineDataService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    // Fix: 添加保存完成后的回调，用于刷新父视图
    var onSave: (() -> Void)?
    
    // 预选小鸟 ID（从小鸟详情页进入时使用）
    private let preselectedBirdId: Int64?
    
    init(preselectedBirdId: Int64? = nil, onSave: (() -> Void)? = nil) {
        self.preselectedBirdId = preselectedBirdId
        self.onSave = onSave
    }
    
    @State private var birds: [Bird] = []
    @State private var localBirds: [LocalBird] = []
    @State private var selectedBirdIndex: Int = 0
    @State private var logDate: Date = Date()
    @State private var summary: String = ""
    @State private var isSaving: Bool = false
    @State private var isLoadingBirds: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    // 可选字段
    @State private var weightText: String = ""
    @State private var moodText: String = ""
    
    // 图片选择相关
    @State private var selectedImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showImagePicker = false
    private let maxImages = 9
    
    // P0 改进：表单验证状态
    @State private var hasAttemptedSave: Bool = false
    @State private var scrollTarget: FormField? = nil
    
    // 表单字段 ID
    private enum FormField: Hashable {
        case content
    }
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            Form {
            if isLoadingBirds {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(NSLocalizedString("加载小鸟列表...", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
            } else if birds.isEmpty && localBirds.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bird")
                                .font(.system(size: 40))
                                .foregroundColor(primaryColor.opacity(0.6))
                            Text(NSLocalizedString("暂无鸟档案", comment: ""))
                                .font(.headline)
                            Text(NSLocalizedString("请先添加一只小鸟", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                }
            } else {
                // P0 改进：移除橙色提示框，改用 placeholder 变红提示
                
                // MARK: - 选择小鸟
                Section {
                    HStack {
                        Image(systemName: "bird.fill")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("选择小鸟", comment: ""))
                            .fontWeight(.semibold)
                        Text("*")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                    
                    Picker(NSLocalizedString("请选择小鸟", comment: ""), selection: $selectedBirdIndex) {
                        ForEach(availableBirds.indices, id: \.self) { index in
                            Text(availableBirds[index].name).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    DatePicker(NSLocalizedString("记录时间", comment: ""), selection: $logDate)
                }
                
                Section {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("日志内容", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if summary.isEmpty {
                            // P0 改进：placeholder 支持变红
                            Text(NSLocalizedString("* 今天小鸟的状态怎么样？吃了什么？有什么特别的表现？", comment: ""))
                                .foregroundColor(hasAttemptedSave ? .red : .gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $summary)
                            .frame(minHeight: 100)
                            .opacity(summary.isEmpty ? 0.6 : 1)
                    }
                    .id(FormField.content)  // 添加 ID 用于滚动定位
                }
                
                // MARK: - 照片记录
                Section {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("照片记录", comment: ""))
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(selectedImages.count)/\(maxImages)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    DraggableImageGrid(
                        images: $selectedImages,
                        maxImages: maxImages,
                        primaryColor: primaryColor,
                        selectedItems: $selectedItems
                    )
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
                        TextField(NSLocalizedString("情绪状态（如：开心、安静、焦虑）", comment: ""), text: $moodText)
                    }
                    
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField(L10n.weight, text: $weightText)
                            .keyboardType(.decimalPad)
                        Text(L10n.weightUnit)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            }
            // P0 改进：监听 scrollTarget 变化，自动滚动到未填写的表单项
            .onChange(of: scrollTarget) { _, target in
                if let target = target {
                    withAnimation {
                        scrollProxy.scrollTo(target, anchor: .center)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollTarget = nil
                    }
                }
            }
        }  // ScrollViewReader 结束
        .scrollContentBackground(.hidden)
        .themedBackground()
        .themedNavigationBar(title: NSLocalizedString("写新日志", comment: ""))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // P0 改进：保存按钮始终可点击
                Button {
                    saveLog()
                } label: {
                    Text(L10n.save)
                        .fontWeight(.semibold)
                }
                .foregroundColor(isSaving ? .gray : primaryColor)
                .disabled(isSaving)
            }
        }
        .task {
            await loadBirdsIfNeeded()
        }
        .alert(L10n.hintTitle, isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(images: $selectedImages, maxCount: maxImages)
        }
        .onChange(of: selectedItems) { newItems in
            Task {
                for (index, item) in newItems.enumerated() {
                    do {
                        if let data = try await item.loadTransferable(type: Data.self) {
                            if let image = UIImage(data: data) {
                                await MainActor.run {
                                    if selectedImages.count < maxImages {
                                        selectedImages.append(image)
                                    }
                                }
                            }
                        }
                    } catch {
                        print("❌ 图片 \(index + 1) 加载错误: \(error)")
                    }
                }
                await MainActor.run {
                    selectedItems = []
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// P0 修复：校验错误信息（用于显示具体错误提示）
    private var validationError: String? {
        if birds.isEmpty && localBirds.isEmpty {
            return NSLocalizedString("请先添加一只小鸟", comment: "")
        }
        if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return NSLocalizedString("请填写日志内容", comment: "")
        }
        return nil
    }
    
    private var canSave: Bool {
        return validationError == nil && !isSaving
    }
    
    private var availableBirds: [(id: String, name: String, isLocal: Bool)] {
        var result: [(id: String, name: String, isLocal: Bool)] = []
        
        for bird in birds {
            result.append((id: String(bird.id), name: bird.nickname, isLocal: false))
        }
        
        for localBird in localBirds where localBird.serverId == nil {
            result.append((id: localBird.localId, name: localBird.nickname + NSLocalizedString(" (本地)", comment: ""), isLocal: true))
        }
        
        return result
    }
    
    // MARK: - Methods
    
    private func loadBirdsIfNeeded() async {
        guard AuthService.shared.isLoggedIn else {
            birds = []
            localBirds = []
            isLoadingBirds = false
            return
        }
        
        guard birds.isEmpty && localBirds.isEmpty && !isLoadingBirds else { return }
        isLoadingBirds = true
        errorMessage = ""
        
        localBirds = offlineService.getAllBirds()
        
        if offlineService.isOnline {
            do {
                birds = try await ApiService.shared.getBirds()
            } catch {
                if localBirds.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        // 根据预选的小鸟 ID 设置默认选中索引
        if let preselectedId = preselectedBirdId {
            let allBirds = availableBirds
            if let index = allBirds.firstIndex(where: { $0.id == String(preselectedId) }) {
                selectedBirdIndex = index
            }
        }
        
        isLoadingBirds = false
    }
    
    private func saveLog() {
        // P0 改进：标记已尝试保存
        hasAttemptedSave = true
        
        guard AuthService.shared.isLoggedIn else {
            errorMessage = NSLocalizedString("请先登录后再写日志", comment: "")
            showError = true
            return
        }
        
        // P0 改进：验证必填项并自动滚动
        if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scrollTarget = .content
            return
        }
        
        isSaving = true
        let notes = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let allBirds = availableBirds
        guard selectedBirdIndex < allBirds.count else {
            isSaving = false
            return
        }
        
        let selectedBird = allBirds[selectedBirdIndex]
        
        let birdLocalId: String
        let birdServerId: Int?  // 用于直接同步到服务器
        
        if selectedBird.isLocal {
            // 本地离线创建的鸟
            birdLocalId = selectedBird.id
            birdServerId = localBirds.first(where: { $0.localId == selectedBird.id })?.serverId
        } else {
            // 服务器上的鸟：使用 "server_{id}" 格式，确保 syncLog 能正确解析
            birdLocalId = "server_\(selectedBird.id)"
            birdServerId = Int(selectedBird.id)
        }
        
        let logLocalId = UUID().uuidString
        var log = LocalBirdLog(birdLocalId: birdLocalId, content: notes)
        log.localId = logLocalId
        log.logDate = logDate
        
        // 情绪状态
        let trimmedMood = moodText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMood.isEmpty {
            log.mood = trimmedMood
        }
        
        // 体重
        if let weight = Double(weightText) {
            log.weight = weight
        }
        
        // 保存图片到本地
        if !selectedImages.isEmpty {
            let imagePaths = LogImageStorage.shared.saveImages(selectedImages, for: logLocalId)
            log.localImagePaths = imagePaths
            log.imageUploadStatus = .pending
        }
        
        // P0 核心改进：有网络时先同步到服务器
        if offlineService.isOnline, let birdId = birdServerId {
            // 在线模式：先上传到服务器
            Task {
                do {
                    // 如果有图片，先上传图片
                    var imageUrls: [String] = []
                    if !log.localImagePaths.isEmpty {
                        await MainActor.run {
                            // 显示上传进度状态（可选）
                        }
                        imageUrls = try await offlineService.uploadImagesAsync(paths: log.localImagePaths)
                        log.ossURLs = imageUrls
                        log.imageUploadStatus = .success
                    }
                    
                    // 调用 API 创建日志
                    // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
                    var logData: [String: Any] = [
                        "notes": log.content ?? "",
                        "logDate": DateFormatters.toAPIDateTime(log.logDate)
                    ]
                    
                    if let weight = log.weight {
                        logData["weight"] = weight
                    }
                    if let mood = log.mood {
                        logData["mood"] = mood
                    }
                    if !imageUrls.isEmpty {
                        logData["imageUrls"] = imageUrls
                    }
                    
                    let result = try await ApiService.shared.createBirdLogAsync(birdId: birdId, data: logData)
                    
                    // 服务器写入成功，直接发送刷新通知
                    // 📌 架构简化：不再本地缓存日志，刷新时从服务器获取完整数据（含正确的 birdName）
                    if let serverId = result["id"] as? Int {
                        print("✅ 日志已同步到服务器: birdId=\(birdId), logId=\(serverId)")
                    }
                    
                    await MainActor.run {
                        isSaving = false
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshLogs"), object: nil)
                        onSave?()
                        dismiss()
                    }
                    
                } catch {
                    // 服务器写入失败，回退到本地存储
                    print("⚠️ 服务器写入失败，保存到本地: \(error.localizedDescription)")
                    log.needsSync = true
                    offlineService.addLog(log)
                    
                    await MainActor.run {
                        isSaving = false
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshLogs"), object: nil)
                        onSave?()
                        dismiss()
                    }
                }
            }
        } else {
            // 离线模式：只存本地
            offlineService.addLog(log)
            
            isSaving = false
            NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshLogs"), object: nil)
            onSave?()
            dismiss()
            
            // 如果在线但没有 birdServerId（本地鸟），也尝试上传图片
            if offlineService.isOnline && !selectedImages.isEmpty {
                offlineService.uploadPendingImages(for: logLocalId)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewLogView()
    }
}
