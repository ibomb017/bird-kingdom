import Foundation
import Combine

// MARK: - 已删除的鸟儿模型
struct DeletedBird: Codable, Identifiable {
    let id: Int64
    let nickname: String
    let species: String
    let gender: String?
    let birthDate: Date?
    let featherColor: String?
    let source: String?
    let deletedAt: Date
    
    // 计算剩余天数
    var remainingDays: Int {
        let calendar = Calendar.current
        let expirationDate = calendar.date(byAdding: .day, value: 7, to: deletedAt) ?? deletedAt
        let days = calendar.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, days)
    }
    
    // 是否已过期
    var isExpired: Bool {
        remainingDays <= 0
    }
}

// MARK: - 回收站服务
class TrashService: ObservableObject {
    static let shared = TrashService()
    
    @Published var deletedBirds: [DeletedBird] = []
    @Published var isLoading = false
    
    private let userDefaultsKey = "deleted_birds"
    
    private init() {
        loadDeletedBirds()
        cleanExpiredBirds()
    }
    
    // 从服务器加载已删除的鸟儿
    func loadFromServer() async {
        guard let userId = AuthService.shared.currentUser?.id else {
            print("🗑️ 未登录，无法加载回收站")
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let birds = try await ApiService.shared.getDeletedBirds(userId: userId)
            print("🗑️ 从服务器加载了 \(birds.count) 只已删除的鸟儿")
            
            // 转换为 DeletedBird 模型
            let deletedBirdsList = birds.map { bird in
                DeletedBird(
                    id: bird.id,
                    nickname: bird.nickname,
                    species: bird.species,
                    gender: bird.gender,
                    birthDate: bird.hatchDate ?? bird.adoptionDate,
                    featherColor: bird.featherColor,
                    source: bird.source,
                    deletedAt: bird.deletedAt ?? Date()
                )
            }
            
            await MainActor.run {
                self.deletedBirds = deletedBirdsList
                self.isLoading = false
                self.saveDeletedBirds()
            }
        } catch {
            print("❌ 加载回收站失败: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // 添加删除的鸟儿到回收站
    func addDeletedBird(_ bird: Bird) {
        let deletedBird = DeletedBird(
            id: bird.id,
            nickname: bird.nickname,
            species: bird.species,
            gender: bird.gender,
            birthDate: bird.hatchDate ?? bird.adoptionDate,
            featherColor: bird.featherColor,
            source: bird.source,
            deletedAt: Date()
        )
        
        deletedBirds.insert(deletedBird, at: 0)
        saveDeletedBirds()
    }
    
    // 从回收站恢复鸟儿（仅VIP）
    func restoreBird(_ deletedBird: DeletedBird) async throws -> Bird {
        // 调用API恢复
        let restoredBird = try await ApiService.shared.restoreBird(id: deletedBird.id)
        
        // 从回收站移除
        await MainActor.run {
            deletedBirds.removeAll { $0.id == deletedBird.id }
            saveDeletedBirds()
        }
        
        return restoredBird
    }
    
    // 永久删除（调用后端API）
    func permanentlyDelete(_ deletedBird: DeletedBird) {
        Task {
            do {
                // 调用后端永久删除接口
                try await ApiService.shared.permanentDeleteBird(id: deletedBird.id)
                await MainActor.run {
                    deletedBirds.removeAll { $0.id == deletedBird.id }
                    saveDeletedBirds()
                }
            } catch {
                print("永久删除失败: \(error)")
                // 即使后端失败，也从本地移除
                await MainActor.run {
                    deletedBirds.removeAll { $0.id == deletedBird.id }
                    saveDeletedBirds()
                }
            }
        }
    }
    
    // 永久删除（异步版本）
    func permanentlyDeleteAsync(_ deletedBird: DeletedBird) async throws {
        try await ApiService.shared.permanentDeleteBird(id: deletedBird.id)
        await MainActor.run {
            deletedBirds.removeAll { $0.id == deletedBird.id }
            saveDeletedBirds()
        }
    }
    
    // 清空回收站（调用后端API逐个删除）
    func emptyTrash() {
        Task {
            for bird in deletedBirds {
                do {
                    try await ApiService.shared.permanentDeleteBird(id: bird.id)
                } catch {
                    print("永久删除 \(bird.nickname) 失败: \(error)")
                }
            }
            await MainActor.run {
                deletedBirds.removeAll()
                saveDeletedBirds()
            }
        }
    }
    
    // 清除所有数据（退出登录时调用）
    func clearAllData() {
        deletedBirds.removeAll()
        KeychainHelper.shared.delete(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)  // 兼容清理旧数据
        print("🗑️ 已清除回收站数据")
    }
    
    // 清理过期的鸟儿
    private func cleanExpiredBirds() {
        deletedBirds.removeAll { $0.isExpired }
        saveDeletedBirds()
    }
    
    // 保存到本地（加密存储）
    private func saveDeletedBirds() {
        if let data = try? JSONEncoder().encode(deletedBirds) {
            // 使用 Keychain 加密存储（更安全）
            KeychainHelper.shared.save(data, forKey: userDefaultsKey)
        }
    }
    
    // 从本地加载（加密存储）
    private func loadDeletedBirds() {
        // 优先从 Keychain 加载
        if let data = KeychainHelper.shared.read(forKey: userDefaultsKey),
           let birds = try? JSONDecoder().decode([DeletedBird].self, from: data) {
            deletedBirds = birds
        } else if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
                  let birds = try? JSONDecoder().decode([DeletedBird].self, from: data) {
            // 兼容旧数据：从 UserDefaults 迁移到 Keychain
            deletedBirds = birds
            saveDeletedBirds()  // 迁移到 Keychain
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)  // 清除旧数据
        }
    }
}
