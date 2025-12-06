import SwiftUI
import Combine

// 主题类型
enum AppTheme: String, CaseIterable, Codable {
    case forest = "森林绿"
    case purple = "紫罗兰"
    case ocean = "海洋蓝"
    case turquoise = "松石青"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .forest: return "leaf.fill"
        case .purple: return "sparkles"
        case .ocean: return "drop.fill"
        case .turquoise: return "circle.hexagongrid.fill"
        }
    }
    
    // 主色调
    var primaryColor: Color {
        switch self {
        case .forest:
            return Color(red: 0.25, green: 0.42, blue: 0.35)
        case .purple:
            return Color(red: 0.55, green: 0.35, blue: 0.65)
        case .ocean:
            return Color(red: 0.20, green: 0.45, blue: 0.70)
        case .turquoise:
            return Color(red: 0.25, green: 0.65, blue: 0.65)
        }
    }
    
    // 次要色
    var secondaryColor: Color {
        switch self {
        case .forest:
            return Color(red: 0.35, green: 0.55, blue: 0.40)
        case .purple:
            return Color(red: 0.70, green: 0.50, blue: 0.80)
        case .ocean:
            return Color(red: 0.35, green: 0.60, blue: 0.85)
        case .turquoise:
            return Color(red: 0.40, green: 0.75, blue: 0.75)
        }
    }
    
    // 浅色背景
    var lightBackground: Color {
        switch self {
        case .forest:
            return Color(red: 0.92, green: 0.95, blue: 0.93)
        case .purple:
            return Color(red: 0.95, green: 0.92, blue: 0.97)
        case .ocean:
            return Color(red: 0.92, green: 0.95, blue: 0.98)
        case .turquoise:
            return Color(red: 0.92, green: 0.97, blue: 0.97)
        }
    }
    
    // 渐变色组
    var gradientColors: [Color] {
        switch self {
        case .forest:
            return [Color(red: 0.72, green: 0.89, blue: 0.78), Color(red: 0.55, green: 0.78, blue: 0.65)]
        case .purple:
            return [Color(red: 0.80, green: 0.70, blue: 0.90), Color(red: 0.65, green: 0.50, blue: 0.80)]
        case .ocean:
            return [Color(red: 0.70, green: 0.85, blue: 0.95), Color(red: 0.50, green: 0.70, blue: 0.90)]
        case .turquoise:
            return [Color(red: 0.70, green: 0.90, blue: 0.90), Color(red: 0.50, green: 0.80, blue: 0.80)]
        }
    }
}

// 主题服务
class ThemeService: ObservableObject {
    static let shared = ThemeService()
    
    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
        }
    }
    
    private let themeKey = "selectedTheme"
    
    private init() {
        // 从 UserDefaults 加载主题
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .forest // 默认森林绿主题
        }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
    }
    
    // 切换主题（需要VIP）
    func changeTheme(to theme: AppTheme, isVIP: Bool) -> Bool {
        // 森林绿主题免费，其他主题需要VIP
        if theme == .forest || isVIP {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentTheme = theme
            }
            return true
        }
        return false
    }
}
