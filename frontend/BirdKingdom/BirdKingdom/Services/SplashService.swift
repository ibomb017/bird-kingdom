import SwiftUI
import Combine

/// 开屏庆生服务
class SplashService: ObservableObject {
    static let shared = SplashService()
    
    @Published var quotas: [String: QuotaInfo] = [:]
    @Published var orders: [SplashOrderInfo] = []
    @Published var isLoading = false
    @Published var currentPrice: Double = 9.9  // P2修复：价格从API动态获取
    
    private let baseURL = AppConfig.apiBaseURL
    
    private init() {}
    
    // MARK: - 数据模型
    
    struct QuotaInfo: Codable {
        let totalQuota: Int
        let usedQuota: Int
        let availableQuota: Int
        let price: Double?
        
        // 兼容性属性，便于访问
        var total: Int { totalQuota }
        var available: Int { availableQuota }
    }
    
    struct SplashOrderInfo: Codable, Identifiable {
        let orderId: Int64
        let displayDate: String
        let amount: Double
        let status: String
        let imageUrl: String?
        let createdAt: String
        let reviewStatus: String?
        let reviewReason: String?
        
        // Identifiable 协议要求
        var id: Int64 { orderId }
    }
    
    struct ReserveResponse: Codable, Identifiable, Hashable {
        let orderId: Int64
        let slotId: Int64?
        let displayDate: String
        let amount: Double
        let expireAt: String?
        let status: String?
        
        // ✅ 用于sheet(item:)绑定
        var id: Int64 { orderId }
    }
    
    struct UploadTokenResponse: Codable {
        let uploadUrl: String
        let ossKey: String
    }
    
    struct SplashImage: Codable {
        let imageUrl: String  // 后端字段名是 imageUrl
        let userId: Int64
        
        // 兼容性属性
        var url: String { imageUrl }
    }
    
    struct LaunchConfig: Codable {
        let hasSplash: Bool
        let splashImages: [SplashImage]  // 后端字段名是 splashImages
        
        // 兼容性属性
        var images: [SplashImage] { splashImages }
    }
    
    // MARK: - API 调用
    
    /// 获取名额信息
    func fetchQuotas(startDate: Date, endDate: Date) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        
        let url = URL(string: "\(baseURL)/splash/quotas?startDate=\(startStr)&endDate=\(endStr)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let data: [String: QuotaInfo]?
            let message: String?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code == 0, let quotaData = response.data {
            await MainActor.run {
                self.quotas = quotaData
                // P2修复：从API更新当前价格
                if let firstPrice = quotaData.values.compactMap({ $0.price }).first {
                    self.currentPrice = firstPrice
                }
            }
        }
    }
    
    /// 预占名额
    func reserveSlot(displayDate: Date) async throws -> ReserveResponse {
        // P3 修复：使用完整的 ISO8601 格式（后端使用 .iso8601 解码器）
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        isoFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let dateStr = isoFormatter.string(from: displayDate)
        
        let url = URL(string: "\(baseURL)/splash/reserve")!
        print("🎯 Splash Reserve URL: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🎯 Token found: \(String(token.prefix(20)))...")
        } else {
            print("❌ No token found!")
        }
        
        let body = ["displayDate": dateStr]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let data: ReserveResponse?
            let message: String?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code == 0, let reserveData = response.data {
            return reserveData
        } else {
            throw NSError(domain: "SplashService", code: response.code, 
                          userInfo: [NSLocalizedDescriptionKey: response.message ?? "预约失败"])
        }
    }
    
    /// 获取上传凭证
    func getUploadToken(orderId: Int64, fileName: String) async throws -> UploadTokenResponse {
        let url = URL(string: "\(baseURL)/splash/upload-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = ["orderId": orderId, "fileName": fileName]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let data: UploadTokenResponse?
            let message: String?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code == 0, let tokenData = response.data {
            return tokenData
        } else {
            throw NSError(domain: "SplashService", code: response.code,
                          userInfo: [NSLocalizedDescriptionKey: response.message ?? "获取上传凭证失败"])
        }
    }
    
    /// 确认上传
    func confirmUpload(orderId: Int64, ossKey: String) async throws {
        let url = URL(string: "\(baseURL)/splash/confirm-upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = ["orderId": orderId, "ossKey": ossKey]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let message: String?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "SplashService", code: response.code,
                          userInfo: [NSLocalizedDescriptionKey: response.message ?? "确认上传失败"])
        }
    }
    
    /// 获取启动配置
    func getLaunchConfig() async throws -> LaunchConfig {
        let url = URL(string: "\(baseURL)/app/launch-config")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5 // 5秒超时（增加容错）
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            struct Response: Codable {
                let code: Int
                let data: LaunchConfig?
            }
            
            let response = try JSONDecoder().decode(Response.self, from: data)
            
            if response.code == 0, let config = response.data {
                print("✅ 获取启动配置成功: hasSplash=\(config.hasSplash), images=\(config.images.count)")
                return config
            } else {
                return LaunchConfig(hasSplash: false, splashImages: [])
            }
        } catch {
            // 网络错误时静默失败，不影响App启动
            print("⚠️ 获取启动配置失败（静默处理）: \(error.localizedDescription)")
            return LaunchConfig(hasSplash: false, splashImages: [])
        }
    }
    
    /// 获取我的订单
    func fetchOrders() async throws {
        let url = URL(string: "\(baseURL)/splash/orders")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let data: [SplashOrderInfo]?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code == 0, let orderData = response.data {
            await MainActor.run {
                self.orders = orderData
            }
        }
    }
    
    /// 取消待付款订单（PENDING 状态，释放名额）
    func cancelOrder(orderId: Int64) async throws {
        let url = URL(string: "\(baseURL)/splash/orders/\(orderId)/cancel")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let message: String?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code == 0 {
            await MainActor.run {
                self.orders.removeAll { $0.id == orderId }
            }
        } else {
            throw NSError(domain: "SplashService", code: response.code,
                          userInfo: [NSLocalizedDescriptionKey: response.message ?? "取消失败"])
        }
    }
    
    /// 删除历史订单（终态订单：CANCELLED/EXPIRED/REFUNDED/PAID）
    func deleteOrder(orderId: Int64) async throws {
        let url = URL(string: "\(baseURL)/splash/orders/\(orderId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let message: String?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code == 0 {
            await MainActor.run {
                self.orders.removeAll { $0.id == orderId }
            }
        } else {
            throw NSError(domain: "SplashService", code: response.code,
                          userInfo: [NSLocalizedDescriptionKey: response.message ?? "删除失败"])
        }
    }
    
    /// 处理支付 - 使用 Apple In-App Purchase
    /// 支付成功后调用后端回调接口确认订单状态
    @MainActor
    func processPayment(orderId: Int64) async throws {
        // 调用 Apple 内购
        let productId = "com.birdkingdom.splash.birthday"
        
        let purchaseResult: StoreManager.PurchaseResult
        do {
            purchaseResult = try await StoreManager.shared.purchase(productId: productId)
        } catch StoreError.productNotFound {
            throw NSError(domain: "SplashService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "无法加载商品信息，请确保网络连接正常后重试。\n\n如果问题持续，请联系客服：birdkingdom@163.com"])
        } catch StoreError.userCancelled {
            throw NSError(domain: "SplashService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "支付已取消"])
        } catch StoreError.verificationFailed {
            throw NSError(domain: "SplashService", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "支付验证失败，请联系客服：birdkingdom@163.com"])
        } catch StoreError.purchaseFailed {
            throw NSError(domain: "SplashService", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "支付处理中，请稍后在「我的订单」中查看结果"])
        }
        
        // 支付成功后，调用后端回调接口确认订单（带重试机制）
        var retryCount = 0
        var lastError: Error?
        while retryCount < 3 {
            do {
                let url = URL(string: "\(baseURL)/splash/payment-callback")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                if let token = AuthService.shared.getToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let body: [String: Any] = [
                    "orderId": orderId,
                    "paymentId": purchaseResult.originalTransactionId,
                    "paymentMethod": "APPLE_IAP",
                    "productId": purchaseResult.productId,
                    "purchaseDate": purchaseResult.purchaseDate  // Int64 毫秒时间戳
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                struct Response: Codable {
                    let code: Int
                    let message: String?
                }
                
                let response = try JSONDecoder().decode(Response.self, from: data)
                
                if response.code == 0 {
                    print("✅ 开屏庆生支付成功: orderId=\(orderId), transactionId=\(purchaseResult.originalTransactionId)")
                    return
                } else {
                    lastError = NSError(domain: "SplashService", code: response.code,
                                        userInfo: [NSLocalizedDescriptionKey: response.message ?? "订单确认失败"])
                }
            } catch {
                lastError = error
            }
            retryCount += 1
            if retryCount < 3 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        // 3次重试都失败，保存待同步记录
        savePendingSplashPayment(orderId: orderId, purchaseResult: purchaseResult)
        let errorMsg = lastError?.localizedDescription ?? "服务器确认失败"
        throw NSError(domain: "SplashService", code: -5,
                      userInfo: [NSLocalizedDescriptionKey: "支付已完成，但服务器确认失败：\(errorMsg)。\n\n请放心，您的支付记录已保存，下次打开App时将自动同步。"])
    }
    
    /// 保存待同步的开屏支付记录（用于后端确认失败时补偿）
    private func savePendingSplashPayment(orderId: Int64, purchaseResult: StoreManager.PurchaseResult) {
        let pendingPayment: [String: Any] = [
            "orderId": orderId,
            "originalTransactionId": purchaseResult.originalTransactionId,
            "productId": purchaseResult.productId,
            "purchaseDate": purchaseResult.purchaseDate,
            "timestamp": Date().timeIntervalSince1970
        ]
        var pendingList = UserDefaults.standard.array(forKey: "pendingSplashPayments") as? [[String: Any]] ?? []
        pendingList.append(pendingPayment)
        UserDefaults.standard.set(pendingList, forKey: "pendingSplashPayments")
        print("📦 保存待同步开屏支付: orderId=\(orderId)")
    }
    
    // MARK: - ✅ P0修复：Pending Payment 重试机制
    
    /// 重试所有待同步的支付记录
    /// 应在 App 启动时调用此方法
    func retryPendingPayments() async {
        var pendingList = UserDefaults.standard.array(forKey: "pendingSplashPayments") as? [[String: Any]] ?? []
        
        guard !pendingList.isEmpty else { return }
        
        print("🔄 检测到 \(pendingList.count) 个待同步支付，开始重试...")
        
        var successfulIds: Set<Int64> = []
        
        for payment in pendingList {
            // ✅ 修复：支持 Int64 和 String 两种类型的 orderId
            let orderId: Int64
            if let id = payment["orderId"] as? Int64 {
                orderId = id
            } else if let id = payment["orderId"] as? Int {
                orderId = Int64(id)
            } else {
                continue
            }
            
            guard let transactionId = payment["originalTransactionId"] as? String,
                  let productId = payment["productId"] as? String else {
                continue
            }
            
            // ✅ 修复：purchaseDate 可能是 Int64（毫秒时间戳）或 String
            let purchaseDateMs: Int64
            if let dateMs = payment["purchaseDate"] as? Int64 {
                purchaseDateMs = dateMs
            } else if let dateMs = payment["purchaseDate"] as? Int {
                purchaseDateMs = Int64(dateMs)
            } else if let dateStr = payment["purchaseDate"] as? String, let dateMs = Int64(dateStr) {
                purchaseDateMs = dateMs
            } else {
                // 如果无法解析购买日期，使用当前时间戳
                purchaseDateMs = Int64(Date().timeIntervalSince1970 * 1000)
            }
            
            do {
                try await retryPaymentCallback(
                    orderId: orderId,
                    paymentId: transactionId,
                    productId: productId,
                    purchaseDate: purchaseDateMs
                )
                successfulIds.insert(orderId)
                print("✅ 重试成功: orderId=\(orderId)")
            } catch {
                print("⚠️ 重试失败: orderId=\(orderId), error=\(error.localizedDescription)")
                // 保留失败的记录，下次继续重试
            }
        }
        
        // 移除成功的记录
        if !successfulIds.isEmpty {
            pendingList.removeAll { payment in
                if let orderId = payment["orderId"] as? Int64 {
                    return successfulIds.contains(orderId)
                } else if let orderId = payment["orderId"] as? Int {
                    return successfulIds.contains(Int64(orderId))
                }
                return false
            }
            UserDefaults.standard.set(pendingList, forKey: "pendingSplashPayments")
            print("✅ 已移除 \(successfulIds.count) 个已同步的支付记录")
        }
    }
    
    /// 重试单个支付回调（purchaseDate 使用 Int64 毫秒时间戳）
    private func retryPaymentCallback(orderId: Int64, paymentId: String, productId: String, purchaseDate: Int64) async throws {
        let url = URL(string: "\(baseURL)/splash/payment-callback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "orderId": orderId,
            "paymentId": paymentId,
            "paymentMethod": "APPLE_IAP",
            "productId": productId,
            "purchaseDate": purchaseDate  // Int64 毫秒时间戳
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let message: String?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "SplashService", code: response.code,
                          userInfo: [NSLocalizedDescriptionKey: response.message ?? "重试失败"])
        }
    }
    
    /// 检查是否有待同步的支付（用于UI提示）
    func hasPendingPayments() -> Bool {
        let pendingList = UserDefaults.standard.array(forKey: "pendingSplashPayments") as? [[String: Any]] ?? []
        return !pendingList.isEmpty
    }
    
    /// 清除所有待同步记录（仅用于调试）
    func clearPendingPayments() {
        UserDefaults.standard.removeObject(forKey: "pendingSplashPayments")
        print("🗑️ 已清除所有待同步支付记录")
    }
    
    /// 测试模式支付（仅用于开发调试）
    /// ⚠️ 正式上线时请勿使用此方法
    func processPaymentForTesting(orderId: Int64) async throws {
        #if DEBUG
        let url = URL(string: "\(baseURL)/splash/payment-callback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // ✅ 添加 Authorization 头以支持用户归属校验
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "orderId": orderId,
            "paymentId": "DEV_\(Date().timeIntervalSince1970)",
            "paymentMethod": "DEV_TEST"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct Response: Codable {
            let code: Int
            let message: String?
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        if response.code != 0 {
            throw NSError(domain: "SplashService", code: response.code,
                          userInfo: [NSLocalizedDescriptionKey: response.message ?? "支付失败"])
        }
        #else
        throw NSError(domain: "SplashService", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "测试支付仅在DEBUG模式可用"])
        #endif
    }
}
