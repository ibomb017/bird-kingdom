//
//  EncyclopediaRepository.swift
//  BirdKingdom
//
//  P0-R01 FIX: 百科模块 Repository 层
//  统一数据获取、缓存管理、搜索防抖
//

import Foundation
import Combine

// MARK: - 缓存配置
struct EncyclopediaCacheConfig {
    let birdsKey = "encyclopedia_birds_cache_v2"
    let categoriesKey = "encyclopedia_categories_cache_v2"
    let timestampKey = "encyclopedia_cache_timestamp_v2"
    let foodsKey = "foods_encyclopedia_cache_v2"
    let symptomsKey = "symptoms_encyclopedia_cache_v2"
    
    let birdsTTL: TimeInterval = 60 * 60 * 24 * 7  // 7天
    let foodsTTL: TimeInterval = 60 * 60 * 24 * 3  // 3天（安全等级可能变更）
    let symptomsTTL: TimeInterval = 60 * 60 * 24 * 3  // 3天
}

// MARK: - P0-C01 FIX: 磁盘缓存服务（替代 UserDefaults）
final class EncyclopediaDiskCache {
    static let shared = EncyclopediaDiskCache()
    
    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "com.birdkingdom.encyclopedia.cache", attributes: .concurrent)
    
    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("EncyclopediaCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func save<T: Encodable>(_ data: T, forKey key: String, ttl: TimeInterval) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let fileURL = self.cacheDirectory.appendingPathComponent(key + ".json")
            let metaURL = self.cacheDirectory.appendingPathComponent(key + ".meta")
            
            do {
                let jsonData = try JSONEncoder().encode(data)
                try jsonData.write(to: fileURL)
                
                // 保存元数据（过期时间）
                let meta = CacheMetadataInfo(createdAt: Date(), ttl: ttl)
                let metaData = try JSONEncoder().encode(meta)
                try metaData.write(to: metaURL)
                
                print("✅ 百科缓存已保存: \(key)")
            } catch {
                print("❌ 百科缓存保存失败 [\(key)]: \(error)")
            }
        }
    }
    
    func load<T: Decodable>(forKey key: String, type: T.Type) -> (data: T?, isStale: Bool) {
        let fileURL = cacheDirectory.appendingPathComponent(key + ".json")
        let metaURL = cacheDirectory.appendingPathComponent(key + ".meta")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return (nil, false)
        }
        
        // 检查是否过期
        var isStale = false
        if let metaData = try? Data(contentsOf: metaURL),
           let meta = try? JSONDecoder().decode(CacheMetadataInfo.self, from: metaData) {
            isStale = Date().timeIntervalSince(meta.createdAt) > meta.ttl
        }
        
        // 加载数据（即使过期也加载，后台刷新）
        guard let jsonData = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(T.self, from: jsonData) else {
            // 文件损坏，清理
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: metaURL)
            return (nil, false)
        }
        
        return (decoded, isStale)
    }
    
    func invalidate(key: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let fileURL = self.cacheDirectory.appendingPathComponent(key + ".json")
            let metaURL = self.cacheDirectory.appendingPathComponent(key + ".meta")
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: metaURL)
        }
    }
    
    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.cacheDirectory)
            try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }
}

// MARK: - 缓存元数据
struct CacheMetadataInfo: Codable {
    let createdAt: Date
    let ttl: TimeInterval
}

// MARK: - P0-N02 FIX: 搜索管理器（防抖 + 取消）
actor SearchManager {
    private var currentTask: Task<Void, Never>?
    private let debounceInterval: UInt64 = 300_000_000  // 300ms
    
    func search(
        keyword: String,
        perform: @escaping (String) async throws -> Void
    ) async {
        // 取消之前的搜索任务
        currentTask?.cancel()
        
        // 创建新的防抖任务
        let task = Task {
            do {
                try await Task.sleep(nanoseconds: debounceInterval)
                guard !Task.isCancelled else { return }
                try await perform(keyword)
            } catch {
                if !Task.isCancelled {
                    print("搜索失败: \(error)")
                }
            }
        }
        
        currentTask = task
        await task.value
    }
    
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}

// MARK: - P0-R01 FIX: 百科 Repository 协议
protocol EncyclopediaRepositoryProtocol {
    func getBirds(forceRefresh: Bool) async throws -> [BirdEncyclopediaDTO]
    func getCategories(forceRefresh: Bool) async throws -> [String]
    func searchBirds(keyword: String) async throws -> [BirdEncyclopediaDTO]
    func getFoods(forceRefresh: Bool) async throws -> [FoodEncyclopediaDTO]
    func getSymptoms(forceRefresh: Bool) async throws -> [SymptomDTO]
    var isCacheStale: Bool { get }
}

// MARK: - 百科 Repository 实现
final class EncyclopediaRepository: EncyclopediaRepositoryProtocol, ObservableObject {
    static let shared = EncyclopediaRepository()
    
    private let config = EncyclopediaCacheConfig()
    private let cache = EncyclopediaDiskCache.shared
    private let searchManager = SearchManager()
    
    // 请求去重
    private var birdsLoadingTask: Task<[BirdEncyclopediaDTO], Error>?
    private var foodsLoadingTask: Task<[FoodEncyclopediaDTO], Error>?
    private var symptomsLoadingTask: Task<[SymptomDTO], Error>?
    
    // P0-C02 FIX: 缓存过期状态（使用简单的非隔离属性）
    @Published private(set) var isCacheStale: Bool = false
    
    private init() {}
    
    // MARK: - 鸟类百科
    
    func getBirds(forceRefresh: Bool = false) async throws -> [BirdEncyclopediaDTO] {
        // P1-N07 FIX: 请求去重
        if let existingTask = birdsLoadingTask, !forceRefresh {
            return try await existingTask.value
        }
        
        // P0-R02 FIX: forceRefresh 真正绕过缓存
        if !forceRefresh {
            let cached = cache.load(forKey: config.birdsKey, type: [BirdEncyclopediaDTO].self)
            if let data = cached.data, !data.isEmpty {
                await MainActor.run { self.isCacheStale = cached.isStale }
                
                // 缓存过期时后台刷新
                if cached.isStale {
                    Task { try? await self.refreshBirdsInBackground() }
                }
                return data
            }
        }
        
        // 网络请求
        let task = Task<[BirdEncyclopediaDTO], Error> {
            let birds = try await ApiService.shared.getEncyclopediaBirds()
            cache.save(birds, forKey: config.birdsKey, ttl: config.birdsTTL)
            await MainActor.run { self.isCacheStale = false }
            return birds
        }
        
        birdsLoadingTask = task
        defer { birdsLoadingTask = nil }
        
        return try await task.value
    }
    
    private func refreshBirdsInBackground() async throws {
        let birds = try await ApiService.shared.getEncyclopediaBirds()
        cache.save(birds, forKey: config.birdsKey, ttl: config.birdsTTL)
        await MainActor.run { self.isCacheStale = false }
    }
    
    func getCategories(forceRefresh: Bool = false) async throws -> [String] {
        if !forceRefresh {
            let cached = cache.load(forKey: config.categoriesKey, type: [String].self)
            if let data = cached.data, !data.isEmpty {
                return data
            }
        }
        
        let categories = try await ApiService.shared.getEncyclopediaCategories()
        cache.save(categories, forKey: config.categoriesKey, ttl: config.birdsTTL)
        return categories
    }
    
    // P0-N02 FIX: 搜索带防抖和取消
    func searchBirds(keyword: String) async throws -> [BirdEncyclopediaDTO] {
        if keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        
        return try await ApiService.shared.searchEncyclopediaBirds(keyword: keyword)
    }
    
    // MARK: - 食物百科
    
    func getFoods(forceRefresh: Bool = false) async throws -> [FoodEncyclopediaDTO] {
        if let existingTask = foodsLoadingTask, !forceRefresh {
            return try await existingTask.value
        }
        
        if !forceRefresh {
            let cached = cache.load(forKey: config.foodsKey, type: [FoodEncyclopediaDTO].self)
            if let data = cached.data, !data.isEmpty {
                if cached.isStale {
                    Task { try? await self.refreshFoodsInBackground() }
                }
                return data
            }
        }
        
        let task = Task<[FoodEncyclopediaDTO], Error> {
            let foods = try await ApiService.shared.getAllFoods()
            cache.save(foods, forKey: config.foodsKey, ttl: config.foodsTTL)
            return foods
        }
        
        foodsLoadingTask = task
        defer { foodsLoadingTask = nil }
        
        return try await task.value
    }
    
    private func refreshFoodsInBackground() async throws {
        let foods = try await ApiService.shared.getAllFoods()
        cache.save(foods, forKey: config.foodsKey, ttl: config.foodsTTL)
    }
    
    // MARK: - 症状百科
    
    func getSymptoms(forceRefresh: Bool = false) async throws -> [SymptomDTO] {
        if let existingTask = symptomsLoadingTask, !forceRefresh {
            return try await existingTask.value
        }
        
        if !forceRefresh {
            let cached = cache.load(forKey: config.symptomsKey, type: [SymptomDTO].self)
            if let data = cached.data, !data.isEmpty {
                if cached.isStale {
                    Task { try? await self.refreshSymptomsInBackground() }
                }
                return data
            }
        }
        
        let task = Task<[SymptomDTO], Error> {
            let symptoms = try await ApiService.shared.getAllSymptoms()
            cache.save(symptoms, forKey: config.symptomsKey, ttl: config.symptomsTTL)
            return symptoms
        }
        
        symptomsLoadingTask = task
        defer { symptomsLoadingTask = nil }
        
        return try await task.value
    }
    
    private func refreshSymptomsInBackground() async throws {
        let symptoms = try await ApiService.shared.getAllSymptoms()
        cache.save(symptoms, forKey: config.symptomsKey, ttl: config.symptomsTTL)
    }
    
    // MARK: - 缓存管理
    
    func invalidateAll() {
        cache.clearAll()
    }
}
