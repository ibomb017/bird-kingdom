import SwiftUI
import PhotosUI

// MARK: - 头像选择视图
struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var selectedPresetAvatar: String? = nil
    @State private var isLoading = false
    @State private var showSuccess = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    // 预设头像列表（鸟类主题）
    private let presetAvatars = [
        "bird.fill",
        "bird",
        "leaf.fill",
        "leaf.circle.fill",
        "hare.fill",
        "tortoise.fill",
        "pawprint.fill",
        "heart.fill",
        "star.fill",
        "moon.fill",
        "sun.max.fill",
        "cloud.fill"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 当前头像预览
                    currentAvatarPreview
                    
                    // 从相册选择
                    photoPickerSection
                    
                    // 预设头像
                    presetAvatarsSection
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .navigationTitle("修改头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveAvatar()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(forestGreen)
                    .disabled(selectedImage == nil && selectedPresetAvatar == nil)
                }
            }
            .alert("保存成功", isPresented: $showSuccess) {
                Button("确定") { dismiss() }
            } message: {
                Text("头像已更新")
            }
        }
    }
    
    // 当前头像预览
    private var currentAvatarPreview: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(forestGreen.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                if let image = selectedImage {
                    // 显示选中的图片
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else if let preset = selectedPresetAvatar {
                    // 显示选中的预设头像
                    Image(systemName: preset)
                        .font(.system(size: 50))
                        .foregroundColor(forestGreen)
                } else if let avatarUrl = authService.currentUser?.avatarUrl, !avatarUrl.isEmpty {
                    // 显示当前头像
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(forestGreen)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                } else {
                    // 默认头像
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(forestGreen)
                }
            }
            .overlay(
                Circle()
                    .stroke(forestGreen.opacity(0.3), lineWidth: 3)
            )
            
            Text("点击下方选择新头像")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 10)
    }
    
    // 从相册选择
    private var photoPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("从相册选择")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(forestGreen)
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                    Text("选择照片")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .foregroundColor(.primary)
                .padding(16)
                .background(Color.white)
                .cornerRadius(12)
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        selectedPresetAvatar = nil
                    }
                }
            }
        }
    }
    
    // 预设头像
    private var presetAvatarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择预设头像")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(forestGreen)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                ForEach(presetAvatars, id: \.self) { avatar in
                    Button {
                        selectedPresetAvatar = avatar
                        selectedImage = nil
                    } label: {
                        ZStack {
                            Circle()
                                .fill(selectedPresetAvatar == avatar ? forestGreen.opacity(0.2) : Color.white)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: avatar)
                                .font(.system(size: 26))
                                .foregroundColor(selectedPresetAvatar == avatar ? forestGreen : forestGreen.opacity(0.6))
                        }
                        .overlay(
                            Circle()
                                .stroke(selectedPresetAvatar == avatar ? forestGreen : Color.gray.opacity(0.2), lineWidth: selectedPresetAvatar == avatar ? 2 : 1)
                        )
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
        }
    }
    
    // 保存头像
    private func saveAvatar() {
        isLoading = true
        
        Task {
            do {
                var avatarUrl: String? = nil
                
                // 1. 如果选择了自定义图片，上传到服务器
                if let image = selectedImage {
                    avatarUrl = try await ApiService.shared.uploadUserAvatar(image: image)
                } else if let preset = selectedPresetAvatar {
                    // 2. 如果选择了预设头像，保存标识
                    avatarUrl = "preset:\(preset)"
                }
                
                // 3. 更新用户资料
                if let avatarUrl = avatarUrl {
                    try await authService.updateProfile(nickname: nil, bio: nil, avatarUrl: avatarUrl)
                }
                
                await MainActor.run {
                    isLoading = false
                    showSuccess = true
                    
                    // 清除图片缓存，强制刷新
                    URLCache.shared.removeAllCachedResponses()
                    
                    // 发送通知刷新所有页面
                    NotificationCenter.default.post(name: NSNotification.Name("UserAvatarUpdated"), object: nil)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("保存头像失败: \(error)")
                }
            }
        }
    }
}

#Preview {
    AvatarPickerView()
}
