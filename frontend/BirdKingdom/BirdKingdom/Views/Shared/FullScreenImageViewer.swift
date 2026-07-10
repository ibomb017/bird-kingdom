import SwiftUI
import Photos

// MARK: - 全屏图片查看器
/// 点击图片进入全屏模式，再次点击退出
/// 长按保存图片（带水印）
struct FullScreenImageViewer: View {
    let imageURL: URL
    let onDismiss: () -> Void
    
    @State private var showingSaveSuccess = false
    @State private var showingSaveError = false
    @State private var errorMessage = ""
    @State private var loadedImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 黑色背景
                Color.black
                    .ignoresSafeArea()
                
                // 图片 - 支持缩放和拖动
                if let uiImage = loadedImage {
                    imageView(uiImage: uiImage, geometry: geometry)
                } else {
                    CachedAsyncImage(url: imageURL, size: .original) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                .scaleEffect(scale)
                                .offset(offset)
                                .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: offset)
                                .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: scale)
                                .gesture(zoomGesture)
                                // 只有放大时才启用拖动手势，避免和 TabView 滑动冲突
                                .gesture(scale > 1 ? dragGesture : nil)
                                .onAppear {
                                    loadImageForSave()
                                }
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text(NSLocalizedString("图片加载失败", comment: ""))
                                    .foregroundColor(.gray)
                            }
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // 保存成功提示
                if showingSaveSuccess {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(NSLocalizedString("已保存到相册", comment: ""))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                        .padding(.bottom, 100)
                    }
                    .transition(.opacity)
                }
            }
            // 点击背景退出
            .contentShape(Rectangle())
        }
        .ignoresSafeArea()
        .onTapGesture(count: 2) {
            // 双击放大/缩小
            withAnimation(.spring()) {
                if scale > 1 {
                    scale = 1
                    offset = .zero
                } else {
                    scale = 2
                }
            }
        }
        .onTapGesture {
            // 单击退出
            onDismiss()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            saveImageWithWatermark()
        }
        .alert(NSLocalizedString("保存失败", comment: ""), isPresented: $showingSaveError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // 图片视图
    @ViewBuilder
    private func imageView(uiImage: UIImage, geometry: GeometryProxy) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: offset)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.7), value: scale)
            .gesture(zoomGesture)
            // 只有放大时才启用拖动手势，避免和 TabView 滑动冲突
            .gesture(scale > 1 ? dragGesture : nil)
    }
    
    // 缩放手势
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1), 4)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale <= 1 {
                    withAnimation(.spring()) {
                        offset = .zero
                    }
                }
            }
    }
    
    // 拖动手势 - 优化为流畅动画
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if scale > 1 {
                    // 使用 withAnimation 实现流畅的跟随效果
                    let newOffset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                    offset = newOffset
                }
            }
            .onEnded { value in
                lastOffset = offset
                
                // 添加惯性滑动效果
                if scale > 1 {
                    let velocity = CGSize(
                        width: value.predictedEndTranslation.width - value.translation.width,
                        height: value.predictedEndTranslation.height - value.translation.height
                    )
                    
                    // 限制惯性距离
                    let maxInertia: CGFloat = 100
                    let inertiaX = min(max(velocity.width * 0.3, -maxInertia), maxInertia)
                    let inertiaY = min(max(velocity.height * 0.3, -maxInertia), maxInertia)
                    
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset = CGSize(
                            width: offset.width + inertiaX,
                            height: offset.height + inertiaY
                        )
                        lastOffset = offset
                    }
                }
            }
    }
    
    // 加载图片用于保存
    private func loadImageForSave() {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        loadedImage = image
                    }
                }
            } catch {
                print("❌ 加载图片失败: \(error)")
            }
        }
    }
    
    // 保存带水印的图片
    private func saveImageWithWatermark() {
        // 检查相册权限
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    performSave()
                } else {
                    errorMessage = NSLocalizedString("请在设置中允许访问相册", comment: "")
                    showingSaveError = true
                }
            }
        }
    }
    
    private func performSave() {
        guard let originalImage = loadedImage else {
            // 如果还没加载，先加载
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: imageURL)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            loadedImage = image
                            saveWithWatermark(image)
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = NSLocalizedString("图片加载失败", comment: "")
                        showingSaveError = true
                    }
                }
            }
            return
        }
        
        saveWithWatermark(originalImage)
    }
    
    private func saveWithWatermark(_ image: UIImage) {
        // 添加水印
        let watermarkedImage = addWatermark(to: image)
        
        // 保存到相册
        UIImageWriteToSavedPhotosAlbum(watermarkedImage, nil, nil, nil)
        
        // 显示成功提示
        withAnimation {
            showingSaveSuccess = true
        }
        
        // 2秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingSaveSuccess = false
            }
        }
    }
    
    // 添加水印
    private func addWatermark(to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // 绘制原图
            image.draw(at: .zero)
            
            // 水印文字
            let watermarkText = NSLocalizedString("鸟鸟王国App", comment: "")
            
            // 计算字体大小（图片宽度的 3%）
            let fontSize = image.size.width * 0.03
            let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            
            // 文字属性
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .paragraphStyle: paragraphStyle
            ]
            
            // 计算文字位置（右下角）
            let textSize = watermarkText.size(withAttributes: attributes)
            let padding = image.size.width * 0.02
            let textRect = CGRect(
                x: image.size.width - textSize.width - padding,
                y: image.size.height - textSize.height - padding,
                width: textSize.width,
                height: textSize.height
            )
            
            // 绘制半透明背景
            let backgroundRect = CGRect(
                x: textRect.origin.x - 8,
                y: textRect.origin.y - 4,
                width: textRect.width + 16,
                height: textRect.height + 8
            )
            UIColor.black.withAlphaComponent(0.3).setFill()
            UIBezierPath(roundedRect: backgroundRect, cornerRadius: 4).fill()
            
            // 绘制水印文字
            watermarkText.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - 多图全屏查看器
/// 支持左右滑动切换图片
struct FullScreenImageGallery: View {
    let imageURLs: [URL]
    @Binding var currentIndex: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    FullScreenImageViewer(imageURL: url, onDismiss: onDismiss)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .automatic : .never))
            
            // 页码指示器（仅多图时显示）
            if imageURLs.count > 1 {
                VStack {
                    Spacer()
                    Text("\(currentIndex + 1) / \(imageURLs.count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                        .padding(.bottom, 50)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}

// MARK: - 便捷版本（接受 URL 字符串数组和 Binding）
/// 用于日志图片查看，接受 URL 字符串数组
struct FullScreenImageViewer_URLs: View {
    let imageURLs: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int = 0
    
    init(imageURLs: [String], initialIndex: Int = 0, isPresented: Binding<Bool>) {
        self.imageURLs = imageURLs
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        let urls = imageURLs.compactMap { URL(string: $0) }
        
        if urls.isEmpty {
            Color.black
                .ignoresSafeArea()
                .overlay(
                    Text(NSLocalizedString("图片加载失败", comment: ""))
                        .foregroundColor(.white)
                )
                .onTapGesture {
                    isPresented = false
                }
        } else {
            FullScreenImageGallery(
                imageURLs: urls,
                currentIndex: $currentIndex,
                onDismiss: { isPresented = false }
            )
        }
    }
}

// 类型别名以保持向后兼容
typealias FullScreenImageViewer_StringURLs = FullScreenImageViewer_URLs
