import SwiftUI
import PhotosUI

// 可识别的图片包装类型，用于 fullScreenCover(item:)
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct EditBirdView: View {
    let bird: Bird
    @Environment(\.dismiss) private var dismiss
    
    @State private var nickname: String = ""
    @State private var species: String = ""
    @State private var gender: String = "UNKNOWN"
    @State private var hatchDate: Date = Date()
    @State private var hasHatchDate: Bool = false
    @State private var adoptionDate: Date = Date()
    @State private var hasAdoptionDate: Bool = false
    @State private var birthdayType: String = "HATCH"
    @State private var deathDate: Date = Date()
    @State private var hasDeathDate: Bool = false
    @State private var featherColor: String = ""
    @State private var source: String = ""
    @State private var notes: String = ""
    @State private var medicalHistory: String = ""
    @State private var fatherInfo: String = ""
    @State private var motherInfo: String = ""
    @State private var legRingId: String = ""
    @State private var isSaving = false
    // @State private var showAvatarPicker = false // 已移除
    @State private var selectedAvatar: UIImage?
    @State private var isUploadingAvatar = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSpeciesPicker = false
    @State private var weightMin: Double?
    @State private var weightMax: Double?
    @State private var hasAttemptedSave = false
    @State private var scrollTarget: FormField? = nil
    
    // 头像选择相关状态
    @State private var showAvatarSelection = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var tempImage: UIImage?  // 用于相机临时存储
    @State private var imageToCrop: IdentifiableImage?  // 控制裁剪器弹出
    
    // 表单字段 ID
    private enum FormField: Hashable {
        case nickname
        case species
    }
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    init(bird: Bird) {
        self.bird = bird
        _nickname = State(initialValue: bird.nickname)
        _species = State(initialValue: bird.species)
        _gender = State(initialValue: bird.gender ?? "UNKNOWN")
        _hatchDate = State(initialValue: bird.hatchDate ?? Date())
        _hasHatchDate = State(initialValue: bird.hatchDate != nil)
        _adoptionDate = State(initialValue: bird.adoptionDate ?? Date())
        _hasAdoptionDate = State(initialValue: bird.adoptionDate != nil)
        _birthdayType = State(initialValue: bird.birthdayType ?? "HATCH")
        _deathDate = State(initialValue: bird.deathDate ?? Date())
        _hasDeathDate = State(initialValue: bird.deathDate != nil)
        _featherColor = State(initialValue: bird.featherColor ?? "")
        _source = State(initialValue: bird.source ?? "")
        _notes = State(initialValue: bird.notes ?? "")
        _medicalHistory = State(initialValue: bird.medicalHistory ?? "")
        _fatherInfo = State(initialValue: bird.fatherInfo ?? "")
        _motherInfo = State(initialValue: bird.motherInfo ?? "")
        _legRingId = State(initialValue: bird.legRingId ?? "")
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            Form {
            // 头像区域
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button {
                                showAvatarSelection = true
                            } label: {
                                if let avatar = selectedAvatar {
                                    Image(uiImage: avatar)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(primaryColor, lineWidth: 3)
                                        )
                                } else if let avatarUrl = bird.avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(primaryColor, lineWidth: 3)
                                                )
                                        default:
                                            defaultAvatarView
                                        }
                                    }
                                } else {
                                    defaultAvatarView
                                }
                            }
                            
                            Text(isUploadingAvatar ? NSLocalizedString("上传中...", comment: "") : NSLocalizedString("点击更换头像", comment: ""))
                                .font(.caption)
                                .foregroundColor(isUploadingAvatar ? primaryColor : .secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                // P0 改进：移除实时验证错误提示，改为保存时弹窗提示
                
                // 基础信息
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("基础信息", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    // 昵称输入框：标签 + 自定义 placeholder
                    HStack {
                        Text(L10n.birdName)
                            .foregroundColor(.primary)
                        ZStack(alignment: .leading) {
                            // 自定义 placeholder：未填写时显示，保存后变红
                            if nickname.isEmpty {
                                Text(NSLocalizedString("* 请输入昵称", comment: ""))
                                    .foregroundColor(hasAttemptedSave ? .red : .secondary)
                            }
                            TextField("", text: $nickname)
                                .onChange(of: nickname) { newValue in
                                    if newValue.count > 50 {
                                        nickname = String(newValue.prefix(50))
                                    }
                                }
                        }
                    }
                    .id(FormField.nickname)  // P0 改进：添加 ID 用于滚动定位
                    // 昵称字数提示（只在接近上限时显示）
                    if nickname.count > 40 {
                        HStack {
                            Spacer()
                            Text("\(nickname.count)/50")
                                .font(.caption2)
                                .foregroundColor(nickname.count >= 50 ? .red : .orange)
                        }
                    }
                    
                    // 品种选择：标签 + 选择按钮（布局与昵称一致）
                    Button {
                        showSpeciesPicker = true
                    } label: {
                        HStack {
                            Text(L10n.birdSpecies)
                                .foregroundColor(.primary)
                            // 自定义 placeholder：未选择时显示，保存后变红
                            Text(species.isEmpty ? NSLocalizedString("* 请选择品种", comment: "") : species)
                                .foregroundColor(species.isEmpty ? (hasAttemptedSave ? .red : .secondary) : primaryColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .id(FormField.species)  // P0 改进：添加 ID 用于滚动定位
                    
                    Picker(L10n.birdGender, selection: $gender) {
                        Text(L10n.male).tag("MALE")
                        Text(L10n.female).tag("FEMALE")
                        Text(L10n.unknownGender).tag("UNKNOWN")
                    }
                    
                    // 脚环编号：标签 + 输入框
                    HStack {
                        Text(NSLocalizedString("脚环编号", comment: ""))
                            .foregroundColor(.primary)
                        TextField(NSLocalizedString("请输入脚环编号", comment: ""), text: $legRingId)
                    }
                }
                
                // 日期信息
                Section {
                    HStack {
                        Image(systemName: "calendar.circle.fill")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("日期信息", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    Toggle(NSLocalizedString("填写破壳日期", comment: ""), isOn: $hasHatchDate)
                    if hasHatchDate {
                        DatePicker(NSLocalizedString("破壳日期", comment: ""), selection: $hatchDate, in: ...Date(), displayedComponents: .date)
                    }
                    
                    Toggle(NSLocalizedString("填写领养日期", comment: ""), isOn: $hasAdoptionDate)
                    if hasAdoptionDate {
                        DatePicker(NSLocalizedString("领养日期", comment: ""), selection: $adoptionDate, in: ...Date(), displayedComponents: .date)
                    }
                    
                    if hasHatchDate || hasAdoptionDate {
                        Picker(NSLocalizedString("生日类型", comment: ""), selection: $birthdayType) {
                            if hasHatchDate {
                                Text(NSLocalizedString("以破壳日期为生日", comment: "")).tag("HATCH")
                            }
                            if hasAdoptionDate {
                                Text(NSLocalizedString("以领养日期为生日", comment: "")).tag("ADOPTION")
                            }
                        }
                    }
                    
                    Toggle(NSLocalizedString("已故", comment: ""), isOn: $hasDeathDate)
                        .foregroundColor(hasDeathDate ? .red : .primary)
                    if hasDeathDate {
                        DatePicker(NSLocalizedString("忌日", comment: ""), selection: $deathDate, in: ...Date(), displayedComponents: .date)
                            .foregroundColor(.red)
                    }
                }
                
                
                // 外观与来源
                Section {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("外观与来源", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    TextField(NSLocalizedString("羽色", comment: ""), text: $featherColor)
                    TextField(NSLocalizedString("来源", comment: ""), text: $source)
                }
                
                // 父母信息
                Section {
                    HStack {
                        Image(systemName: "figure.2.and.child.holdinghands")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("父母信息", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    TextField(NSLocalizedString("爸爸昵称 / 血统编号", comment: ""), text: $fatherInfo)
                    TextField(NSLocalizedString("妈妈昵称 / 血统编号", comment: ""), text: $motherInfo)
                }
                
                // 病例
                Section {
                    HStack {
                        Image(systemName: "cross.case.fill")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("病例记录", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    TextEditor(text: $medicalHistory)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if medicalHistory.isEmpty {
                                    Text(NSLocalizedString("记录疾病史、用药情况、就医记录等", comment: ""))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                // 备注
                Section {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("备注", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
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
        .themedNavigationBar(title: NSLocalizedString("编辑鸟档案", comment: ""))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // P0 改进：保存按钮始终可点击，验证在点击时进行
                Button(L10n.save) { validateAndSave() }
                    .fontWeight(.semibold)
                    .foregroundColor(isSaving ? .gray : primaryColor)
                    .disabled(isSaving)
            }
        }
        .confirmationDialog(L10n.changeAvatar, isPresented: $showAvatarSelection, titleVisibility: .visible) {
            Button(NSLocalizedString("从相册选择", comment: "")) {
                showPhotoPicker = true
            }
            Button(NSLocalizedString("拍摄照片", comment: "")) {
                showCamera = true
            }
            Button(L10n.cancel, role: .cancel) {
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage.downsample(from: data, toMaxDimension: 1500) {
                        // 延迟设置 imageToCrop，等待 photosPicker 完全关闭
                        await MainActor.run {
                            // 重置 selectedItem 以便下次可以选择同一张图片
                            self.selectedItem = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.imageToCrop = IdentifiableImage(image: image)
                            }
                        }
                    } else {
                        // 如果无法加载数据或转换图片失败
                        throw NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("无法加载图片数据", comment: "")])
                    }
                } catch {
                    print("❌ 图片加载失败: \(error)")
                    await MainActor.run {
                        self.selectedItem = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.errorMessage = NSLocalizedString("图片加载失败。如果是iCloud照片，请确保网络连接正常后重试。", comment: "")
                            self.showErrorAlert = true
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(image: $tempImage)
                .ignoresSafeArea()
        }
        // 监听 Camera 关闭
        .onChange(of: showCamera) { _, isOpen in
            if !isOpen, let image = tempImage {
                // 延迟设置 imageToCrop，等待 camera fullScreenCover 完全关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.imageToCrop = IdentifiableImage(image: image)
                    self.tempImage = nil
                }
            }
        }
        // 使用 item 版本的 fullScreenCover，只有当 imageToCrop 有值时才弹出
        .fullScreenCover(item: $imageToCrop) { wrapper in
            ImageCropperView(croppedImage: $selectedAvatar, originalImage: wrapper.image)
        }
        .sheet(isPresented: $showSpeciesPicker) {
            SpeciesPickerView(
                selectedSpecies: $species,
                weightMin: $weightMin,
                weightMax: $weightMax
            )
        }
        .alert(NSLocalizedString("保存失败", comment: ""), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var defaultAvatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [primaryColor.opacity(0.7), primaryColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
            
            Image(systemName: "camera.fill")
                .font(.title)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - P1-04: 表单校验
    
    /// 校验错误信息
    private var validationError: String? {
        if nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            return NSLocalizedString("昵称不能为空", comment: "")
        }
        if nickname.count > 50 {
            return NSLocalizedString("昵称不能超过50个字符", comment: "")
        }
        if species.isEmpty {
            return NSLocalizedString("请选择品种", comment: "")
        }
        // P1-02: 忌日不能早于破壳日期
        if hasDeathDate && hasHatchDate {
            if deathDate < hatchDate {
                return NSLocalizedString("忌日不能早于破壳日期", comment: "")
            }
        }
        return nil
    }
    
    /// 是否可以保存
    private var canSave: Bool {
        !isSaving && validationError == nil
    }
    
    /// 校验并保存
    private func validateAndSave() {
        // P0 改进：标记已尝试保存，用于显示红色提示
        hasAttemptedSave = true
        
        // P0 改进：检查必填项并自动滚动到未填写的位置
        if nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            scrollTarget = .nickname  // 触发滚动到昵称
            return
        }
        if species.isEmpty {
            scrollTarget = .species  // 触发滚动到品种
            return
        }
        
        saveBird()
    }
    
    private func saveBird() {
        isSaving = true
        
        // 调试日志
        print("📝 开始保存鸟儿信息...")
        print("   - hasDeathDate: \(hasDeathDate)")
        print("   - deathDate: \(deathDate)")
        
        // Hybrid Saving Logic: Priority Online -> Fallback Offline
        Task {
            do {
                // 1. 如果有新头像，先上传 (仅在线)
                var avatarUrl: String? = bird.avatarUrl
                if let avatar = selectedAvatar, OfflineDataService.shared.isOnline {
                    print("📸 开始上传头像...")
                    isUploadingAvatar = true
                    avatarUrl = try await ApiService.shared.uploadBirdAvatar(image: avatar)
                    isUploadingAvatar = false
                    print("✅ 头像上传成功: \(avatarUrl ?? "nil")")
                }
                
                // 2. 准备更新的数据
                let updateData = Bird(
                    id: bird.id,
                    nickname: nickname,
                    species: species,
                    gender: gender,
                    hatchDate: hasHatchDate ? hatchDate : nil,
                    adoptionDate: hasAdoptionDate ? adoptionDate : nil,
                    birthdayType: birthdayType,
                    deathDate: hasDeathDate ? deathDate : nil,
                    featherColor: featherColor.isEmpty ? nil : featherColor,
                    source: source.isEmpty ? nil : source,
                    avatarUrl: avatarUrl,
                    notes: notes.isEmpty ? nil : notes,
                    medicalHistory: medicalHistory.isEmpty ? nil : medicalHistory,
                    fatherInfo: fatherInfo.isEmpty ? nil : fatherInfo,
                    motherInfo: motherInfo.isEmpty ? nil : motherInfo,
                    legRingId: legRingId.isEmpty ? nil : legRingId,
                    ageMonths: bird.ageMonths
                )

                // 3. 在线模式：调用 API
                if OfflineDataService.shared.isOnline {
                    print("📤 调用API更新鸟儿...")
                    let _ = try await ApiService.shared.updateBird(
                        id: bird.id,
                        nickname: updateData.nickname,
                        species: updateData.species,
                        gender: updateData.gender ?? "UNKNOWN",
                        hatchDate: updateData.hatchDate,
                        adoptionDate: updateData.adoptionDate,
                        birthdayType: updateData.birthdayType ?? "HATCH",
                        featherColor: updateData.featherColor,
                        source: updateData.source,
                        avatarUrl: updateData.avatarUrl,
                        notes: updateData.notes,
                        deathDate: updateData.deathDate,
                        fatherInfo: updateData.fatherInfo,
                        motherInfo: updateData.motherInfo,
                        legRingId: updateData.legRingId,
                        medicalHistory: updateData.medicalHistory
                    )
                    
                    // 成功后，如果有本地对应的缓存，也更新一下（保持一致性）
                    if var mutableLocal = OfflineDataService.shared.getBirdByServerId(Int(bird.id)) {
                        mutableLocal.nickname = updateData.nickname
                        mutableLocal.species = updateData.species
                        mutableLocal.gender = updateData.gender
                        mutableLocal.hatchDate = updateData.hatchDate
                        mutableLocal.adoptionDate = updateData.adoptionDate
                        mutableLocal.birthdayType = updateData.birthdayType
                        mutableLocal.deathDate = updateData.deathDate
                        mutableLocal.featherColor = updateData.featherColor
                        mutableLocal.source = updateData.source
                        mutableLocal.avatarUrl = updateData.avatarUrl
                        mutableLocal.notes = updateData.notes
                        mutableLocal.medicalHistory = updateData.medicalHistory
                        mutableLocal.fatherInfo = updateData.fatherInfo
                        mutableLocal.motherInfo = updateData.motherInfo
                        mutableLocal.legRingId = updateData.legRingId
                        OfflineDataService.shared.updateLocalBird(mutableLocal)
                    }
                } else {
                    // 离线模式：只更新本地，标记需要同步
                    print("📡 离线模式：更新本地鸟儿信息")
                    if var localBird = OfflineDataService.shared.getBirdByServerId(Int(bird.id)) {
                        localBird.nickname = updateData.nickname
                        localBird.species = updateData.species
                        localBird.gender = updateData.gender
                        localBird.hatchDate = updateData.hatchDate
                        localBird.adoptionDate = updateData.adoptionDate
                        localBird.birthdayType = updateData.birthdayType
                        localBird.deathDate = updateData.deathDate
                        localBird.featherColor = updateData.featherColor
                        localBird.source = updateData.source
                        localBird.notes = updateData.notes
                        localBird.medicalHistory = updateData.medicalHistory
                        localBird.fatherInfo = updateData.fatherInfo
                        localBird.motherInfo = updateData.motherInfo
                        localBird.legRingId = updateData.legRingId
                        // 离线时保存头像到本地
                        if let avatar = selectedAvatar {
                            let birdId = localBird.localId ?? String(bird.id)
                            let imagePath = LogImageStorage.shared.saveImage(avatar, birdId: birdId)
                            localBird.localAvatarPath = imagePath
                            localBird.imageUploadStatus = .pending
                        }
                        localBird.needsSync = true
                        OfflineDataService.shared.updateLocalBird(localBird)
                    } else {
                        throw NSError(domain: "EditBird", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("离线无法编辑未缓存的鸟儿", comment: "")])
                    }
                }
                
                await MainActor.run {
                    isSaving = false
                    URLCache.shared.removeAllCachedResponses()
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    isUploadingAvatar = false
                    errorMessage = String(format: NSLocalizedString("保存失败: %@", comment: ""), error.localizedDescription)
                    showErrorAlert = true
                }
                print("❌ 保存失败: \(error)")
            }
        }
    }
}

// 添加鸟页面
struct AddBirdView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    @State private var nickname: String = ""
    @State private var species: String = ""
    @State private var gender: String = "UNKNOWN"
    @State private var birthDate: Date = Date()
    @State private var hasBirthDate: Bool = false
    @State private var featherColor: String = ""
    @State private var source: String = ""
    @State private var legRingId: String = ""
    @State private var fatherInfo: String = ""
    @State private var motherInfo: String = ""
    @State private var notes: String = ""
    @State private var medicalHistory: String = ""
    @State private var isSaving = false
    // @State private var showAvatarPicker = false // 已移除
    @State private var selectedAvatar: UIImage?
    @State private var isUploadingAvatar = false
    @State private var showLoginAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSpeciesPicker = false
    @State private var weightMin: Double?
    @State private var weightMax: Double?
    @State private var hasAttemptedSave = false
    @State private var scrollTarget: FormField? = nil
    
    // 头像选择相关状态
    @State private var showAvatarSelection = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var tempImage: UIImage?  // 用于相机临时存储
    @State private var imageToCrop: IdentifiableImage?  // 控制裁剪器弹出
    
    // 表单字段 ID
    private enum FormField: Hashable {
        case nickname
        case species
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            Form {
            // 头像区域
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button {
                                showAvatarSelection = true
                            } label: {
                                if let avatar = selectedAvatar {
                                    Image(uiImage: avatar)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(primaryColor, lineWidth: 3)
                                        )
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [primaryColor.opacity(0.7), primaryColor.opacity(0.5)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 90, height: 90)
                                        
                                        Image(systemName: "camera.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            
                            Text(isUploadingAvatar ? NSLocalizedString("上传中...", comment: "") : (selectedAvatar != nil ? NSLocalizedString("点击更换头像", comment: "") : NSLocalizedString("给小鸟拍一张证件照", comment: "")))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(isUploadingAvatar ? primaryColor : .primary)
                            if selectedAvatar == nil {
                                Text(NSLocalizedString("点击上方图标选择或拍摄照片", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }
                
                // P0 改进：移除实时验证错误提示，改为保存时弹窗提示
                
                // 基础信息
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("基础信息", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    // 昵称输入框：标签 + 自定义 placeholder
                    HStack {
                        Text(L10n.birdName)
                            .foregroundColor(.primary)
                        ZStack(alignment: .leading) {
                            // 自定义 placeholder：未填写时显示，保存后变红
                            if nickname.isEmpty {
                                Text(NSLocalizedString("* 请输入昵称", comment: ""))
                                    .foregroundColor(hasAttemptedSave ? .red : .secondary)
                            }
                            TextField("", text: $nickname)
                                .onChange(of: nickname) { newValue in
                                    if newValue.count > 50 {
                                        nickname = String(newValue.prefix(50))
                                    }
                                }
                        }
                    }
                    .id(FormField.nickname)  // P0 改进：添加 ID 用于滚动定位
                    // 昵称字数提示（只在接近上限时显示）
                    if nickname.count > 40 {
                        HStack {
                            Spacer()
                            Text("\(nickname.count)/50")
                                .font(.caption2)
                                .foregroundColor(nickname.count >= 50 ? .red : .orange)
                        }
                    }
                    
                    // 品种选择：标签 + 选择按钮（布局与昵称一致）
                    Button {
                        showSpeciesPicker = true
                    } label: {
                        HStack {
                            Text(L10n.birdSpecies)
                                .foregroundColor(.primary)
                            // 自定义 placeholder：未选择时显示，保存后变红
                            Text(species.isEmpty ? NSLocalizedString("* 请选择品种", comment: "") : species)
                                .foregroundColor(species.isEmpty ? (hasAttemptedSave ? .red : .secondary) : primaryColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .id(FormField.species)  // P0 改进：添加 ID 用于滚动定位
                    
                    Picker(L10n.birdGender, selection: $gender) {
                        Text(L10n.male).tag("MALE")
                        Text(L10n.female).tag("FEMALE")
                        Text(L10n.unknownGender).tag("UNKNOWN")
                    }
                    
                    // 脚环编号：标签 + 输入框
                    HStack {
                        Text(NSLocalizedString("脚环编号", comment: ""))
                            .foregroundColor(.primary)
                        TextField(NSLocalizedString("请输入脚环编号", comment: ""), text: $legRingId)
                    }
                    
                    Toggle(NSLocalizedString("填写出生日期", comment: ""), isOn: $hasBirthDate)
                    
                    if hasBirthDate {
                        DatePicker(NSLocalizedString("出生日期", comment: ""), selection: $birthDate, in: ...Date(), displayedComponents: .date)
                    }
                }
                
                // 外观与来源
                Section {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("外观与来源", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    TextField(NSLocalizedString("羽色（如：白、灰、黄头白身）", comment: ""), text: $featherColor)
                    TextField(NSLocalizedString("来源（如：自家繁殖、花鸟市场）", comment: ""), text: $source)
                }
                
                // 父母信息
                Section {
                    HStack {
                        Image(systemName: "figure.2.and.child.holdinghands")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("父母信息", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    TextField(NSLocalizedString("爸爸昵称 / 血统编号", comment: ""), text: $fatherInfo)
                    TextField(NSLocalizedString("妈妈昵称 / 血统编号", comment: ""), text: $motherInfo)
                }
                
                // 病例
                Section {
                    HStack {
                        Image(systemName: "cross.case.fill")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("病例记录", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    TextEditor(text: $medicalHistory)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if medicalHistory.isEmpty {
                                    Text(NSLocalizedString("记录疾病史、用药情况、就医记录等", comment: ""))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                // 备注
                Section {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(primaryColor)
                        Text(NSLocalizedString("备注", comment: ""))
                            .fontWeight(.semibold)
                    }
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if notes.isEmpty {
                                    Text(NSLocalizedString("记录这只鸟的性格、来历、特殊注意事项等", comment: ""))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            },
                            alignment: .topLeading
                        )
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
        .themedNavigationBar(title: NSLocalizedString("添加鸟档案", comment: ""))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // P0 改进：保存按钮始终可点击，验证在点击时进行
                Button(L10n.save) { saveBird() }
                    .fontWeight(.semibold)
                    .foregroundColor(isSaving ? .gray : primaryColor)
                    .disabled(isSaving)
            }
        }
        .confirmationDialog(NSLocalizedString("上传头像", comment: ""), isPresented: $showAvatarSelection, titleVisibility: .visible) {
            Button(NSLocalizedString("从相册选择", comment: "")) {
                showPhotoPicker = true
            }
            Button(NSLocalizedString("拍摄照片", comment: "")) {
                showCamera = true
            }
            Button(L10n.cancel, role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage.downsample(from: data, toMaxDimension: 1500) {
                        // 延迟设置 imageToCrop，等待 photosPicker 完全关闭
                        await MainActor.run {
                            // 重置 selectedItem 以便下次可以选择同一张图片
                            self.selectedItem = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.imageToCrop = IdentifiableImage(image: image)
                            }
                        }
                    } else {
                         throw NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("无法加载图片数据", comment: "")])
                    }
                } catch {
                     print("❌ 图片加载失败: \(error)")
                     await MainActor.run {
                         self.selectedItem = nil
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                             self.errorMessage = NSLocalizedString("图片加载失败。如果是iCloud照片，请确保网络连接正常后重试。", comment: "")
                             self.showErrorAlert = true
                         }
                     }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(image: $tempImage)
                .ignoresSafeArea()
        }
        // 监听 Camera 关闭
        .onChange(of: showCamera) { _, isOpen in
            if !isOpen, let image = tempImage {
                // 延迟设置 imageToCrop，等待 camera fullScreenCover 完全关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.imageToCrop = IdentifiableImage(image: image)
                    self.tempImage = nil
                }
            }
        }
        // 使用 item 版本的 fullScreenCover
        .fullScreenCover(item: $imageToCrop) { wrapper in
            ImageCropperView(croppedImage: $selectedAvatar, originalImage: wrapper.image)
        }
        .sheet(isPresented: $showSpeciesPicker) {
            SpeciesPickerView(
                selectedSpecies: $species,
                weightMin: $weightMin,
                weightMax: $weightMax
            )
        }
        .alert(NSLocalizedString("请先登录", comment: ""), isPresented: $showLoginAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {
                dismiss() // P1-2 修复：点击确定后返回上一页
            }
        } message: {
            Text(NSLocalizedString("登录后才能添加鸟档案", comment: ""))
        }
        .onAppear {
            // P1-2 修复：进入页面时立即检查登录状态
            if !authService.isLoggedIn {
                showLoginAlert = true
            }
        }
        .alert(NSLocalizedString("保存失败", comment: ""), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - 表单校验
    
    /// 校验错误信息
    private var validationError: String? {
        if nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            return NSLocalizedString("昵称不能为空", comment: "")
        }
        if nickname.count > 50 {
            return NSLocalizedString("昵称不能超过50个字符", comment: "")
        }
        if species.isEmpty {
            return NSLocalizedString("请选择品种", comment: "")
        }
        return nil
    }
    
    /// 是否可以保存
    private var canSave: Bool {
        !isSaving && validationError == nil
    }
    
    private func saveBird() {
        // P0 改进：标记已尝试保存，用于显示红色提示
        hasAttemptedSave = true
        
        // 检查是否登录
        guard authService.isLoggedIn else {
            showLoginAlert = true
            return
        }
        
        // P0 前端校验：必填字段验证，并自动滚动到未填写的项
        if nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            scrollTarget = .nickname  // 触发滚动到昵称
            return
        }
        if species.isEmpty {
            scrollTarget = .species  // 触发滚动到品种
            return
        }
        
        isSaving = true
        
        // 创建鸟对象（必填字段已通过校验）
        let newBird = Bird(
            id: 0, // 后端会生成ID
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            species: species.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender,
            hatchDate: hasBirthDate ? birthDate : nil,
            adoptionDate: nil,
            birthdayType: "HATCH",
            deathDate: nil,
            featherColor: featherColor.isEmpty ? nil : featherColor,
            source: source.isEmpty ? nil : source,
            avatarUrl: nil,  // 头像URL会在创建后上传
            notes: notes.isEmpty ? nil : notes,
            medicalHistory: medicalHistory.isEmpty ? nil : medicalHistory,
            ageMonths: nil
        )
        
        Task {
            // 构造 LocalBird 对象 (用于离线或 fallback)
            let birdId = UUID().uuidString
            var localBird = LocalBird(
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                species: species.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            localBird.localId = birdId
            localBird.gender = gender
            localBird.hatchDate = hasBirthDate ? birthDate : nil
            localBird.featherColor = featherColor.isEmpty ? nil : featherColor
            localBird.source = source.isEmpty ? nil : source
            localBird.notes = notes.isEmpty ? nil : notes
            localBird.medicalHistory = medicalHistory.isEmpty ? nil : medicalHistory
            localBird.fatherInfo = fatherInfo.isEmpty ? nil : fatherInfo
            localBird.motherInfo = motherInfo.isEmpty ? nil : motherInfo
            localBird.legRingId = legRingId.isEmpty ? nil : legRingId
            
            // 头像处理
            if let avatar = selectedAvatar {
                let imagePath = LogImageStorage.shared.saveImage(avatar, birdId: birdId) // 假设有这个方法或类似的
                localBird.localAvatarPath = imagePath // 需要在 LocalBird 中支持
                localBird.imageUploadStatus = .pending
            }
            
            if OfflineDataService.shared.isOnline {
                do {
                    // 在线模式：上传头像(如有) -> 创建鸟 -> 刷新
                    var avatarUrl: String? = nil
                    if let avatar = selectedAvatar {
                        await MainActor.run { isUploadingAvatar = true }
                        avatarUrl = try await ApiService.shared.uploadBirdAvatar(image: avatar)
                        await MainActor.run { isUploadingAvatar = false }
                    }
                    
                    var newBird = Bird(
                        id: 0,
                        nickname: localBird.nickname,
                        species: localBird.species,
                        gender: localBird.gender,
                        hatchDate: localBird.hatchDate,
                        adoptionDate: nil,
                        birthdayType: "HATCH",
                        deathDate: nil,
                        featherColor: localBird.featherColor,
                        source: localBird.source,
                        avatarUrl: avatarUrl,
                        notes: localBird.notes,
                        medicalHistory: localBird.medicalHistory,
                        fatherInfo: localBird.fatherInfo,
                        motherInfo: localBird.motherInfo,
                        legRingId: localBird.legRingId,
                        ageMonths: nil
                    )
                    
                    let _ = try await ApiService.shared.createBird(newBird)
                    print("✅ 在线创建鸟儿成功")
                    
                    await MainActor.run {
                        isSaving = false
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                        dismiss()
                    }
                } catch {
                    print("❌ 在线创建失败，回退到离线: \(error)")
                    // 失败回退：保存到本地
                    await MainActor.run { isUploadingAvatar = false }
                    localBird.needsSync = true
                    OfflineDataService.shared.addBird(localBird)
                    
                    await MainActor.run {
                        isSaving = false
                        // 告知用户已离线保存
                        errorMessage = NSLocalizedString("网络异常，鸟儿已保存到本地，联网后将自动同步", comment: "")
                        showErrorAlert = true
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                        // 不立即 dismiss，让用户看到提示
                    }
                }
            } else {
                // 离线模式：直接保存本地
                print("📡 离线模式：保存到本地")
                localBird.needsSync = true
                OfflineDataService.shared.addBird(localBird)
                
                await MainActor.run {
                    isSaving = false
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                    dismiss()
                }
            }
        }
    }
}

#Preview("编辑") {
    NavigationStack {
        EditBirdView(bird: Bird(
            id: 1,
            nickname: NSLocalizedString("小白", comment: ""),
            species: NSLocalizedString("虎皮鹦鹉", comment: ""),
            gender: "FEMALE",
            hatchDate: Date(),
            adoptionDate: nil,
            birthdayType: "HATCH",
            deathDate: nil,
            featherColor: NSLocalizedString("白色", comment: ""),
            source: NSLocalizedString("自家繁殖", comment: ""),
            avatarUrl: nil,
            notes: NSLocalizedString("爱安静", comment: ""),
            ageMonths: 12
        ))
    }
}
