import SwiftUI

// MARK: - 支付页面
struct PaymentView: View {
    let plan: VipPlan
    let onPaymentSuccess: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPaymentMethod: PaymentMethod = .wechat
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 订单信息
                    orderInfoSection
                    
                    // 支付方式选择
                    paymentMethodSection
                    
                    // 支付按钮
                    paymentButton
                    
                    // 说明
                    notesSection
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGray6).opacity(0.3))
            .navigationTitle("确认支付")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("支付成功", isPresented: $showSuccess) {
                Button("确定") {
                    onPaymentSuccess()
                    dismiss()
                }
            } message: {
                Text("恭喜您成为\(plan.name)！")
            }
            .alert("支付失败", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // 订单信息
    private var orderInfoSection: some View {
        VStack(spacing: 16) {
            Text("订单信息")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                orderRow(title: "商品", value: plan.name)
                Divider().padding(.leading, 16)
                orderRow(title: "价格", value: "¥\(plan.price)")
                
                if let originalPrice = plan.originalPrice {
                    Divider().padding(.leading, 16)
                    orderRow(title: "原价", value: "¥\(originalPrice)", strikethrough: true)
                    Divider().padding(.leading, 16)
                    orderRow(title: "优惠", value: "-¥\(originalPrice - plan.price)", color: .red)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            
            // 实付金额
            HStack {
                Text("实付金额")
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
    
    // 支付方式选择
    private var paymentMethodSection: some View {
        VStack(spacing: 16) {
            Text("支付方式")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                paymentMethodCard(.wechat)
                paymentMethodCard(.alipay)
                paymentMethodCard(.applePay)
            }
        }
    }
    
    private func paymentMethodCard(_ method: PaymentMethod) -> some View {
        Button {
            selectedPaymentMethod = method
        } label: {
            HStack(spacing: 12) {
                Image(systemName: method.icon)
                    .font(.title2)
                    .foregroundColor(method.color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: selectedPaymentMethod == method ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedPaymentMethod == method ? goldColor : .gray)
                    .font(.title3)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPaymentMethod == method ? goldColor : Color.clear, lineWidth: 2)
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
            Text("支付说明")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("• 支付成功后立即生效\n• 支持微信、支付宝、Apple Pay\n• 如有问题请联系客服")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 处理支付
    private func processPayment() {
        isProcessing = true
        
        // 模拟支付流程
        Task {
            do {
                // 根据支付方式调用不同的支付SDK
                switch selectedPaymentMethod {
                case .wechat:
                    try await processWeChatPay()
                case .alipay:
                    try await processAliPay()
                case .applePay:
                    try await processApplePay()
                }
                
                // 支付成功后调用后端API开通VIP
                let response = try await ApiService.shared.purchaseVip(
                    vipType: plan.apiVipType,
                    duration: getDuration()
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
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "支付失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func getDuration() -> Int? {
        switch plan {
        case .monthly: return 1
        case .yearly: return 12
        case .lifetime, .coupleLifetime: return nil
        }
    }
    
    // 模拟支付流程
    private func processWeChatPay() async throws {
        // TODO: 集成微信支付SDK
        try await Task.sleep(nanoseconds: 2_000_000_000) // 模拟2秒
    }
    
    private func processAliPay() async throws {
        // TODO: 集成支付宝SDK
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func processApplePay() async throws {
        // TODO: 集成Apple Pay
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }
}

// MARK: - 支付方式
enum PaymentMethod: CaseIterable {
    case wechat
    case alipay
    case applePay
    
    var name: String {
        switch self {
        case .wechat: return "微信支付"
        case .alipay: return "支付宝"
        case .applePay: return "Apple Pay"
        }
    }
    
    var description: String {
        switch self {
        case .wechat: return "推荐使用"
        case .alipay: return "快捷支付"
        case .applePay: return "安全便捷"
        }
    }
    
    var icon: String {
        switch self {
        case .wechat: return "message.fill"
        case .alipay: return "creditcard.fill"
        case .applePay: return "apple.logo"
        }
    }
    
    var color: Color {
        switch self {
        case .wechat: return Color.green
        case .alipay: return Color.blue
        case .applePay: return Color.black
        }
    }
}

#Preview {
    PaymentView(plan: .yearly) {
        print("支付成功")
    }
}
