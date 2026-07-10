import Foundation
import CoreData
import Combine
import os.log

private let logger = Logger(subsystem: "com.birdkingdom", category: "SpeciesData")

/// 同步状态枚举
enum SyncStatus: Int16, Codable {
    case pending = 1      // 未同步
    case syncing = 2      // 同步中
    case synced = 3       // 同步成功
    case failed = 4       // 同步失败
}

/// 品种数据服务 - 从后端加载品种数据并缓存到本地
class SpeciesDataService: ObservableObject {
    static let shared = SpeciesDataService()
    
    private let persistenceController = PersistenceController.shared
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    
    private let cacheKey = "speciesLastSyncTime"
    private let cacheValidDuration: TimeInterval = 24 * 60 * 60  // 缓存有效期24小时
    
    // 重举修复 #9: 内存缓存用于存储品种体重范围，避免 View 重建时丢失
    private var weightRangeCache: [String: (min: Double, max: Double)] = [:]
    
    private init() {
        // 读取上次同步时间
        if let timestamp = UserDefaults.standard.object(forKey: cacheKey) as? Date {
            lastSyncTime = timestamp
        }
        // 启动时异步从服务器同步品种数据
        Task {
            await syncFromServerIfNeeded()
        }
    }
    
    // MARK: - 从服务器同步数据
    
    /// 检查是否需要从服务器同步（缓存过期或首次启动）
    func syncFromServerIfNeeded() async {
        // 如果缓存有效，不需要同步
        if let lastSync = lastSyncTime, Date().timeIntervalSince(lastSync) < cacheValidDuration {
            logger.info("✅ 品种缓存有效，跳过同步")
            return
        }
        
        await syncFromServer()
    }
    
    /// 强制从服务器同步品种数据
    func syncFromServer() async {
        await MainActor.run { isLoading = true }
        
        do {
            let categories = try await ApiService.shared.getSpecies()
            
            // 清空旧数据
            await clearLocalCache()
            
            // 保存新数据到本地
            await MainActor.run {
                for category in categories {
                    for species in category.species {
                        let entity = ParrotSpeciesEntity(context: viewContext)
                        entity.serverId = Int32(species.id)
                        entity.category = category.name
                        entity.name = species.name
                        entity.weightMin = species.weightMin
                        entity.weightMax = species.weightMax
                        
                        // 设置生理周期数据（从后端获取）
                        if let moltingDurationMin = species.moltingDurationMin {
                            entity.moltingDurationMin = NSNumber(value: Int16(moltingDurationMin))
                        }
                        if let moltingDurationMax = species.moltingDurationMax {
                            entity.moltingDurationMax = NSNumber(value: Int16(moltingDurationMax))
                        }
                        if let moltingCycleMin = species.moltingCycleMin {
                            entity.moltingCycleMin = NSNumber(value: Int16(moltingCycleMin))
                        }
                        if let moltingCycleMax = species.moltingCycleMax {
                            entity.moltingCycleMax = NSNumber(value: Int16(moltingCycleMax))
                        }
                        if let incubation = species.incubationDays {
                            entity.incubationDaysMin = NSNumber(value: Int16(incubation))
                            entity.incubationDaysMax = NSNumber(value: Int16(incubation + 4))
                        }
                        if let clutchMin = species.clutchSizeMin {
                            entity.clutchSizeMin = NSNumber(value: Int16(clutchMin))
                        }
                        if let clutchMax = species.clutchSizeMax {
                            entity.clutchSizeMax = NSNumber(value: Int16(clutchMax))
                        }
                        if let estrusCycleMin = species.estrusCycleMin {
                            entity.estrusCycleMin = NSNumber(value: Int16(estrusCycleMin))
                        }
                        if let estrusCycleMax = species.estrusCycleMax {
                            entity.estrusCycleMax = NSNumber(value: Int16(estrusCycleMax))
                        }
                        
                        entity.isLayingEggsAvailable = true
                        entity.lastUpdated = Date()
                    }
                }
                
                persistenceController.save()
                lastSyncTime = Date()
                UserDefaults.standard.set(lastSyncTime, forKey: cacheKey)
                isLoading = false
                
                let totalCount = categories.reduce(0) { $0 + $1.species.count }
                logger.info("✅ 从服务器同步品种数据完成，共\(totalCount)个品种")
            }
        } catch {
            await MainActor.run { isLoading = false }
            logger.error("❌ 从服务器同步品种数据失败: \(error.localizedDescription)")
        }
    }
    
    /// 清空本地缓存
    private func clearLocalCache() async {
        await MainActor.run {
            let request: NSFetchRequest<NSFetchRequestResult> = ParrotSpeciesEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try viewContext.execute(deleteRequest)
                try viewContext.save()
                logger.debug("🗑️ 已清空本地品种缓存")
            } catch {
                logger.error("清空本地缓存失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 查询方法
    
    /// 根据品种名称获取数据（优先本地缓存）
    func getSpeciesByName(_ name: String) -> ParrotSpeciesEntity? {
        let request: NSFetchRequest<ParrotSpeciesEntity> = ParrotSpeciesEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            logger.error("查询品种数据失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 获取品种体重范围（支持模糊匹配）
    func getWeightRange(for speciesName: String) -> (min: Double, max: Double)? {
        // 精确匹配
        if let species = getSpeciesByName(speciesName) {
            return (min: species.weightMin, max: species.weightMax)
        }
        
        // 模糊匹配：查找包含关键词的品种
        let request: NSFetchRequest<ParrotSpeciesEntity> = ParrotSpeciesEntity.fetchRequest()
        do {
            let allSpecies = try viewContext.fetch(request)
            // 先查找 species名称包含数据库中的关键词
            for entity in allSpecies {
                if let name = entity.name {
                    if speciesName.contains(name) || name.contains(speciesName) {
                        return (min: entity.weightMin, max: entity.weightMax)
                    }
                }
            }
            // 查找分类匹配
            for entity in allSpecies {
                if let category = entity.category {
                    if speciesName.contains(category) {
                        return (min: entity.weightMin, max: entity.weightMax)
                    }
                }
            }
        } catch {
            logger.error("模糊查询品种数据失败: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - 重举修复 #9: 内存缓存访问方法
    
    /// 获取内存缓存中的体重范围
    func getCachedWeightRange(for species: String) -> (min: Double, max: Double)? {
        return weightRangeCache[species]
    }
    
    /// 设置内存缓存中的体重范围
    func setCachedWeightRange(for species: String, min: Double, max: Double) {
        weightRangeCache[species] = (min: min, max: max)
    }
    
    /// 获取换羽周期参考值
    func getMoltingCycleRange(for speciesName: String) -> (min: Int, max: Int)? {
        guard let species = getSpeciesByName(speciesName) else { return nil }
        guard let min = species.moltingCycleMin, let max = species.moltingCycleMax else { return nil }
        return (min: Int(min.int16Value), max: Int(max.int16Value))
    }
    
    /// 获取换羽持续时间参考值
    func getMoltingDurationRange(for speciesName: String) -> (min: Int, max: Int)? {
        guard let species = getSpeciesByName(speciesName) else { return nil }
        guard let min = species.moltingDurationMin, let max = species.moltingDurationMax else { return nil }
        return (min: Int(min.int16Value), max: Int(max.int16Value))
    }
    
    /// 获取孵化天数参考值
    func getIncubationDaysRange(for speciesName: String) -> (min: Int, max: Int)? {
        guard let species = getSpeciesByName(speciesName) else { return nil }
        guard let min = species.incubationDaysMin, let max = species.incubationDaysMax else { return nil }
        return (min: Int(min.int16Value), max: Int(max.int16Value))
    }
    
    /// 获取发情周期参考值
    func getEstrusCycleRange(for speciesName: String) -> (min: Int, max: Int)? {
        guard let species = getSpeciesByName(speciesName) else { return nil }
        guard let min = species.estrusCycleMin, let max = species.estrusCycleMax else { return nil }
        return (min: Int(min.int16Value), max: Int(max.int16Value))
    }
    
    /// 获取所有品种（按分类分组）
    func getAllSpeciesGrouped() -> [String: [ParrotSpeciesEntity]] {
        let request: NSFetchRequest<ParrotSpeciesEntity> = ParrotSpeciesEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ParrotSpeciesEntity.category, ascending: true),
            NSSortDescriptor(keyPath: \ParrotSpeciesEntity.name, ascending: true)
        ]
        
        do {
            let results = try viewContext.fetch(request)
            return Dictionary(grouping: results) { $0.category ?? "其他" }
        } catch {
            logger.error("获取品种列表失败: \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// 获取所有品种名称列表
    func getAllSpeciesNames() -> [String] {
        let request: NSFetchRequest<ParrotSpeciesEntity> = ParrotSpeciesEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ParrotSpeciesEntity.name, ascending: true)]
        
        do {
            return try viewContext.fetch(request).compactMap { $0.name }
        } catch {
            logger.error("获取品种名称列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 从服务器更新缓存
    
    /// 从服务器数据更新本地缓存
    func updateFromServer(_ serverSpecies: BirdSpecies) {
        let request: NSFetchRequest<ParrotSpeciesEntity> = ParrotSpeciesEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", serverSpecies.name)
        
        do {
            let results = try viewContext.fetch(request)
            let entity = results.first ?? ParrotSpeciesEntity(context: viewContext)
            
            entity.serverId = Int32(serverSpecies.id)
            entity.category = serverSpecies.category
            entity.name = serverSpecies.name
            entity.weightMin = serverSpecies.weightMin
            entity.weightMax = serverSpecies.weightMax
            entity.lastUpdated = Date()
            
            persistenceController.save()
            logger.debug("更新品种缓存: \(serverSpecies.name)")
        } catch {
            logger.error("更新品种缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// 批量更新品种数据
    func batchUpdateFromServer(_ serverSpeciesList: [BirdSpecies]) {
        for species in serverSpeciesList {
            updateFromServer(species)
        }
        logger.info("批量更新品种缓存完成: \(serverSpeciesList.count)个")
    }
}
