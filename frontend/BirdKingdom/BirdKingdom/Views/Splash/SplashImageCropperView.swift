import SwiftUI

/// 简约高级感开屏图片裁剪视图（9:19.5 全屏比例）
struct SplashImageCropperView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var croppedImage: UIImage?
    
    let originalImage: UIImage
    
    // 开屏图片比例（9:19.5，接近iPhone全屏）
    private let targetAspectRatio: CGFloat = 9.0 / 19.5
    
    // 缩放相关
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    // 偏移相关
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // 布局相关
    @State private var containerSize: CGSize = .zero
    @State private var imageDisplaySize: CGSize = .zero
    @State private var cropFrameSize: CGSize = .zero
    @State private var isInitialized: Bool = false
    
    // 手势状态
    @State private var isScaling: Bool = false
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {

        ZStack {
            Color.black.ignoresSafeArea()
            
            // 裁剪区域 (全屏)
            GeometryReader { geometry in
                let containerWidth = geometry.size.width
                let containerHeight = geometry.size.height
                
                // 增加高度占比，提升沉浸感 (0.85 -> 0.92)
                // 留出底部操作栏的空间
                let cropHeight = containerHeight * 0.92
                let cropWidth = cropHeight * targetAspectRatio
                
                let imageAspect = originalImage.size.width / originalImage.size.height
                let containerAspect = containerWidth / containerHeight
                let fittedImageSize: CGSize = {
                    if imageAspect > containerAspect {
                        let w = containerWidth
                        let h = containerWidth / imageAspect
                        return CGSize(width: w, height: h)
                    } else {
                        let h = containerHeight
                        let w = containerHeight * imageAspect
                        return CGSize(width: w, height: h)
                    }
                }()
                
                ZStack {
                    // 可缩放拖动的图片
                    Image(uiImage: originalImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(createMagnificationGesture(cropSize: CGSize(width: cropWidth, height: cropHeight), imageSize: fittedImageSize))
                        .simultaneousGesture(createDragGesture(cropSize: CGSize(width: cropWidth, height: cropHeight), imageSize: fittedImageSize))
                        .onAppear {
                            imageDisplaySize = fittedImageSize
                            containerSize = geometry.size
                            cropFrameSize = CGSize(width: cropWidth, height: cropHeight)
                            
                            if !isInitialized {
                                initializeScaleWithSize(fittedImageSize, cropSize: CGSize(width: cropWidth, height: cropHeight))
                                isInitialized = true
                            }
                        }
                    
                    // 简洁矩形遮罩
                    SimpleCropOverlay(cropWidth: cropWidth, cropHeight: cropHeight)
                }
                .frame(width: containerWidth, height: containerHeight)
                // 稍微上移，为底部按钮留空间，保持视觉平衡
                .offset(y: -20)
            }
            
            // 底部操作栏 (仿微信/抖音风格)
            VStack {
                Spacer()
                
                HStack {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Text(L10n.cancel)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .frame(height: 44)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    Text(NSLocalizedString("开屏预览", comment: ""))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Button {
                        HapticFeedback.medium()
                        performCrop()
                    } label: {
                        Text(L10n.done)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(primaryColor) // 使用主题色，保持一致性
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(primaryColor.opacity(0.15))
                            .cornerRadius(8)
                            .padding(.trailing, 10)
                    }
                }
                .padding(.bottom, 30) // 适配全面屏底部
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.8), Color.black.opacity(0.4), Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .ignoresSafeArea()
                )
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true) // 隐藏状态栏，更沉浸
    }
    
    // MARK: - 手势
    private func createMagnificationGesture(cropSize: CGSize, imageSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isScaling = true
                let delta = value / lastScale
                lastScale = value
                
                let newScale = scale * delta
                let minScale = calculateMinScale(cropSize: cropSize, imageSize: imageSize)
                
                scale = min(max(newScale, minScale), 5.0)
            }
            .onEnded { _ in
                lastScale = 1.0
                isScaling = false
                offset = clampOffset(offset, cropSize: cropSize, imageSize: imageSize)
                lastOffset = offset
            }
    }
    
    private func createDragGesture(cropSize: CGSize, imageSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isScaling else { return }
                let newOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampOffset(newOffset, cropSize: cropSize, imageSize: imageSize)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    // MARK: - 辅助方法
    private func calculateMinScale(cropSize: CGSize, imageSize: CGSize) -> CGFloat {
        guard imageSize.width > 0 && imageSize.height > 0 else { return 1.0 }
        
        let minScaleW = cropSize.width / imageSize.width
        let minScaleH = cropSize.height / imageSize.height
        return max(minScaleW, minScaleH)
    }
    
    private func initializeScaleWithSize(_ imageSize: CGSize, cropSize: CGSize) {
        guard imageSize.width > 0 && imageSize.height > 0 && cropSize.width > 0 else { return }
        
        let minScale = calculateMinScale(cropSize: cropSize, imageSize: imageSize)
        scale = minScale
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
        imageDisplaySize = imageSize
    }
    
    private func clampOffset(_ proposedOffset: CGSize, cropSize: CGSize, imageSize: CGSize) -> CGSize {
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return proposedOffset
        }
        
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        let maxOffsetX = max(0, (scaledWidth - cropSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropSize.height) / 2)
        
        let clampedX = min(max(proposedOffset.width, -maxOffsetX), maxOffsetX)
        let clampedY = min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
        
        return CGSize(width: clampedX, height: clampedY)
    }
    
    private func performCrop() {
        guard imageDisplaySize.width > 0 && imageDisplaySize.height > 0 else {
            croppedImage = cropToAspectRatio(originalImage)
            dismiss()
            return
        }
        
        let imageSize = originalImage.size
        
        let scaledDisplayWidth = imageDisplaySize.width * scale
        let scaledDisplayHeight = imageDisplaySize.height * scale
        
        let cropCenterX = scaledDisplayWidth / 2 - offset.width
        let cropCenterY = scaledDisplayHeight / 2 - offset.height
        
        let scaleToOriginalX = imageSize.width / scaledDisplayWidth
        let scaleToOriginalY = imageSize.height / scaledDisplayHeight
        
        let cropWidthInOriginal = cropFrameSize.width * scaleToOriginalX
        let cropHeightInOriginal = cropFrameSize.height * scaleToOriginalY
        
        let cropX = cropCenterX * scaleToOriginalX - cropWidthInOriginal / 2
        let cropY = cropCenterY * scaleToOriginalY - cropHeightInOriginal / 2
        
        let safeX = max(0, min(cropX, imageSize.width - cropWidthInOriginal))
        let safeY = max(0, min(cropY, imageSize.height - cropHeightInOriginal))
        let safeWidth = min(cropWidthInOriginal, imageSize.width - safeX)
        let safeHeight = min(cropHeightInOriginal, imageSize.height - safeY)
        
        let cropRect = CGRect(x: safeX, y: safeY, width: safeWidth, height: safeHeight)
        
        if let cgImage = originalImage.cgImage?.cropping(to: cropRect) {
            let croppedUIImage = UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
            croppedImage = resizeToStandardSize(croppedUIImage)
        } else {
            croppedImage = cropToAspectRatio(originalImage)
        }
        
        dismiss()
    }
    
    private func cropToAspectRatio(_ image: UIImage) -> UIImage {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        
        var cropWidth: CGFloat
        var cropHeight: CGFloat
        
        if imageAspect > targetAspectRatio {
            cropHeight = imageSize.height
            cropWidth = cropHeight * targetAspectRatio
        } else {
            cropWidth = imageSize.width
            cropHeight = cropWidth / targetAspectRatio
        }
        
        let cropX = (imageSize.width - cropWidth) / 2
        let cropY = (imageSize.height - cropHeight) / 2
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            return resizeToStandardSize(cropped)
        }
        
        return resizeToStandardSize(image)
    }
    
    private func resizeToStandardSize(_ image: UIImage) -> UIImage {
        let targetWidth: CGFloat = 1080
        let targetHeight: CGFloat = targetWidth / targetAspectRatio
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        let imageAspect = image.size.width / image.size.height
        let targetAspect = targetWidth / targetHeight
        
        var drawRect: CGRect
        
        if abs(imageAspect - targetAspect) < 0.01 {
            drawRect = CGRect(origin: .zero, size: targetSize)
        } else if imageAspect > targetAspect {
            let scaledWidth = targetHeight * imageAspect
            let offsetX = (scaledWidth - targetWidth) / 2
            drawRect = CGRect(x: -offsetX, y: 0, width: scaledWidth, height: targetHeight)
        } else {
            let scaledHeight = targetWidth / imageAspect
            let offsetY = (scaledHeight - targetHeight) / 2
            drawRect = CGRect(x: 0, y: -offsetY, width: targetWidth, height: scaledHeight)
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            context.cgContext.clip(to: CGRect(origin: .zero, size: targetSize))
            image.draw(in: drawRect)
        }
    }
}

// MARK: - 简洁矩形裁剪遮罩
struct SimpleCropOverlay: View {
    let cropWidth: CGFloat
    let cropHeight: CGFloat
    
    var body: some View {
        ZStack {
            // 半透明遮罩
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .mask(
                    ZStack {
                        Rectangle()
                        RoundedRectangle(cornerRadius: 8)
                            .frame(width: cropWidth, height: cropHeight)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
            
            // 白色边框
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: cropWidth, height: cropHeight)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    SplashImageCropperView(
        croppedImage: .constant(nil),
        originalImage: UIImage(systemName: "photo.fill")!
    )
}
