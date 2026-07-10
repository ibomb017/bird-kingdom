import SwiftUI

// MARK: - View Extensions
// 通用 View 扩展，用于提供一致的 UI 行为

extension View {
    /// 隐藏键盘
    /// 使用方式：在任何需要隐藏键盘的地方调用
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// 点击空白处收起键盘的全局修饰器
    /// 使用方式：在任何 View 上添加 .dismissKeyboardOnTap()
    /// 效果：点击视图空白区域自动收起键盘，不影响按钮、列表等交互元素
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    /// 添加透明背景手势层来收起键盘（不影响子视图交互）
    /// 使用方式：在需要收起键盘的容器视图上添加 .dismissKeyboardOnBackground()
    /// 效果：点击未被子视图覆盖的区域时收起键盘
    func dismissKeyboardOnBackground() -> some View {
        self.background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
    
    /// 同时支持滑动和点击收起键盘的高级修饰器
    /// 使用方式：在 ScrollView 等容器上添加 .dismissKeyboardInteractively()
    func dismissKeyboardInteractively() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}

// MARK: - 支持键盘自动隐藏的 ScrollView
/// 带有原生键盘隐藏功能的 ScrollView 包装器
/// 使用方式：用 KeyboardDismissScrollView 替代普通 ScrollView
/// 效果：滑动时键盘交互式下滑（与微信、小红书一致）
struct KeyboardDismissScrollView<Content: View>: View {
    let showsIndicators: Bool
    let content: Content
    
    init(showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }
    
    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            content
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - 支持键盘隐藏的 Form
/// 带有原生键盘隐藏功能的 Form 包装器
struct KeyboardDismissForm<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Form {
            content
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - 点击隐藏键盘的 VStack
/// 点击任意区域可隐藏键盘的 VStack
/// 适用于不使用 ScrollView 的页面
struct TapToDismissKeyboardVStack<Content: View>: View {
    let spacing: CGFloat?
    let alignment: HorizontalAlignment
    let content: Content
    
    init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - UIImage 扩展
extension UIImage {
    /// 修正图片方向（处理 EXIF Orientation）
    /// 部分设备/相机拍摄的图片方向信息存储在 EXIF 中，直接使用可能导致图片旋转
    func fixedOrientation() -> UIImage {
        // 如果方向已经是正常的，直接返回
        guard imageOrientation != .up else { return self }
        
        // 创建正确方向的图片
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
