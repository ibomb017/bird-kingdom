import SwiftUI
import UIKit
import AVKit

// MARK: - 小红书/抖音式全屏视频控制器
/// 核心：保留导航栈完整性 + 显式启用系统边缘手势 + 手势优先级与方向隔离
class VideoFeedViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {
    
    // 数据
    var posts: [ForumPost] = []
    var initialIndex: Int = 0
    var primaryColor: UIColor = .systemBlue
    var onDismiss: (() -> Void)?
    
    // UI
    private var collectionView: UICollectionView!
    private var currentIndex: Int = 0
    private var hasScrolledToInitial = false
    
    // 边缘触发宽度（20-30pt）
    private let edgeWidth: CGFloat = 25
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 【关键1】隐藏导航栏但不"断开"
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // 【关键2】强制启用原生边缘手势并设置代理
        if let navController = navigationController {
            navController.interactivePopGestureRecognizer?.isEnabled = true
            navController.interactivePopGestureRecognizer?.delegate = self
            
            // 【关键3】设置手势优先级 - CollectionView 等待系统手势失败
            if let popGesture = navController.interactivePopGestureRecognizer {
                collectionView.panGestureRecognizer.require(toFail: popGesture)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 恢复导航栏（给其他页面）
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasScrolledToInitial && initialIndex > 0 && initialIndex < posts.count {
            let indexPath = IndexPath(item: initialIndex, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            hasScrolledToInitial = true
        }
    }
    
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.bounces = true
        collectionView.alwaysBounceVertical = true
        
        // 【关键4】锁定纵向滚动，避免横向干扰
        collectionView.isDirectionalLockEnabled = true
        
        collectionView.register(VideoFeedCell.self, forCellWithReuseIdentifier: "VideoFeedCell")
        
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return posts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoFeedCell", for: indexPath) as! VideoFeedCell
        cell.configure(with: posts[indexPath.item], primaryColor: primaryColor, onDismiss: { [weak self] in
            self?.handleDismiss()
        })
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    // 【关键5】边缘触发 - 仅当触摸点在左侧 25pt 边缘时触发返回手势
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            // 栈长度必须 > 1
            guard (navigationController?.viewControllers.count ?? 0) > 1 else { return false }
            
            // 触摸点必须在左侧边缘
            let location = gestureRecognizer.location(in: view)
            return location.x <= edgeWidth
        }
        
        if gestureRecognizer == collectionView.panGestureRecognizer {
            let velocity = collectionView.panGestureRecognizer.velocity(in: collectionView)
            let location = gestureRecognizer.location(in: view)
            
            // 如果在边缘且是横向滑动，禁止 CollectionView 处理
            if location.x <= edgeWidth && abs(velocity.x) > abs(velocity.y) {
                return false
            }
            return true
        }
        
        return true
    }
    
    // 【关键6】允许手势共存
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: - 统一导航操作
    
    private func handleDismiss() {
        if let navController = navigationController {
            // 【关键7】栈长度 > 2 时正常 pop，只剩锚点时 dismiss
            if navController.viewControllers.count > 2 {
                navController.popViewController(animated: true)
            } else {
                // 只剩锚点 VC 和当前 VC，dismiss 整个模态
                navController.dismiss(animated: true) {
                    self.onDismiss?()
                }
            }
        } else {
            onDismiss?()
        }
    }
}

// MARK: - 视频 Cell
class VideoFeedCell: UICollectionViewCell {
    private var hostingController: UIHostingController<AnyView>?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .black
        // 【关键8】不独占触摸，允许手势穿透
        contentView.isExclusiveTouch = false
        contentView.isUserInteractionEnabled = true
        isExclusiveTouch = false
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with post: ForumPost, primaryColor: UIColor, onDismiss: @escaping () -> Void) {
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        
        let swiftUIView = VideoPlayerView(
            post: post,
            isActive: true,
            primaryColor: Color(primaryColor),
            onDismiss: onDismiss
        )
        
        let hostingVC = UIHostingController(rootView: AnyView(swiftUIView))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.frame = contentView.bounds
        hostingVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingVC.view.isUserInteractionEnabled = true
        hostingVC.view.isExclusiveTouch = false  // 不独占触摸
        
        contentView.addSubview(hostingVC.view)
        hostingController = hostingVC
        
        if let parentVC = findViewController() {
            parentVC.addChild(hostingVC)
            hostingVC.didMove(toParent: parentVC)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}

// MARK: - 锚点 VC（透明占位，确保导航栈 ≥ 2）
class AnchorViewController: UIViewController {
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 如果被 pop 回来，说明用户完成了返回，dismiss 整个模态
        if navigationController?.viewControllers.first === self && navigationController?.viewControllers.count == 1 {
            dismiss(animated: false) {
                self.onDismiss?()
            }
        }
    }
}

// MARK: - 自定义 UINavigationController（统一导航操作）
class VideoFeedNavigationController: UINavigationController, UINavigationControllerDelegate {
    
    var onFullDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        isNavigationBarHidden = true
        interactivePopGestureRecognizer?.isEnabled = true
    }
    
    // 【关键9】监听导航栈变化，防止白屏
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        // 如果只剩锚点 VC，自动 dismiss
        if viewController is AnchorViewController && viewControllers.count == 1 {
            dismiss(animated: true) {
                self.onFullDismiss?()
            }
        }
    }
}

// MARK: - SwiftUI 桥接（使用 fullScreenCover 呈现）
struct VideoFeedPresenter: UIViewControllerRepresentable {
    let posts: [ForumPost]
    let initialIndex: Int
    let primaryColor: Color
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> VideoFeedNavigationController {
        // 【关键10】创建锚点 VC 作为根，确保导航栈 ≥ 2
        let anchorVC = AnchorViewController()
        anchorVC.onDismiss = onDismiss
        
        let navController = VideoFeedNavigationController(rootViewController: anchorVC)
        navController.onFullDismiss = onDismiss
        navController.modalPresentationStyle = .fullScreen
        
        // 创建视频 Feed VC 并 push
        let videoFeedVC = VideoFeedViewController()
        videoFeedVC.posts = posts
        videoFeedVC.initialIndex = initialIndex
        videoFeedVC.primaryColor = UIColor(primaryColor)
        videoFeedVC.onDismiss = onDismiss
        
        navController.pushViewController(videoFeedVC, animated: false)
        
        return navController
    }
    
    func updateUIViewController(_ uiViewController: VideoFeedNavigationController, context: Context) {}
}

// MARK: - SwiftUI 包装器（用于 fullScreenCover）
struct VideoFeedSheet: View {
    let posts: [ForumPost]
    let initialIndex: Int
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VideoFeedPresenter(
            posts: posts,
            initialIndex: initialIndex,
            primaryColor: primaryColor,
            onDismiss: { dismiss() }
        )
        .ignoresSafeArea()
    }
}
