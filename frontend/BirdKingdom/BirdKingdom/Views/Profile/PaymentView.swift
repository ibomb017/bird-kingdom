import SwiftUI
import StoreKit
import Combine

// MARK: - 支付页面（Apple 内购）
struct PaymentView: View {
    let plan: VipPlan
    let onPaymentSuccess: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreManager.shared
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var primaryColor: Color { themeManager.primaryColor }
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    
    var body: some View {
        NavigationStack {
            
            ScrollView {
                VStack(spacing: 24) {
                    // 订单信息
                    orderInfoSection
                    
                    // Apple 内购说明
                    applePayInfoSection
                    
                    // 支付按钮
                    paymentButton
                    
                    // 说明
                    notesSection
                }
                .padding(20)
            }
            .themedBackground()
            .themedNavigationBar(title: NSLocalizedString("确认支付", comment: ""))
        }
        .alert(NSLocalizedString("支付成功", comment: ""), isPresented: $showSuccess) {
                Button(NSLocalizedString("确定", comment: "")) {
                    onPaymentSuccess()
                    dismiss()
                }
            } message: {
                Text("恭喜您成为\(plan.name)！")
            }
            .alert(NSLocalizedString("支付失败", comment: ""), isPresented: $showError) {
                Button(NSLocalizedString("确定", comment: "")) {}
            } message: {
                Text(errorMessage)
            }
    }
    
    // 订单信息
    private var orderInfoSection: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("订单信息", comment: ""))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                orderRow(title: NSLocalizedString("商品", comment: ""), value: plan.name)
                Divider().padding(.leading, 16)
                orderRow(title: NSLocalizedString("价格", comment: ""), value: "¥\(plan.price)")
                
                if let originalPrice = plan.originalPrice {
                    Divider().padding(.leading, 16)
                    orderRow(title: NSLocalizedString("原价", comment: ""), value: "¥\(originalPrice)", strikethrough: true)
                    Divider().padding(.leading, 16)
                    orderRow(title: NSLocalizedString("优惠", comment: ""), value: "-¥\(originalPrice - plan.price)", color: .red)
                }
            }
            .background(Color.adaptiveCard)
            .cornerRadius(12)
            
            // 实付金额
            HStack {
                Text(NSLocalizedString("实付金额", comment: ""))
                    .font(.headline)
                Spacer()
                Text("¥\(plan.price)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(goldColor)
            }
            .padding(16)
            .background(goldColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func orderRow(title: String, value: String, strikethrough: Bool = false, color: Color = .primary) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            if strikethrough {
                Text(value)
                    .strikethrough()
                    .foregroundColor(.secondary)
            } else {
                Text(value)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
        }
        .padding(16)
    }
    
    // Apple 内购说明
    private var applePayInfoSection: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("支付方式", comment: ""))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.title2)
                    .foregroundColor(.black)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("Apple 内购", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(NSLocalizedString("安全便捷，由 Apple 提供支付保障", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(goldColor)
                    .font(.title3)
            }
            .padding(16)
            .background(Color.adaptiveCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(goldColor, lineWidth: 2)
            )
        }
    }
    
    // 支付按钮
    private var paymentButton: some View {
        Button {
            processPayment()
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("确认支付 ¥\(plan.price)")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [goldColor, Color(red: 0.9, green: 0.7, blue: 0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
        }
        .disabled(isProcessing)
    }
    
    // 说明
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("支付说明", comment: ""))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Group {
                if plan.isAutoRenewing {
                    Text(NSLocalizedString("• 支付成功后立即生效\n• 本订阅为自动续费服务，到期前24小时自动扣费续订\n• 如需取消，请在到期前24小时在「设置-Apple ID-订阅」中取消\n• 通过 Apple 账户安全支付\n• 如有问题请联系客服：birdkingdom@163.com", comment: ""))
                } else {
                    Text(NSLocalizedString("• 支付成功后立即生效\n• 本商品为一次性购买，无需续费\n• 通过 Apple 账户安全支付\n• 如有问题请联系客服：birdkingdom@163.com", comment: ""))
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 处理支付（Apple 内购）
    // ⚠️ 生产环境：必须为 false 以使用真实 Apple 内购
    // 测试模式开启会跳过 Apple 内购，苹果审核会拒绝
    private let testMode = false  // 正式上线
    
    private func processPayment() {
        isProcessing = true
        
        Task {
            do {
                var purchaseResult: StoreManager.PurchaseResult? = nil
                
                // 测试模式：跳过 Apple 内购
                if !testMode {
                    // 获取对应的产品ID
                    let productId = plan.productId
                    
                    // 调用 Apple 内购，获取交易信息
                    purchaseResult = try await storeManager.purchase(productId: productId)
                }
                
                // 调用后端API开通VIP（带重试机制，传递交易信息用于绑定订单）
                var retryCount = 0
                while retryCount < 3 {
                    do {
                        // 构建交易信息
                        let txInfo: (originalTransactionId: String, productId: String, purchaseDate: Int64)? = purchaseResult.map {
                            ($0.originalTransactionId, $0.productId, $0.purchaseDate)
                        }
                        
                        let response = try await ApiService.shared.purchaseVip(
                            vipType: plan.apiVipType,
                            duration: getDuration(),
                            transactionInfo: txInfo
                        )
                        
                        await MainActor.run {
                            isProcessing = false
                            if response.success {
                                showSuccess = true
                            } else {
                                errorMessage = response.message
                                showError = true
                            }
                        }
                        return
                    } catch {
                        retryCount += 1
                        if retryCount < 3 {
                            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒后重试
                        }
                    }
                }
                
                // 3次重试都失败，保存待同步订单（包含交易信息）
                savePendingPurchase(purchaseResult: purchaseResult)
                await MainActor.run {
                    isProcessing = false
                    errorMessage = NSLocalizedString("支付已完成，会员开通中，请稍后查看", comment: "")
                    showError = true
                }
                
            } catch StoreError.userCancelled {
                // P2-09: 支付取消添加明确提示
                await MainActor.run {
                    isProcessing = false
                    errorMessage = NSLocalizedString("支付已取消，您可以稍后再次尝试购买", comment: "")
                    showError = true
                }
            } catch StoreError.productNotFound {
                // 产品未在 App Store Connect 配置或网络问题
                await MainActor.run {
                    isProcessing = false
                    errorMessage = NSLocalizedString("无法加载商品信息，请检查网络连接。如问题持续，请联系客服：birdkingdom@163.com", comment: "")
                    showError = true
                }
            } catch StoreError.verificationFailed {
                // 交易验证失败
                await MainActor.run {
                    isProcessing = false
                    errorMessage = NSLocalizedString("支付验证失败，请联系客服：birdkingdom@163.com", comment: "")
                    showError = true
                }
            } catch StoreError.purchaseFailed {
                // 购买待处理或其他失败
                await MainActor.run {
                    isProcessing = false
                    errorMessage = NSLocalizedString("支付处理中，请稍后在「恢复购买」中查看结果", comment: "")
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "支付失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // 保存待同步的购买记录（用于后端API失败时补偿，包含交易信息）
    private func savePendingPurchase(purchaseResult: StoreManager.PurchaseResult?) {
        var pendingPurchase: [String: Any] = [
            "vipType": plan.apiVipType,
            "duration": getDuration() ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ]
        // 保存交易信息用于后续绑定订单
        if let result = purchaseResult {
            pendingPurchase["originalTransactionId"] = result.originalTransactionId
            pendingPurchase["productId"] = result.productId
            pendingPurchase["purchaseDate"] = result.purchaseDate
        }
        var pendingList = UserDefaults.standard.array(forKey: "pendingVipPurchases") as? [[String: Any]] ?? []
        pendingList.append(pendingPurchase)
        UserDefaults.standard.set(pendingList, forKey: "pendingVipPurchases")
    }
    
    private func getDuration() -> Int? {
        switch plan {
        case .monthly: return 1
        case .yearly: return 12
        case .lifetime, .coupleLifetime: return nil
        }
    }
}

// MARK: - Apple 内购错误
enum StoreError: Error {
    case userCancelled
    case productNotFound
    case purchaseFailed
    case verificationFailed
}

// MARK: - Apple 内购管理器
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    private var productIDs: Set<String> = [
        // VIP 产品暂时隐藏，上线时再开启
        // "com.birdkingdom.vip.monthly",
        // "com.birdkingdom.vip.yearly",
        // "com.birdkingdom.vip.lifetime",
        // "com.birdkingdom.vip.couple.lifetime",
        "com.birdkingdom.splash.birthday"  // 开屏庆生 ¥10
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // 加载产品（带重试机制）
    func loadProducts() async {
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            do {
                let loadedProducts = try await Product.products(for: productIDs)
                products = loadedProducts
                
                if products.isEmpty {
                    print("⚠️ 产品列表为空，可能未在 App Store Connect 配置产品")
                    print("⚠️ 请确保以下产品ID已在 App Store Connect 中配置并处于 READY_TO_SUBMIT 或更高状态：")
                    for productId in productIDs {
                        print("   ❌ 未找到: \(productId)")
                    }
                } else {
                    print("✅ 已加载 \(products.count)/\(productIDs.count) 个产品:")
                    let loadedIds = Set(products.map { $0.id })
                    for productId in productIDs {
                        if loadedIds.contains(productId) {
                            let p = products.first { $0.id == productId }!
                            print("   ✅ \(productId): \(p.displayName) - \(p.displayPrice)")
                        } else {
                            print("   ⚠️ 未找到: \(productId) (可能未在ASC配置或状态为MISSING_METADATA)")
                        }
                    }
                }
                return
            } catch {
                retryCount += 1
                print("❌ 加载产品失败 (尝试 \(retryCount)/\(maxRetries)): \(error)")
                if retryCount < maxRetries {
                    // 等待 2 秒后重试（给网络更多时间）
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        print("❌ 所有 \(maxRetries) 次加载产品尝试均失败")
    }
    
    // 购买产品，返回交易信息用于绑定订单
    func purchase(productId: String) async throws -> PurchaseResult {
        print("🛒 准备购买产品: \(productId)")
        
        // 检查产品是否已加载
        if products.isEmpty {
            print("⚠️ 产品列表为空，正在重新加载...")
            await loadProducts()
        }
        
        guard let product = products.first(where: { $0.id == productId }) else {
            // 如果产品仍未找到，尝试单独加载目标产品
            print("⚠️ 未找到产品 \(productId)，正在单独加载...")
            do {
                let singleProducts = try await Product.products(for: [productId])
                if let product = singleProducts.first {
                    print("✅ 单独加载产品成功: \(product.displayName)")
                    // 添加到缓存
                    if !products.contains(where: { $0.id == productId }) {
                        products.append(product)
                    }
                    return try await purchaseProduct(product)
                }
            } catch {
                print("❌ 单独加载产品也失败: \(error)")
            }
            
            print("❌ 最终未能找到产品: \(productId)")
            print("❌ 已加载的产品列表: \(products.map { $0.id })")
            print("💡 请确保该产品在 App Store Connect 中已创建且状态不是 MISSING_METADATA")
            throw StoreError.productNotFound
        }
        
        print("✅ 找到产品: \(product.displayName) - \(product.displayPrice)")
        return try await purchaseProduct(product)
    }
    
    private func purchaseProduct(_ product: Product) async throws -> PurchaseResult {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            purchasedProductIDs.insert(product.id)
            print("✅ 购买成功: \(product.id), 交易ID: \(transaction.originalID)")
            
            // 返回交易信息用于绑定订单
            return PurchaseResult(
                originalTransactionId: String(transaction.originalID),
                productId: transaction.productID,
                purchaseDate: Int64(transaction.purchaseDate.timeIntervalSince1970 * 1000)
            )
            
        case .userCancelled:
            throw StoreError.userCancelled
            
        case .pending:
            print("⏳ 购买待处理")
            throw StoreError.purchaseFailed
            
        @unknown default:
            throw StoreError.purchaseFailed
        }
    }
    
    // 购买结果，包含交易信息
    struct PurchaseResult {
        let originalTransactionId: String
        let productId: String
        let purchaseDate: Int64 // 毫秒时间戳
    }
    
    // 验证交易
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // 监听交易更新
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("❌ 交易验证失败: \(error)")
                }
            }
        }
    }
    
    // 更新已购买产品
    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
    }
    
    // 恢复购买 - 完整流程：Apple恢复 → 后端同步（含交易ID绑定验证）
    func restorePurchases() async -> (success: Bool, message: String) {
        do {
            // 1. 从Apple恢复购买记录（带重试机制）
            var syncRetry = 0
            while syncRetry < 3 {
                do {
                    try await AppStore.sync()
                    break
                } catch {
                    syncRetry += 1
                    if syncRetry < 3 {
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒后重试
                    } else {
                        throw error
                    }
                }
            }
            
            // 2. 获取所有交易的完整信息（包含交易ID、产品ID、购买日期）
            var transactions: [[String: Any]] = []
            var seenTransactionIds = Set<String>()  // 去重
            
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    let txId = String(transaction.originalID)
                    
                    // 防止重复交易
                    guard !seenTransactionIds.contains(txId) else { continue }
                    seenTransactionIds.insert(txId)
                    
                    purchasedProductIDs.insert(transaction.productID)
                    
                    // 构建交易信息
                    let txInfo: [String: Any] = [
                        "originalTransactionId": txId,
                        "productId": transaction.productID,
                        "purchaseDate": Int64(transaction.purchaseDate.timeIntervalSince1970 * 1000) // 毫秒时间戳
                    ]
                    transactions.append(txInfo)
                    print("📦 交易: \(transaction.productID), ID: \(transaction.originalID), 日期: \(transaction.purchaseDate)")
                }
            }
            
            // 3. 如果有交易记录，调用后端API同步VIP状态
            if !transactions.isEmpty {
                print("📦 共找到 \(transactions.count) 笔交易记录")
                
                // 4. 调用后端接口恢复VIP状态（后端会验证交易ID是否已被其他账号绑定）
                let response = try await ApiService.shared.restoreVipPurchase(transactions: transactions)
                
                if response.success {
                    print("✅ 恢复购买成功: \(response.message)")
                    // 显示剩余天数
                    if let days = response.remainingDays, days > 0 {
                        return (true, "恢复成功！会员剩余 \(days) 天")
                    }
                    return (true, response.message)
                } else {
                    print("⚠️ 后端恢复失败: \(response.message)")
                    // 友好错误提示
                    return (false, friendlyErrorMessage(response.message))
                }
            } else {
                print("ℹ️ 没有找到可恢复的购买记录")
                return (false, NSLocalizedString("没有找到可恢复的购买记录，请确认使用购买时的 Apple ID", comment: ""))
            }
        } catch {
            print("❌ 恢复购买失败: \(error)")
            return (false, NSLocalizedString("网络连接失败，请检查网络后重试", comment: ""))
        }
    }
    
    // 将后端错误转为用户友好提示
    private func friendlyErrorMessage(_ message: String) -> String {
        if message.contains(NSLocalizedString("已绑定", comment: "")) || message.contains("ALREADY_BOUND") {
            return NSLocalizedString("此订单已绑定其他手机号，请使用原手机号登录后恢复，或联系客服：birdkingdom@163.com", comment: "")
        } else if message.contains(NSLocalizedString("过期", comment: "")) || message.contains("EXPIRED") {
            return NSLocalizedString("订单已过期，请重新购买会员", comment: "")
        } else if message.contains(NSLocalizedString("退款", comment: "")) || message.contains("REFUNDED") {
            return NSLocalizedString("此订单已申请退款，无法恢复", comment: "")
        }
        return message
    }
}

#Preview {
    PaymentView(plan: .yearly) {
        print("支付成功")
    }
}
