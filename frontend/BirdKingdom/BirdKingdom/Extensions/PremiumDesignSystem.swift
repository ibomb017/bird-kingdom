import SwiftUI

// MARK: - 苹果原生交互设计系统
// 设计原则：简约、精致、高级感，不追求花哨
// 参考：Apple 原生应用的交互设计规范

// MARK: - 高级感按钮样式
/// 主按钮样式 - 用于主要操作（保存、确认、发布等）
struct PrimaryButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(isEnabled ? .white : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.4))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 次级按钮样式 - 用于次要操作（取消、返回等）
struct SecondaryButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(themeManager.primaryColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.primaryColor.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 卡片按钮样式 - 用于可点击的卡片
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 列表项按钮样式 - 用于列表中的可点击项
struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.gray.opacity(0.1) : Color.clear)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 轻触按钮样式 - 用于小型图标按钮
struct LightTapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 高级感卡片样式
extension View {
    /// 标准卡片样式 - 简约设计
    func premiumCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptiveCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
    }
    
    /// 带主题色边框的卡片
    func themedCard() -> some View {
        let themeManager = ThemeManager.shared
        return self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptiveCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.primaryColor.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
    }
    
    /// 输入框背景样式
    func inputFieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

// MARK: - 高级感列表分隔线
struct PremiumDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.12))
            .frame(height: 0.5)
    }
}

// MARK: - Section Header 样式
struct PremiumSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            if let actionLabel = actionLabel, let action = action {
                Button(actionLabel, action: action)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.primaryColor)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - 空状态视图
struct PremiumEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(themeManager.primaryColor.opacity(0.6))
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(themeManager.primaryColor)
                    )
                    .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

// MARK: - 加载状态视图
struct PremiumLoadingView: View {
    var message: String = "加载中..."
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(themeManager.primaryColor)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - 触觉反馈工具
struct HapticFeedback {
    /// 轻触反馈 - 用于小型交互
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    /// 中等反馈 - 用于确认操作
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// 成功反馈
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    /// 错误反馈
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    /// 选择变化反馈 - 用于 Picker、Tab 切换
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - View 扩展：标准交互动画
extension View {
    /// 添加点击缩放效果
    func pressAnimation() -> some View {
        self.buttonStyle(CardButtonStyle())
    }
    
    /// 添加出现动画
    func appearAnimation(delay: Double = 0) -> some View {
        self.modifier(AppearAnimationModifier(delay: delay))
    }
    
    /// 标准内容内边距
    func standardPadding() -> some View {
        self.padding(.horizontal, 16)
    }
}

// MARK: - 出现动画修饰符
struct AppearAnimationModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Sheet 呈现样式
extension View {
    /// 标准 Sheet 样式
    func premiumSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            content()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
    }
}

// MARK: - 渐变遮罩
struct GradientMask: View {
    var body: some View {
        LinearGradient(
            colors: [.clear, Color(.systemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - 标准阴影
extension View {
    /// 轻微阴影 - 用于卡片
    func lightShadow() -> some View {
        self.shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
    
    /// 中等阴影 - 用于浮动元素
    func mediumShadow() -> some View {
        self.shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}
