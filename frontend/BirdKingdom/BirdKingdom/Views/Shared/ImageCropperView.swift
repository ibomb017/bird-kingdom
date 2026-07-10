import SwiftUI
import UIKit
import Combine

// MARK: - 基于 UIViewController 的原生裁剪器

struct ImageCropperView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var croppedImage: UIImage?
    let originalImage: UIImage
    
    // 使用 @StateObject 确保引用在 View 生命周期内保持稳定
    @StateObject private var cropperState = CropperState()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 核心裁剪容器 (UIViewController)
            ImageCropperHost(originalImage: originalImage, cropperState: cropperState)
                .ignoresSafeArea()
            
            // 底部工具栏
            VStack {
                Spacer()
                
                HStack(alignment: .center) {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        Text(L10n.cancel)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    
                    Spacer()
                    
                    Text(NSLocalizedString("移动和缩放", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Button {
                        HapticFeedback.medium()
                        if let image = cropperState.crop() {
                            croppedImage = image
                        }
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("选取", comment: ""))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(ThemeManager.shared.primaryColor)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10 + safeAreaBottomPadding)
                .background(.ultraThinMaterial)
                .colorScheme(.dark)
            }
        }
        .statusBar(hidden: true)
    }
    
    private var safeAreaBottomPadding: CGFloat {
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first {
            return window.safeAreaInsets.bottom
        }
        return 0
    }
}

// MARK: - 裁剪器状态管理 (ObservableObject 确保稳定引用)

class CropperState: ObservableObject {
    // 需要至少一个 @Published 属性或者显式声明 objectWillChange
    @Published private var _dummy: Bool = false
    weak var viewController: ImageCropperViewController?
    
    func crop() -> UIImage? {
        return viewController?.cropImage()
    }
}

// MARK: - UIViewController 封装

struct ImageCropperHost: UIViewControllerRepresentable {
    let originalImage: UIImage
    let cropperState: CropperState
    
    func makeUIViewController(context: Context) -> ImageCropperViewController {
        let controller = ImageCropperViewController()
        controller.originalImage = originalImage
        cropperState.viewController = controller
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ImageCropperViewController, context: Context) {
        // 不需要更新
    }
}

// MARK: - 核心控制器

class ImageCropperViewController: UIViewController, UIScrollViewDelegate {
    
    var originalImage: UIImage?
    
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let maskLayer = CAShapeLayer()
    private let overlayView = UIView()
    
    private var cropRect: CGRect = .zero
    private var isLayoutConfigured = false
    private var borderLayer: CAShapeLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScrollView()
        setupOverlay()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard !isLayoutConfigured && view.bounds.width > 0 else {
            if isLayoutConfigured {
                updateMaskLayer()
            }
            return
        }
        
        // 直接配置，不使用 async
        isLayoutConfigured = true
        configureLayout()
        updateMaskLayer()
    }
    
    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.image = originalImage
        scrollView.addSubview(imageView)
    }

    private func setupOverlay() {
        overlayView.frame = view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.addSubview(overlayView)
        
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
    }

    private func configureLayout() {
        guard let image = originalImage else { return }
        
        // 裁剪区域
        let padding: CGFloat = 20
        let width = view.bounds.width - (padding * 2)
        let height = width
        let x = (view.bounds.width - width) / 2
        let y = (view.bounds.height - height) / 2
        cropRect = CGRect(x: x, y: y, width: width, height: height)
        
        // ScrollView 的 ContentInset
        scrollView.contentInset = UIEdgeInsets(
            top: cropRect.minY,
            left: cropRect.minX,
            bottom: view.bounds.height - cropRect.maxY,
            right: view.bounds.width - cropRect.maxX
        )
        
        // ImageView 初始 Frame 和 ContentSize
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
        
        // 缩放比例 (AspectFill)
        let scaleWidth = cropRect.width / image.size.width
        let scaleHeight = cropRect.height / image.size.height
        let minScale = max(scaleWidth, scaleHeight)
        
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(minScale * 3.0, 3.0)
        scrollView.zoomScale = minScale
        
        // 居中
        let contentWidth = scrollView.contentSize.width
        let contentHeight = scrollView.contentSize.height
        let finalOffsetX = -scrollView.contentInset.left + (contentWidth - cropRect.width) / 2
        let finalOffsetY = -scrollView.contentInset.top + (contentHeight - cropRect.height) / 2
        scrollView.contentOffset = CGPoint(x: finalOffsetX, y: finalOffsetY)
        
        // 双击手势
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }
    
    private func updateMaskLayer() {
        let path = UIBezierPath(rect: overlayView.bounds)
        let cropPath = UIBezierPath(ovalIn: cropRect)
        path.append(cropPath)
        maskLayer.path = path.cgPath
        
        if borderLayer == nil {
            let layer = CAShapeLayer()
            layer.strokeColor = UIColor.white.cgColor
            layer.lineWidth = 1
            layer.fillColor = UIColor.clear.cgColor
            overlayView.layer.addSublayer(layer)
            borderLayer = layer
        }
        borderLayer?.path = UIBezierPath(ovalIn: cropRect).cgPath
    }
    
    // MARK: - UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    @objc private func handleDoubleTap() {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            scrollView.setZoomScale(scrollView.maximumZoomScale, animated: true)
        }
    }
    
    func cropImage() -> UIImage? {
        guard let image = originalImage else { return nil }
        
        let offset = scrollView.contentOffset
        let scale = scrollView.zoomScale
        
        let x = offset.x + scrollView.contentInset.left
        let y = offset.y + scrollView.contentInset.top
        
        let imageX = x / scale
        let imageY = y / scale
        let imageW = cropRect.width / scale
        let imageH = cropRect.height / scale
        
        let finalRect = CGRect(x: imageX, y: imageY, width: imageW, height: imageH)
        
        guard let cgImage = image.cgImage?.cropping(to: finalRect) else { return nil }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

#Preview {
    ImageCropperView(croppedImage: .constant(nil), originalImage: UIImage(systemName: "person.crop.circle")!)
}
