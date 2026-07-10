import Foundation
import Combine
import SwiftUI

/// P1: BirdListViewModel - 鸟档案列表业务逻辑层
/// 将 BirdListView 的业务逻辑抽取到 ViewModel，提高可测试性和代码清晰度
@MainActor
class BirdListViewModel: ObservableObject {
    
    // MARK: - 发布属性
    @Published var birds: [Bird] = []
    @Published var logs: [BirdLog] = []
    @Published var reminders: [Reminder] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedIndex: Int? = nil
    @Published var showSyncConflictAlert: Bool = false
    @Published var syncConflictMessage: String = ""
    
    // MARK: - 同步状态
    @Published var syncFailedBirdIds: Set<String> = []
    @Published var pendingSyncBirdIds: Set<String> = []
    
    // MARK: - 依赖
    private let authService = AuthService.shared
    private let offlineService = OfflineDataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 计算属性
    var selectedBird: Bird? {
        guard let index = selectedIndex, birds.indices.contains(index) else { return nil }
        return birds[index]
    }
    
    var hasSyncFailures: Bool {
        !syncFailedBirdIds.isEmpty
    }
    
    var failedSyncCount: Int {
        syncFailedBirdIds.count
    }
    
    // MARK: - 初始化
    init() {
        setupObservers()
    }
    
    // MARK: - 设置观察者
    private func setupObservers() {
        // 监听同步冲突通知
        NotificationCenter.default.publisher(for: NSNotification.Name("SyncConflictDetected"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let nickname = notification.userInfo?["nickname"] as? String {
                    self?.syncConflictMessage = "「\(nickname)」的数据已被其他设备修改，请下拉刷新获取最新数据"
                    self?.showSyncConflictAlert = true
                }
            }
            .store(in: &cancellables)
        
        // 监听同步状态变化
        offlineService.$pendingSyncCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSyncStatus()
            }
            .store(in: &cancellables)
        
        // 监听刷新通知
        NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBirds"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 数据加载
    func loadData() async {
        guard authService.isLoggedIn else {
            birds = []
            logs = []
            reminders = []
            return
        }
        
        // 首次加载显示 loading
        if birds.isEmpty {
            isLoading = true
        }
        
        do {
            // 并发加载所有数据
            async let birdsResult = loadBirds()
            async let logsResult = loadRecentLogs()
            async let remindersResult = loadReminders()
            
            let (loadedBirds, loadedLogs, loadedReminders) = await (birdsResult, logsResult, remindersResult)
            
            self.birds = loadedBirds
            self.logs = loadedLogs
            self.reminders = loadedReminders
            self.errorMessage = nil
            
            // 更新同步状态
            updateSyncStatus()
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func loadBirds() async -> [Bird] {
        do {
            return try await ApiService.shared.getBirds()
        } catch {
            // 离线模式：从本地缓存加载
            return offlineService.localBirds.map { localBird in
                Bird(
                    id: Int64(localBird.serverId ?? 0),
                    nickname: localBird.nickname,
                    species: localBird.species,
                    gender: localBird.gender,
                    hatchDate: localBird.hatchDate,
                    adoptionDate: localBird.adoptionDate,
                    birthdayType: localBird.birthdayType,
                    deathDate: localBird.deathDate,
                    featherColor: localBird.featherColor,
                    source: localBird.source,
                    avatarUrl: localBird.avatarUrl,
                    notes: localBird.notes,
                    medicalHistory: localBird.medicalHistory,
                    fatherInfo: localBird.fatherInfo,
                    motherInfo: localBird.motherInfo,
                    legRingId: localBird.legRingId,
                    ageMonths: nil,
                    isDeleted: false,
                    deletedAt: nil,
                    isLost: localBird.isLost,
                    lostDate: localBird.lostDate,
                    lostLocation: localBird.lostLocation,
                    lostPostId: localBird.lostPostId
                )
            }
        }
    }
    
    private func loadRecentLogs() async -> [BirdLog] {
        do {
            // 加载所有日志
            return try await ApiService.shared.getLogs()
        } catch {
            return []
        }
    }
    
    private func loadReminders() async -> [Reminder] {
        do {
            return try await ApiService.shared.getReminders()
        } catch {
            return []
        }
    }
    
    // MARK: - 同步状态更新
    private func updateSyncStatus() {
        // 清空状态
        syncFailedBirdIds.removeAll()
        pendingSyncBirdIds.removeAll()
        
        // 遍历本地鸟儿，检查同步状态
        for localBird in offlineService.localBirds {
            if localBird.syncRetryCount >= 3 {
                // 同步失败（达到最大重试次数）
                syncFailedBirdIds.insert(localBird.localId)
            } else if localBird.needsSync {
                // 待同步
                pendingSyncBirdIds.insert(localBird.localId)
            }
        }
    }
    
    // MARK: - 同步状态查询
    func getSyncStatus(for bird: Bird) -> SyncStatus {
        // 通过 serverId 查找对应的本地鸟儿
        if let localBird = offlineService.localBirds.first(where: { Int64($0.serverId ?? 0) == bird.id }) {
            if localBird.syncRetryCount >= 3 {
                return .failed(error: "同步失败，请重试")
            } else if localBird.needsSync {
                return .pending
            }
        }
        return .synced
    }
    
    // MARK: - 操作方法
    func markBirdAsFound(_ bird: Bird) async {
        // 更新本地数据
        if let index = birds.firstIndex(where: { $0.id == bird.id }) {
            var updatedBird = birds[index]
            updatedBird.isLost = false
            updatedBird.lostDate = nil
            updatedBird.lostLocation = nil
            updatedBird.lostPostId = nil
            birds[index] = updatedBird
        }
        
        // 调用后端 API
        do {
            try await ApiService.shared.updateBirdLostStatus(birdId: bird.id, isLost: false)
        } catch {
            print("❌ 更新鸟儿状态失败: \(error)")
        }
    }
    
    func retryFailedSync() {
        // 重置同步失败的鸟儿，允许重新同步
        for localId in syncFailedBirdIds {
            offlineService.resetSyncRetryCount(localId: localId)
        }
        syncFailedBirdIds.removeAll()
        
        // 触发同步
        offlineService.syncPendingData()
    }
    
    func refreshData() {
        // 下拉刷新时，同时从服务器获取最新数据
        Task {
            await loadData()
        }
    }
}

// MARK: - 同步状态枚举
extension BirdListViewModel {
    enum SyncStatus {
        case synced
        case pending
        case failed(error: String)
        
        var icon: String {
            switch self {
            case .synced: return ""
            case .pending: return "icloud.and.arrow.up"
            case .failed: return "exclamationmark.icloud"
            }
        }
        
        var color: Color {
            switch self {
            case .synced: return .clear
            case .pending: return .orange
            case .failed: return .red
            }
        }
    }
}
