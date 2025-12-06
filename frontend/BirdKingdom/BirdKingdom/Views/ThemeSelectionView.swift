import SwiftUI

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeService = ThemeService.shared
    @ObservedObject var authService = AuthService.shared
    
    @State private var showVIPAlert = false
    @State private var selectedTheme: AppTheme?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 当前主题预览
                    VStack(spacing: 16) {
                        Text("当前主题")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ThemePreviewCard(
                            theme: themeService.currentTheme,
                            isSelected: true,
                            isLocked: false
                        )
                    }
                    .padding(.top, 20)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // 所有主题
                    VStack(alignment: .leading, spacing: 16) {
                        Text("选择主题")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                ThemeCard(
                                    theme: theme,
                                    isSelected: themeService.currentTheme == theme,
                                    isLocked: !isThemeUnlocked(theme)
                                ) {
                                    selectTheme(theme)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // VIP提示
                    if authService.currentUser?.isVipValid != true {
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                                Text("升级VIP解锁全部主题")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Text("森林绿主题永久免费")
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
            .navigationTitle("专属主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("需要VIP会员", isPresented: $showVIPAlert) {
            Button("取消", role: .cancel) {}
            Button("升级VIP") {
                // TODO: 跳转到VIP页面
                dismiss()
            }
        } message: {
            Text("该主题需要VIP会员才能使用\n升级VIP解锁全部专属主题")
        }
    }
    
    private func isThemeUnlocked(_ theme: AppTheme) -> Bool {
        return theme == .forest || (authService.currentUser?.isVipValid == true)
    }
    
    private func selectTheme(_ theme: AppTheme) {
        if themeService.changeTheme(to: theme, isVIP: authService.currentUser?.isVipValid == true) {
            // 主题切换成功
        } else {
            // 需要VIP
            selectedTheme = theme
            showVIPAlert = true
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
                Text(theme.displayName)
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
                    
                    Text(theme.displayName)
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
