import SwiftUI
import PhotosUI

// MARK: - 简约高级感用户头像选择视图
struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var tempImage: UIImage? = nil
    @State private var showCropper = false
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var forestGreen: Color { themeManager.primaryColor }
    
    private var canSave: Bool {
        selectedImage != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // 头像预览
                        avatarPreviewSection
                            .padding(.top, 20)
                        
                        // 从相册选择
                        photoPickerCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                
                // 加载指示器
                if isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    PremiumLoadingView(message: NSLocalizedString("处理中...", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("修改头像", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .tint(themeManager.primaryColor)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticFeedback.medium()
                        saveAvatar()
                    } label: {
                        Text(L10n.save)
                            .fontWeight(.semibold)
                            .foregroundColor(canSave ? themeManager.primaryColor : .gray)
                    }
                    .disabled(!canSave)
                }
            }
        }
        .alert(NSLocalizedString("保存成功", comment: ""), isPresented: $showSuccess) {
            Button(NSLocalizedString("确定", comment: "")) {
                HapticFeedback.success()
                dismiss()
            }
        } message: {
            Text(NSLocalizedString("头像已更新", comment: ""))
        }
        .alert(NSLocalizedString("保存失败", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let image = tempImage {
                ImageCropperView(croppedImage: $selectedImage, originalImage: image)
            }
        }
        .onChange(of: showCropper) { _, newValue in
            if !newValue {
                tempImage = nil
            }
        }
    }
    
    // MARK: - 头像预览区域
    private var avatarPreviewSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // 头像边框
                Circle()
                    .stroke(forestGreen.opacity(0.3), lineWidth: 3)
                    .frame(width: 130, height: 130)
                
                // 头像内容
                avatarContent
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            }
            
            // 提示文字
            if selectedImage != nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(forestGreen)
                    
                    Text(NSLocalizedString("已选择新头像", comment: ""))
                        .foregroundColor(forestGreen)
                }
                .font(.system(size: 14, weight: .medium))
            } else {
                Text(NSLocalizedString("点击下方选择新头像", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var avatarContent: some View {
        if let image = selectedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let avatarUrl = authService.currentUser?.avatarUrl, !avatarUrl.isEmpty {
            AsyncImage(url: URL(string: AppConfig.applyCDN(to: avatarUrl))) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                defaultAvatarIcon
            }
        } else {
            defaultAvatarIcon
        }
    }
    
    private var defaultAvatarIcon: some View {
        ZStack {
            Circle()
                .fill(forestGreen.opacity(0.1))
            
            Image("bird")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(forestGreen.opacity(0.5))
        }
    }
    
    // MARK: - 照片选择卡片
    private var photoPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("从相册选择", comment: ""))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(forestGreen)
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 14) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20))
                        .foregroundColor(forestGreen)
                        .frame(width: 44, height: 44)
                        .background(forestGreen.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("选择照片", comment: ""))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(NSLocalizedString("从相册中选择一张照片", comment: ""))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.gray.opacity(0.4))
                }
                .padding(16)
                .background(Color.adaptiveCard)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                )
            }
            .onChange(of: selectedItem) { _, newItem in
                handlePhotoSelection(newItem)
            }
        }
    }
    
    // MARK: - 辅助方法
    private func handlePhotoSelection(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        isLoading = true
        
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    // P0 Fix: 使用 downsample 方法防止大图导致的内存溢出和页面卡死
                    if let image = UIImage.downsample(from: data, toMaxDimension: 1500) {
                        await MainActor.run {
                            tempImage = image
                            isLoading = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showCropper = true
                            }
                        }
                    } else {
                        await MainActor.run {
                            isLoading = false
                            errorMessage = NSLocalizedString("无法解析图片", comment: "")
                            showError = true
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = NSLocalizedString("无法加载图片数据", comment: "")
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "加载图片失败: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func saveAvatar() {
        isLoading = true
        
        Task {
            do {
                var avatarUrl: String? = nil
                
                if let image = selectedImage {
                    avatarUrl = try await ApiService.shared.uploadUserAvatar(image: image)
                }
                
                if let avatarUrl = avatarUrl {
                    try await authService.updateProfile(nickname: nil, bio: nil, avatarUrl: avatarUrl)
                }
                
                await MainActor.run {
                    isLoading = false
                    showSuccess = true
                    
                    URLCache.shared.removeAllCachedResponses()
                    NotificationCenter.default.post(name: NSNotification.Name("UserAvatarUpdated"), object: nil)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "保存头像失败: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    AvatarPickerView()
}
