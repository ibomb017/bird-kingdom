//
//  PersistenceController.swift
//  BirdKingdom
//
//  Core Data 持久化控制器
//

import CoreData
import Combine
import os.log

private let logger = Logger(subsystem: "com.birdkingdom", category: "CoreData")

/// Core Data 持久化控制器
/// 管理 Core Data 栈，提供主上下文和后台上下文
class PersistenceController: ObservableObject {
    
    // MARK: - 单例
    static let shared = PersistenceController()
    
    // MARK: - Preview 实例（用于 SwiftUI 预览）
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // 创建一些预览数据
        let bird = LocalBirdEntity(context: viewContext)
        bird.localId = UUID().uuidString
        bird.nickname = "小绿"
        bird.species = "虎皮鹦鹉"
        bird.gender = "male"
        bird.needsSync = false
        bird.markedAsDeleted = false
        bird.createdAt = Date()
        bird.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            logger.error("Preview 数据保存失败: \(error.localizedDescription)")
        }
        
        return controller
    }()
    
    // MARK: - Core Data 容器
    let container: NSPersistentContainer
    
    /// 主上下文（主线程使用）
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    // MARK: - 初始化
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BirdKingdom")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // P0 修复：启用自动轻量迁移，防止 App 更新后数据库加载失败
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                logger.error("❌ Core Data 加载失败: \(error), \(error.userInfo)")
                
                // 尝试删除损坏的数据库并重新创建
                if let storeURL = description.url {
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        logger.info("🔄 已删除损坏的数据库，将重新创建")
                        
                        // 重新加载
                        self.container.loadPersistentStores { _, retryError in
                            if let retryError = retryError {
                                logger.error("❌ 重新加载 Core Data 仍然失败: \(retryError.localizedDescription)")
                            } else {
                                logger.info("✅ Core Data 重新加载成功")
                            }
                        }
                    } catch {
                        logger.error("❌ 删除损坏数据库失败: \(error.localizedDescription)")
                    }
                }
            } else {
                logger.info("✅ Core Data 加载成功: \(description.url?.absoluteString ?? "unknown")")
            }
        }
        
        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // 设置回滚策略
        container.viewContext.undoManager = nil
    }
    
    // MARK: - 后台上下文
    
    /// 创建新的后台上下文（用于后台任务）
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// 在后台执行任务
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
    
    // MARK: - 保存
    
    /// 保存主上下文
    func save() {
        let context = container.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            logger.debug("💾 Core Data 保存成功")
        } catch {
            logger.error("❌ Core Data 保存失败: \(error.localizedDescription)")
            // 回滚更改
            context.rollback()
        }
    }
    
    /// 保存指定上下文
    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            logger.debug("💾 Core Data 上下文保存成功")
        } catch {
            logger.error("❌ Core Data 上下文保存失败: \(error.localizedDescription)")
            context.rollback()
        }
    }
    
    // MARK: - 便捷查询方法
    
    /// 查询所有实体
    func fetchAll<T: NSManagedObject>(_ type: T.Type) -> [T] {
        let request = T.fetchRequest()
        do {
            return try viewContext.fetch(request) as? [T] ?? []
        } catch {
            logger.error("查询失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 按条件查询
    func fetch<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [T] {
        let request = T.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        do {
            return try viewContext.fetch(request) as? [T] ?? []
        } catch {
            logger.error("查询失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 删除所有实体数据
    /// 重举修复 #8: NSBatchDeleteRequest 直接操作 SQLite，不会更新 viewContext 中的 managed objects
    /// 必须在删除后 reset context 以避免访问陈旧对象导致崩溃
    func deleteAll<T: NSManagedObject>(_ type: T.Type) {
        let request = T.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        // 配置返回受影响的对象 IDs 以便合并变更
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try container.persistentStoreCoordinator.execute(batchDeleteRequest, with: viewContext) as? NSBatchDeleteResult
            
            // 将删除的对象 IDs 合并到 viewContext
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
            
            logger.info("🗑️ 批量删除成功: \(String(describing: type))")
        } catch {
            logger.error("批量删除失败: \(error.localizedDescription)")
        }
    }
    
    /// 清空所有数据
    /// 重举修复 #8: 批量删除后完全重置 viewContext，确保 UI 不会访问陈旧对象
    func clearAllData() {
        deleteAll(LocalBirdEntity.self)
        deleteAll(LocalBirdLogEntity.self)
        deleteAll(LocalWeightRecordEntity.self)
        deleteAll(LocalExpenseEntity.self)
        deleteAll(LocalCycleRecordEntity.self)
        deleteAll(LocalBirdShareEntity.self)
        
        // 重举修复 #8: 完全重置 viewContext，确保所有 managed objects 被释放
        viewContext.reset()
        
        logger.info("🗑️ 已清空所有 Core Data 数据")
    }
}
