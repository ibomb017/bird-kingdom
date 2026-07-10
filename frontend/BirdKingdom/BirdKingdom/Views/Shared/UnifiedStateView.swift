import SwiftUI

// MARK: - 统一状态视图（苹果原生风格）
// 用于加载失败、空状态、搜索无结果等场景

/// 状态类型
enum StateViewType {
    case loading
    case error(String)
    case empty
    case noResults
    case noNetwork
    case custom(icon: String, title: String, message: String)
}

/// 统一的状态视图 - 使用 iOS 17 ContentUnavailableView 风格
struct UnifiedStateView: View {
    let type: StateViewType
    var retryAction: (() -> Void)? = nil
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        VStack {
            Spacer()
            contentView
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch type {
        case .loading:
            loadingView
            
        case .error(let message):
            errorView(message: message)
            
        case .empty:
            emptyView
            
        case .noResults:
            noResultsView
            
        case .noNetwork:
            noNetworkView
            
        case .custom(let icon, let title, let message):
            customView(icon: icon, title: title, message: message)
        }
    }
    
    // MARK: - 加载中
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(primaryColor)
            
            Text(L10n.loading)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 加载失败
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            // 高级渐变背景图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.95, blue: 0.97),
                                Color(red: 0.90, green: 0.90, blue: 0.93)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                
                Image(systemName: "icloud.slash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.secondary, Color.secondary.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("加载失败", comment: ""))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(3)
            }
            
            if let retryAction = retryAction {
                Button {
                    retryAction()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text(NSLocalizedString("重新加载", comment: ""))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(primaryColor)
                    )
                    .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - 空状态
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            
            Text(NSLocalizedString("暂无内容", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(NSLocalizedString("这里还没有任何内容", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 搜索无结果
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            
            Text(NSLocalizedString("未找到结果", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(NSLocalizedString("尝试使用其他关键词搜索", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 无网络
    private var noNetworkView: some View {
        VStack(spacing: 20) {
            // 高级渐变背景图标
            ZStack {
                // 外圈动态效果
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.secondary.opacity(0.15),
                                Color.secondary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.95, blue: 0.97),
                                Color(red: 0.90, green: 0.90, blue: 0.93)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.secondary, Color.secondary.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("网络连接失败", comment: ""))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(NSLocalizedString("请检查您的网络设置后重试", comment: ""))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            
            if let retryAction = retryAction {
                Button {
                    retryAction()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text(NSLocalizedString("重新连接", comment: ""))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(primaryColor)
                    )
                    .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - 自定义
    private func customView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let retryAction = retryAction {
                Button {
                    retryAction()
                } label: {
                    Text(L10n.retry)
                        .font(.body)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(primaryColor)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - 快捷构造器扩展

extension UnifiedStateView {
    /// 加载中视图
    static var loading: UnifiedStateView {
        UnifiedStateView(type: .loading)
    }
    
    /// 加载失败视图
    static func error(_ message: String, retry: (() -> Void)? = nil) -> UnifiedStateView {
        UnifiedStateView(type: .error(message), retryAction: retry)
    }
    
    /// 空状态视图
    static var empty: UnifiedStateView {
        UnifiedStateView(type: .empty)
    }
    
    /// 搜索无结果视图
    static var noResults: UnifiedStateView {
        UnifiedStateView(type: .noResults)
    }
    
    /// 无网络视图
    static func noNetwork(retry: (() -> Void)? = nil) -> UnifiedStateView {
        UnifiedStateView(type: .noNetwork, retryAction: retry)
    }
    
    /// 自定义状态视图
    static func custom(icon: String, title: String, message: String, retry: (() -> Void)? = nil) -> UnifiedStateView {
        UnifiedStateView(type: .custom(icon: icon, title: title, message: message), retryAction: retry)
    }
}

// MARK: - 特定场景预设视图

/// 鸟类空状态视图
struct EmptyBirdsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bird")
                .font(.system(size: 50))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.primaryColor.opacity(0.5))
            
            Text(NSLocalizedString("还没有鸟档案", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(NSLocalizedString("点击右上角添加你的第一只鸟儿", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 日志空状态视图
struct EmptyLogsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "note.text")
                .font(.system(size: 50))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.primaryColor.opacity(0.5))
            
            Text(NSLocalizedString("还没有日志", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(NSLocalizedString("记录鸟儿的日常点滴", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 帖子空状态视图
struct EmptyPostsView: View {
    let message: String
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.primaryColor.opacity(0.5))
            
            Text(NSLocalizedString("暂无内容", comment: ""))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("加载失败") {
    UnifiedStateView.error(NSLocalizedString("无法连接到服务器，请检查网络", comment: "")) {
        print("重试")
    }
}

#Preview("空状态") {
    UnifiedStateView.empty
}

#Preview("搜索无结果") {
    UnifiedStateView.noResults
}

#Preview("鸟类空状态") {
    EmptyBirdsView()
}
