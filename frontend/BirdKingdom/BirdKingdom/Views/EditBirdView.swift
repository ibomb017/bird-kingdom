import SwiftUI
import PhotosUI

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
    @State private var isSaving = false
    @State private var showAvatarPicker = false
    @State private var selectedAvatar: UIImage?
    @State private var isUploadingAvatar = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
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
    }
    
    var body: some View {
        Form {
            // 头像区域
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button {
                            showAvatarPicker = true
                        } label: {
                            if let avatar = selectedAvatar {
                                Image(uiImage: avatar)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(forestGreen, lineWidth: 3)
                                    )
                            } else if let avatarUrl = bird.avatarUrl, let url = URL(string: avatarUrl) {
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
                                                    .stroke(forestGreen, lineWidth: 3)
                                            )
                                    default:
                                        defaultAvatarView
                                    }
                                }
                            } else {
                                defaultAvatarView
                            }
                        }
                        
                        Text(isUploadingAvatar ? "上传中..." : "点击更换头像")
                            .font(.caption)
                            .foregroundColor(isUploadingAvatar ? forestGreen : .secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            // 基础信息
            Section {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(forestGreen)
                    Text("基础信息")
                        .fontWeight(.semibold)
                }
                
                TextField("昵称 *", text: $nickname)
                TextField("品种", text: $species)
                
                Picker("性别", selection: $gender) {
                    Text("公").tag("MALE")
                    Text("母").tag("FEMALE")
                    Text("未知").tag("UNKNOWN")
                }
            }
            
            // 日期信息
            Section {
                HStack {
                    Image(systemName: "calendar.circle.fill")
                        .foregroundColor(forestGreen)
                    Text("日期信息")
                        .fontWeight(.semibold)
                }
                
                Toggle("填写破壳日期", isOn: $hasHatchDate)
                if hasHatchDate {
                    DatePicker("破壳日期", selection: $hatchDate, displayedComponents: .date)
                }
                
                Toggle("填写领养日期", isOn: $hasAdoptionDate)
                if hasAdoptionDate {
                    DatePicker("领养日期", selection: $adoptionDate, displayedComponents: .date)
                }
                
                if hasHatchDate || hasAdoptionDate {
                    Picker("生日类型", selection: $birthdayType) {
                        if hasHatchDate {
                            Text("以破壳日期为生日").tag("HATCH")
                        }
                        if hasAdoptionDate {
                            Text("以领养日期为生日").tag("ADOPTION")
                        }
                    }
                }
                
                Toggle("已故", isOn: $hasDeathDate)
                    .foregroundColor(hasDeathDate ? .red : .primary)
                if hasDeathDate {
                    DatePicker("忌日", selection: $deathDate, displayedComponents: .date)
                        .foregroundColor(.red)
                }
            }
            
            
            // 外观与来源
            Section {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(forestGreen)
                    Text("外观与来源")
                        .fontWeight(.semibold)
                }
                
                TextField("羽色", text: $featherColor)
                TextField("来源", text: $source)
            }
            
            // 病例
            Section {
                HStack {
                    Image(systemName: "cross.case.fill")
                        .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                    Text("病例记录")
                        .fontWeight(.semibold)
                }
                
                TextEditor(text: $medicalHistory)
                    .frame(minHeight: 80)
                    .overlay(
                        Group {
                            if medicalHistory.isEmpty {
                                Text("记录疾病史、用药情况、就医记录等")
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
                        .foregroundColor(forestGreen)
                    Text("备注")
                        .fontWeight(.semibold)
                }
                
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }
        }
        .navigationTitle("编辑鸟档案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveBird()
                }
                .fontWeight(.semibold)
                .disabled(nickname.isEmpty || isSaving)
            }
        }
        .sheet(isPresented: $showAvatarPicker) {
            BirdAvatarPicker(selectedImage: $selectedAvatar)
        }
    }
    
    private var defaultAvatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.72, green: 0.89, blue: 0.78), Color(red: 0.55, green: 0.78, blue: 0.65)],
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
    
    private func saveBird() {
        isSaving = true
        Task {
            do {
                // 1. 如果有新头像，先上传
                var avatarUrl: String? = bird.avatarUrl
                if let avatar = selectedAvatar {
                    isUploadingAvatar = true
                    avatarUrl = try await ApiService.shared.uploadBirdAvatar(image: avatar)
                    isUploadingAvatar = false
                }
                
                // 2. 更新鸟儿信息
                let updatedBird = try await ApiService.shared.updateBird(
                    id: bird.id,
                    nickname: nickname,
                    species: species,
                    gender: gender,
                    hatchDate: hasHatchDate ? hatchDate : nil,
                    adoptionDate: hasAdoptionDate ? adoptionDate : nil,
                    birthdayType: birthdayType,
                    featherColor: featherColor.isEmpty ? nil : featherColor,
                    source: source.isEmpty ? nil : source,
                    avatarUrl: avatarUrl,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    isSaving = false
                    
                    // 清除图片缓存，强制刷新头像
                    URLCache.shared.removeAllCachedResponses()
                    
                    // 通知刷新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    isUploadingAvatar = false
                }
                print("保存失败: \(error)")
            }
        }
    }
}

// 添加鸟页面
struct AddBirdView: View {
    @Environment(\.dismiss) private var dismiss
    
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
    @State private var showImagePicker = false
    
    var body: some View {
        Form {
            // 头像区域
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button {
                            showImagePicker = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.72, green: 0.89, blue: 0.78), Color(red: 0.55, green: 0.78, blue: 0.65)],
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
                        
                        Text("给小鸟拍一张证件照")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("点击上方图标选择或拍摄照片")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 10)
                .listRowBackground(Color.clear)
            }
            
            // 基础信息
            Section {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                    Text("基础信息")
                        .fontWeight(.semibold)
                }
                
                TextField("昵称 *", text: $nickname)
                TextField("品种（如：文鸟、虎皮鹦鹉）", text: $species)
                
                Picker("性别", selection: $gender) {
                    Text("公").tag("MALE")
                    Text("母").tag("FEMALE")
                    Text("未知").tag("UNKNOWN")
                }
                
                TextField("脚环编号（可选）", text: $legRingId)
                
                Toggle("填写出生日期", isOn: $hasBirthDate)
                
                if hasBirthDate {
                    DatePicker("出生日期", selection: $birthDate, displayedComponents: .date)
                }
            }
            
            // 外观与来源
            Section {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                    Text("外观与来源")
                        .fontWeight(.semibold)
                }
                
                TextField("羽色（如：白、灰、黄头白身）", text: $featherColor)
                TextField("来源（如：自家繁殖、花鸟市场）", text: $source)
            }
            
            // 父母信息
            Section {
                HStack {
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                    Text("父母信息（可选）")
                        .fontWeight(.semibold)
                }
                
                TextField("爸爸昵称 / 血统编号", text: $fatherInfo)
                TextField("妈妈昵称 / 血统编号", text: $motherInfo)
            }
            
            // 病例
            Section {
                HStack {
                    Image(systemName: "cross.case.fill")
                        .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                    Text("病例记录")
                        .fontWeight(.semibold)
                }
                
                TextEditor(text: $medicalHistory)
                    .frame(minHeight: 80)
                    .overlay(
                        Group {
                            if medicalHistory.isEmpty {
                                Text("记录疾病史、用药情况、就医记录等")
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
                        .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                    Text("备注")
                        .fontWeight(.semibold)
                }
                
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .overlay(
                        Group {
                            if notes.isEmpty {
                                Text("记录这只鸟的性格、来历、特殊注意事项等")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                        },
                        alignment: .topLeading
                    )
            }
        }
        .navigationTitle("添加鸟档案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveBird()
                }
                .fontWeight(.semibold)
                .disabled(nickname.isEmpty || isSaving)
            }
        }
        .alert("选择头像", isPresented: $showImagePicker) {
            Button("从相册选择") {
                // TODO: 实现相册选择
            }
            Button("拍照") {
                // TODO: 实现拍照
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("头像功能将在后续版本中支持")
        }
    }
    
    private func saveBird() {
        isSaving = true
        // TODO: 调用 API 创建鸟
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}

#Preview("编辑") {
    NavigationStack {
        EditBirdView(bird: Bird(
            id: 1,
            nickname: "小白",
            species: "虎皮鹦鹉",
            gender: "FEMALE",
            hatchDate: Date(),
            adoptionDate: nil,
            birthdayType: "HATCH",
            deathDate: nil,
            featherColor: "白色",
            source: "自家繁殖",
            avatarUrl: nil,
            notes: "爱安静",
            ageMonths: 12
        ))
    }
}

#Preview("添加") {
    NavigationStack {
        AddBirdView()
    }
}
