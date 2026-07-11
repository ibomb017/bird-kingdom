import SwiftUI
import PhotosUI

/// 重新上传图片视图（用于已支付但未上传图片的订单）
struct SplashReuploadView: View {
    let orderResponse: SplashService.ReserveResponse
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var splashService = SplashService.shared  // ✅ 修复：单例用 ObservedObject
    
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var showConfirmAlert = false
    @State private var isLoadingImage = false
    @State private var imageLoadTask: Task<Void, Never>?
    
    // ✅ 恢复裁剪功能
    @State private var showCropper = false
    @State private var originalImageForCrop: UIImage?
    
    private var primaryColor: Color { themeManager.primaryColor }
    private var gradientColors: [Color] { [primaryColor, primaryColor.opacity(0.7)] }
    
    var body: some View {
        VStack(spacing: 24) {
            // 订单信息
            orderInfoCard
            
            // 提示信息
            infoNotice
            
            // 图片选择区域
            imagePickerArea
            
            Spacer()
            
            // 上传按钮
            uploadButton
        }
        .padding()
        .themedBackground()
        .navigationTitle(NSLocalizedString("上传鸟鸟照片", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(primaryColor.opacity(0.08), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(primaryColor)
        .onChange(of: selectedItem) { oldValue, newValue in
            loadAndProcessImage(from: newValue)
        }
        .alert(NSLocalizedString("上传失败", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage ?? L10n.unknownError)
        }
        .alert(NSLocalizedString("提交成功", comment: ""), isPresented: $showSuccess) {
            Button(L10n.done) {
                dismiss()
            }
        } message: {
            Text(String(format: NSLocalizedString("您的开屏图片已提交，正在等待审核。\n\n审核通过后将在 %@ 展示给所有用户。\n\n如审核未通过，费用将自动退还。", comment: ""), orderResponse.displayDate))
        }
        .alert(NSLocalizedString("确认上传", comment: ""), isPresented: $showConfirmAlert) {
            Button(L10n.cancel, role: .cancel) { }
            Button(NSLocalizedString("确认上传", comment: ""), role: .destructive) {
                performUpload()
            }
        } message: {
            Text(NSLocalizedString("图片一旦上传成功将无法修改或更换！\n\n请确认您已仔细检查图片，确定要继续吗？", comment: ""))
        }
        // ✅ 恢复裁剪器
        .navigationDestination(isPresented: $showCropper) {
            if let originalImage = originalImageForCrop {
                SplashImageCropperView(
                    croppedImage: $selectedImage,
                    originalImage: originalImage
                )
                .hidesTabBar()
            }
        }
    }
    
    // MARK: - 订单信息卡片
    
    private var orderInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(NSLocalizedString("展示日期", comment: ""))
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                Text(orderResponse.displayDate)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.textColor)
            }
            
            Divider()
            
            HStack {
                Text(L10n.orderStatus)
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                Text(NSLocalizedString("已付款", comment: ""))
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.cardBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 4)
        )
    }
    
    // MARK: - 提示信息
    
    private var infoNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("订单已支付", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.textColor)
                Text(NSLocalizedString("请上传您要展示的图片。图片一旦上传成功将无法修改。", comment: ""))
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    // MARK: - 图片选择区域
    
    private var imagePickerArea: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(primaryColor.opacity(0.3))
                
                if isLoadingImage {
                    // ✅ 修复：显示加载状态
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(NSLocalizedString("正在处理图片...", comment: ""))
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                } else if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(8)
                } else {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(primaryColor.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 35))
                                .foregroundColor(primaryColor)
                        }
                        
                        Text(NSLocalizedString("点击选择图片", comment: ""))
                            .font(.headline)
                            .foregroundColor(themeManager.textColor)
                        
                        // ✅ 恢复裁剪功能提示
                        Text(NSLocalizedString("将自动裁剪为全屏比例 (9:19.5)", comment: ""))
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
        }
        .disabled(isLoadingImage)
    }
    
    // MARK: - 上传按钮
    
    private var uploadButton: some View {
        VStack(spacing: 8) {
            Button {
                showConfirmAlert = true
            } label: {
                HStack {
                    if isUploading {
                        ProgressView()
                            .tint(.white)
                        Text(NSLocalizedString("上传中...", comment: ""))
                    } else {
                        Text(NSLocalizedString("上传图片", comment: ""))
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedImage != nil && !isUploading ? primaryColor : Color(uiColor: .systemGray3))
                .cornerRadius(14)
            }
            .disabled(selectedImage == nil || isUploading)
            
            if isUploading && uploadProgress > 0 {
                ProgressView(value: uploadProgress)
                    .tint(primaryColor)
            }
        }
    }
    
    // MARK: - 加载并处理图片（支持任务取消，解决并发竞态）
    
    private func loadAndProcessImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        imageLoadTask?.cancel()
        
        isLoadingImage = true
        
        imageLoadTask = Task {
            do {
                guard !Task.isCancelled else { return }
                
                if let data = try await item.loadTransferable(type: Data.self),
                   // P0 Fix: 使用 downsample 方法防止大图导致的内存溢出和页面卡死
                   let uiImage = UIImage.downsample(from: data, toMaxDimension: 2000) {
                    
                    guard !Task.isCancelled else { return }
                    
                    // ✅ 修正图片方向
                    let orientedImage = uiImage.fixedOrientation()
                    
                    await MainActor.run {
                        isLoadingImage = false
                        // ✅ 恢复裁剪功能：保存原图并打开裁剪器
                        originalImageForCrop = orientedImage
                        showCropper = true
                    }
                    print("✅ 图片加载成功，打开裁剪器: \(Int(orientedImage.size.width))x\(Int(orientedImage.size.height))")
                } else {
                    await MainActor.run {
                        isLoadingImage = false
                        errorMessage = NSLocalizedString("无法读取图片", comment: "")
                        showError = true
                    }
                }
            } catch {
                if Task.isCancelled { return }
                
                print("❌ 加载图片失败: \(error)")
                await MainActor.run {
                    isLoadingImage = false
                    errorMessage = NSLocalizedString("图片加载失败，请重试", comment: "")
                    showError = true
                }
            }
        }
    }
    
    /// 处理图片：修正方向 + 压缩到适合上传的尺寸
    private func processImageForUpload(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // ✅ 修复：先修正图片方向
                let orientedImage = image.fixedOrientation()
                
                let targetWidth: CGFloat = 1080
                guard orientedImage.size.width > targetWidth else {
                    continuation.resume(returning: orientedImage)
                    return
                }
                
                let scale = targetWidth / orientedImage.size.width
                let newWidth = orientedImage.size.width * scale
                let newHeight = orientedImage.size.height * scale
                let newSize = CGSize(width: newWidth, height: newHeight)
                
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let compressed = renderer.image { _ in
                    orientedImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
                print("📸 图片已处理: \(Int(image.size.width))x\(Int(image.size.height)) -> \(Int(newWidth))x\(Int(newHeight))")
                continuation.resume(returning: compressed)
            }
        }
    }
    
    // MARK: - 执行上传（订单已支付，只需上传图片）
    
    private func performUpload() {
        guard let image = selectedImage else { return }
        guard !isUploading else { return }  // ✅ 防止重复点击
        
        isUploading = true
        uploadProgress = 0
        
        // ✅ 修复：Task { @MainActor in } 确保整个异步块在MainActor上执行
        Task { @MainActor in
            do {
                // 订单已支付，只需执行上传流程
                
                // 1. 获取上传凭证
                uploadProgress = 0.2
                let tokenResponse = try await splashService.getUploadToken(
                    orderId: orderResponse.orderId,
                    fileName: "splash.jpg"
                )
                
                // 2. 上传图片到 OSS
                uploadProgress = 0.5
                try await uploadImageToOSS(image: image, uploadUrl: tokenResponse.uploadUrl)
                
                // 3. 确认上传
                uploadProgress = 0.8
                try await splashService.confirmUpload(
                    orderId: orderResponse.orderId,
                    ossKey: tokenResponse.ossKey
                )
                
                uploadProgress = 1.0
                isUploading = false
                showSuccess = true
                
            } catch {
                isUploading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    // MARK: - 上传图片到 OSS
    
    private func uploadImageToOSS(image: UIImage, uploadUrl: String) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("图片处理失败", comment: "")])
        }
        
        guard let url = URL(string: uploadUrl) else {
            throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("上传地址无效", comment: "")])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("上传失败，请重试", comment: "")])
        }
    }
}

#Preview {
    NavigationStack {
        SplashReuploadView(
            orderResponse: SplashService.ReserveResponse(
                orderId: 1,
                slotId: 1,
                displayDate: "2025-12-25",
                amount: 10.0,
                expireAt: "",
                status: "PAID"
            )
        )
    }
}
