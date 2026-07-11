import SwiftUI

// MARK: - 离线状态指示器
struct OfflineStatusView: View {
    @ObservedObject var offlineService = OfflineDataService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        if !offlineService.isOnline || offlineService.pendingSyncCount > 0 {
            HStack(spacing: 8) {
                // 网络状态图标
                Image(systemName: offlineService.isOnline ? "wifi" : "wifi.slash")
                    .font(.system(size: 14))
                    .foregroundColor(offlineService.isOnline ? .green : .orange)
                
                // 状态文字
                if !offlineService.isOnline {
                    Text(NSLocalizedString("离线模式", comment: ""))
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if offlineService.isSyncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(NSLocalizedString("同步中...", comment: ""))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else if offlineService.pendingSyncCount > 0 {
                    Text(String(format: NSLocalizedString("待同步: %d", comment: ""), offlineService.pendingSyncCount))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                // 手动同步按钮
                if offlineService.isOnline && offlineService.pendingSyncCount > 0 && !offlineService.isSyncing {
                    Button(action: {
                        offlineService.syncPendingData()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.primaryColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(offlineService.isOnline ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - 离线状态横幅（用于首页顶部）
struct OfflineBanner: View {
    @ObservedObject var offlineService = OfflineDataService.shared
    @State private var showDetails = false
    
    var body: some View {
        if !offlineService.isOnline {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.white)
                    
                    Text(NSLocalizedString("当前处于离线模式，数据将在联网后自动同步", comment: ""))
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if offlineService.pendingSyncCount > 0 {
                        Text(String(format: NSLocalizedString("%d项待同步", comment: ""), offlineService.pendingSyncCount))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.3)))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.orange)
            }
        }
    }
}

// MARK: - 同步状态浮动按钮
struct SyncFloatingButton: View {
    @ObservedObject var offlineService = OfflineDataService.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if offlineService.pendingSyncCount > 0 {
            Button(action: {
                if offlineService.isOnline {
                    offlineService.syncPendingData()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(offlineService.isOnline ? themeManager.primaryColor : Color.orange)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    if offlineService.isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        VStack(spacing: 2) {
                            Image(systemName: offlineService.isOnline ? "arrow.triangle.2.circlepath" : "wifi.slash")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            
                            Text("\(offlineService.pendingSyncCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .disabled(!offlineService.isOnline || offlineService.isSyncing)
        }
    }
}

// MARK: - 最后同步时间显示
struct LastSyncTimeView: View {
    @ObservedObject var offlineService = OfflineDataService.shared
    
    var body: some View {
        if let lastSync = offlineService.lastSyncTime {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: NSLocalizedString("上次同步: %@", comment: ""), formatTime(lastSync)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VStack(spacing: 20) {
        OfflineStatusView()
        OfflineBanner()
        SyncFloatingButton()
        LastSyncTimeView()
    }
    .environmentObject(ThemeManager.shared)
}
