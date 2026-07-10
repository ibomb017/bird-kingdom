import Foundation
import Network
import Combine
import CoreData
import os.log
import UserNotifications

private let logger = Logger(subsystem: "com.birdkingdom", category: "OfflineData")

// MARK: - 离线数据管理服务
/// 使用 Core Data 实现鸟儿、日志、体重、支出的本地存储和离线同步
class OfflineDataService: ObservableObject {
    static let shared = OfflineDataService()
    
    // MARK: - Core Data 上下文
    private let persistenceController = PersistenceController.shared
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    // MARK: - 发布属性
    @Published var isOnline: Bool = true
    @Published var pendingSyncCount: Int = 0
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    
    // MARK: - 本地数据（保持向后兼容的访问方式）
    @Published var localBirds: [LocalBird] = []
    @Published var localLogs: [LocalBirdLog] = []
    @Published var localWeights: [LocalWeightRecord] = []
    @Published var localExpenses: [LocalExpense] = []
    @Published var localCycles: [LocalCycleRecord] = []  // 生理周期离线支持
    @Published var localShares: [LocalBirdShare] = []    // P2-01: 共享关系离线支持
    
    // MARK: - 私有属性
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - 初始化
    private init() {
        // 启动网络监控
        startNetworkMonitoring()
        
        // 加载上次同步时间
        if let timestamp = userDefaults.object(forKey: "lastSyncTime") as? Date {
            lastSyncTime = timestamp
        }
        
        // 延迟加载本地数据，避免在 init 中访问 Core Data 导致崩溃
        DispatchQueue.main.async { [weak self] in
            self?.loadLocalDataSafely()
        }
    }
    
    // MARK: - 网络监控
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                
                // 从离线变为在线时，自动同步
                if wasOffline && path.status == .satisfied {
                    let pendingCount = self?.pendingSyncCount ?? 0
                    if pendingCount > 0 {
                        logger.info("📶 网络恢复，检测到 \(pendingCount) 条待同步数据，开始自动同步...")
                    } else {
                        logger.info("📶 网络恢复，无待同步数据")
                    }
                    
                    // P0 增强：网络恢复时，重置之前失败的任务，给它们新的机会
                    let resetCount = self?.resetFailedSyncTasks() ?? 0
                    if resetCount > 0 {
                        logger.info("🔄 网络恢复，已重置 \(resetCount) 个失败任务")
                    }
                    
                    self?.syncPendingData()
                    self?.checkPendingImageUploads()  // P0: 恢复待上传图片
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - 安全加载本地数据
    private func loadLocalDataSafely() {
        do {
            try loadLocalData()
            
            // P0 增强：APP 启动时，如果在线且有未同步数据，立即同步
            if isOnline && pendingSyncCount > 0 {
                let count = pendingSyncCount
                logger.info("📶 检测到 \(count) 条待同步数据，启动自动同步...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    // P0 增强：启动时重置失败任务
                    let _ = self?.resetFailedSyncTasks()
                    self?.syncPendingData()
                    self?.checkPendingImageUploads()
                }
            }
        } catch {
            logger.error("⚠️ 加载本地数据失败，可能需要重置数据库: \(error.localizedDescription)")
            // 数据损坏时，重置本地数据（保持空状态）
            localBirds = []
            localLogs = []
            localWeights = []
            localExpenses = []
            localCycles = []
            localShares = []
            pendingSyncCount = 0
        }
    }
    
    // MARK: - 加载本地数据（从 Core Data）
    private func loadLocalData() throws {
        refreshLocalBirds()
        refreshLocalLogs()
        refreshLocalWeights()
        refreshLocalExpenses()
        refreshLocalCycles()
        refreshLocalShares()  // P2-01: 加载共享关系
        updatePendingSyncCount()
        
        logger.info("📂 加载本地数据: \(self.localBirds.count)只鸟, \(self.localLogs.count)条日志, \(self.localWeights.count)条体重记录, \(self.localExpenses.count)条支出记录, \(self.localCycles.count)条周期记录, \(self.localShares.count)条共享记录")
    }
    
    private func refreshLocalBirds() {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        // P1-01: 按userId过滤，确保多用户数据隔离
        if let currentUserId = AuthService.shared.currentUserId {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO AND (userId == %@ OR userId == nil)", currentUserId)
        } else {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO")
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LocalBirdEntity.createdAt, ascending: false)]
        
        do {
            let entities = try viewContext.fetch(request)
            localBirds = entities.map { LocalBird(from: $0) }
        } catch {
            logger.error("加载鸟儿数据失败: \(error.localizedDescription)")
        }
    }
    
    private func refreshLocalLogs() {
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        // P0 修复：按userId过滤，确保多用户数据隔离
        if let currentUserId = AuthService.shared.currentUserId {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO AND (userId == %@ OR userId == nil)", currentUserId)
        } else {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO")
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LocalBirdLogEntity.logDate, ascending: false)]
        
        do {
            let entities = try viewContext.fetch(request)
            localLogs = entities.map { LocalBirdLog(from: $0) }
        } catch {
            logger.error("加载日志数据失败: \(error.localizedDescription)")
        }
    }
    
    private func refreshLocalWeights() {
        let request: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
        // P0 修复：按userId过滤，确保多用户数据隔离
        if let currentUserId = AuthService.shared.currentUserId {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO AND (userId == %@ OR userId == nil)", currentUserId)
        } else {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO")
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LocalWeightRecordEntity.recordDate, ascending: false)]
        
        do {
            let entities = try viewContext.fetch(request)
            localWeights = entities.map { LocalWeightRecord(from: $0) }
        } catch {
            logger.error("加载体重数据失败: \(error.localizedDescription)")
        }
    }
    
    private func refreshLocalExpenses() {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        // P1-01: 按userId过滤，确保多用户数据隔离
        if let currentUserId = AuthService.shared.currentUserId {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO AND (userId == %@ OR userId == nil)", currentUserId)
        } else {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO")
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LocalExpenseEntity.expenseDate, ascending: false)]
        
        do {
            let entities = try viewContext.fetch(request)
            localExpenses = entities.map { LocalExpense(from: $0) }
        } catch {
            logger.error("加载支出数据失败: \(error.localizedDescription)")
        }
    }
    
    private func refreshLocalCycles() {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        // P0 修复：按userId过滤，确保多用户数据隔离
        if let currentUserId = AuthService.shared.currentUserId {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO AND (userId == %@ OR userId == nil)", currentUserId)
        } else {
            request.predicate = NSPredicate(format: "markedAsDeleted == NO")
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LocalCycleRecordEntity.startDate, ascending: false)]
        
        do {
            let entities = try viewContext.fetch(request)
            localCycles = entities.map { LocalCycleRecord(from: $0) }
        } catch {
            logger.error("加载周期数据失败: \(error.localizedDescription)")
        }
    }
    
    // P2-01: 刷新本地共享记录
    // 重举修复 #10: 过滤 userId，确保只返回当前用户相关的共享记录
    private func refreshLocalShares() {
        let request: NSFetchRequest<LocalBirdShareEntity> = LocalBirdShareEntity.fetchRequest()
        
        // 重举修复 #10: 只加载当前用户作为 owner 或 sharedUser 的共享记录
        if let currentUserIdStr = AuthService.shared.currentUserId,
           let currentUserId = Int64(currentUserIdStr) {
            request.predicate = NSPredicate(format: "ownerId == %lld OR sharedUserId == %lld", currentUserId, currentUserId)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LocalBirdShareEntity.createdAt, ascending: false)]
        
        do {
            let entities = try viewContext.fetch(request)
            localShares = entities.map { LocalBirdShare(from: $0) }
        } catch {
            logger.error("加载共享数据失败: \(error.localizedDescription)")
        }
    }
    
    private func updatePendingSyncCount() {
        let birdRequest: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        birdRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let logRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        logRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let weightRequest: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
        weightRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let expenseRequest: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        expenseRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let cycleRequest: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        cycleRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            let pendingBirds = try viewContext.count(for: birdRequest)
            let pendingLogs = try viewContext.count(for: logRequest)
            let pendingWeights = try viewContext.count(for: weightRequest)
            let pendingExpenses = try viewContext.count(for: expenseRequest)
            let pendingCycles = try viewContext.count(for: cycleRequest)
            pendingSyncCount = pendingBirds + pendingLogs + pendingWeights + pendingExpenses + pendingCycles
        } catch {
            logger.error("统计待同步数据失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 鸟儿管理
    
    /// 添加或更新鸟儿（本地）
    func saveBird(_ bird: LocalBird) {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", bird.localId)
        
        do {
            let results = try viewContext.fetch(request)
            let entity = results.first ?? LocalBirdEntity(context: viewContext)
            bird.updateEntity(entity)
            
            persistenceController.save()
            refreshLocalBirds()
            updatePendingSyncCount()
            
            // 如果在线，立即同步
            if isOnline {
                syncBird(bird)
            }
        } catch {
            logger.error("保存鸟儿失败: \(error.localizedDescription)")
        }
    }
    
    /// 添加鸟儿（本地）- 别名 saveBird
    func addBird(_ bird: LocalBird) {
        saveBird(bird)
    }

    /// P0 新增：根据 serverId 获取本地鸟儿
    func getBirdByServerId(_ serverId: Int) -> LocalBird? {
        return localBirds.first(where: { $0.serverId == serverId })
    }

    /// P0 新增：更新本地鸟儿信息
    func updateLocalBird(_ bird: LocalBird) {
        saveBird(bird)
    }

    
    /// 缓存服务器鸟到本地（仅缓存，不同步）
    /// 用于确保日志能正确显示关联的鸟名，即使 API 调用失败
    func cacheServerBird(_ bird: LocalBird) {
        // 检查是否已存在相同 serverId 的缓存
        if let serverId = bird.serverId {
            let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
            request.predicate = NSPredicate(format: "serverId == %d", Int64(serverId))
            
            do {
                let results = try viewContext.fetch(request)
                if let existing = results.first {
                    // 已存在，更新信息
                    existing.nickname = bird.nickname
                    existing.species = bird.species
                    existing.gender = bird.gender
                    existing.avatarUrl = bird.avatarUrl
                    existing.hatchDate = bird.hatchDate
                    existing.updatedAt = Date()
                    // 不修改 needsSync，保持为 false
                } else {
                    // 不存在，创建新缓存
                    let entity = LocalBirdEntity(context: viewContext)
                    bird.updateEntity(entity)
                    entity.needsSync = false  // 明确标记为不需要同步
                    entity.userId = AuthService.shared.currentUserId
                }
                
                persistenceController.save()
                refreshLocalBirds()
                
                logger.info("📦 缓存服务器鸟: \(bird.nickname) (serverId=\(String(describing: bird.serverId)))")
            } catch {
                logger.error("缓存服务器鸟失败: \(error.localizedDescription)")
            }
        } else {
            logger.warning("⚠️ cacheServerBird 调用时 serverId 为空，跳过缓存")
        }
    }
    
    /// 删除鸟儿（本地）- P1-02: 级联删除关联的日志、体重、周期记录
    /// P2: 取消与该鸟相关的本地通知
    func deleteBird(localId: String) {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.markedAsDeleted = true
                entity.needsSync = true
                entity.deletedAt = Date()  // P0: 记录删除时间
                
                // P2: 取消与该鸟相关的本地通知
                if let serverId = entity.serverId?.int64Value {
                    cancelNotificationsForBird(birdId: serverId)
                }
                
                // P1-02: 级联删除关联的日志记录
                let logRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
                logRequest.predicate = NSPredicate(format: "birdLocalId == %@", localId)
                let logs = try viewContext.fetch(logRequest)
                for log in logs {
                    // P0 修复（问题7）：同时删除日志关联的本地图片
                    if let logLocalId = log.localId {
                        LogImageStorage.shared.deleteImages(for: logLocalId)
                    }
                    log.markedAsDeleted = true
                    log.needsSync = true
                    log.deletedAt = Date()
                }
                
                // P1-02: 级联删除关联的体重记录
                let weightRequest: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
                weightRequest.predicate = NSPredicate(format: "birdLocalId == %@", localId)
                let weights = try viewContext.fetch(weightRequest)
                for weight in weights {
                    weight.markedAsDeleted = true
                    weight.needsSync = true
                    weight.deletedAt = Date()
                }
                
                // P1-02: 级联删除关联的周期记录
                let cycleRequest: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
                cycleRequest.predicate = NSPredicate(format: "birdLocalId == %@", localId)
                let cycles = try viewContext.fetch(cycleRequest)
                for cycle in cycles {
                    cycle.markedAsDeleted = true
                    cycle.needsSync = true
                }
                
                persistenceController.save()
                refreshLocalBirds()
                refreshLocalLogs()
                refreshLocalWeights()
                refreshLocalCycles()
                updatePendingSyncCount()
                
                logger.info("🗑️ 级联删除鸟儿及关联数据: \(logs.count)条日志, \(weights.count)条体重, \(cycles.count)条周期")
                
                if isOnline, let bird = LocalBird(from: entity) as LocalBird? {
                    syncBird(bird)
                }
            }
        } catch {
            logger.error("删除鸟儿失败: \(error.localizedDescription)")
        }
    }
    
    /// P2: 取消与指定鸟儿相关的所有本地通知
    private func cancelNotificationsForBird(birdId: Int64) {
        let center = UNUserNotificationCenter.current()
        
        // 获取所有待处理的通知请求
        center.getPendingNotificationRequests { requests in
            // 找出与该鸟相关的通知标识符（按照命名约定：包含 birdId 的标识符）
            let identifiersToRemove = requests.compactMap { request -> String? in
                // 检查通知标识符是否包含该鸟的 ID
                if request.identifier.contains("bird_\(birdId)_") ||
                   request.identifier.contains("_\(birdId)_") {
                    return request.identifier
                }
                
                // 检查 userInfo 中是否有该鸟的 ID
                if let notificationBirdId = request.content.userInfo["birdId"] as? Int64,
                   notificationBirdId == birdId {
                    return request.identifier
                }
                
                return nil
            }
            
            if !identifiersToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                logger.info("🔔 已取消 \(identifiersToRemove.count) 个与鸟儿 \(birdId) 相关的通知")
            }
        }
    }
    
    /// 获取所有鸟儿（包括本地未同步的）
    func getAllBirds() -> [LocalBird] {
        return localBirds.filter { !$0.isDeleted }
    }
    
    /// 从服务器数据更新本地缓存
    /// Bug #6/#7 修复：添加时间戳冲突解决（最新修改优先）
    /// Bug #9 修复：清理服务器已删除但本地仍存在的鸟儿
    func updateBirdsFromServer(_ serverBirds: [BirdDTO]) {
        // 获取服务器返回的所有鸟儿 ID
        let serverBirdIds = Set(serverBirds.compactMap { $0.id })
        
        // Bug #9 修复：清理本地缓存中已被服务器删除的鸟儿
        // 只清理那些已有 serverId 且不在服务器列表中、且非待同步的本地鸟儿
        let cleanupRequest: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        cleanupRequest.predicate = NSPredicate(format: "serverId != nil AND needsSync == NO")
        
        do {
            let localEntities = try viewContext.fetch(cleanupRequest)
            for entity in localEntities {
                if let serverId = entity.serverId?.intValue, !serverBirdIds.contains(serverId) {
                    // 该鸟在服务器不存在，删除本地缓存
                    logger.info("🗑️ 清理已删除鸟儿的本地缓存: \(entity.nickname ?? "")")
                    viewContext.delete(entity)
                }
            }
        } catch {
            logger.error("清理已删除鸟儿失败: \(error.localizedDescription)")
        }
        
        // 更新或添加服务器鸟儿
        for serverBird in serverBirds {
            let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
            request.predicate = NSPredicate(format: "serverId == %lld", serverBird.id ?? 0)
            
            do {
                let results = try viewContext.fetch(request)
                if let existing = results.first {
                    // Bug #6 修复：如果本地有未同步修改，比较时间戳
                    if existing.needsSync {
                        // Bug #7 修复：冲突解决 - 最新修改优先
                        let localUpdateTime = existing.updatedAt ?? Date.distantPast
                        let serverUpdateTime = serverBird.updatedAt ?? Date.distantPast
                        
                        if serverUpdateTime > localUpdateTime {
                            // 服务器更新更新，使用服务器数据
                            LocalBird(from: serverBird).updateEntity(existing)
                            existing.needsSync = false
                            logger.info("🔄 冲突解决：服务器数据更新，覆盖本地 - \(serverBird.nickname ?? "")")
                        } else {
                            // 本地更新更新，保留本地数据，等待同步
                            logger.info("🔄 冲突解决：本地数据更新，等待上传 - \(existing.nickname ?? "")")
                        }
                    } else {
                        // 无冲突，直接更新
                        LocalBird(from: serverBird).updateEntity(existing)
                    }
                } else {
                    // 添加新记录
                    let entity = LocalBirdEntity(context: viewContext)
                    LocalBird(from: serverBird).updateEntity(entity)
                }
            } catch {
                logger.error("更新鸟儿缓存失败: \(error.localizedDescription)")
            }
        }
        
        persistenceController.save()
        refreshLocalBirds()
    }
    
    // MARK: - P2-01: 共享关系管理
    
    /// 从服务器更新共享关系缓存（同时缓存共享的鸟儿数据到双方本地）
    func updateSharesFromServer(_ coOwners: [BirdCoOwner], birdId: Int64, ownerId: Int64) {
        // 删除该鸟儿的旧共享记录
        let deleteRequest: NSFetchRequest<LocalBirdShareEntity> = LocalBirdShareEntity.fetchRequest()
        deleteRequest.predicate = NSPredicate(format: "birdId == %lld", birdId)
        
        do {
            let oldEntities = try viewContext.fetch(deleteRequest)
            for entity in oldEntities {
                viewContext.delete(entity)
            }
            
            // 添加新的共享关系
            for coOwner in coOwners {
                let entity = LocalBirdShareEntity(context: viewContext)
                LocalBirdShare(from: coOwner, birdId: birdId, ownerId: ownerId).updateEntity(entity)
            }
            
            persistenceController.save()
            refreshLocalShares()
            logger.info("✅ 更新共享关系缓存: 鸟儿ID=\(birdId), 共享用户数=\(coOwners.count)")
        } catch {
            logger.error("更新共享关系失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取鸟儿的共享关系
    func getShares(for birdId: Int64) -> [LocalBirdShare] {
        return localShares.filter { $0.birdId == birdId && $0.status == "ACCEPTED" }
    }
    
    /// 获取当前用户被共享的鸟儿ID列表
    func getSharedBirdIds(forUserId userId: Int64) -> [Int64] {
        return localShares.filter { $0.sharedUserId == userId && $0.status == "ACCEPTED" }.map { $0.birdId }
    }
    
    /// 清除指定鸟儿的共享记录
    func clearShares(for birdId: Int64) {
        let request: NSFetchRequest<LocalBirdShareEntity> = LocalBirdShareEntity.fetchRequest()
        request.predicate = NSPredicate(format: "birdId == %lld", birdId)
        
        do {
            let entities = try viewContext.fetch(request)
            for entity in entities {
                viewContext.delete(entity)
            }
            persistenceController.save()
            refreshLocalShares()
            logger.info("🗑️ 清除共享记录: 鸟儿ID=\(birdId)")
        } catch {
            logger.error("清除共享记录失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 日志管理
    
    /// 添加日志（本地）
    /// 重举修复 #2: 添加日志时设置 userId，确保多用户数据隔离
    func addLog(_ log: LocalBirdLog) {
        var newLog = log
        // P0 修复：仅在未设置时生成新的 localId（支持预设 localId 用于图片关联）
        if newLog.localId.isEmpty {
            newLog.localId = UUID().uuidString
        }
        newLog.createdAt = Date()
        newLog.needsSync = true
        
        let entity = LocalBirdLogEntity(context: viewContext)
        newLog.updateEntity(entity)
        
        // 重举修复 #2: 设置 userId 确保数据隔离
        entity.userId = AuthService.shared.currentUserId
        
        persistenceController.save()
        refreshLocalLogs()
        updatePendingSyncCount()
        
        logger.info("📝 添加本地日志: \(newLog.content ?? "无内容"), 图片: \(newLog.localImagePaths.count) 张")
        
        // 如果在线且有待上传图片，不立即同步日志（等图片上传完成后再同步）
        // 如果在线且无图片，立即同步
        if isOnline && newLog.imageUploadStatus == .none {
            syncLog(newLog)
        }
    }
    
    /// 获取鸟儿的日志
    func getLogs(for birdLocalId: String) -> [LocalBirdLog] {
        return localLogs.filter { $0.birdLocalId == birdLocalId && !$0.isDeleted }
            .sorted { $0.logDate > $1.logDate }
    }
    
    /// 获取所有本地日志（包括未同步的）
    func getAllLogs() -> [LocalBirdLog] {
        return localLogs.filter { !$0.isDeleted }
            .sorted { $0.logDate > $1.logDate }
    }
    
    /// 删除本地日志（根据 localId）
    /// 用于删除本地未同步的日志记录
    func deleteLogByLocalId(_ localId: String) {
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                // P0 修复：删除日志关联的本地图片
                LogImageStorage.shared.deleteImages(for: localId)
                
                // 标记为已删除（软删除）
                entity.markedAsDeleted = true
                entity.needsSync = false  // 本地日志无需同步删除到服务器
                entity.deletedAt = Date()
                
                persistenceController.save()
                refreshLocalLogs()
                updatePendingSyncCount()
                
                logger.info("🗑️ 已删除本地日志: \(localId)")
            }
        } catch {
            logger.error("删除本地日志失败: \(error.localizedDescription)")
        }
    }
    
    /// 从服务器数据更新本地日志缓存
    func updateLogsFromServer(_ serverLogs: [BirdLogDTO], for birdLocalId: String) {
        // 删除该鸟儿的已同步日志
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "birdLocalId == %@ AND needsSync == NO", birdLocalId)
        
        do {
            let toDelete = try viewContext.fetch(request)
            toDelete.forEach { viewContext.delete($0) }
            
            // 添加服务器日志
            for serverLog in serverLogs {
                let entity = LocalBirdLogEntity(context: viewContext)
                LocalBirdLog(from: serverLog, birdLocalId: birdLocalId).updateEntity(entity)
            }
            
            persistenceController.save()
            refreshLocalLogs()
        } catch {
            logger.error("更新日志缓存失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 日志图片管理
    
    /// 检查并上传待处理的日志图片（App 启动或网络恢复时调用）
    func checkPendingImageUploads() {
        guard isOnline else { return }
        
        let pendingLogs = localLogs.filter { 
            $0.imageUploadStatus == .pending || $0.imageUploadStatus == .partial 
        }
        
        guard !pendingLogs.isEmpty else { return }
        
        logger.info("📸 发现 \(pendingLogs.count) 条日志有待上传图片")
        
        for log in pendingLogs {
            uploadPendingImages(for: log.localId)
        }
    }
    
    /// 上传指定日志的待上传图片
    /// - Parameter logLocalId: 日志本地 ID
    func uploadPendingImages(for logLocalId: String) {
        guard isOnline else {
            logger.info("📵 离线状态，跳过图片上传")
            return
        }
        
        // 获取日志
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", logLocalId)
        
        do {
            guard let entity = try viewContext.fetch(request).first else {
                logger.warning("⚠️ 未找到日志: \(logLocalId)")
                return
            }
            
            let log = LocalBirdLog(from: entity)
            
            // 检查是否有待上传的图片
            guard !log.localImagePaths.isEmpty else {
                logger.info("📝 日志无图片需要上传: \(logLocalId)")
                return
            }
            
            // 更新状态为上传中
            entity.imageUploadStatus = ImageUploadStatus.uploading.rawValue
            persistenceController.save()
            
            logger.info("📤 开始上传 \(log.localImagePaths.count) 张图片: \(logLocalId)")
            
            // 计算需要上传的图片（排除已上传的）
            let uploadedCount = log.ossURLs.count
            let pathsToUpload = Array(log.localImagePaths.dropFirst(uploadedCount))
            
            guard !pathsToUpload.isEmpty else {
                // 所有图片都已上传
                entity.imageUploadStatus = ImageUploadStatus.success.rawValue
                persistenceController.save()
                refreshLocalLogs()
                logger.info("✅ 所有图片已上传完成: \(logLocalId)")
                return
            }
            
            // 逐张上传（使用 async/await）
            Task {
                var successCount = uploadedCount
                var lastError: String?
                
                for path in pathsToUpload {
                    guard let image = LogImageStorage.shared.loadImage(at: path) else {
                        logger.warning("⚠️ 无法加载图片: \(path)")
                        continue
                    }
                    
                    do {
                        let ossURL = try await ApiService.shared.uploadPostImage(image: image)
                        
                        // 更新 Core Data
                        await MainActor.run {
                            if let updatedEntity = try? self.viewContext.fetch(request).first {
                                var updatedLog = LocalBirdLog(from: updatedEntity)
                                updatedLog.ossURLs.append(ossURL)
                                updatedLog.updateEntity(updatedEntity)
                                self.persistenceController.save()
                            }
                        }
                        
                        successCount += 1
                        logger.info("✅ 图片上传成功 (\(successCount)/\(log.localImagePaths.count)): \(ossURL)")
                        
                    } catch {
                        lastError = error.localizedDescription
                        logger.error("❌ 图片上传失败: \(error.localizedDescription)")
                    }
                }
                
                // 更新最终状态
                await MainActor.run {
                    if let finalEntity = try? self.viewContext.fetch(request).first {
                        if successCount == log.localImagePaths.count {
                            finalEntity.imageUploadStatus = ImageUploadStatus.success.rawValue
                            logger.info("🎉 日志所有图片上传完成: \(logLocalId)")
                        } else if successCount > uploadedCount {
                            finalEntity.imageUploadStatus = ImageUploadStatus.partial.rawValue
                            logger.info("⚠️ 日志图片部分上传成功 (\(successCount)/\(log.localImagePaths.count)): \(logLocalId)")
                        } else {
                            finalEntity.imageUploadStatus = ImageUploadStatus.failed.rawValue
                            finalEntity.imageRetryCount += 1
                            finalEntity.lastImageUploadError = lastError
                            logger.warning("❌ 日志图片上传失败: \(logLocalId)")
                        }
                        self.persistenceController.save()
                        self.refreshLocalLogs()
                        
                        // 如果图片全部上传成功且日志需要同步，触发日志同步
                        let updatedLog = LocalBirdLog(from: finalEntity)
                        if updatedLog.imageUploadStatus == .success && updatedLog.needsSync {
                            self.syncLog(updatedLog)
                        }
                    }
                }
            }
            
        } catch {
            logger.error("查询日志失败: \(error.localizedDescription)")
        }
    }
    
    /// 上传图片到 OSS（async 版本）
    /// 用于同步写入服务器流程
    func uploadImagesAsync(paths: [String]) async throws -> [String] {
        var ossURLs: [String] = []
        
        for path in paths {
            guard let image = LogImageStorage.shared.loadImage(at: path) else {
                logger.warning("⚠️ 无法加载图片: \(path)")
                continue
            }
            
            let ossURL = try await ApiService.shared.uploadPostImage(image: image)
            ossURLs.append(ossURL)
            logger.info("✅ 图片上传成功: \(ossURL)")
        }
        
        return ossURLs
    }
    
    /// 保存已同步的日志到本地（作为缓存，不触发同步）
    /// 用于同步写入服务器成功后保存到本地
    /// P0 关键修复：检查是否已存在相同 serverId 的日志，避免重复创建导致数据混乱
    func saveLogAsCache(_ log: LocalBirdLog) {
        var cachedLog = log
        cachedLog.needsSync = false  // 明确标记为已同步
        
        // P0 关键修复：先检查是否已存在相同 serverId 的日志
        if let serverId = log.serverId {
            let existingRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
            existingRequest.predicate = NSPredicate(format: "serverId == %d", Int64(serverId))
            
            do {
                let existingLogs = try viewContext.fetch(existingRequest)
                if let existing = existingLogs.first {
                    // 已存在，更新现有记录
                    cachedLog.updateEntity(existing)
                    existing.needsSync = false
                    persistenceController.save()
                    refreshLocalLogs()
                    logger.info("📦 日志缓存已更新: localId=\(cachedLog.localId), serverId=\(serverId)")
                    return
                }
            } catch {
                logger.error("查询现有日志缓存失败: \(error.localizedDescription)")
            }
        }
        
        // 再检查是否存在相同 localId 的日志
        let localIdRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        localIdRequest.predicate = NSPredicate(format: "localId == %@", log.localId)
        
        do {
            let existingByLocalId = try viewContext.fetch(localIdRequest)
            if let existing = existingByLocalId.first {
                // 已存在，更新现有记录
                cachedLog.updateEntity(existing)
                existing.needsSync = false
                if let serverId = log.serverId {
                    existing.serverId = NSNumber(value: serverId)
                }
                persistenceController.save()
                refreshLocalLogs()
                logger.info("📦 日志缓存已更新(by localId): localId=\(cachedLog.localId), serverId=\(String(describing: log.serverId))")
                return
            }
        } catch {
            logger.error("查询现有日志缓存(by localId)失败: \(error.localizedDescription)")
        }
        
        // 不存在，创建新记录
        let entity = LocalBirdLogEntity(context: viewContext)
        cachedLog.updateEntity(entity)
        entity.userId = AuthService.shared.currentUserId
        entity.needsSync = false
        
        persistenceController.save()
        refreshLocalLogs()
        
        logger.info("📦 日志已缓存到本地: localId=\(cachedLog.localId), serverId=\(String(describing: cachedLog.serverId))")
    }
    
    /// 更新日志的图片路径和状态
    /// - Parameters:
    ///   - logLocalId: 日志本地 ID
    ///   - imagePaths: 本地图片路径数组
    func updateLogImages(logLocalId: String, imagePaths: [String]) {
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", logLocalId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                var log = LocalBirdLog(from: entity)
                log.localImagePaths = imagePaths
                log.imageUploadStatus = imagePaths.isEmpty ? .none : .pending
                log.updateEntity(entity)
                persistenceController.save()
                refreshLocalLogs()
                logger.info("📸 更新日志图片路径: \(logLocalId), 图片数: \(imagePaths.count)")
            }
        } catch {
            logger.error("更新日志图片失败: \(error.localizedDescription)")
        }
    }
    
    /// 重试上传失败的日志图片
    /// - Parameter logLocalId: 日志本地 ID
    func retryImageUpload(for logLocalId: String) {
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", logLocalId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.imageUploadStatus = ImageUploadStatus.pending.rawValue
                entity.lastImageUploadError = nil
                persistenceController.save()
                refreshLocalLogs()
                
                // 立即触发上传
                if isOnline {
                    uploadPendingImages(for: logLocalId)
                }
            }
        } catch {
            logger.error("重置图片上传状态失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 体重记录管理
    
    /// 添加体重记录（本地）- P2-02: 同步更新日志的weight字段
    func addWeight(_ weight: LocalWeightRecord, autoSync: Bool = true) {
        var newWeight = weight
        newWeight.localId = UUID().uuidString
        newWeight.createdAt = Date()
        newWeight.needsSync = autoSync
        
        let entity = LocalWeightRecordEntity(context: viewContext)
        newWeight.updateEntity(entity)
        
        // P2-02: 同步更新同一天的日志记录的weight字段
        syncWeightToLog(birdLocalId: weight.birdLocalId, weight: weight.weight, date: weight.recordDate)
        
        persistenceController.save()
        refreshLocalWeights()
        refreshLocalLogs()
        updatePendingSyncCount()
        
        logger.info("⚖️ 添加本地体重记录: \(newWeight.weight)g, needsSync: \(autoSync)")
        
        // 如果在线且需要同步，立即同步
        if isOnline && autoSync {
            syncWeight(newWeight)
        }
    }
    
    /// P2-02: 同步体重到日志记录
    private func syncWeightToLog(birdLocalId: String, weight: Double, date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "birdLocalId == %@ AND logDate >= %@ AND logDate < %@", birdLocalId, startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let logs = try viewContext.fetch(request)
            for log in logs {
                log.weight = NSNumber(value: weight)
                log.needsSync = true
            }
            if !logs.isEmpty {
                logger.info("📝 已同步体重到 \(logs.count) 条日志记录")
            }
        } catch {
            logger.error("同步体重到日志失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取鸟儿的体重记录
    func getWeights(for birdLocalId: String) -> [LocalWeightRecord] {
        return localWeights.filter { $0.birdLocalId == birdLocalId && !$0.isDeleted }
            .sorted { $0.recordDate > $1.recordDate }
    }
    
    /// 从服务器数据更新本地体重缓存
    func updateWeightsFromServer(_ serverWeights: [WeightRecordDTO], for birdLocalId: String) {
        let request: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "birdLocalId == %@ AND needsSync == NO", birdLocalId)
        
        do {
            let toDelete = try viewContext.fetch(request)
            toDelete.forEach { viewContext.delete($0) }
            
            for serverWeight in serverWeights {
                let entity = LocalWeightRecordEntity(context: viewContext)
                LocalWeightRecord(from: serverWeight, birdLocalId: birdLocalId).updateEntity(entity)
            }
            
            persistenceController.save()
            refreshLocalWeights()
        } catch {
            logger.error("更新体重缓存失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 支出管理
    
    /// 添加支出（本地）
    func addExpense(_ expense: LocalExpense) {
        var newExpense = expense
        newExpense.localId = UUID().uuidString
        newExpense.createdAt = Date()
        newExpense.needsSync = true
        
        let entity = LocalExpenseEntity(context: viewContext)
        newExpense.updateEntity(entity)
        
        persistenceController.save()
        refreshLocalExpenses()
        updatePendingSyncCount()
        
        logger.info("💰 添加本地支出: \(newExpense.title), 金额: \(newExpense.amount)")
        
        // 如果在线，立即同步
        if isOnline {
            syncExpense(newExpense)
        }
    }
    
    /// 获取所有支出
    func getAllExpenses() -> [LocalExpense] {
        return localExpenses.filter { !$0.isDeleted }
            .sorted { $0.expenseDate > $1.expenseDate }
    }
    
    /// P2-08: 更新支出记录（编辑时调用）
    func updateExpense(_ expense: LocalExpense) {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", expense.localId)
        
        do {
            let results = try viewContext.fetch(request)
            if let entity = results.first {
                var updatedExpense = expense
                updatedExpense.needsSync = true
                updatedExpense.updatedAt = Date()
                updatedExpense.updateEntity(entity)
                
                persistenceController.save()
                refreshLocalExpenses()
                updatePendingSyncCount()
                
                logger.info("✏️ 更新本地支出: \(expense.title)")
                
                // 如果在线，立即同步
                if isOnline {
                    syncExpense(updatedExpense)
                }
            }
        } catch {
            logger.error("更新支出失败: \(error.localizedDescription)")
        }
    }
    
    /// 从服务器数据更新本地支出缓存
    func updateExpensesFromServer(_ serverExpenses: [ExpenseDTO]) {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == NO")
        
        do {
            let toDelete = try viewContext.fetch(request)
            toDelete.forEach { viewContext.delete($0) }
            
            for serverExpense in serverExpenses {
                let entity = LocalExpenseEntity(context: viewContext)
                LocalExpense(from: serverExpense).updateEntity(entity)
            }
            
            persistenceController.save()
            refreshLocalExpenses()
        } catch {
            logger.error("更新支出缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// Bug #8 修复：根据服务器 ID 删除本地缓存的支出记录
    func deleteExpenseByServerId(_ serverId: Int) {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %d", serverId)
        
        do {
            let results = try viewContext.fetch(request)
            for entity in results {
                viewContext.delete(entity)
            }
            persistenceController.save()
            refreshLocalExpenses()
            logger.info("🗑️ 已删除本地缓存支出 serverId: \(serverId)")
        } catch {
            logger.error("删除本地支出缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// 离线模式：标记支出为待删除，联网后同步
    func markExpenseDeleted(serverId: Int) {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %d", serverId)
        
        do {
            let results = try viewContext.fetch(request)
            if let entity = results.first {
                entity.markedAsDeleted = true
                entity.needsSync = true
                persistenceController.save()
                refreshLocalExpenses()
                logger.info("🗑️ 已标记支出为待删除 serverId: \(serverId)")
            } else {
                // 没有本地缓存，创建一条待删除记录
                let entity = LocalExpenseEntity(context: viewContext)
                entity.localId = UUID().uuidString
                entity.serverId = NSNumber(value: serverId)
                entity.markedAsDeleted = true
                entity.needsSync = true
                entity.title = ""
                entity.amount = 0
                entity.category = "other"
                entity.expenseDate = Date()
                persistenceController.save()
                refreshLocalExpenses()
                logger.info("🗑️ 创建待删除支出记录 serverId: \(serverId)")
            }
        } catch {
            logger.error("标记支出删除失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 生理周期管理
    
    /// 添加周期记录（本地）
    func addCycle(_ cycle: LocalCycleRecord) {
        var newCycle = cycle
        newCycle.localId = UUID().uuidString
        newCycle.createdAt = Date()
        newCycle.needsSync = true
        
        let entity = LocalCycleRecordEntity(context: viewContext)
        newCycle.updateEntity(entity)
        
        persistenceController.save()
        refreshLocalCycles()
        updatePendingSyncCount()
        
        logger.info("🔄 添加本地周期记录: \(newCycle.cycleType)")
        
        // 如果在线，立即同步
        if isOnline {
            syncCycle(newCycle)
        }
    }
    
    /// 结束周期（本地）
    func endCycle(localId: String, endDate: Date) {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.endDate = endDate
                entity.needsSync = true
                
                persistenceController.save()
                refreshLocalCycles()
                updatePendingSyncCount()
                
                if isOnline, let cycle = localCycles.first(where: { $0.localId == localId }) {
                    syncCycle(cycle)
                }
            }
        } catch {
            logger.error("结束周期失败: \(error.localizedDescription)")
        }
    }
    
    /// 删除周期记录（本地）
    func deleteCycle(localId: String, birdId: Int64? = nil) {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                // 如果有serverId，标记为删除待同步；否则直接删除
                if entity.serverId != nil {
                    entity.markedAsDeleted = true
                    entity.needsSync = true
                    entity.syncStatus = SyncStatus.pending.rawValue
                } else {
                    viewContext.delete(entity)
                }
                
                persistenceController.save()
                refreshLocalCycles()
                updatePendingSyncCount()
                
                // 删除对应的本地通知
                if let birdId = birdId, let cycleTypeStr = entity.cycleType,
                   let cycleType = CycleType(rawValue: cycleTypeStr) {
                    CycleReminderService.shared.cancelReminder(birdId: birdId, cycleType: cycleType)
                    logger.info("🔔 已删除周期提醒通知")
                }
                
                logger.info("🗑️ 删除周期记录: \(localId)")
                
                if isOnline, let cycle = localCycles.first(where: { $0.localId == localId }) {
                    syncDeletedCycle(cycle)
                }
            }
        } catch {
            logger.error("删除周期失败: \(error.localizedDescription)")
        }
    }
    
    /// 同步删除的周期记录
    private func syncDeletedCycle(_ cycle: LocalCycleRecord) {
        guard let serverId = cycle.serverId else { return }
        
        Task {
            do {
                try await ApiService.shared.deleteCycle(cycleId: Int64(serverId))
                await MainActor.run {
                    self.removeCycleEntity(localId: cycle.localId)
                }
            } catch {
                logger.error("同步删除周期失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 从Core Data删除周期实体
    private func removeCycleEntity(localId: String) {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistenceController.save()
                refreshLocalCycles()
            }
        } catch {
            logger.error("删除周期实体失败: \(error.localizedDescription)")
        }
    }
    
    /// 更新周期记录（本地）
    func updateCycle(localId: String, notes: String? = nil, eggCount: Int? = nil, hatchedCount: Int? = nil) {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                if let notes = notes { entity.notes = notes }
                if let eggCount = eggCount { entity.eggCount = NSNumber(value: eggCount) }
                if let hatchedCount = hatchedCount { entity.hatchedCount = NSNumber(value: hatchedCount) }
                entity.needsSync = true
                entity.syncStatus = SyncStatus.pending.rawValue
                
                persistenceController.save()
                refreshLocalCycles()
                updatePendingSyncCount()
            }
        } catch {
            logger.error("更新周期失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取鸟儿的周期记录
    func getCycles(for birdLocalId: String) -> [LocalCycleRecord] {
        return localCycles.filter { $0.birdLocalId == birdLocalId && !$0.isDeleted }
            .sorted { $0.startDate > $1.startDate }
    }
    
    /// 从服务器数据更新本地周期缓存
    func updateCyclesFromServer(_ serverCycles: [BirdCycleRecord], for birdLocalId: String, speciesName: String? = nil) {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "birdLocalId == %@ AND needsSync == NO", birdLocalId)
        
        // 尝试获取品种名称（如果未提供）
        var species = speciesName
        if species == nil {
            // 从本地鸟儿数据中获取品种
            if let bird = localBirds.first(where: { $0.localId == birdLocalId || String($0.serverId ?? 0) == birdLocalId }) {
                species = bird.species
            }
        }
        
        do {
            let toDelete = try viewContext.fetch(request)
            toDelete.forEach { viewContext.delete($0) }
            
            for serverCycle in serverCycles {
                let entity = LocalCycleRecordEntity(context: viewContext)
                LocalCycleRecord(from: serverCycle, birdLocalId: birdLocalId, speciesName: species).updateEntity(entity)
            }
            
            persistenceController.save()
            refreshLocalCycles()
        } catch {
            logger.error("更新周期缓存失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 同步功能
    
    /// P0 修复（问题5）：同步所有待同步数据（两阶段同步）
    /// 第一阶段：同步所有鸟儿，等待全部完成
    /// 第二阶段：同步依赖鸟儿serverId的日志/体重/周期
    func syncPendingData() {
        guard isOnline && !isSyncing else { return }
        
        isSyncing = true
        logger.info("🔄 开始同步待上传数据（两阶段同步）...")
        
        Task {
            // ========== 第一阶段：同步所有鸟儿 ==========
            let pendingBirds = await MainActor.run { fetchPendingSyncBirds() }
            
            // P1-03: 按优先级分类鸟儿同步任务
            let newBirds = pendingBirds.filter { $0.serverId == nil && !$0.isDeleted }
            let updateBirds = pendingBirds.filter { $0.serverId != nil && !$0.isDeleted }
            let deleteBirds = pendingBirds.filter { $0.isDeleted }
            
            logger.info("📊 第一阶段 - 鸟儿同步: 新增\(newBirds.count)只, 更新\(updateBirds.count)只, 删除\(deleteBirds.count)只")
            
            // 使用 DispatchGroup 等待第一阶段完成
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let birdGroup = DispatchGroup()
                
                for bird in newBirds {
                    birdGroup.enter()
                    syncBird(bird) { birdGroup.leave() }
                }
                for bird in updateBirds {
                    birdGroup.enter()
                    syncBird(bird) { birdGroup.leave() }
                }
                for bird in deleteBirds {
                    birdGroup.enter()
                    syncBird(bird) { birdGroup.leave() }
                }
                
                birdGroup.notify(queue: .main) {
                    continuation.resume()
                }
            }
            
            logger.info("✅ 第一阶段完成，开始第二阶段（日志/体重/周期）...")
            
            // ========== 第二阶段：同步依赖鸟儿的数据 ==========
            // 重新获取待同步数据（因为第一阶段可能更新了 birdServerId）
            let pendingLogs = await MainActor.run { fetchPendingSyncLogs() }
            let pendingWeights = await MainActor.run { fetchPendingSyncWeights() }
            let pendingExpenses = await MainActor.run { fetchPendingSyncExpenses() }
            let pendingCycles = await MainActor.run { fetchPendingSyncCycles() }
            
            logger.info("📊 第二阶段 - 数据同步: \(pendingLogs.count)条日志, \(pendingWeights.count)条体重, \(pendingExpenses.count)条支出, \(pendingCycles.count)条周期")
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let dataGroup = DispatchGroup()
                
                for log in pendingLogs {
                    dataGroup.enter()
                    syncLog(log) { dataGroup.leave() }
                }
                for weight in pendingWeights {
                    dataGroup.enter()
                    syncWeight(weight) { dataGroup.leave() }
                }
                for expense in pendingExpenses {
                    dataGroup.enter()
                    syncExpense(expense) { dataGroup.leave() }
                }
                for cycle in pendingCycles {
                    dataGroup.enter()
                    syncCycle(cycle) { dataGroup.leave() }
                }
                
                dataGroup.notify(queue: .main) {
                    continuation.resume()
                }
            }
            
            // 同步完成
            await MainActor.run {
                self.isSyncing = false
                self.lastSyncTime = Date()
                self.userDefaults.set(Date(), forKey: "lastSyncTime")
                self.updatePendingSyncCount()
                logger.info("✅ 两阶段同步完成，剩余待同步: \(self.pendingSyncCount)")
            }
        }
    }
    
    private func fetchPendingSyncBirds() -> [LocalBird] {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            return try viewContext.fetch(request).map { LocalBird(from: $0) }
        } catch {
            return []
        }
    }
    
    private func fetchPendingSyncLogs() -> [LocalBirdLog] {
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            return try viewContext.fetch(request).map { LocalBirdLog(from: $0) }
        } catch {
            return []
        }
    }
    
    private func fetchPendingSyncWeights() -> [LocalWeightRecord] {
        let request: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            return try viewContext.fetch(request).map { LocalWeightRecord(from: $0) }
        } catch {
            return []
        }
    }
    
    private func fetchPendingSyncExpenses() -> [LocalExpense] {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            return try viewContext.fetch(request).map { LocalExpense(from: $0) }
        } catch {
            return []
        }
    }
    
    private func fetchPendingSyncCycles() -> [LocalCycleRecord] {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            return try viewContext.fetch(request).map { LocalCycleRecord(from: $0) }
        } catch {
            return []
        }
    }
    
    // MARK: - 单项同步
    
    /// P2-04: 最大同步重试次数
    private let maxSyncRetryCount = 3
    
    private func syncBird(_ bird: LocalBird, completion: (() -> Void)? = nil) {
        guard let _ = AuthService.shared.getToken() else {
            completion?()
            return
        }
        
        // P2-04: 检查重试次数限制
        if bird.syncRetryCount >= maxSyncRetryCount {
            logger.warning("⚠️ 鸟儿同步已达最大重试次数: \(bird.nickname)")
            completion?()
            return
        }
        
        if bird.isDeleted {
            if let serverId = bird.serverId {
                ApiService.shared.deleteBird(id: serverId) { [weak self] result in
                    switch result {
                    case .success:
                        self?.removeBirdEntity(localId: bird.localId)
                    case .failure(let error):
                        self?.incrementSyncRetryCount(localId: bird.localId, entityType: .bird, errorMessage: error.localizedDescription)
                    }
                    completion?()
                }
            } else {
                removeBirdEntity(localId: bird.localId)
                completion?()
            }
        } else if bird.serverId == nil {
            // 重举修复 #3: 创建时携带 localId 作为幂等键
            // 如果之前的创建请求已经成功但客户端超时没收到响应，
            // 后端可以用 localId 在数据库中查找已存在的记录并返回，避免重复创建
            var dto = bird.toBirdDTO()
            dto.idempotencyKey = bird.localId  // 客户端 UUID 作为幂等键
            
            // P0 修复：同步时上传离线保存的头像
            if let avatarPath = bird.localAvatarPath,
               bird.imageUploadStatus == .pending,
               let image = LogImageStorage.shared.loadImage(at: avatarPath) {
                Task {
                    do {
                        let avatarUrl = try await ApiService.shared.uploadBirdAvatar(image: image)
                        dto.avatarUrl = avatarUrl
                        logger.info("✅ 离线头像上传成功: \(avatarUrl)")
                    } catch {
                        logger.error("❌ 离线头像上传失败: \(error.localizedDescription)")
                        // 头像上传失败不阻塞鸟的创建
                    }
                    
                    ApiService.shared.createBird(dto) { [weak self] result in
                        switch result {
                        case .success(let serverBird):
                            self?.updateBirdServerId(localId: bird.localId, serverId: serverBird.id)
                        case .failure(let error):
                            self?.incrementSyncRetryCount(localId: bird.localId, entityType: .bird, errorMessage: error.localizedDescription)
                        }
                        completion?()
                    }
                }
            } else {
                ApiService.shared.createBird(dto) { [weak self] result in
                    switch result {
                    case .success(let serverBird):
                        self?.updateBirdServerId(localId: bird.localId, serverId: serverBird.id)
                    case .failure(let error):
                        self?.incrementSyncRetryCount(localId: bird.localId, entityType: .bird, errorMessage: error.localizedDescription)
                    }
                    completion?()
                }
            }
        } else {
            var dto = bird.toBirdDTO()
            
            // P0 修复：同步时上传离线保存的头像（编辑鸟时离线选择的头像）
            if let avatarPath = bird.localAvatarPath,
               bird.imageUploadStatus == .pending,
               let image = LogImageStorage.shared.loadImage(at: avatarPath) {
                Task {
                    do {
                        let avatarUrl = try await ApiService.shared.uploadBirdAvatar(image: image)
                        dto.avatarUrl = avatarUrl
                        logger.info("✅ 离线编辑头像上传成功: \(avatarUrl)")
                    } catch {
                        logger.error("❌ 离线编辑头像上传失败: \(error.localizedDescription)")
                    }
                    
                    ApiService.shared.updateBird(id: bird.serverId!, dto) { [weak self] result in
                        switch result {
                        case .success:
                            self?.markBirdSynced(localId: bird.localId)
                        case .failure(let error):
                            let errorMessage = error.localizedDescription
                            if errorMessage.contains("VERSION_CONFLICT") {
                                logger.error("⚠️ 版本冲突: \(bird.nickname) - 数据已被其他设备修改，请刷新后重试")
                                self?.markBirdAsConflicted(localId: bird.localId, errorMessage: "版本冲突：数据已被其他设备修改")
                            } else {
                                self?.incrementSyncRetryCount(localId: bird.localId, entityType: .bird, errorMessage: errorMessage)
                            }
                        }
                        completion?()
                    }
                }
            } else {
                ApiService.shared.updateBird(id: bird.serverId!, dto) { [weak self] result in
                    switch result {
                    case .success:
                        self?.markBirdSynced(localId: bird.localId)
                    case .failure(let error):
                        // P0: 特殊处理版本冲突错误
                        let errorMessage = error.localizedDescription
                        if errorMessage.contains("VERSION_CONFLICT") {
                            logger.error("⚠️ 版本冲突: \(bird.nickname) - 数据已被其他设备修改，请刷新后重试")
                            self?.markBirdAsConflicted(localId: bird.localId, errorMessage: "版本冲突：数据已被其他设备修改")
                        } else {
                            self?.incrementSyncRetryCount(localId: bird.localId, entityType: .bird, errorMessage: errorMessage)
                        }
                    }
                    completion?()
                }
            }
        }
    }
    
    /// P0: 标记鸟儿为版本冲突状态（需要用户干预）
    private func markBirdAsConflicted(localId: String, errorMessage: String) {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        if let entity = try? viewContext.fetch(request).first {
            entity.syncError = errorMessage
            entity.syncRetryCount = Int16(maxSyncRetryCount) // 直接设为最大值，停止自动重试
            persistenceController.save()
            
            // 发送通知让 UI 显示冲突提示
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SyncConflictDetected"), object: nil, userInfo: ["localId": localId, "nickname": entity.nickname ?? "未知"])
            }
        }
    }
    
    /// P2-04: 增加同步重试次数
    /// P1: 增强版本 - 同时记录错误信息
    private enum EntityType { case bird, log, weight, expense, cycle }
    
    private func incrementSyncRetryCount(localId: String, entityType: EntityType, errorMessage: String? = nil) {
        switch entityType {
        case .bird:
            let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
            request.predicate = NSPredicate(format: "localId == %@", localId)
            if let entity = try? viewContext.fetch(request).first {
                entity.syncRetryCount += 1
                entity.syncError = errorMessage
                persistenceController.save()
                if entity.syncRetryCount >= maxSyncRetryCount {
                    logger.warning("⚠️ 鸟儿同步已达最大重试次数: \(entity.nickname ?? ""), 错误: \(errorMessage ?? "未知")")
                }
            }
        case .log:
            let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
            request.predicate = NSPredicate(format: "localId == %@", localId)
            if let entity = try? viewContext.fetch(request).first {
                entity.syncRetryCount += 1
                entity.syncError = errorMessage
                persistenceController.save()
                if entity.syncRetryCount >= maxSyncRetryCount {
                    logger.warning("⚠️ 日志同步已达最大重试次数, 错误: \(errorMessage ?? "未知")")
                }
            }
        case .weight:
            let request: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
            request.predicate = NSPredicate(format: "localId == %@", localId)
            if let entity = try? viewContext.fetch(request).first {
                entity.syncRetryCount += 1
                entity.syncError = errorMessage
                persistenceController.save()
                if entity.syncRetryCount >= maxSyncRetryCount {
                    logger.warning("⚠️ 体重记录同步已达最大重试次数, 错误: \(errorMessage ?? "未知")")
                }
            }
        case .expense:
            // P1-01: 支出记录同步重试计数
            let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
            request.predicate = NSPredicate(format: "localId == %@", localId)
            if let entity = try? viewContext.fetch(request).first {
                entity.syncRetryCount += 1
                persistenceController.save()
                logger.warning("⚠️ 支出同步失败，重试次数: \(entity.syncRetryCount), 错误: \(errorMessage ?? "未知")")
            }
        case .cycle:
            // 重举修复 #6: 实现周期记录同步重试计数，防止无限重试
            let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
            request.predicate = NSPredicate(format: "localId == %@", localId)
            if let entity = try? viewContext.fetch(request).first {
                entity.syncRetryCount += 1
                entity.syncError = errorMessage
                persistenceController.save()
                if entity.syncRetryCount >= maxSyncRetryCount {
                    logger.warning("⚠️ 周期记录同步已达最大重试次数, 错误: \(errorMessage ?? "未知")")
                }
            }
        }
    }
    
    /// 重举修复 #7: 完善日志同步错误处理，特别是图片已上传但日志同步失败的情况
    private func syncLog(_ log: LocalBirdLog, completion: (() -> Void)? = nil) {
        guard let _ = AuthService.shared.getToken() else {
            completion?()
            return
        }
        
        // 检查重试次数限制
        if log.syncRetryCount >= maxSyncRetryCount {
            logger.warning("⚠️ 日志同步已达最大重试次数，停止重试。图片状态: \(log.imageUploadStatus.rawValue)")
            completion?()
            return
        }
        
        // 找到对应鸟儿的服务器ID
        // P0 修复：支持多种 birdLocalId 格式
        var birdServerId: Int?
        
        // 1. 先尝试匹配本地鸟的 localId
        if let bird = localBirds.first(where: { $0.localId == log.birdLocalId }) {
            birdServerId = bird.serverId
        }
        // 2. 检查是否是 "server_{id}" 格式
        else if log.birdLocalId.hasPrefix("server_"),
                let idString = log.birdLocalId.components(separatedBy: "server_").last,
                let serverId = Int(idString) {
            birdServerId = serverId
        }
        // 3. 尝试直接解析为服务器ID（兼容旧数据）
        else if let directId = Int(log.birdLocalId) {
            birdServerId = directId
        }
        
        guard let finalBirdServerId = birdServerId else {
            // 如果图片已上传但找不到鸟儿，记录警告（可能是孤儿日志）
            if log.imageUploadStatus == .success && !log.ossURLs.isEmpty {
                logger.warning("⚠️ 重举 #7: 图片已上传但找不到关联鸟儿，birdLocalId=\(log.birdLocalId)，ossURLs=\(log.ossURLs.count)张")
            }
            logger.warning("⚠️ 无法解析日志的鸟儿ID: birdLocalId=\(log.birdLocalId)")
            completion?()
            return
        }
        
        // P0 修复：构建日志数据，包含 ossURLs 和 weight
        // 注意：后端期望的字段名是 notes，不是 content
        // P1 修复：区分新建和更新
        if let serverId = log.serverId, serverId > 0 {
            // 更新逻辑
            Task {
                do {
                    try await ApiService.shared.patchLog(
                        id: Int64(serverId),
                        logDate: log.logDate,
                        weight: log.weight,
                        notes: log.content ?? "",
                        imageUrls: log.ossURLs.isEmpty ? nil : log.ossURLs
                    )
                    
                    await MainActor.run {
                        logger.info("✅ 日志更新同步成功，服务器ID: \(serverId)")
                        self.markLogSynced(localId: log.localId, serverId: serverId, birdServerId: finalBirdServerId)
                    }
                } catch {
                    let errorMessage = error.localizedDescription
                    await MainActor.run {
                        self.incrementSyncRetryCount(localId: log.localId, entityType: .log, errorMessage: errorMessage)
                        logger.error("❌ 日志更新同步失败 (ID: \(serverId)): \(errorMessage)")
                    }
                }
                completion?()
            }
        } else {
            // 新建逻辑
            // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
            
            // 构建符合后端 CreateLogRequest 的数据结构
            var logData: [String: Any] = [
                "notes": log.content ?? "",
                "logDate": DateFormatters.toAPIDateTime(log.logDate)
            ]
            
            // 添加体重字段（如果有）
            if let weight = log.weight {
                logData["weight"] = weight
                logger.info("📤 同步日志携带体重: \(weight)g")
            }
            
            // 如果图片已上传成功，包含 OSS URLs
            if !log.ossURLs.isEmpty {
                logData["imageUrls"] = log.ossURLs
                logger.info("📤 同步日志携带 \(log.ossURLs.count) 张图片 URL")
            }
            
            ApiService.shared.addBirdLog(birdId: finalBirdServerId, data: logData) { [weak self] result in
                switch result {
                case .success(let responseData):
                    // P0 修复：从服务器响应中解析日志 ID
                    var serverLogId: Int? = nil
                    if let idValue = responseData["id"] {
                        if let intId = idValue as? Int {
                            serverLogId = intId
                        } else if let int64Id = idValue as? Int64 {
                            serverLogId = Int(int64Id)
                        } else if let doubleId = idValue as? Double {
                            serverLogId = Int(doubleId)
                        }
                    }
                    
                    if let serverId = serverLogId {
                        logger.info("✅ 日志同步成功，服务器ID: \(serverId)")
                        self?.markLogSynced(localId: log.localId, serverId: serverId, birdServerId: finalBirdServerId)
                    } else {
                        logger.warning("⚠️ 日志同步成功但未获取到服务器ID，响应: \(responseData)")
                        self?.markLogSynced(localId: log.localId, serverId: nil, birdServerId: finalBirdServerId)
                    }
                case .failure(let error):
                    let errorMessage = error.localizedDescription
                    self?.incrementSyncRetryCount(localId: log.localId, entityType: .log, errorMessage: errorMessage)
                    
                    if !log.ossURLs.isEmpty {
                        logger.warning("⚠️ 重举 #7: 图片已上传到 OSS，但日志同步失败: \(errorMessage)")
                    }
                }
                completion?()
            }
        }
    }
    
    private func syncWeight(_ weight: LocalWeightRecord, completion: (() -> Void)? = nil) {
        guard let _ = AuthService.shared.getToken() else {
            completion?()
            return
        }
        
        // P0 修复：支持多种 birdLocalId 格式
        var birdServerId: Int?
        
        // 1. 先尝试匹配本地鸟的 localId
        if let bird = localBirds.first(where: { $0.localId == weight.birdLocalId }) {
            birdServerId = bird.serverId
        }
        // 2. 检查是否是 "server_{id}" 格式
        else if weight.birdLocalId.hasPrefix("server_"),
                let idString = weight.birdLocalId.components(separatedBy: "server_").last,
                let serverId = Int(idString) {
            birdServerId = serverId
        }
        // 3. 尝试直接解析为服务器ID（兼容旧数据）
        else if let directId = Int(weight.birdLocalId) {
            birdServerId = directId
        }
        
        guard let finalBirdServerId = birdServerId else {
            logger.warning("⚠️ 无法解析体重记录的鸟儿ID: birdLocalId=\(weight.birdLocalId)")
            completion?()
            return
        }
        
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        let weightData: [String: Any] = [
            "weight": weight.weight,
            "recordDate": DateFormatters.toAPIDateTime(weight.recordDate)
        ]
        
        ApiService.shared.addBirdWeight(birdId: finalBirdServerId, data: weightData) { [weak self] result in
            if case .success = result {
                self?.markWeightSynced(localId: weight.localId)
            }
            completion?()
        }
    }
    
    private func syncExpense(_ expense: LocalExpense, completion: (() -> Void)? = nil) {
        guard let _ = AuthService.shared.getToken() else {
            completion?()
            return
        }
        
        // P1-01: 检查重试次数限制
        if expense.syncRetryCount >= maxSyncRetryCount {
            logger.warning("⚠️ 支出同步已达最大重试次数(\(self.maxSyncRetryCount))，停止重试: \(expense.title)")
            completion?()
            return
        }
        
        if expense.isDeleted {
            if let serverId = expense.serverId {
                Task {
                    let success = await ExpenseService.shared.deleteExpense(id: Int64(serverId))
                    if success {
                        await MainActor.run {
                            self.removeExpenseEntity(localId: expense.localId)
                        }
                    } else {
                        // P1-01: 删除失败，增加重试次数
                        await MainActor.run {
                            self.incrementSyncRetryCount(localId: expense.localId, entityType: .expense)
                        }
                    }
                    completion?()
                }
            } else {
                removeExpenseEntity(localId: expense.localId)
                completion?()
            }
        } else if expense.serverId == nil {
            Task {
                let success = await ExpenseService.shared.addExpense(
                    title: expense.title,
                    amount: expense.amount,
                    category: ExpenseCategory(rawValue: expense.category) ?? .other,
                    date: expense.expenseDate,
                    birdId: expense.birdId.flatMap { Int64($0) },
                    birdName: expense.birdName,
                    note: expense.note
                )
                
                if success {
                    await MainActor.run {
                        self.markExpenseSynced(localId: expense.localId)
                    }
                } else {
                    // P1-01: 新增失败，增加重试次数
                    await MainActor.run {
                        self.incrementSyncRetryCount(localId: expense.localId, entityType: .expense)
                    }
                }
                completion?()
            }
        } else {
            Task {
                let success = await ExpenseService.shared.updateExpense(
                    id: Int64(expense.serverId!),
                    title: expense.title,
                    amount: expense.amount,
                    category: ExpenseCategory(rawValue: expense.category) ?? .other,
                    date: expense.expenseDate,
                    birdId: expense.birdId.flatMap { Int64($0) },
                    birdName: expense.birdName,
                    note: expense.note
                )
                
                if success {
                    await MainActor.run {
                        self.markExpenseSynced(localId: expense.localId)
                    }
                } else {
                    // P1-01: 更新失败，增加重试次数
                    await MainActor.run {
                        self.incrementSyncRetryCount(localId: expense.localId, entityType: .expense)
                    }
                }
                completion?()
            }
        }
    }
    
    private func syncCycle(_ cycle: LocalCycleRecord, completion: (() -> Void)? = nil) {
        guard let _ = AuthService.shared.getToken() else {
            completion?()
            return
        }
        
        // P0 修复：支持多种 birdLocalId 格式
        var birdServerId: Int?
        
        // 1. 先尝试匹配本地鸟的 localId
        if let bird = localBirds.first(where: { $0.localId == cycle.birdLocalId }) {
            birdServerId = bird.serverId
        }
        // 2. 检查是否是 "server_{id}" 格式
        else if cycle.birdLocalId.hasPrefix("server_"),
                let idString = cycle.birdLocalId.components(separatedBy: "server_").last,
                let serverId = Int(idString) {
            birdServerId = serverId
        }
        // 3. 尝试直接解析为服务器ID（兼容旧数据）
        else if let directId = Int(cycle.birdLocalId) {
            birdServerId = directId
        }
        
        guard let finalBirdServerId = birdServerId else {
            logger.warning("⚠️ 无法解析周期记录的鸟儿ID: birdLocalId=\(cycle.birdLocalId)")
            completion?()
            return
        }
        
        if cycle.serverId == nil {
            // 新建周期
            Task {
                do {
                    let request = CreateCycleRequest(
                        cycleType: CycleType(rawValue: cycle.cycleType) ?? .BATHING,
                        startDate: cycle.startDate,
                        notes: cycle.notes
                    )
                    let _ = try await ApiService.shared.createCycle(birdId: Int64(finalBirdServerId), request: request)
                    await MainActor.run {
                        self.markCycleSynced(localId: cycle.localId)
                    }
                } catch {
                    logger.error("同步周期失败: \(error.localizedDescription)")
                }
                completion?()
            }
        } else if cycle.endDate != nil {
            // 结束周期
            Task {
                do {
                    let _ = try await ApiService.shared.endCycle(cycleId: Int64(cycle.serverId!), endDate: cycle.endDate!)
                    await MainActor.run {
                        self.markCycleSynced(localId: cycle.localId)
                    }
                } catch {
                    logger.error("同步结束周期失败: \(error.localizedDescription)")
                }
                completion?()
            }
        } else if let serverId = cycle.serverId, cycle.endDate == nil {
            // 更新周期（例如更新备注）
            Task {
                do {
                    let _ = try await ApiService.shared.updateCycle(
                        cycleId: Int64(serverId),
                        endDate: nil,
                        notes: cycle.notes
                    )
                    await MainActor.run {
                        self.markCycleSynced(localId: cycle.localId)
                    }
                } catch {
                    logger.error("同步更新周期失败: \(error.localizedDescription)")
                }
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    private func markCycleSynced(localId: String) {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.needsSync = false
                persistenceController.save()
                refreshLocalCycles()
            }
        } catch {
            logger.error("标记周期已同步失败: \(error.localizedDescription)")
        }
    }
    
    
    private func removeBirdEntity(localId: String) {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistenceController.save()
                refreshLocalBirds()
            }
        } catch {
            logger.error("删除鸟儿实体失败: \(error.localizedDescription)")
        }
    }
    
    /// 重举修复 #4: 使用 performAndWait 确保更新 serverId 和关联记录的 birdLocalId 是原子操作
    /// 如果中途失败或 crash，整个事务会回滚，避免孤儿日志
    private func updateBirdServerId(localId: String, serverId: Int?) {
        // 重举修复 #4: 使用 performAndWait 确保整个更新在同一事务内完成
        viewContext.performAndWait {
            let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
            request.predicate = NSPredicate(format: "localId == %@", localId)
            
            do {
                guard let entity = try viewContext.fetch(request).first else {
                    logger.warning("未找到要更新的鸟儿: \(localId)")
                    return
                }
                
                entity.serverId = serverId.map { NSNumber(value: $0) }
                entity.needsSync = false
                
                // P0 修复（问题2）：同步更新所有关联记录的 birdLocalId 为 serverId 字符串
                // 确保离线创建的日志在 API 同步时能正确关联到已同步的鸟儿
                if let serverId = serverId {
                    let serverIdStr = String(serverId)
                    
                    let logRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
                    logRequest.predicate = NSPredicate(format: "birdLocalId == %@", localId)
                    let logs = try viewContext.fetch(logRequest)
                    for log in logs {
                        log.birdLocalId = serverIdStr  // 更新为 serverId 字符串
                    }
                    
                    let weightRequest: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
                    weightRequest.predicate = NSPredicate(format: "birdLocalId == %@", localId)
                    let weights = try viewContext.fetch(weightRequest)
                    for weight in weights {
                        weight.birdLocalId = serverIdStr  // 更新为 serverId 字符串
                    }
                    
                    let cycleRequest: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
                    cycleRequest.predicate = NSPredicate(format: "birdLocalId == %@", localId)
                    let cycles = try viewContext.fetch(cycleRequest)
                    for cycle in cycles {
                        cycle.birdLocalId = serverIdStr  // 更新为 serverId 字符串
                    }
                    
                    logger.info("📝 已更新 \(logs.count) 条日志、\(weights.count) 条体重、\(cycles.count) 条周期的 birdLocalId 为 serverId:\(serverId)")
                }
                
                // 在同一事务内保存
                try viewContext.save()
                
                // 事务成功后刷新 UI
                DispatchQueue.main.async { [weak self] in
                    self?.refreshLocalBirds()
                }
                
            } catch {
                // 重举修复 #4: 事务失败时回滚，确保不会产生部分更新的中间状态
                viewContext.rollback()
                logger.error("更新鸟儿服务器ID失败（已回滚）: \(error.localizedDescription)")
            }
        }
    }
    
    private func markBirdSynced(localId: String) {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.needsSync = false
                entity.syncError = nil
                entity.syncRetryCount = 0
                persistenceController.save()
                refreshLocalBirds()
            }
        } catch {
            logger.error("标记鸟儿已同步失败: \(error.localizedDescription)")
        }
    }
    
    /// P1: 重置同步重试次数，允许重新同步
    func resetSyncRetryCount(localId: String) {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.syncRetryCount = 0
                entity.syncError = nil
                entity.needsSync = true
                persistenceController.save()
                refreshLocalBirds()
                updatePendingSyncCount()
                logger.info("🔄 已重置同步状态: \(entity.nickname ?? "")")
            }
        } catch {
            logger.error("重置同步状态失败: \(error.localizedDescription)")
        }
    }
    
    /// P0 修复：日志同步成功后保存服务器ID，确保本地日志与服务器日志正确关联
    /// - Parameters:
    ///   - localId: 本地日志 ID (UUID)
    ///   - serverId: 服务器返回的日志 ID（可选）
    ///   - birdServerId: 服务器鸟 ID，用于更新 birdLocalId 为统一格式
    private func markLogSynced(localId: String, serverId: Int? = nil, birdServerId: Int? = nil) {
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.needsSync = false
                entity.syncError = nil
                entity.syncRetryCount = 0
                
                // P0 修复：保存服务器返回的日志 ID
                if let serverId = serverId {
                    entity.serverId = NSNumber(value: serverId)
                    logger.info("📝 日志已同步，本地ID: \(localId), 服务器ID: \(serverId)")
                }
                
                // P0 关键修复：将 birdLocalId 更新为服务器鸟 ID 的统一格式（纯数字字符串）
                // 这样后续显示时不再需要复杂的解析逻辑
                if let birdServerId = birdServerId {
                    let oldBirdLocalId = entity.birdLocalId ?? ""
                    entity.birdLocalId = String(birdServerId)
                    logger.info("📝 日志 birdLocalId 已更新: \(oldBirdLocalId) -> \(birdServerId)")
                }
                
                persistenceController.save()
                refreshLocalLogs()
            }
        } catch {
            logger.error("标记日志已同步失败: \(error.localizedDescription)")
        }
    }
    
    private func markWeightSynced(localId: String) {
        let request: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.needsSync = false
                persistenceController.save()
                refreshLocalWeights()
            }
        } catch {
            logger.error("标记体重已同步失败: \(error.localizedDescription)")
        }
    }
    
    private func markExpenseSynced(localId: String) {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                entity.needsSync = false
                persistenceController.save()
                refreshLocalExpenses()
            }
        } catch {
            logger.error("标记支出已同步失败: \(error.localizedDescription)")
        }
    }
    
    private func removeExpenseEntity(localId: String) {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", localId)
        
        do {
            if let entity = try viewContext.fetch(request).first {
                viewContext.delete(entity)
                persistenceController.save()
                refreshLocalExpenses()
            }
        } catch {
            logger.error("删除支出实体失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 清理
    
    /// 清除所有本地数据
    func clearAllLocalData() {
        persistenceController.clearAllData()
        
        localBirds = []
        localLogs = []
        localWeights = []
        localExpenses = []
        localCycles = []
        localShares = []
        pendingSyncCount = 0
        lastSyncTime = nil
        userDefaults.removeObject(forKey: "lastSyncTime")
        
        logger.info("🗑️ 已清空所有本地数据")
    }
    
    /// #16 修复：登出时清除当前用户的所有本地数据
    /// 在 AuthService.clearAuth() 中调用此方法
    func clearAllUserData() {
        guard let userId = AuthService.shared.currentUserId else {
            logger.warning("⚠️ 无法清除用户数据：未登录")
            return
        }
        
        // 清除属于当前用户的所有数据
        clearUserBirds(userId: userId)
        clearUserLogs(userId: userId)
        clearUserWeights(userId: userId)
        clearUserExpenses(userId: userId)
        clearUserCycles(userId: userId)
        clearUserShares(userId: userId)
        
        // 刷新内存中的数据
        refreshLocalBirds()
        refreshLocalLogs()
        refreshLocalWeights()
        refreshLocalExpenses()
        refreshLocalCycles()
        refreshLocalShares()
        updatePendingSyncCount()
        
        // 清除用户相关的 UserDefaults 缓存
        userDefaults.removeObject(forKey: "cachedExpenseStats_\(userId)")
        userDefaults.removeObject(forKey: "cachedExpenseStatsTimestamp_\(userId)")
        
        logger.info("🗑️ 已清除用户 \(userId) 的所有本地数据")
    }
    
    private func clearUserBirds(userId: String) {
        let request: NSFetchRequest<LocalBirdEntity> = LocalBirdEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        do {
            let entities = try viewContext.fetch(request)
            entities.forEach { viewContext.delete($0) }
            persistenceController.save()
        } catch {
            logger.error("清除用户鸟儿数据失败: \(error.localizedDescription)")
        }
    }
    
    private func clearUserLogs(userId: String) {
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        do {
            let entities = try viewContext.fetch(request)
            // 同时删除关联的本地图片
            for entity in entities {
                if let logLocalId = entity.localId {
                    LogImageStorage.shared.deleteImages(for: logLocalId)
                }
            }
            entities.forEach { viewContext.delete($0) }
            persistenceController.save()
        } catch {
            logger.error("清除用户日志数据失败: \(error.localizedDescription)")
        }
    }
    
    private func clearUserWeights(userId: String) {
        let request: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        do {
            let entities = try viewContext.fetch(request)
            entities.forEach { viewContext.delete($0) }
            persistenceController.save()
        } catch {
            logger.error("清除用户体重数据失败: \(error.localizedDescription)")
        }
    }
    
    private func clearUserExpenses(userId: String) {
        let request: NSFetchRequest<LocalExpenseEntity> = LocalExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        do {
            let entities = try viewContext.fetch(request)
            entities.forEach { viewContext.delete($0) }
            persistenceController.save()
        } catch {
            logger.error("清除用户支出数据失败: \(error.localizedDescription)")
        }
    }
    
    private func clearUserCycles(userId: String) {
        let request: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        do {
            let entities = try viewContext.fetch(request)
            entities.forEach { viewContext.delete($0) }
            persistenceController.save()
        } catch {
            logger.error("清除用户周期数据失败: \(error.localizedDescription)")
        }
    }
    
    private func clearUserShares(userId: String) {
        guard let userIdInt = Int64(userId) else { return }
        let request: NSFetchRequest<LocalBirdShareEntity> = LocalBirdShareEntity.fetchRequest()
        request.predicate = NSPredicate(format: "ownerId == %lld OR sharedUserId == %lld", userIdInt, userIdInt)
        do {
            let entities = try viewContext.fetch(request)
            entities.forEach { viewContext.delete($0) }
            persistenceController.save()
        } catch {
            logger.error("清除用户共享数据失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 数据诊断和修复
    
    /// P0 新增：诊断用户数据完整性问题
    /// 返回一个报告字典，包含各种数据问题的统计
    func diagnoseDataIntegrity() -> [String: Any] {
        var report: [String: Any] = [:]
        
        guard let userId = AuthService.shared.currentUserId else {
            report["error"] = "未登录"
            return report
        }
        
        report["userId"] = userId
        
        // 1. 检查孤儿日志（已同步成功但没有 serverId 的日志）
        let orphanLogRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        orphanLogRequest.predicate = NSPredicate(format: "userId == %@ AND needsSync == NO AND serverId == nil AND markedAsDeleted == NO", userId)
        
        do {
            let orphanLogs = try viewContext.fetch(orphanLogRequest)
            report["orphanLogsCount"] = orphanLogs.count
            report["orphanLogDetails"] = orphanLogs.prefix(10).map { 
                ["localId": $0.localId ?? "", "content": $0.content ?? "", "logDate": $0.logDate?.description ?? ""]
            }
        } catch {
            report["orphanLogsError"] = error.localizedDescription
        }
        
        // 2. 检查同步失败的数据
        let failedSyncLogRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        failedSyncLogRequest.predicate = NSPredicate(format: "userId == %@ AND syncRetryCount >= 3", userId)
        
        do {
            let failedLogs = try viewContext.fetch(failedSyncLogRequest)
            report["failedSyncLogsCount"] = failedLogs.count
            report["failedSyncLogDetails"] = failedLogs.prefix(10).map {
                ["localId": $0.localId ?? "", "error": $0.syncError ?? "未知错误", "retryCount": $0.syncRetryCount]
            }
        } catch {
            report["failedSyncLogsError"] = error.localizedDescription
        }
        
        // 3. 检查无关联鸟儿的日志（鸟儿已删除但日志还在）
        let allLogsRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        allLogsRequest.predicate = NSPredicate(format: "userId == %@ AND markedAsDeleted == NO", userId)
        
        do {
            let allLogs = try viewContext.fetch(allLogsRequest)
            var orphanBirdLogs: [LocalBirdLogEntity] = []
            
            for log in allLogs {
                guard let birdLocalId = log.birdLocalId else { continue }
                
                // 检查鸟儿是否存在
                let birdExists = localBirds.contains { $0.localId == birdLocalId || String($0.serverId ?? 0) == birdLocalId }
                if !birdExists {
                    orphanBirdLogs.append(log)
                }
            }
            
            report["logsWithDeletedBirdCount"] = orphanBirdLogs.count
        } catch {
            report["logsWithDeletedBirdError"] = error.localizedDescription
        }
        
        // 4. 统计待同步数据
        report["pendingSyncCount"] = pendingSyncCount
        
        // 5. 检查图片上传问题
        let imageIssueRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        imageIssueRequest.predicate = NSPredicate(format: "userId == %@ AND (imageUploadStatus == %@ OR imageUploadStatus == %@)", userId, ImageUploadStatus.failed.rawValue, ImageUploadStatus.partial.rawValue)
        
        do {
            let imageIssueLogs = try viewContext.fetch(imageIssueRequest)
            report["imageUploadIssuesCount"] = imageIssueLogs.count
        } catch {
            report["imageUploadIssuesError"] = error.localizedDescription
        }
        
        logger.info("📊 数据诊断完成: \(report)")
        return report
    }
    
    /// P0 新增：清理孤儿日志（已同步成功但没有 serverId 的日志）
    /// 将这些日志重新标记为需要同步
    func repairOrphanLogs() -> Int {
        guard let userId = AuthService.shared.currentUserId else { return 0 }
        
        let request: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND needsSync == NO AND serverId == nil AND markedAsDeleted == NO", userId)
        
        do {
            let orphanLogs = try viewContext.fetch(request)
            for log in orphanLogs {
                log.needsSync = true
                log.syncRetryCount = 0
                log.syncError = nil
            }
            persistenceController.save()
            refreshLocalLogs()
            updatePendingSyncCount()
            
            logger.info("🔧 已修复 \(orphanLogs.count) 条孤儿日志，将重新同步")
            return orphanLogs.count
        } catch {
            logger.error("修复孤儿日志失败: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// P0 新增：重置所有失败的同步任务，允许重新尝试
    func resetFailedSyncTasks() -> Int {
        guard let userId = AuthService.shared.currentUserId else { return 0 }
        
        var resetCount = 0
        
        // 重置日志
        let logRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        logRequest.predicate = NSPredicate(format: "userId == %@ AND syncRetryCount >= 3", userId)
        
        do {
            let failedLogs = try viewContext.fetch(logRequest)
            for log in failedLogs {
                log.syncRetryCount = 0
                log.syncError = nil
                log.needsSync = true
            }
            resetCount += failedLogs.count
        } catch {
            logger.error("重置失败日志同步任务失败: \(error.localizedDescription)")
        }
        
        // 重置体重记录
        let weightRequest: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
        weightRequest.predicate = NSPredicate(format: "userId == %@ AND syncRetryCount >= 3", userId)
        
        do {
            let failedWeights = try viewContext.fetch(weightRequest)
            for weight in failedWeights {
                weight.syncRetryCount = 0
                weight.syncError = nil
                weight.needsSync = true
            }
            resetCount += failedWeights.count
        } catch {
            logger.error("重置失败体重同步任务失败: \(error.localizedDescription)")
        }
        
        // 重置周期记录
        let cycleRequest: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        cycleRequest.predicate = NSPredicate(format: "userId == %@ AND syncRetryCount >= 3", userId)
        
        do {
            let failedCycles = try viewContext.fetch(cycleRequest)
            for cycle in failedCycles {
                cycle.syncRetryCount = 0
                cycle.syncError = nil
                cycle.needsSync = true
            }
            resetCount += failedCycles.count
        } catch {
            logger.error("重置失败周期同步任务失败: \(error.localizedDescription)")
        }
        
        persistenceController.save()
        updatePendingSyncCount()
        
        logger.info("🔄 已重置 \(resetCount) 个失败的同步任务")
        return resetCount
    }
    
    /// P0 新增：强制清除本地数据并从服务器重新拉取
    /// 这是解决数据不一致的终极方案
    func forceResyncFromServer() {
        guard let userId = AuthService.shared.currentUserId else {
            logger.warning("⚠️ 无法强制同步：未登录")
            return
        }
        
        logger.info("🔄 开始强制从服务器重新同步所有数据...")
        
        // 1. 清除所有已同步的本地数据（保留未同步的数据）
        clearSyncedData(userId: userId)
        
        // 2. 刷新内存数据
        refreshLocalBirds()
        refreshLocalLogs()
        refreshLocalWeights()
        refreshLocalExpenses()
        refreshLocalCycles()
        refreshLocalShares()
        
        // 3. 发送通知让 UI 重新拉取服务器数据
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ForceRefreshFromServer"), object: nil)
        }
        
        logger.info("✅ 本地已同步数据已清除，请刷新页面从服务器重新获取")
    }
    
    /// 清除已同步的数据（保留未同步的本地数据）
    private func clearSyncedData(userId: String) {
        // 清除已同步的日志
        let logRequest: NSFetchRequest<LocalBirdLogEntity> = LocalBirdLogEntity.fetchRequest()
        logRequest.predicate = NSPredicate(format: "userId == %@ AND needsSync == NO", userId)
        
        do {
            let syncedLogs = try viewContext.fetch(logRequest)
            for log in syncedLogs {
                // 删除关联的本地图片
                if let localId = log.localId {
                    LogImageStorage.shared.deleteImages(for: localId)
                }
            }
            syncedLogs.forEach { viewContext.delete($0) }
            logger.info("🗑️ 清除 \(syncedLogs.count) 条已同步日志")
        } catch {
            logger.error("清除已同步日志失败: \(error.localizedDescription)")
        }
        
        // 清除已同步的体重记录
        let weightRequest: NSFetchRequest<LocalWeightRecordEntity> = LocalWeightRecordEntity.fetchRequest()
        weightRequest.predicate = NSPredicate(format: "userId == %@ AND needsSync == NO", userId)
        
        do {
            let syncedWeights = try viewContext.fetch(weightRequest)
            syncedWeights.forEach { viewContext.delete($0) }
            logger.info("🗑️ 清除 \(syncedWeights.count) 条已同步体重记录")
        } catch {
            logger.error("清除已同步体重记录失败: \(error.localizedDescription)")
        }
        
        // 清除已同步的周期记录
        let cycleRequest: NSFetchRequest<LocalCycleRecordEntity> = LocalCycleRecordEntity.fetchRequest()
        cycleRequest.predicate = NSPredicate(format: "userId == %@ AND needsSync == NO", userId)
        
        do {
            let syncedCycles = try viewContext.fetch(cycleRequest)
            syncedCycles.forEach { viewContext.delete($0) }
            logger.info("🗑️ 清除 \(syncedCycles.count) 条已同步周期记录")
        } catch {
            logger.error("清除已同步周期记录失败: \(error.localizedDescription)")
        }
        
        persistenceController.save()
    }
}

// MARK: - 本地数据模型

/// 本地鸟儿数据
struct LocalBird: Codable, Identifiable {
    var id: String { localId }
    var localId: String = UUID().uuidString
    var serverId: Int?
    var userId: String?                      // P1-01: 用户ID隔离
    
    var nickname: String
    var species: String
    var gender: String?
    var hatchDate: Date?
    var adoptionDate: Date?
    var birthdayType: String?                // 生日类型: HATCH 或 ADOPTION
    var deathDate: Date?                     // P0-01: 忌日
    var featherColor: String?
    var source: String?                      // 来源
    var avatarUrl: String?
    var notes: String?
    var medicalHistory: String?              // 医疗史
    var fatherInfo: String?                  // 父亲信息
    var motherInfo: String?                  // 母亲信息
    var legRingId: String?                   // 脚环ID
    
    // P2-01: 走失状态字段
    var isLost: Bool = false
    var lostDate: Date?
    var lostLocation: String?
    var lostPostId: Int64?                   // 关联的寻鸟帖子ID
    
    var needsSync: Bool = true
    var isDeleted: Bool = false              // P0-02: 是否已删除
    var deletedAt: Date?                     // P0-02: 删除时间
    var syncRetryCount: Int = 0              // P2-04: 同步重试次数
    var syncError: String?                   // P1: 同步错误信息
    var version: Int64 = 0                   // P0: 版本号（乐观锁）
    var cacheTimestamp: Date?                // P3-01: 缓存时间戳
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // P0: 离线头像上传支持
    var localAvatarPath: String?
    var imageUploadStatus: ImageUploadStatus = .none
    
    init(nickname: String, species: String, userId: String? = nil) {
        self.nickname = nickname
        self.species = species
        self.userId = userId ?? AuthService.shared.currentUserId
    }
    
    init(from entity: LocalBirdEntity) {
        self.localId = entity.localId ?? UUID().uuidString
        self.serverId = entity.serverId?.intValue
        self.userId = entity.userId
        self.nickname = entity.nickname ?? ""
        self.species = entity.species ?? ""
        self.gender = entity.gender
        self.hatchDate = entity.hatchDate
        self.adoptionDate = entity.adoptionDate
        self.birthdayType = entity.birthdayType
        self.deathDate = entity.deathDate
        self.featherColor = entity.featherColor
        self.source = entity.source
        self.avatarUrl = entity.avatarUrl
        self.notes = entity.notes
        self.medicalHistory = entity.medicalHistory
        self.fatherInfo = entity.fatherInfo
        self.motherInfo = entity.motherInfo
        self.legRingId = entity.legRingId
        self.isLost = entity.isLost
        self.lostDate = entity.lostDate
        self.lostLocation = entity.lostLocation
        self.lostPostId = entity.lostPostId?.int64Value
        self.needsSync = entity.needsSync
        self.isDeleted = entity.markedAsDeleted
        self.deletedAt = entity.deletedAt
        self.syncRetryCount = Int(entity.syncRetryCount)
        self.syncError = entity.syncError
        self.version = entity.version
        self.cacheTimestamp = entity.cacheTimestamp
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }
    
    init(from dto: BirdDTO) {
        self.localId = UUID().uuidString
        self.serverId = dto.id
        self.userId = AuthService.shared.currentUserId
        self.nickname = dto.nickname ?? ""
        self.species = dto.species ?? ""
        self.gender = dto.gender
        self.hatchDate = dto.hatchDate
        self.adoptionDate = dto.adoptionDate
        self.birthdayType = dto.birthdayType
        self.deathDate = dto.deathDate
        self.featherColor = dto.featherColor
        self.source = dto.source
        self.avatarUrl = dto.avatarUrl
        self.notes = dto.notes
        self.medicalHistory = dto.medicalHistory
        self.fatherInfo = dto.fatherInfo
        self.motherInfo = dto.motherInfo
        self.legRingId = dto.legRingId
        self.isLost = dto.isLost ?? false
        self.lostDate = dto.lostDate
        self.lostLocation = dto.lostLocation
        self.lostPostId = dto.lostPostId
        self.needsSync = false
        self.isDeleted = dto.isDeleted ?? false
        self.deletedAt = dto.deletedAt
        self.version = dto.version ?? 0   // P0: 从服务器读取版本号
        self.cacheTimestamp = Date()
    }
    
    func updateEntity(_ entity: LocalBirdEntity) {
        entity.localId = localId
        entity.serverId = serverId.map { NSNumber(value: $0) }
        entity.userId = userId
        entity.nickname = nickname
        entity.species = species
        entity.gender = gender
        entity.hatchDate = hatchDate
        entity.adoptionDate = adoptionDate
        entity.birthdayType = birthdayType
        entity.deathDate = deathDate
        entity.featherColor = featherColor
        entity.source = source
        entity.avatarUrl = avatarUrl
        entity.notes = notes
        entity.medicalHistory = medicalHistory
        entity.fatherInfo = fatherInfo
        entity.motherInfo = motherInfo
        entity.legRingId = legRingId
        entity.isLost = isLost
        entity.lostDate = lostDate
        entity.lostLocation = lostLocation
        entity.lostPostId = lostPostId.map { NSNumber(value: $0) }
        entity.needsSync = needsSync
        entity.markedAsDeleted = isDeleted
        entity.deletedAt = deletedAt
        entity.syncRetryCount = Int16(syncRetryCount)
        entity.syncError = syncError
        entity.version = version
        entity.cacheTimestamp = cacheTimestamp
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
    }
    
    func toBirdDTO() -> BirdDTO {
        var dto = BirdDTO()
        dto.id = serverId
        dto.nickname = nickname
        dto.species = species
        dto.gender = gender
        dto.hatchDate = hatchDate
        dto.adoptionDate = adoptionDate
        dto.birthdayType = birthdayType
        dto.deathDate = deathDate
        dto.featherColor = featherColor
        dto.source = source
        dto.avatarUrl = avatarUrl
        dto.notes = notes
        dto.medicalHistory = medicalHistory
        dto.fatherInfo = fatherInfo
        dto.motherInfo = motherInfo
        dto.legRingId = legRingId
        dto.isLost = isLost
        dto.lostDate = lostDate
        dto.lostLocation = lostLocation
        dto.lostPostId = lostPostId
        dto.isDeleted = isDeleted
        dto.deletedAt = deletedAt
        dto.version = version
        return dto
    }
}

// MARK: - 图片上传状态枚举
enum ImageUploadStatus: String, Codable {
    case none = "none"           // 无图片
    case pending = "pending"     // 待上传
    case uploading = "uploading" // 上传中
    case success = "success"     // 全部成功
    case partial = "partial"     // 部分成功
    case failed = "failed"       // 全部失败
}

/// 本地日志数据
struct LocalBirdLog: Codable, Identifiable {
    var id: String { localId }
    var localId: String = UUID().uuidString
    var serverId: Int?
    var birdLocalId: String
    
    var logDate: Date = Date()
    var content: String?
    var mood: String?
    var behavior: String?
    var healthScore: Int?
    var weight: Double?
    var feedAmount: Double?      // 喂食量
    var waterAmount: Double?     // 饮水量
    var temperature: Double?     // 环境温度
    var humidity: Double?        // 环境湿度
    var isCleaned: Bool?         // 是否清洁
    
    var needsSync: Bool = true
    var isDeleted: Bool = false
    var deletedAt: Date?                     // P0: 删除时间
    var syncRetryCount: Int = 0              // P1: 同步重试次数
    var syncError: String?                   // P1: 同步错误信息
    var version: Int64 = 0                   // P0: 版本号（乐观锁）
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // P0 新增：图片相关字段
    var localImagePaths: [String] = []       // 本地图片路径（Document 目录）
    var ossURLs: [String] = []               // OSS 已上传的 URL
    var imageUploadStatus: ImageUploadStatus = .none  // 图片上传状态
    var imageRetryCount: Int = 0             // 图片上传重试次数
    var lastImageUploadError: String?        // 最后一次上传错误
    
    init(birdLocalId: String, content: String?, mood: String? = nil) {
        self.birdLocalId = birdLocalId
        self.content = content
        self.mood = mood
    }
    
    init(from entity: LocalBirdLogEntity) {
        self.localId = entity.localId ?? UUID().uuidString
        self.serverId = entity.serverId?.intValue
        self.birdLocalId = entity.birdLocalId ?? ""
        self.logDate = entity.logDate ?? Date()
        self.content = entity.content
        self.mood = entity.mood
        self.behavior = entity.behavior
        self.healthScore = entity.healthScore?.intValue
        self.weight = entity.weight?.doubleValue
        self.needsSync = entity.needsSync
        self.isDeleted = entity.markedAsDeleted
        self.deletedAt = entity.deletedAt
        self.syncRetryCount = Int(entity.syncRetryCount)
        self.syncError = entity.syncError
        self.version = entity.version
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
        
        // P0 新增：读取图片字段
        if let pathsJson = entity.localImagePaths,
           let data = pathsJson.data(using: .utf8),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            self.localImagePaths = paths
        }
        if let urlsJson = entity.ossURLs,
           let data = urlsJson.data(using: .utf8),
           let urls = try? JSONDecoder().decode([String].self, from: data) {
            self.ossURLs = urls
        }
        if let statusRaw = entity.imageUploadStatus,
           let status = ImageUploadStatus(rawValue: statusRaw) {
            self.imageUploadStatus = status
        }
        self.imageRetryCount = Int(entity.imageRetryCount)
        self.lastImageUploadError = entity.lastImageUploadError
    }
    
    init(from dto: BirdLogDTO, birdLocalId: String) {
        self.localId = UUID().uuidString
        self.serverId = dto.id
        self.birdLocalId = birdLocalId
        self.logDate = dto.logDate ?? Date()
        self.content = dto.notes
        self.mood = dto.mood
        self.behavior = dto.behavior
        self.healthScore = dto.healthScore
        self.weight = dto.weight
        self.feedAmount = dto.feedAmount
        self.waterAmount = dto.waterAmount
        self.temperature = dto.temperature
        self.humidity = dto.humidity
        self.isCleaned = dto.isCleaned
        self.needsSync = false
        
        // 从服务器同步的日志，图片已经在 OSS
        if let urls = dto.imageUrls, !urls.isEmpty {
            self.ossURLs = urls
            self.imageUploadStatus = .success
        }
    }
    
    func updateEntity(_ entity: LocalBirdLogEntity) {
        entity.localId = localId
        entity.serverId = serverId.map { NSNumber(value: $0) }
        entity.birdLocalId = birdLocalId
        entity.logDate = logDate
        entity.content = content
        entity.mood = mood
        entity.behavior = behavior
        entity.healthScore = healthScore.map { NSNumber(value: $0) }
        entity.weight = weight.map { NSNumber(value: $0) }
        entity.needsSync = needsSync
        entity.markedAsDeleted = isDeleted
        entity.deletedAt = deletedAt
        entity.syncRetryCount = Int16(syncRetryCount)
        entity.syncError = syncError
        entity.version = version
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        
        // P0 新增：保存图片字段
        if let data = try? JSONEncoder().encode(localImagePaths) {
            entity.localImagePaths = String(data: data, encoding: .utf8)
        }
        if let data = try? JSONEncoder().encode(ossURLs) {
            entity.ossURLs = String(data: data, encoding: .utf8)
        }
        entity.imageUploadStatus = imageUploadStatus.rawValue
        entity.imageRetryCount = Int16(imageRetryCount)
        entity.lastImageUploadError = lastImageUploadError
    }
}

/// 本地体重记录
struct LocalWeightRecord: Codable, Identifiable {
    var id: String { localId }
    var localId: String = UUID().uuidString
    var serverId: Int?
    var birdLocalId: String
    
    var weight: Double
    var recordDate: Date = Date()
    
    var needsSync: Bool = true
    var isDeleted: Bool = false
    var deletedAt: Date?                     // P0: 删除时间
    var syncRetryCount: Int = 0              // P1: 同步重试次数
    var syncError: String?                   // P1: 同步错误信息
    var version: Int64 = 0                   // P0: 版本号（乐观锁）
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(birdLocalId: String, weight: Double, recordDate: Date = Date()) {
        self.birdLocalId = birdLocalId
        self.weight = weight
        self.recordDate = recordDate
    }
    
    init(from entity: LocalWeightRecordEntity) {
        self.localId = entity.localId ?? UUID().uuidString
        self.serverId = entity.serverId?.intValue
        self.birdLocalId = entity.birdLocalId ?? ""
        self.weight = entity.weight
        self.recordDate = entity.recordDate ?? Date()
        self.needsSync = entity.needsSync
        self.isDeleted = entity.markedAsDeleted
        self.deletedAt = entity.deletedAt
        self.syncRetryCount = Int(entity.syncRetryCount)
        self.syncError = entity.syncError
        self.version = entity.version
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }
    
    init(from dto: WeightRecordDTO, birdLocalId: String) {
        self.localId = UUID().uuidString
        self.serverId = dto.id
        self.birdLocalId = birdLocalId
        self.weight = dto.weight ?? 0
        self.recordDate = dto.recordDate ?? Date()
        self.needsSync = false
    }
    
    func updateEntity(_ entity: LocalWeightRecordEntity) {
        entity.localId = localId
        entity.serverId = serverId.map { NSNumber(value: $0) }
        entity.birdLocalId = birdLocalId
        entity.weight = weight
        entity.recordDate = recordDate
        entity.needsSync = needsSync
        entity.markedAsDeleted = isDeleted
        entity.deletedAt = deletedAt
        entity.syncRetryCount = Int16(syncRetryCount)
        entity.syncError = syncError
        entity.version = version
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
    }
}

// MARK: - DTO扩展

struct BirdLogDTO: Codable {
    var id: Int?
    var logDate: Date?
    var weight: Double?
    var feedAmount: Double?      // 喂食量
    var waterAmount: Double?     // 饮水量
    var mood: String?
    var behavior: String?
    var notes: String?
    var healthScore: Int?
    var temperature: Double?     // 环境温度
    var humidity: Double?        // 环境湿度
    var isCleaned: Bool?
    var imageUrls: [String]?     // 日志图片URL列表
    var createdAt: Date?
}

struct WeightRecordDTO: Codable {
    var id: Int?
    var weight: Double?
    var recordDate: Date?
    var createdAt: Date?
}

// MARK: - 本地支出数据

/// 本地支出记录
struct LocalExpense: Codable, Identifiable {
    var id: String { localId }
    var localId: String = UUID().uuidString
    var serverId: Int?
    var userId: String?                      // P1-01: 用户ID隔离
    
    var title: String
    var amount: Double
    var category: String
    var expenseDate: Date
    var birdId: Int?
    var birdName: String?
    var note: String?
    
    var needsSync: Bool = true
    var isDeleted: Bool = false
    var syncRetryCount: Int = 0              // P2-01: 同步重试次数
    var createdAt: Date = Date()
    var updatedAt: Date = Date()             // P2-01: 更新时间戳
    
    init(title: String, amount: Double, category: String, expenseDate: Date, birdId: Int? = nil, birdName: String? = nil, note: String? = nil) {
        self.title = title
        self.amount = amount
        self.category = category
        self.expenseDate = expenseDate
        self.birdId = birdId
        self.birdName = birdName
        self.note = note
        self.userId = AuthService.shared.currentUserId
    }
    
    init(from entity: LocalExpenseEntity) {
        self.localId = entity.localId ?? UUID().uuidString
        self.serverId = entity.serverId?.intValue
        self.userId = entity.userId
        self.title = entity.title ?? ""
        self.amount = entity.amount
        self.category = entity.category ?? "other"
        self.expenseDate = entity.expenseDate ?? Date()
        self.birdId = entity.birdId?.intValue
        self.birdName = entity.birdName
        self.note = entity.note
        self.needsSync = entity.needsSync
        self.isDeleted = entity.markedAsDeleted
        self.syncRetryCount = Int(entity.syncRetryCount)
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }
    
    init(from dto: ExpenseDTO) {
        self.localId = UUID().uuidString
        self.serverId = dto.id
        self.userId = AuthService.shared.currentUserId
        self.title = dto.title
        self.amount = dto.amount
        self.category = dto.category
        self.expenseDate = dto.expenseDate
        self.birdId = dto.birdId
        self.birdName = dto.birdName
        self.note = dto.note
        self.needsSync = false
        self.updatedAt = Date()
    }
    
    func updateEntity(_ entity: LocalExpenseEntity) {
        entity.localId = localId
        entity.serverId = serverId.map { NSNumber(value: $0) }
        entity.userId = userId
        entity.title = title
        entity.amount = amount
        entity.category = category
        entity.expenseDate = expenseDate
        entity.birdId = birdId.map { NSNumber(value: $0) }
        entity.birdName = birdName
        entity.note = note
        entity.needsSync = needsSync
        entity.markedAsDeleted = isDeleted
        entity.syncRetryCount = Int16(syncRetryCount)
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
    }
}

/// 支出 DTO
struct ExpenseDTO: Codable {
    var id: Int?
    var title: String
    var amount: Double
    var category: String
    var expenseDate: Date
    var birdId: Int?
    var birdName: String?
    var note: String?
    var createdAt: Date?
}

// MARK: - 生理周期离线记录

/// 本地生理周期记录
struct LocalCycleRecord: Codable, Identifiable {
    var id: String { localId }
    var localId: String = UUID().uuidString
    var serverId: Int?
    var birdLocalId: String
    
    var cycleType: String  // MOLTING, EGG_LAYING, BREEDING
    var startDate: Date
    var endDate: Date?
    var notes: String?
    var eggCount: Int?
    var hatchedCount: Int?
    var speciesName: String?          // 关联品种名称
    var nextPredictedDate: Date?      // 预测下次周期日期
    var syncStatus: SyncStatus = .pending  // 同步状态
    
    var needsSync: Bool = true
    var isDeleted: Bool = false
    var createdAt: Date = Date()
    
    init(birdLocalId: String, cycleType: CycleType, startDate: Date, speciesName: String? = nil) {
        self.birdLocalId = birdLocalId
        self.cycleType = cycleType.rawValue
        self.startDate = startDate
        self.speciesName = speciesName
    }
    
    init(from entity: LocalCycleRecordEntity) {
        self.localId = entity.localId ?? UUID().uuidString
        self.serverId = entity.serverId?.intValue
        self.birdLocalId = entity.birdLocalId ?? ""
        self.cycleType = entity.cycleType ?? "MOLTING"
        self.startDate = entity.startDate ?? Date()
        self.endDate = entity.endDate
        self.notes = entity.notes
        self.eggCount = entity.eggCount?.intValue
        self.hatchedCount = entity.hatchedCount?.intValue
        self.speciesName = entity.speciesName
        self.nextPredictedDate = entity.nextPredictedDate
        self.syncStatus = SyncStatus(rawValue: entity.syncStatus) ?? .pending
        self.needsSync = entity.needsSync
        self.isDeleted = entity.markedAsDeleted
        self.createdAt = entity.createdAt ?? Date()
    }
    
    init(from serverRecord: BirdCycleRecord, birdLocalId: String, speciesName: String? = nil) {
        self.localId = UUID().uuidString
        self.serverId = Int(serverRecord.id)
        self.birdLocalId = birdLocalId
        self.cycleType = serverRecord.cycleType.rawValue
        self.startDate = serverRecord.startDate
        self.endDate = serverRecord.endDate
        self.notes = serverRecord.notes
        self.eggCount = serverRecord.eggCount
        self.hatchedCount = serverRecord.hatchedCount
        self.speciesName = speciesName
        self.syncStatus = .synced
        self.needsSync = false
    }
    
    func updateEntity(_ entity: LocalCycleRecordEntity) {
        entity.localId = localId
        entity.serverId = serverId.map { NSNumber(value: $0) }
        entity.birdLocalId = birdLocalId
        entity.cycleType = cycleType
        entity.startDate = startDate
        entity.endDate = endDate
        entity.notes = notes
        entity.eggCount = eggCount.map { NSNumber(value: $0) }
        entity.hatchedCount = hatchedCount.map { NSNumber(value: $0) }
        entity.speciesName = speciesName
        entity.nextPredictedDate = nextPredictedDate
        entity.syncStatus = syncStatus.rawValue
        entity.needsSync = needsSync
        entity.markedAsDeleted = isDeleted
        entity.createdAt = createdAt
    }
    
    /// 转换为 BirdCycleRecord（用于 UI 展示）
    func toBirdCycleRecord() -> BirdCycleRecord {
        return BirdCycleRecord(
            id: Int64(serverId ?? 0),
            birdId: 0,
            cycleType: CycleType(rawValue: cycleType) ?? .BATHING,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            eggCount: eggCount,
            hatchedCount: hatchedCount
        )
    }
}

// MARK: - P2-01: 本地共享记录

/// 本地共享关系数据（用于缓存共享鸟到双方本地）
struct LocalBirdShare: Codable, Identifiable {
    var id: String { localId }
    var localId: String = UUID().uuidString
    var serverId: Int64?
    var birdId: Int64
    var birdLocalId: String?
    var ownerId: Int64
    var ownerName: String?
    var sharedUserId: Int64
    var sharedUserName: String?
    var role: String = "VIEWER"  // OWNER or VIEWER
    var status: String = "PENDING"  // PENDING, ACCEPTED, REJECTED
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(birdId: Int64, ownerId: Int64, sharedUserId: Int64, role: String = "VIEWER") {
        self.birdId = birdId
        self.ownerId = ownerId
        self.sharedUserId = sharedUserId
        self.role = role
    }
    
    init(from entity: LocalBirdShareEntity) {
        self.localId = entity.localId ?? UUID().uuidString
        self.serverId = entity.serverId?.int64Value
        self.birdId = entity.birdId
        self.birdLocalId = entity.birdLocalId
        self.ownerId = entity.ownerId
        self.ownerName = entity.ownerName
        self.sharedUserId = entity.sharedUserId
        self.sharedUserName = entity.sharedUserName
        self.role = entity.role ?? "VIEWER"
        self.status = entity.status ?? "PENDING"
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }
    
    init(from coOwner: BirdCoOwner, birdId: Int64, ownerId: Int64) {
        self.localId = UUID().uuidString
        self.serverId = coOwner.id
        self.birdId = birdId
        self.ownerId = ownerId
        self.sharedUserId = coOwner.userId
        self.sharedUserName = coOwner.nickname
        self.role = coOwner.role.rawValue
        self.status = "ACCEPTED"
        self.createdAt = coOwner.sharedAt ?? Date()
        self.updatedAt = Date()
    }
    
    func updateEntity(_ entity: LocalBirdShareEntity) {
        entity.localId = localId
        entity.serverId = serverId.map { NSNumber(value: $0) }
        entity.birdId = birdId
        entity.birdLocalId = birdLocalId
        entity.ownerId = ownerId
        entity.ownerName = ownerName
        entity.sharedUserId = sharedUserId
        entity.sharedUserName = sharedUserName
        entity.role = role
        entity.status = status
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
    }
}

