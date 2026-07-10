import SwiftUI
import PhotosUI

/// 简约高级感鸟类头像选择器
struct BirdAvatarPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedImage: UIImage?
    var currentAvatarUrl: String? = nil
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var tempImage: UIImage?
    @State private var showCropper = false
    @State private var isLoading = false
    @State private var showCamera = false
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var forestGreen: Color { themeManager.primaryColor }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer().frame(height: 20)
                
                // 头像预览
                avatarPreviewSection
                
                // 选择按钮
                VStack(spacing: 12) {
                    // 从相册选择
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        actionRow(
                            icon: "photo.on.rectangle",
                            title: NSLocalizedString("从相册选择", comment: ""),
                            subtitle: NSLocalizedString("选择一张照片作为头像", comment: "")
                        )
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        handlePhotoSelection(newItem)
                    }
                    
                    // 拍摄照片
                    Button {
                        HapticFeedback.light()
                        showCamera = true
                    } label: {
                        actionRow(
                            icon: "camera",
                            title: NSLocalizedString("拍摄照片", comment: ""),
                            subtitle: NSLocalizedString("使用相机拍摄新头像", comment: "")
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 底部提示
                Text(NSLocalizedString("头像将以圆形裁剪展示", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            
            // 加载指示器
            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                PremiumLoadingView(message: L10n.loading)
            }
        }
        .themedNavigationBar(title: NSLocalizedString("选择头像", comment: ""))
        .fullScreenCover(isPresented: $showCropper) {
            if let image = tempImage {
                ImageCropperView(croppedImage: $selectedImage, originalImage: image)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(image: $tempImage)
        }
        .onChange(of: showCropper) { _, newValue in
            if !newValue {
                tempImage = nil
                if selectedImage != nil {
                    HapticFeedback.success()
                    dismiss()
                }
            }
        }
        .onChange(of: tempImage) { _, newValue in
            if newValue != nil && !showCropper {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showCropper = true
                }
            }
        }
    }
    
    // MARK: - 头像预览
    private var avatarPreviewSection: some View {
        ZStack {
            // 头像边框
            Circle()
                .stroke(forestGreen.opacity(0.3), lineWidth: 3)
                .frame(width: 180, height: 180)
            
            // 头像内容
            avatarPreview
                .frame(width: 170, height: 170)
                .clipShape(Circle())
        }
    }
    
    @ViewBuilder
    private var avatarPreview: some View {
        if let image = selectedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let avatarUrl = currentAvatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    defaultAvatarContent
                }
            }
        } else {
            defaultAvatarContent
        }
    }
    
    private var defaultAvatarContent: some View {
        ZStack {
            Circle()
                .fill(forestGreen.opacity(0.1))
            
            Image("bird")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundColor(forestGreen.opacity(0.5))
        }
    }
    
    // MARK: - 操作行
    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(forestGreen)
                .frame(width: 44, height: 44)
                .background(forestGreen.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
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
    
    // MARK: - 图片选择处理
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
                        await MainActor.run { isLoading = false }
                        print("❌ [ERROR] BirdAvatarPicker: Failed to downsample image")
                    }
                } else {
                    await MainActor.run { isLoading = false }
                    print("❌ [ERROR] BirdAvatarPicker: loadTransferable returned nil")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("加载图片失败: \(error)")
                }
            }
        }
    }
}
