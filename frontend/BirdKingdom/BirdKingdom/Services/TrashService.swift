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
    
    private let userDefaultsKey = "deleted_birds"
    
    private init() {
        loadDeletedBirds()
        cleanExpiredBirds()
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
    
    // 永久删除
    func permanentlyDelete(_ deletedBird: DeletedBird) {
        deletedBirds.removeAll { $0.id == deletedBird.id }
        saveDeletedBirds()
    }
    
    // 清空回收站
    func emptyTrash() {
        deletedBirds.removeAll()
        saveDeletedBirds()
    }
    
    // 清理过期的鸟儿
    private func cleanExpiredBirds() {
        deletedBirds.removeAll { $0.isExpired }
        saveDeletedBirds()
    }
    
    // 保存到本地
    private func saveDeletedBirds() {
        if let data = try? JSONEncoder().encode(deletedBirds) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    // 从本地加载
    private func loadDeletedBirds() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let birds = try? JSONDecoder().decode([DeletedBird].self, from: data) {
            deletedBirds = birds
        }
    }
}
