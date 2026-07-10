import Foundation

/// 首页日志合并服务
/// 统一处理服务器日志与本地离线日志的合并逻辑
/// 供 BirdListView、AllLogsView 等多个视图共用
class HomeLogService {
    static let shared = HomeLogService()
    
    private init() {}
    
    // MARK: - 日志合并
    
    /// 将本地未同步的日志转换为 BirdLog 格式并与服务器日志合并
    /// - Parameters:
    ///   - serverLogs: 从服务器获取的日志列表
    ///   - serverBirds: 从服务器获取的鸟儿列表
    ///   - localLogs: 本地离线日志列表
    ///   - localBirds: 本地离线鸟儿列表 (LocalBird 类型)
    /// - Returns: 合并后的日志列表（按时间降序排序）
    func mergeLogsWithLocalData(
        serverLogs: [BirdLog],
        serverBirds: [Bird],
        localLogs: [LocalBirdLog],
        localBirds: [LocalBird]
    ) -> [BirdLog] {
        var allLogs: [BirdLog] = []
        
        // P0 关键修复：记录服务器日志的 ID，用于去重避免本地缓存重复
        var serverLogIds = Set<Int64>()
        
        // DEBUG: 打印输入数据
        print("🔍 HomeLogService.mergeLogsWithLocalData 调用:")
        print("   - serverLogs 数量: \(serverLogs.count)")
        print("   - serverBirds 数量: \(serverBirds.count)")
        print("   - localLogs 数量: \(localLogs.count)")
        print("   - localBirds 数量: \(localBirds.count)")
        
        if !serverBirds.isEmpty {
            print("   - serverBirds 详情: \(serverBirds.map { "ID=\($0.id), name=\($0.nickname)" })")
        }
        if !localBirds.isEmpty {
            print("   - localBirds 详情: \(localBirds.map { "localId=\($0.localId), serverId=\(String(describing: $0.serverId)), name=\($0.nickname)" })")
        }
        
        // 1. 处理服务器日志：
        //    - 服务器返回的日志已经包含正确的 birdName（后端动态填充）
        //    - 只有当 birdName 是 "未知鸟儿" 时才尝试本地匹配
        for var log in serverLogs {
            serverLogIds.insert(log.id)  // 记录 ID 用于去重
            
            // 只有当 birdName 是默认值时才尝试匹配
            if log.birdName == "未知鸟儿" {
                // 尝试从 serverBirds 匹配
                if let bird = serverBirds.first(where: { $0.id == log.birdId }) {
                    log.birdName = bird.nickname
                    print("   🔄 服务器日志校准鸟名(from serverBirds): logId=\(log.id), birdName=\(log.birdName)")
                } 
                // 尝试从 localBirds 匹配
                else if let localBird = localBirds.first(where: { $0.serverId == Int(log.birdId) }) {
                    log.birdName = localBird.nickname
                    print("   🔄 服务器日志校准鸟名(from localBirds): logId=\(log.id), birdName=\(log.birdName)")
                }
            }
            allLogs.append(log)
        }
        
        // 2. 将本地未同步的日志转换为 BirdLog 格式
        //    P0 关键修复：排除已经在服务器日志中的（通过 serverId 判断）
        let unsyncedLogs = localLogs.filter { log in
            // 只处理需要同步的、未删除的日志
            guard log.needsSync && !log.isDeleted else { return false }
            
            // P0 关键去重：如果这条本地日志已有 serverId 且存在于服务器日志中，跳过
            if let serverId = log.serverId, serverLogIds.contains(Int64(serverId)) {
                return false
            }
            
            return true
        }
        print("   - 需要合并的未同步日志数量: \(unsyncedLogs.count)")
        
        for localLog in unsyncedLogs {
            print("   📝 处理本地日志: localId=\(localLog.localId), birdLocalId=\(localLog.birdLocalId)")
            if let convertedLog = convertLocalLogToBirdLog(
                localLog: localLog,
                serverBirds: serverBirds,
                localBirds: localBirds
            ) {
                print("   ✅ 转换成功: birdName=\(convertedLog.birdName), birdId=\(convertedLog.birdId)")
                allLogs.append(convertedLog)
            } else {
                print("   ❌ 转换失败!")
            }
        }
        
        // 3. 按时间降序排序
        return allLogs.sorted { $0.logDate > $1.logDate }
    }
    
    /// 将单个本地日志转换为 BirdLog
    /// - Returns: 转换后的 BirdLog，如果无法匹配到鸟则返回 nil（跳过脏数据）
    func convertLocalLogToBirdLog(
        localLog: LocalBirdLog,
        serverBirds: [Bird],
        localBirds: [LocalBird]
    ) -> BirdLog? {
        var birdName: String = "未知鸟儿"
        var resolvedBirdId: Int64 = 0
        var foundMatch = false
        
        // 策略1: 检查是否是 "server_{id}" 格式（新日志对已同步鸟使用这种格式）
        if localLog.birdLocalId.hasPrefix("server_"),
           let idString = localLog.birdLocalId.components(separatedBy: "server_").last,
           let serverId = Int64(idString) {
            resolvedBirdId = serverId
            if let bird = serverBirds.first(where: { $0.id == serverId }) {
                birdName = bird.nickname
                foundMatch = true
            } else {
                // 服务器鸟列表没有，尝试从本地鸟列表获取
                if let localBird = localBirds.first(where: { $0.serverId == Int(serverId) }) {
                    birdName = localBird.nickname
                    foundMatch = true
                }
            }
        }

        // 策略2: 尝试匹配本地鸟的 localId（离线创建的鸟）
        else if let localBird = localBirds.first(where: { $0.localId == localLog.birdLocalId }) {
            birdName = localBird.nickname
            if let serverId = localBird.serverId {
                resolvedBirdId = Int64(serverId)
            } else {
                // 使用稳定的负数 ID 表示本地鸟（基于 localId 哈希）
                let hashValue = Int64(truncatingIfNeeded: localBird.localId.hashValue)
                resolvedBirdId = hashValue < 0 ? hashValue : -abs(hashValue)
            }
            foundMatch = true
        }
        // 策略3: 尝试直接解析为数字并匹配服务器鸟（兼容旧数据）
        else if let directId = Int64(localLog.birdLocalId),
                let bird = serverBirds.first(where: { $0.id == directId }) {
            birdName = bird.nickname
            resolvedBirdId = directId
            foundMatch = true
        }
        // 策略4: 尝试直接解析为数字并匹配本地鸟（通过 serverId）
        else if let directId = Int64(localLog.birdLocalId),
                let localBird = localBirds.first(where: { $0.serverId == Int(directId) }) {
            birdName = localBird.nickname
            resolvedBirdId = directId
            foundMatch = true
        }
        // 策略5: 尝试直接解析为数字（鸟可能已被删除，但ID有效）
        else if let directId = Int64(localLog.birdLocalId) {
            resolvedBirdId = directId
            foundMatch = true
        }
        
        // P0 关键修复：即使没匹配到鸟，也绝不能丢弃用户的日志！
        // 只打印警告，保留数据
        if !foundMatch && birdName == "未知鸟儿" {
            print("⚠️ HomeLogService: 未匹配到鸟信息，但保留日志显示: birdLocalId=\(localLog.birdLocalId), localId=\(localLog.localId)")
        }
        
        // 如果找到了匹配但 resolvedBirdId 还是 0，使用哈希值作为临时 ID
        if resolvedBirdId == 0 {
            let hashValue = Int64(truncatingIfNeeded: localLog.birdLocalId.hashValue)
            resolvedBirdId = hashValue < 0 ? hashValue : -abs(hashValue)
        }
        
        // 创建 BirdLog 用于显示
        // 使用负数 ID 标识本地日志，避免与服务器 ID 冲突
        let localIdHash = Int64(truncatingIfNeeded: localLog.localId.hashValue)
        let negativeId = localIdHash < 0 ? localIdHash : -abs(localIdHash)
        
        return BirdLog(
            id: negativeId,
            birdId: resolvedBirdId,
            birdName: birdName,
            logDate: localLog.logDate,
            weight: localLog.weight,
            feedAmount: nil,
            waterAmount: nil,
            mood: localLog.mood,
            behavior: localLog.behavior,
            isMolting: nil,
            isBreeding: nil,
            temperature: nil,
            humidity: nil,
            isCleaned: nil,
            healthScore: localLog.healthScore,
            notes: appendSyncMarker(localLog.content),
            createdAt: localLog.createdAt,
            imageUrls: localLog.ossURLs.isEmpty ? nil : localLog.ossURLs
        )
    }
    
    // MARK: - 日志过滤
    
    /// 按鸟ID过滤日志
    /// - Parameters:
    ///   - logs: 日志列表
    ///   - birdId: 鸟ID，nil表示不过滤
    /// - Returns: 过滤后的日志列表
    func filterLogs(_ logs: [BirdLog], byBirdId birdId: Int64?) -> [BirdLog] {
        guard let birdId = birdId else { return logs }
        return logs.filter { $0.birdId == birdId }
    }
    
    /// 按日期分组日志
    /// - Parameter logs: 日志列表
    /// - Returns: 按日期分组的字典
    func groupLogsByDate(_ logs: [BirdLog]) -> [String: [BirdLog]] {
        // P0 日期偏移修复：使用 DateFormatters 工具类，确保使用中国时区
        return Dictionary(grouping: logs) { log in
            DateFormatters.dateLabel(for: log.logDate)
        }
    }
    
    // MARK: - 辅助方法
    
    /// 添加待同步标记
    private func appendSyncMarker(_ content: String?) -> String {
        guard let content = content, !content.isEmpty else { return "📤 待同步" }
        return content + " 📤"
    }
    
    /// 判断日志是否为本地未同步日志
    func isLocalLog(_ log: BirdLog) -> Bool {
        return log.id < 0
    }
    
    /// 根据显示用的 log.id 查找对应的本地日志
    func findLocalLog(byDisplayId displayId: Int64, in localLogs: [LocalBirdLog]) -> LocalBirdLog? {
        return localLogs.first { localLog in
            let localIdHash = Int64(truncatingIfNeeded: localLog.localId.hashValue)
            let negativeId = localIdHash < 0 ? localIdHash : -abs(localIdHash)
            return negativeId == displayId
        }
    }
}
