import SwiftUI

// MARK: - 统一自定义导航栏组件
struct CustomNavigationBar<LeftContent: View, RightContent: View>: View {
    let title: String
    let leftContent: LeftContent
    let rightContent: RightContent
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    init(
        title: String,
        @ViewBuilder leftContent: () -> LeftContent,
        @ViewBuilder rightContent: () -> RightContent
    ) {
        self.title = title
        self.leftContent = leftContent()
        self.rightContent = rightContent()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // 标题居中
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // 左右按钮
                HStack {
                    leftContent
                        .frame(minWidth: 44, alignment: .leading)
                    
                    Spacer()
                    
                    rightContent
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 16)
            .background(themeManager.backgroundColor.opacity(0.3))
            
            Divider()
        }
    }
}

// MARK: - 便捷初始化器
extension CustomNavigationBar where LeftContent == EmptyView, RightContent == EmptyView {
    init(title: String) {
        self.init(title: title, leftContent: { EmptyView() }, rightContent: { EmptyView() })
    }
}

extension CustomNavigationBar where RightContent == EmptyView {
    init(title: String, @ViewBuilder leftContent: () -> LeftContent) {
        self.init(title: title, leftContent: leftContent, rightContent: { EmptyView() })
    }
}

extension CustomNavigationBar where LeftContent == EmptyView {
    init(title: String, @ViewBuilder rightContent: () -> RightContent) {
        self.init(title: title, leftContent: { EmptyView() }, rightContent: rightContent)
    }
}

// MARK: - 常用导航栏按钮
struct NavBarButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isBold: Bool = false
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundColor(isEnabled ? themeManager.primaryColor : .gray)
        }
        .disabled(!isEnabled)
    }
}

struct NavBarBackButton: View {
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text(L10n.back)
            }
            .foregroundColor(themeManager.primaryColor)
        }
    }
}

struct NavBarCloseButton: View {
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(L10n.close, action: action)
            .foregroundColor(themeManager.primaryColor)
    }
}

struct NavBarCancelButton: View {
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(L10n.cancel, action: action)
            .foregroundColor(themeManager.primaryColor)
    }
}

struct NavBarSaveButton: View {
    let action: () -> Void
    var isEnabled: Bool = true
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            Text(L10n.save)
                .fontWeight(.semibold)
                .foregroundColor(isEnabled ? themeManager.primaryColor : .gray)
        }
        .disabled(!isEnabled)
    }
}

struct NavBarDoneButton: View {
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(L10n.done, action: action)
            .fontWeight(.semibold)
            .foregroundColor(themeManager.primaryColor)
    }
}

// MARK: - 带自定义导航栏的页面容器（支持左边缘滑动返回）
struct CustomNavPage<Content: View, LeftContent: View, RightContent: View>: View {
    let title: String
    let leftContent: LeftContent
    let rightContent: RightContent
    let content: Content
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // 滑动返回状态
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    init(
        title: String,
        @ViewBuilder leftContent: () -> LeftContent,
        @ViewBuilder rightContent: () -> RightContent,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.leftContent = leftContent()
        self.rightContent = rightContent()
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth: CGFloat = geometry.size.width
            
            ZStack {
                // 背景（滑动时显示暗色遮罩效果）
                Color.black
                    .opacity(Double(isDragging ? 0.3 * (1.0 - dragOffset / screenWidth) : 0))
                    .ignoresSafeArea()
                
                // 主要内容
                VStack(spacing: 0) {
                    CustomNavigationBar(
                        title: title,
                        leftContent: { leftContent },
                        rightContent: { rightContent }
                    )
                    
                    content
                }
                .background(Color.adaptiveCard)
                .offset(x: dragOffset)  // 水平偏移
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // 只响应从左边缘开始的向右滑动
                        if value.startLocation.x < 30 && value.translation.width > 0 {
                            isDragging = true
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        // 滑动超过屏幕1/3或速度够快则关闭页面
                        if value.startLocation.x < 30 && (value.translation.width > screenWidth / 3 || value.predictedEndTranslation.width > screenWidth / 2) {
                            dragOffset = screenWidth
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                dismiss()
                            }
                        } else {
                            dragOffset = 0
                        }
                        isDragging = false
                    }
            )
        }
        .navigationBarHidden(true)
    }
}

// MARK: - 便捷初始化器
extension CustomNavPage where LeftContent == NavBarBackButton, RightContent == EmptyView {
    /// 带返回按钮的页面
    init(title: String, onBack: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(
            title: title,
            leftContent: { NavBarBackButton(action: onBack) },
            rightContent: { EmptyView() },
            content: content
        )
    }
}

extension CustomNavPage where LeftContent == NavBarCloseButton, RightContent == EmptyView {
    /// 带关闭按钮的页面
    init(title: String, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(
            title: title,
            leftContent: { NavBarCloseButton(action: onClose) },
            rightContent: { EmptyView() },
            content: content
        )
    }
}

extension CustomNavPage where LeftContent == NavBarCancelButton, RightContent == NavBarSaveButton {
    /// 带取消和保存按钮的页面
    init(title: String, onCancel: @escaping () -> Void, onSave: @escaping () -> Void, canSave: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(
            title: title,
            leftContent: { NavBarCancelButton(action: onCancel) },
            rightContent: { NavBarSaveButton(action: onSave, isEnabled: canSave) },
            content: content
        )
    }
}

extension CustomNavPage where LeftContent == EmptyView, RightContent == NavBarDoneButton {
    /// 带完成按钮的页面
    init(title: String, onDone: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(
            title: title,
            leftContent: { EmptyView() },
            rightContent: { NavBarDoneButton(action: onDone) },
            content: content
        )
    }
}

extension CustomNavPage where LeftContent == NavBarCloseButton, RightContent == NavBarDoneButton {
    /// 带关闭和完成按钮的页面
    init(title: String, onClose: @escaping () -> Void, onDone: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(
            title: title,
            leftContent: { NavBarCloseButton(action: onClose) },
            rightContent: { NavBarDoneButton(action: onDone) },
            content: content
        )
    }
}

// MARK: - Preview
#Preview("自定义导航栏") {
    VStack {
        CustomNavigationBar(
            title: NSLocalizedString("页面标题", comment: ""),
            leftContent: { NavBarCancelButton {} },
            rightContent: { NavBarSaveButton {} }
        )
        
        Spacer()
        
        Text(NSLocalizedString("页面内容", comment: ""))
        
        Spacer()
    }
}

#Preview("带导航栏的页面") {
    CustomNavPage(title: L10n.editProfile, onCancel: {}, onSave: {}) {
        Form {
            Section(NSLocalizedString("基本信息", comment: "")) {
                TextField(L10n.birdName, text: .constant(NSLocalizedString("小鸟", comment: "")))
            }
        }
        .scrollContentBackground(.hidden)
    }
}
