import SwiftUI

// MARK: - 统一导航栏样式扩展
// 设计原则：苹果原生导航栏样式，简约高级

extension View {
    /// 应用统一导航栏样式（苹果原生风格）
    /// - Parameters:
    ///   - title: 导航栏标题
    ///   - displayMode: 标题显示模式，默认 .inline
    /// - Returns: 带有统一样式的视图
    func themedNavigationBar(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline
    ) -> some View {
        let themeManager = ThemeManager.shared
        
        return self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .tint(themeManager.primaryColor)
    }
    
    /// 应用统一导航栏样式（带关闭按钮）
    func themedNavigationBar(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        onDismiss: @escaping () -> Void
    ) -> some View {
        let themeManager = ThemeManager.shared
        
        return self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .tint(themeManager.primaryColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticFeedback.light()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
    }
    
    /// 应用统一导航栏样式（带完成按钮）
    func themedNavigationBarWithDone(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        doneText: String = "完成",
        doneDisabled: Bool = false,
        onDone: @escaping () -> Void
    ) -> some View {
        let themeManager = ThemeManager.shared
        
        return self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .tint(themeManager.primaryColor)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticFeedback.medium()
                        onDone()
                    } label: {
                        Text(doneText)
                            .fontWeight(.semibold)
                            .foregroundColor(doneDisabled ? .gray : themeManager.primaryColor)
                    }
                    .disabled(doneDisabled)
                }
            }
    }
    
    /// 应用统一导航栏样式（带取消和保存按钮）
    func themedNavigationBarWithActions(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        saveDisabled: Bool = false
    ) -> some View {
        let themeManager = ThemeManager.shared
        
        return self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .tint(themeManager.primaryColor)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticFeedback.light()
                        onCancel()
                    } label: {
                        Text("取消")
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticFeedback.medium()
                        onSave()
                    } label: {
                        Text("保存")
                            .fontWeight(.semibold)
                            .foregroundColor(saveDisabled ? .gray : themeManager.primaryColor)
                    }
                    .disabled(saveDisabled)
                }
            }
    }
}


// MARK: - 统一背景样式扩展

extension View {
    /// 应用统一页面背景色
    func themedBackground() -> some View {
        self.background(Color(.systemBackground))
    }
    
    /// 应用统一卡片背景
    func themedCardBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.adaptiveCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
    }
}

// MARK: - TabBar 隐藏修饰符

extension View {
    /// 进入此视图时自动隐藏底部 TabBar，离开时自动恢复显示
    /// 适用于所有详情页面，实现类似小红书的导航体验
    func hidesTabBar() -> some View {
        self
            .onAppear {
                TabBarVisibilityManager.shared.hide()
            }
            .onDisappear {
                TabBarVisibilityManager.shared.show()
            }
    }
}

// MARK: - 导航栏外观配置（App启动时调用）

struct NavigationBarAppearance {
    static func configure() {
        // 使用苹果原生默认外观配置
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // 设置标题字体
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
