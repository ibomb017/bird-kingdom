import SwiftUI
import Combine

/// 全局 Toast 提示管理器
/// 用于在 catch 静默错误时向用户显示友好提示
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: Toast?
    
    private init() {}
    
    struct Toast: Equatable {
        let message: String
        let type: ToastType
        let id = UUID()
        
        static func == (lhs: Toast, rhs: Toast) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum ToastType {
        case error
        case success
        case warning
        case info
        
        var backgroundColor: Color {
            switch self {
            case .error: return Color.red
            case .success: return Color.green
            case .warning: return Color.orange
            case .info: return Color.blue
            }
        }
        
        var icon: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    /// 显示错误提示
    @MainActor
    func showError(_ message: String) {
        show(message, type: .error)
    }
    
    /// 显示成功提示
    @MainActor
    func showSuccess(_ message: String) {
        show(message, type: .success)
    }
    
    /// 显示警告提示
    @MainActor
    func showWarning(_ message: String) {
        show(message, type: .warning)
    }
    
    /// 显示信息提示
    @MainActor
    func showInfo(_ message: String) {
        show(message, type: .info)
    }
    
    @MainActor
    private func show(_ message: String, type: ToastType) {
        withAnimation(.spring(response: 0.3)) {
            currentToast = Toast(message: message, type: type)
        }
        
        // 2秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            withAnimation(.spring(response: 0.3)) {
                self?.currentToast = nil
            }
        }
    }
}

/// Toast 显示视图 - 添加到 App 根视图
struct ToastView: View {
    @ObservedObject var toastManager = ToastManager.shared
    
    var body: some View {
        if let toast = toastManager.currentToast {
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    Image(systemName: toast.type.icon)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                    
                    Text(toast.message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // 关闭按钮
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(toast.type.backgroundColor.opacity(0.95))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // 留出 TabBar 空间
                .onTapGesture {
                    // 点击立即消除
                    withAnimation(.spring(response: 0.3)) {
                        toastManager.currentToast = nil
                    }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(999)
        }
    }
}

/// View Modifier 方便添加 Toast
struct ToastModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
            ToastView()
        }
    }
}

extension View {
    func withToast() -> some View {
        modifier(ToastModifier())
    }
}
