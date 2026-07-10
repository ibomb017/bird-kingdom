//
//  SettingsView.swift
//  BirdKingdom
//
//  系统设置页面
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var showLanguageSelector = false
    @State private var showPrivacyCenter = false
    @State private var showDeleteAccount = false
    @State private var showClearCacheAlert = false
    
    // 子导航目标激活状态
    @State private var showThemeSelection = false
    @State private var showHelp = false
    @State private var showAbout = false
    @State private var showContactAuthor = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Section 1: 个性化偏好
                VStack(spacing: 0) {
                    menuRow(icon: "paintpalette.fill", title: NSLocalizedString("专属主题", comment: ""), badge: nil) {
                        showThemeSelection = true
                    }
                    Divider().padding(.leading, 50)
                    
                    menuRow(icon: "globe", title: L10n.languageSetting, badge: LanguageManager.shared.current.displayName) {
                        showLanguageSelector = true
                    }
                }
                .background(Color.adaptiveCard)
                .cornerRadius(14)
                .shadow(color: themeManager.primaryColor.opacity(0.04), radius: 6, x: 0, y: 2)
                
                // Section 2: 存储与隐私
                VStack(spacing: 0) {
                    menuRow(icon: "internaldrive", title: L10n.clearCache, badge: CacheManager.shared.formattedTotalCacheSize()) {
                        showClearCacheAlert = true
                    }
                    Divider().padding(.leading, 50)
                    
                    menuRow(icon: "hand.raised.fill", title: LanguageManager.shared.isChinese ? NSLocalizedString("隐私中心", comment: "") : "Privacy", badge: nil) {
                        showPrivacyCenter = true
                    }
                }
                .background(Color.adaptiveCard)
                .cornerRadius(14)
                .shadow(color: themeManager.primaryColor.opacity(0.04), radius: 6, x: 0, y: 2)
                
                // Section 3: 关于与反馈
                VStack(spacing: 0) {
                    menuRow(icon: "questionmark.circle", title: NSLocalizedString("使用帮助", comment: ""), badge: nil) {
                        showHelp = true
                    }
                    Divider().padding(.leading, 50)
                    
                    menuRow(icon: "envelope.fill", title: NSLocalizedString("联系作者", comment: ""), badge: nil) {
                        showContactAuthor = true
                    }
                    Divider().padding(.leading, 50)
                    
                    menuRow(icon: "info.circle", title: NSLocalizedString("关于鸟类王国", comment: ""), badge: nil) {
                        showAbout = true
                    }
                }
                .background(Color.adaptiveCard)
                .cornerRadius(14)
                .shadow(color: themeManager.primaryColor.opacity(0.04), radius: 6, x: 0, y: 2)
                
                // Section 4: 账号操作
                VStack(spacing: 0) {
                    menuRow(icon: "rectangle.portrait.and.arrow.right", title: L10n.logout, badge: nil, isDestructive: true) {
                        authService.logout()
                        dismiss()
                    }
                    Divider().padding(.leading, 50)
                    
                    menuRow(icon: "xmark.circle", title: L10n.deleteAccount, badge: nil, isDestructive: true) {
                        showDeleteAccount = true
                    }
                }
                .background(Color.adaptiveCard)
                .cornerRadius(14)
                .shadow(color: themeManager.primaryColor.opacity(0.04), radius: 6, x: 0, y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(themeManager.pageBackgroundGradient)
        .navigationTitle(NSLocalizedString("设置", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        
        // sheets & alerts bindings
        .sheet(isPresented: $showLanguageSelector) {
            LanguageSelectorView()
        }
        .sheet(isPresented: $showPrivacyCenter) {
            PrivacyCenterView()
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountConfirmView(onDeleted: {
                authService.logout()
                dismiss()
            })
        }
        .alert(L10n.clearCache, isPresented: $showClearCacheAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(NSLocalizedString("清除", comment: ""), role: .destructive) {
                CacheManager.shared.clearAllCache()
                NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
            }
        } message: {
            let details = CacheManager.shared.getCacheSizeDetails()
            Text("当前缓存:\n图片: \(details.images)\n视频: \(details.videos)\n帖子: \(details.posts)\n\n⚠️ 将清除所有本地数据（包括未同步的离线日志），请确保网络正常后再操作")
        }
        
        // Navigation destinations within the settings context
        .navigationDestination(isPresented: $showThemeSelection) {
            ThemeSelectionView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showHelp) {
            HelpView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showAbout) {
            AboutView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
        .navigationDestination(isPresented: $showContactAuthor) {
            ContactAuthorView()
                .onAppear { TabBarVisibilityManager.shared.hide() }
                .onDisappear { TabBarVisibilityManager.shared.show() }
        }
    }
    
    private func menuRow(icon: String, title: String, badge: String?, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? .red : themeManager.primaryColor)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isDestructive ? .red : .primary)
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.primaryColor.opacity(0.1))
                        .foregroundColor(themeManager.primaryColor)
                        .cornerRadius(10)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
