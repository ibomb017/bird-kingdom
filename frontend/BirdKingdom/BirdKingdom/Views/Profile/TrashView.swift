import SwiftUI

// MARK: - 回收站视图
struct TrashView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var trashService = TrashService.shared
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var offlineService = OfflineDataService.shared
    
    @State private var showEmptyAlert = false
    @State private var showRestoreAlert = false
    @State private var showVipAlert = false
    @State private var showOfflineAlert = false
    @State private var showVipExpiredAlert = false
    @State private var selectedBird: DeletedBird?
    @State private var isRestoring = false
    @State private var isVerifyingVIP = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var primaryColor: Color { themeManager.primaryColor }
    private let dangerColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 离线状态提示（苹果原生风格）
                if !offlineService.isOnline {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("当前处于离线状态，无法查看回收站", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground))
                }
                
                Group {
                    if !offlineService.isOnline {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text(NSLocalizedString("需要联网查看回收站", comment: ""))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(NSLocalizedString("请连接网络后重试", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if trashService.isLoading {
                        VStack {
                            Spacer()
                            ProgressView(L10n.loading)
                            Spacer()
                        }
                    } else if trashService.deletedBirds.isEmpty {
                        emptyState
                    } else {
                        deletedBirdsList
                    }
                }
            }
            
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
        .themedBackground()
        .navigationTitle(L10n.recycleBin)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !trashService.deletedBirds.isEmpty {
                    Button(NSLocalizedString("清空", comment: "")) { showEmptyAlert = true }
                        .foregroundColor(dangerColor)
                }
            }
        }
        .task {
            if offlineService.isOnline {
                await trashService.loadFromServer()
            }
        }
        .alert(NSLocalizedString("清空回收站", comment: ""), isPresented: $showEmptyAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(NSLocalizedString("清空", comment: ""), role: .destructive) {
                trashService.emptyTrash()
            }
        } message: {
            Text(NSLocalizedString("清空后将无法恢复，确定要清空回收站吗？", comment: ""))
        }
        .alert(NSLocalizedString("恢复鸟儿", comment: ""), isPresented: $showRestoreAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(NSLocalizedString("恢复", comment: "")) {
                if let bird = selectedBird {
                    restoreBird(bird)
                }
            }
        } message: {
            if let bird = selectedBird {
                Text(String(format: NSLocalizedString("确定要恢复「%@」吗？", comment: ""), bird.nickname))
            }
        }
        .alert(NSLocalizedString("VIP专属功能", comment: ""), isPresented: $showVipAlert) {
            Button(NSLocalizedString("开通VIP", comment: ""), role: .none) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowVIPPage"),
                        object: nil
                    )
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(NSLocalizedString("恢复已删除的鸟儿是VIP专属功能，开通VIP后即可使用。", comment: ""))
        }
        .alert(NSLocalizedString("会员已过期", comment: ""), isPresented: $showVipExpiredAlert) {
            Button(NSLocalizedString("续费VIP", comment: ""), role: .none) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowVIPPage"),
                        object: nil
                    )
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(NSLocalizedString("您的VIP会员已过期，续费后即可恢复鸟儿档案。", comment: ""))
        }
    }
    
    // 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            
            Text(NSLocalizedString("回收站是空的", comment: ""))
                .font(.headline)
                .foregroundColor(themeManager.textSecondary)
            
            Text(NSLocalizedString("删除的鸟儿会在这里保留7天", comment: ""))
                .font(.subheadline)
                .foregroundColor(themeManager.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 已删除鸟儿列表
    private var deletedBirdsList: some View {
        List {
            Section {
                ForEach(trashService.deletedBirds) { bird in
                    deletedBirdRow(bird)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        trashService.permanentlyDelete(trashService.deletedBirds[index])
                    }
                }
            } header: {
                HStack {
                    Text(NSLocalizedString("已删除的鸟儿", comment: ""))
                    Spacer()
                    Text(NSLocalizedString("VIP可在7天内恢复", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text(NSLocalizedString("左滑可永久删除，超过7天将自动清除", comment: ""))
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // 已删除鸟儿行
    private func deletedBirdRow(_ bird: DeletedBird) -> some View {
        HStack(spacing: 14) {
            // 头像
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image("bird")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .opacity(0.6)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(bird.nickname)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(bird.species)
                    .font(.caption)
                    .foregroundColor(themeManager.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(bird.remainingDays > 0 ? "剩余\(bird.remainingDays)天" : NSLocalizedString("即将过期", comment: ""))
                        .font(.caption2)
                }
                .foregroundColor(bird.remainingDays <= 1 ? themeManager.dangerColor : themeManager.textSecondary)
            }
            
            Spacer()
            
            // 恢复按钮
            Button {
                selectedBird = bird
                if authService.currentUser?.isVipValid == true {
                    showRestoreAlert = true
                } else {
                    showVipAlert = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption)
                    Text(NSLocalizedString("恢复", comment: ""))
                        .font(.caption)
                }
                .foregroundColor(authService.currentUser?.isVipValid == true ? primaryColor : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (authService.currentUser?.isVipValid == true ? primaryColor : Color.gray).opacity(0.1)
                )
                .cornerRadius(14)
            }
            .disabled(isRestoring || isVerifyingVIP)
        }
        .padding(.vertical, 4)
    }
    
    // 恢复鸟儿
    private func restoreBird(_ bird: DeletedBird) {
        isRestoring = true
        Task {
            do {
                _ = try await trashService.restoreBird(bird)
                await MainActor.run {
                    isRestoring = false
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    let errorMessage = error.localizedDescription.lowercased()
                    if errorMessage.contains("403") || errorMessage.contains("vip") || errorMessage.contains("forbidden") {
                        Task {
                            try? await authService.fetchCurrentUser()
                        }
                        showVipExpiredAlert = true
                    }
                }
            }
        }
    }
}

#Preview {
    TrashView()
}
