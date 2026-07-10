import SwiftUI
import Combine
import UIKit

// 主题类型 - 森林绿为默认，牡丹鹦鹉主题为VIP专属
enum AppTheme: String, CaseIterable {
    case classicGreen = "森林绿"    // 默认主题（经典森林绿）
    case forestGreen = "薄荷绿"     // 免费主题
    case lavender = "大卑紫"       // 免费主题
    case lutino = "蛋黄"           // VIP - 蛋黄色主题
    case cobalt = "宝石蓝"         // VIP - 宝石蓝主题
    case hacker = "黑客黑"         // VIP - 黑客主题
    
    // 主题主色调（用于文字、图标等需要清晰显示的元素）
    var primaryColor: Color {
        switch self {
        case .classicGreen:
            // 经典森林绿：深绿色 #246A49
            return Color(red: 0.14, green: 0.42, blue: 0.29)
        case .forestGreen:
            // 薄荷绿深色版：用于文字和图标 #5BBFBF
            return Color(red: 0.357, green: 0.749, blue: 0.749)
        case .lavender:
            // 大卑紫深色版：用于文字和图标 #8A9BD4
            return Color(red: 0.541, green: 0.608, blue: 0.831)
        case .lutino:
            // 黄化：整体黄色，头部橙黄色
            return Color(red: 0.95, green: 0.70, blue: 0.15)
        case .cobalt:
            // 宝石蓝：#00BFFF
            return Color(red: 0.0, green: 0.749, blue: 1.0)
        case .hacker:
            // 霓虹紫色（更亮，在深色背景上醒目）
            return Color(red: 0.75, green: 0.55, blue: 1.0)
        }
    }
    
    // 主题背景色（用于卡片背景等浅色区域）
    var backgroundColor: Color {
        switch self {
        case .classicGreen:
            // 经典森林绿浅色版：#A8D5BA
            return Color(red: 0.66, green: 0.84, blue: 0.73)
        case .forestGreen:
            // 薄荷绿浅色版：#A7E5E5
            return Color(red: 0.655, green: 0.898, blue: 0.898)
        case .lavender:
            // 大卑紫浅色版：#D1D9F0
            return Color(red: 0.820, green: 0.851, blue: 0.941)
        case .lutino:
            return Color(red: 1.0, green: 0.96, blue: 0.88)
        case .cobalt:
            // 宝石蓝浅色背景
            return Color(red: 0.88, green: 0.96, blue: 1.0)
        case .hacker:
            // 纯黑背景（与苹果深色模式一致）
            return Color(uiColor: .black)
        }
    }
    
    // 主题次要色调（身体颜色）
    var secondaryColor: Color {
        switch self {
        case .classicGreen:
            // 经典森林绿次要色 #3D8B5F
            return Color(red: 0.24, green: 0.55, blue: 0.37)
        case .forestGreen:
            // 薄荷绿次要色
            return Color(red: 0.55, green: 0.80, blue: 0.80)
        case .lavender:
            // 大卑紫次要色
            return Color(red: 0.75, green: 0.78, blue: 0.88)
        case .lutino:
            // 身体浅黄色
            return Color(red: 1.0, green: 0.85, blue: 0.40)
        case .cobalt:
            // 宝石蓝次要色
            return Color(red: 0.0, green: 0.65, blue: 0.90)
        case .hacker:
            // 深空灰（用于卡片背景，与系统深色模式一致）
            return Color(red: 0.11, green: 0.11, blue: 0.118)  // #1C1C1E
        }
    }
    
    // 渐变色（模拟牡丹鹦鹉头部到身体的自然渐变）
    var gradientColors: [Color] {
        switch self {
        case .classicGreen:
            // 经典森林绿渐变
            return [
                Color(red: 0.14, green: 0.42, blue: 0.29),  // 深森林绿 #246A49
                Color(red: 0.24, green: 0.55, blue: 0.37)   // 浅森林绿 #3D8B5F
            ]
        case .forestGreen:
            // 薄荷绿渐变
            return [
                Color(red: 0.55, green: 0.82, blue: 0.82),  // 深薄荷绿
                Color(red: 0.70, green: 0.92, blue: 0.92)   // 浅薄荷绿
            ]
        case .lavender:
            // 大卑紫渐变
            return [
                Color(red: 0.75, green: 0.78, blue: 0.88),  // 深大卑紫
                Color(red: 0.88, green: 0.90, blue: 0.96)   // 浅大卑紫
            ]
        case .lutino:
            // 橙黄色头部 -> 浅黄色身体
            return [
                Color(red: 0.95, green: 0.70, blue: 0.15),  // 头部橙黄
                Color(red: 1.0, green: 0.85, blue: 0.40)    // 身体浅黄
            ]
        case .cobalt:
            // 宝石蓝渐变
            return [
                Color(red: 0.0, green: 0.749, blue: 1.0),   // 宝石蓝
                Color(red: 0.0, green: 0.65, blue: 0.90)    // 深宝石蓝
            ]
        case .hacker:
            // 更深的渐变（纯黑到深灰）
            return [
                Color(red: 0.11, green: 0.11, blue: 0.118), // #1C1C1E 深空灰
                Color(red: 0.0, green: 0.0, blue: 0.0)      // 纯黑
            ]
        }
    }
    
    // 选中状态的渐变色（稍微亮一些）
    var selectedGradientColors: [Color] {
        switch self {
        case .classicGreen:
            return [
                Color(red: 0.30, green: 0.50, blue: 0.42),
                Color(red: 0.50, green: 0.68, blue: 0.58)
            ]
        case .forestGreen:
            return [
                Color(red: 0.50, green: 0.78, blue: 0.78),
                Color(red: 0.65, green: 0.88, blue: 0.88)
            ]
        case .lavender:
            return [
                Color(red: 0.70, green: 0.75, blue: 0.85),
                Color(red: 0.85, green: 0.88, blue: 0.95)
            ]
        case .lutino:
            return [
                Color(red: 1.0, green: 0.80, blue: 0.25),
                Color(red: 1.0, green: 0.92, blue: 0.50)
            ]
        case .cobalt:
            return [
                Color(red: 0.2, green: 0.80, blue: 1.0),
                Color(red: 0.0, green: 0.70, blue: 0.95)
            ]
        case .hacker:
            return [
                Color(red: 0.22, green: 0.22, blue: 0.24),   // 选中态亮灰
                Color(red: 0.15, green: 0.15, blue: 0.16)    // 选中态深灰
            ]
        }
    }
    
    // 主题图标
    var icon: String {
        switch self {
        case .classicGreen:
            return "tree.fill"
        case .forestGreen:
            return "leaf.fill"
        case .lavender:
            return "sparkle"
        case .lutino:
            return "sun.max.fill"
        case .cobalt:
            return "drop.fill"
        case .hacker:
            return "terminal.fill"
        }
    }
    
    // 是否需要VIP
    var requiresVIP: Bool {
        switch self {
        case .classicGreen, .forestGreen, .lavender:
            return false  // 免费主题，所有用户可用
        default:
            return true   // 其他牡丹鹦鹉主题需要VIP
        }
    }
}

// 主题管理器
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published private var savedTheme: AppTheme
    @Published var systemColorSchemeIsDark: Bool = false  // 系统是否为深色模式
    private var themeBeforeDarkMode: AppTheme?  // 切换到深色模式前的主题
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 从UserDefaults加载保存的主题
        if let savedThemeStr = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedThemeStr) {
            self.savedTheme = theme
        } else {
            self.savedTheme = .classicGreen
        }
        
        // 加载系统深色模式前保存的主题
        if let beforeDarkStr = UserDefaults.standard.string(forKey: "themeBeforeDarkMode"),
           let theme = AppTheme(rawValue: beforeDarkStr) {
            self.themeBeforeDarkMode = theme
        }
        
        // 检测初始系统颜色模式
        self.systemColorSchemeIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        
        // 监听系统颜色模式变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTraitCollectionChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // 监听登录状态变化
        AuthService.shared.$isLoggedIn
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // 监听用户VIP状态变化 - P2-06: 添加VIP过期实时监听
        AuthService.shared.$currentUser
            .sink { [weak self] user in
                guard let self = self else { return }
                // P2-06: VIP过期时自动重置为默认主题
                if let user = user, !user.isVip && self.savedTheme.requiresVIP {
                    self.savedTheme = .classicGreen
                    self.saveTheme()
                    print("⚠️ VIP已过期，自动重置为默认主题")
                }
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    @objc private func handleTraitCollectionChange() {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        if isDark != systemColorSchemeIsDark {
            systemColorSchemeIsDark = isDark
            handleSystemColorSchemeChange(isDark: isDark)
        }
    }
    
    /// 处理系统颜色模式变化
    private func handleSystemColorSchemeChange(isDark: Bool) {
        if isDark {
            // 系统切换到深色模式 -> 自动切换到黑客黑主题
            if savedTheme != .hacker {
                themeBeforeDarkMode = savedTheme
                UserDefaults.standard.set(savedTheme.rawValue, forKey: "themeBeforeDarkMode")
                savedTheme = .hacker
                saveTheme()
                print("🌙 系统切换到深色模式，自动启用黑客黑主题")
            }
        } else {
            // 系统切换到浅色模式 -> 恢复之前的主题
            if savedTheme == .hacker, let previousTheme = themeBeforeDarkMode {
                savedTheme = previousTheme
                saveTheme()
                themeBeforeDarkMode = nil
                UserDefaults.standard.removeObject(forKey: "themeBeforeDarkMode")
                print("☀️ 系统切换到浅色模式，恢复之前的主题: \(previousTheme.rawValue)")
            }
        }
        objectWillChange.send()
    }
    
    // 当前实际使用的主题（考虑登录和VIP状态）
    var currentTheme: AppTheme {
        get {
            // 未登录时，强制使用默认森林绿主题
            guard AuthService.shared.isLoggedIn else {
                return .classicGreen
            }
            
            // 已登录但非VIP，且保存的主题需要VIP，则使用默认主题
            let isVIP = AuthService.shared.currentUser?.isVip ?? false
            if savedTheme.requiresVIP && !isVIP {
                return .classicGreen
            }
            
            return savedTheme
        }
        set {
            savedTheme = newValue
            saveTheme()
        }
    }
    
    // 保存主题到UserDefaults
    private func saveTheme() {
        UserDefaults.standard.set(savedTheme.rawValue, forKey: "selectedTheme")
    }
    
    // 切换主题（需要检查权限）
    func changeTheme(to theme: AppTheme) -> Bool {
        // 未登录不能切换主题
        guard AuthService.shared.isLoggedIn else {
            return false
        }
        
        // VIP主题需要VIP权限
        if theme.requiresVIP {
            let isVIP = AuthService.shared.currentUser?.isVip ?? false
            if !isVIP {
                return false
            }
        }
        
        savedTheme = theme
        saveTheme()
        
        // 更新导航栏外观
        DispatchQueue.main.async {
            self.updateNavigationBarAppearance()
        }
        
        return true
    }
    
    // 检查是否可以使用某个主题
    func canUseTheme(_ theme: AppTheme) -> Bool {
        // 默认主题所有人可用
        if !theme.requiresVIP {
            return true
        }
        
        // VIP主题需要登录且是VIP
        guard AuthService.shared.isLoggedIn else {
            return false
        }
        
        return AuthService.shared.currentUser?.isVip ?? false
    }
    
    /// P0-01: VIP主题切换（强制后端校验VIP状态）
    /// 返回值：true=切换成功，false=无权限
    @MainActor
    func changeThemeWithBackendValidation(to theme: AppTheme) async -> Bool {
        // 未登录不能切换主题
        guard AuthService.shared.isLoggedIn else {
            return false
        }
        
        // VIP主题需要后端校验VIP权限
        if theme.requiresVIP {
            do {
                // 强制从后端获取最新VIP状态
                let isVipValid = try await AuthService.shared.checkVipStatus()
                if !isVipValid {
                    print("⚠️ 后端VIP校验失败，无权使用VIP主题")
                    return false
                }
            } catch {
                print("❌ VIP状态校验网络错误: \(error.localizedDescription)")
                // 网络错误时，拒绝切换VIP主题（安全优先）
                return false
            }
        }
        
        savedTheme = theme
        saveTheme()
        
        // 更新导航栏外观
        updateNavigationBarAppearance()
        
        return true
    }
    
    // 获取当前主题的主色调（深色，用于文字和图标）
    var primaryColor: Color {
        currentTheme.primaryColor
    }
    
    // 获取当前主题的背景色（浅色，用于卡片背景）
    var backgroundColor: Color {
        currentTheme.backgroundColor
    }
    
    var secondaryColor: Color {
        currentTheme.secondaryColor
    }
    
    var gradientColors: [Color] {
        currentTheme.gradientColors
    }
    
    var selectedGradientColors: [Color] {
        currentTheme.selectedGradientColors
    }
    
    // 是否是深色主题（黑客主题）
    var isDarkTheme: Bool {
        currentTheme == .hacker
    }
    
    // 主要文字颜色（深色主题用白色，浅色主题用黑色）
    var textColor: Color {
        isDarkTheme ? .white : .primary
    }
    
    // 次要文字颜色
    var secondaryTextColor: Color {
        isDarkTheme ? Color(white: 0.7) : .secondary
    }
    
    // 卡片背景色（深色主题用深空灰，浅色主题用白色）
    var cardBackgroundColor: Color {
        isDarkTheme ? secondaryColor : .white
    }
    
    // 页面背景色（深色主题用纯黑，浅色主题用系统背景）
    var pageBackgroundColor: Color {
        isDarkTheme ? backgroundColor : Color(uiColor: .systemBackground)
    }
    
    // 页面背景渐变色
    var pageBackgroundGradient: LinearGradient {
        return LinearGradient(
            colors: [backgroundColor.opacity(0.15), backgroundColor.opacity(0.15)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - 导航栏淡色主题色（统一参数，参考广场详情页）
    /// 导航栏背景色 - 淡色主题色 (opacity 0.08)
    var navigationBarBackgroundColor: Color {
        currentTheme.primaryColor.opacity(0.08)
    }
    
    // 更新导航栏外观
    func updateNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // 设置返回按钮颜色为主题色
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(currentTheme.primaryColor)
    }
    
    // MARK: - 语义化颜色系统 (Compliance Design System)
    
    /// 交互高亮色（按钮点击态）- primaryColor 亮度提升
    var primaryColorHighlight: Color {
        primaryColor.opacity(0.9)
    }
    
    /// 禁用态强调色 - primaryColor 透明度降低
    var primaryColorDisabled: Color {
        primaryColor.opacity(0.6)
    }
    
    /// 浅色背景色（标签、卡片选中背景）
    var primaryColorBackground: Color {
        primaryColor.opacity(0.15)
    }
    
    /// 页面主背景 (System Background)
    var backgroundPrimary: Color {
        Color(uiColor: .systemBackground)
    }
    
    /// 次级背景 (System Grouped Background) - 用于卡片、输入框
    var backgroundSecondary: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    /// 主要文字 (Label)
    var textPrimary: Color {
        Color(uiColor: .label)
    }
    
    /// 次要文字 (Secondary Label) - 副标题、提示
    var textSecondary: Color {
        Color(uiColor: .secondaryLabel)
    }
    
    /// 辅助文字 (Tertiary Label) - 时间、备注
    var textTertiary: Color {
        Color(uiColor: .tertiaryLabel)
    }
    
    /// 分隔线颜色
    var separatorColor: Color {
        Color(uiColor: .separator)
    }
    
    /// 危险操作 (System Red) - 删除、取消订阅
    var dangerColor: Color {
        Color.red
    }
    
    /// 成功状态 (System Green) - 安全等级
    var successColor: Color {
        Color.green
    }
    
    /// 警告状态 (System Yellow) - 合规警示栏
    var warningColor: Color {
        Color.yellow
    }
    
    // MARK: - 导航栏颜色（苹果原生风格）
    
    /// 淡色导航栏背景色
    /// 类似苹果原生 App 的导航栏：白色底色 + 极淡的主题色调
    var lightNavBarBackgroundColor: Color {
        // 深色主题使用系统深色背景
        if isDarkTheme {
            return Color(uiColor: .systemBackground)
        }
        // 浅色主题：使用极淡的主题色背景
        // 类似 Apple Music、Apple Fitness 等原生 App 风格
        return Color(uiColor: .systemBackground).opacity(0.95)
    }
}

// MARK: - Color Extension for Adaptive Card Background
extension Color {
    /// 自适应卡片背景色：浅色模式为白色，深色模式为深空灰
    static var adaptiveCard: Color {
        Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemBackground
        })
    }
}
