import SwiftUI

// MARK: - VIP 会员页面
struct VipView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: VipPlan = .yearly
    @State private var isLoading = false
    @State private var showPurchaseSuccess = false
    @State private var showError = false
    @State private var alertMessage = ""
    @State private var showPayment = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // VIP 状态卡片
                    vipStatusCard
                    
                    // VIP 特权
                    privilegesSection
                    
                    // 套餐选择
                    plansSection
                    
                    // 购买按钮
                    purchaseButton
                    
                    // 说明
                    notesSection
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.96, blue: 0.90), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("VIP会员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(forestGreen)
                }
            }
            .alert("开通成功", isPresented: $showPurchaseSuccess) {
                Button("确定") { dismiss() }
            } message: {
                Text("恭喜你成为VIP会员！现在可以享受所有特权了")
            }
            .sheet(isPresented: $showPayment) {
                PaymentView(plan: selectedPlan) {
                    // 支付成功回调
                    Task {
                        try? await authService.fetchCurrentUser()
                    }
                    showPurchaseSuccess = true
                }
            }
        }
    }
    
    // VIP 状态卡片
    private var vipStatusCard: some View {
        VStack(spacing: 16) {
            if let user = authService.currentUser, user.isVipValid {
                // 已是VIP
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 36))
                        .foregroundColor(goldColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("VIP会员")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(user.vipType?.displayName ?? "")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(goldColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        if let days = user.vipRemainingDays {
                            if user.vipType == .lifetime {
                                Text("永久有效")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("剩余 \(days) 天")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
            } else {
                // 非VIP
                VStack(spacing: 12) {
                    Image(systemName: "crown")
                        .font(.system(size: 50))
                        .foregroundColor(goldColor.opacity(0.5))
                    
                    Text("开通VIP会员")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("解锁全部特权，畅享无限可能")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.98, blue: 0.92), Color(red: 1.0, green: 0.95, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(goldColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // VIP 特权
    private var privilegesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("VIP专属特权")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                privilegeItem(icon: "person.2.fill", title: "共享鸟儿", description: "邀请他人共同管理")
                privilegeItem(icon: "xmark.circle", title: "去除广告", description: "纯净无广告体验")
                privilegeItem(icon: "paintbrush.fill", title: "专属主题", description: "4种精美主题")
                privilegeItem(icon: "trash.circle", title: "回收站", description: "7天内可恢复")
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    private func privilegeItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(goldColor)
                .frame(width: 36, height: 36)
                .background(goldColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .systemGray6).opacity(0.5))
        .cornerRadius(10)
    }
    
    // 套餐选择
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择套餐")
                .font(.headline)
            
            VStack(spacing: 12) {
                planCard(plan: .monthly)
                planCard(plan: .yearly)
                planCard(plan: .lifetime)
                planCard(plan: .coupleLifetime)
            }
        }
    }
    
    private func planCard(plan: VipPlan) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if plan.tag != nil {
                            Text(plan.tag!)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(plan.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("¥")
                            .font(.subheadline)
                            .foregroundColor(goldColor)
                        Text("\(plan.price)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(goldColor)
                    }
                    
                    if let originalPrice = plan.originalPrice {
                        Text("¥\(originalPrice)")
                            .font(.caption)
                            .strikethrough()
                            .foregroundColor(.gray)
                    }
                }
                
                Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedPlan == plan ? goldColor : .gray)
                    .font(.title3)
            }
            .padding(16)
            .background(selectedPlan == plan ? goldColor.opacity(0.1) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPlan == plan ? goldColor : Color.gray.opacity(0.2), lineWidth: selectedPlan == plan ? 2 : 1)
            )
        }
    }
    
    // 购买按钮
    private var purchaseButton: some View {
        Button {
            showPayment = true
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("立即开通 ¥\(selectedPlan.price)")
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
        .disabled(isLoading)
    }
    
    // 说明
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("说明")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("• 会员服务开通后立即生效\n• 续费时长将在当前会员基础上叠加\n• 月度/年度会员到期后不自动续费\n• 如有问题请联系客服")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    // 购买/续费
    private func purchase() {
        isLoading = true
        
        Task {
            do {
                // 确定VIP类型和时长
                let vipType = selectedPlan.apiVipType
                let duration: Int?
                
                switch selectedPlan {
                case .monthly:
                    duration = 1
                case .yearly:
                    duration = 12
                case .lifetime, .coupleLifetime:
                    duration = nil
                }
                
                // 调用API购买/续费
                let response = try await ApiService.shared.purchaseVip(vipType: vipType, duration: duration)
                
                await MainActor.run {
                    isLoading = false
                    
                    if response.success {
                        // 显示成功提示
                        alertMessage = response.message
                        showPurchaseSuccess = true
                        
                        // 刷新用户信息以更新VIP状态
                        Task {
                            try? await authService.fetchCurrentUser()
                        }
                    } else {
                        alertMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "购买失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - VIP 套餐
enum VipPlan: CaseIterable {
    case monthly
    case yearly
    case lifetime
    case coupleLifetime
    
    var name: String {
        switch self {
        case .monthly: return "月度会员"
        case .yearly: return "年度会员"
        case .lifetime: return "永久会员"
        case .coupleLifetime: return "情侣永久会员"
        }
    }
    
    var description: String {
        switch self {
        case .monthly: return "按月付费，灵活选择"
        case .yearly: return "年付更划算，省60元"
        case .lifetime: return "一次购买，永久使用"
        case .coupleLifetime: return "💕 专属情侣标识 · 爱的结晶"
        }
    }
    
    var price: Int {
        switch self {
        case .monthly: return 12
        case .yearly: return 88
        case .lifetime: return 198
        case .coupleLifetime: return 520
        }
    }
    
    var originalPrice: Int? {
        switch self {
        case .monthly: return nil
        case .yearly: return 144
        case .lifetime: return 288
        case .coupleLifetime: return 888
        }
    }
    
    var tag: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "推荐"
        case .lifetime: return "最划算"
        case .coupleLifetime: return "💕 浪漫"
        }
    }
    
    var vipType: VipType {
        switch self {
        case .monthly: return .monthly
        case .yearly: return .yearly
        case .lifetime: return .lifetime
        case .coupleLifetime: return .lifetime
        }
    }
    
    var apiVipType: String {
        switch self {
        case .monthly: return "MONTHLY"
        case .yearly: return "YEARLY"
        case .lifetime: return "LIFETIME"
        case .coupleLifetime: return "COUPLE_LIFETIME"
        }
    }
}

// MARK: - VIP 特权检查
struct VipFeature {
    // 检查是否有VIP特权
    static func canUse(_ feature: Feature, user: User?) -> Bool {
        guard let user = user else { return false }
        
        switch feature {
        case .shareBird, .removeAds, .cloudBackup, .dataStats, .smartReminder, .customTheme:
            return user.isVipValid
        case .basic:
            return true
        }
    }
    
    enum Feature {
        case basic          // 基础功能
        case shareBird      // 共享鸟儿
        case removeAds      // 去除广告
        case cloudBackup    // 云端备份
        case dataStats      // 数据统计
        case smartReminder  // 智能提醒
        case customTheme    // 自定义主题
    }
}

#Preview {
    VipView()
}
