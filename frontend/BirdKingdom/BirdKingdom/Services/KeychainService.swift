import Foundation
import Security

// MARK: - Keychain安全存储服务
// #1 FIX: 统一 Keychain 实现，KeychainService 作为 KeychainHelper 的高级接口
// KeychainHelper (AuthService.swift) 处理底层 Data 存储
// KeychainService 提供便捷的 String / 类型安全接口
class KeychainService {
    static let shared = KeychainService()
    
    // 使用与 KeychainHelper 相同的 serviceName，确保数据一致性
    private let serviceName = "com.birdkingdom.app"
    
    private init() {}
    
    // MARK: - 存储字符串数据
    func save(key: String, data: String) -> Bool {
        guard let data = data.data(using: .utf8) else { return false }
        return saveData(data, forKey: key)
    }
    
    // MARK: - 读取字符串数据
    func load(key: String) -> String? {
        guard let data = loadData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - 删除数据
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - 检查是否存在
    func exists(key: String) -> Bool {
        return load(key: key) != nil
    }
    
    // MARK: - 存储 Data 类型（统一底层实现）
    func save(_ data: Data, forKey key: String) {
        saveData(data, forKey: key)
    }
    
    // MARK: - 读取 Data 类型
    func load(forKey key: String) -> Data? {
        return loadData(forKey: key)
    }
    
    // MARK: - Private: 统一的底层实现
    @discardableResult
    private func saveData(_ data: Data, forKey key: String) -> Bool {
        // 先删除已存在的数据，确保原子性
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // 与 KeychainHelper 保持一致
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ KeychainService 保存成功: \(key)")
            return true
        } else {
            print("⚠️ KeychainService 保存失败: \(key), 错误码: \(status)")
            return false
        }
    }
    
    private func loadData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            return nil
        }
    }
}

// MARK: - Keychain Keys（集中管理所有 Keychain key）
extension KeychainService {
    struct Keys {
        // AI 服务相关
        static let doubaoAPIKey = "doubao_api_key"
        
        // #2 FIX: 区分 Access Token 和 Refresh Token
        static let accessToken = "com.birdkingdom.access_token"
        static let refreshToken = "com.birdkingdom.refresh_token"
        
        // 旧版 Token key（兼容迁移）
        static let userToken = "user_auth_token"
        static let legacyAuthToken = "com.birdkingdom.auth_token"
    }
}
