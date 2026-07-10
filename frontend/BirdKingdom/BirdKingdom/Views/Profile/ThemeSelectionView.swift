import SwiftUI

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var authService = AuthService.shared
    
    @State private var showVIPAlert = false
    @State private var showLoginAlert = false
    @State private var showNetworkErrorAlert = false
    @State private var selectedTheme: AppTheme?
    @State private var isVerifyingVIP = false
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 未登录提示
                if !authService.isLoggedIn {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("登录后可切换主题", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text(NSLocalizedString("当前使用默认薄荷绿主题", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                
                // 当前主题预览
                VStack(spacing: 16) {
                    Text(NSLocalizedString("当前主题", comment: ""))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ThemePreviewCard(
                        theme: themeManager.currentTheme,
                        isSelected: true,
                        isLocked: false
                    )
                }
                .padding(.top, authService.isLoggedIn ? 20 : 0)
                
                Divider()
                    .padding(.horizontal)
                
                // 所有主题
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("选择主题", comment: ""))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: themeManager.currentTheme == theme,
                                isLocked: !themeManager.canUseTheme(theme)
                            ) {
                                selectTheme(theme)
                            }
                            .disabled(isVerifyingVIP)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // VIP提示（已登录但非VIP时显示）
                if authService.isLoggedIn && authService.currentUser?.isVipValid != true {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image("bird")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text(NSLocalizedString("升级VIP解锁全部主题", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text(NSLocalizedString("薄荷绿、大卑紫主题永久免费", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 30)
        }
        .themedBackground()
        .navigationTitle(NSLocalizedString("专属主题", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            // VIP校验加载遮罩
            if isVerifyingVIP {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(NSLocalizedString("正在验证会员状态...", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color(white: 0.2))
                        .cornerRadius(16)
                    )
            }
        }
        .alert(L10n.loginRequiredTitle, isPresented: $showLoginAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(NSLocalizedString("去登录", comment: "")) {
                dismiss()
            }
        } message: {
            Text(NSLocalizedString("登录后才能切换主题", comment: ""))
        }
        .alert(NSLocalizedString("需要VIP会员", comment: ""), isPresented: $showVIPAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(NSLocalizedString("升级VIP", comment: "")) {
                dismiss()
            }
        } message: {
            Text(NSLocalizedString("该主题需要VIP会员才能使用\n升级VIP解锁全部专属主题", comment: ""))
        }
        .alert(NSLocalizedString("网络错误", comment: ""), isPresented: $showNetworkErrorAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("无法验证会员状态，请检查网络后重试", comment: ""))
        }
    }
    
    private func selectTheme(_ theme: AppTheme) {
        // 未登录时提示登录
        if !authService.isLoggedIn {
            showLoginAlert = true
            return
        }
        
        // 免费主题直接切换
        if !theme.requiresVIP {
            _ = themeManager.changeTheme(to: theme)
            return
        }
        
        // P0-01: VIP主题需要后端校验
        isVerifyingVIP = true
        Task {
            let success = await themeManager.changeThemeWithBackendValidation(to: theme)
            await MainActor.run {
                isVerifyingVIP = false
                if !success {
                    // 后端确认非VIP或网络错误
                    if authService.currentUser?.isVipValid == true {
                        // 本地显示VIP但后端校验失败，说明网络问题
                        showNetworkErrorAlert = true
                    } else {
                        // 非VIP用户
                        selectedTheme = theme
                        showVIPAlert = true
                    }
                }
            }
        }
    }
}

// 主题卡片
struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // 主题预览
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: theme.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)
                    
                    // 图标
                    Image(systemName: theme.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    // 锁定标识
                    if isLocked {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                                    .padding(8)
                            }
                        }
                    }
                    
                    // 选中标识
                    if isSelected {
                        VStack {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(8)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                
                // 主题名称
                Text(theme.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? theme.primaryColor : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// 主题预览卡片（大）
struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let isLocked: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: theme.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)
                
                VStack(spacing: 12) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text(theme.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .shadow(color: theme.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ThemeSelectionView()
}
