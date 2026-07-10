import SwiftUI

/// 开屏庆生入口页面 - Apple 风格设计
struct SplashPurchaseView: View {
    @StateObject private var splashService = SplashService.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showCalendar = false
    @State private var reuploadOrder: SplashService.ReserveResponse?
    @State private var continuePayOrder: SplashService.ReserveResponse?
    
    // 审核结果弹窗
    @State private var showApprovedAlert = false
    @State private var showRejectedAlert = false
    @State private var rejectedReason: String = ""
    @State private var approvedDate: String = ""
    
    // ✅ 修复：会话级标记，防止每次进入页面都弹窗
    @State private var hasCheckedReview = false
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        List {
            // 头部介绍
            Section {
                headerSection
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            
            // 权益说明
            Section {
                ForEach(benefits.indices, id: \.self) { index in
                    HStack(spacing: 16) {
                        Image(systemName: benefits[index].icon)
                            .font(.system(size: 20))
                            .foregroundColor(primaryColor)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(benefits[index].title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(benefits[index].description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(NSLocalizedString("专属权益", comment: ""))
            }
            
            // 价格与购买
            Section {
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text(splashService.currentPrice.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(NSLocalizedString("/ 次", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                    .padding(.top, 8)
                    
                    Text(NSLocalizedString("每日限10个展示位", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        if AuthService.shared.isLoggedIn {
                            showCalendar = true
                        }
                    } label: {
                        Text(NSLocalizedString("选择日期", comment: ""))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(primaryColor)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain) // 防止点击整个列触发行
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            } header: {
                Text(NSLocalizedString("立即预订", comment: ""))
            }
            
            // 我的订单
            if !splashService.orders.isEmpty {
                Section {
                    ForEach(splashService.orders) { order in
                        AppleStyleOrderRow(
                            order: order,
                            primaryColor: primaryColor,
                            onReupload: {
                                reuploadOrder = SplashService.ReserveResponse(
                                    orderId: order.id,
                                    slotId: 0,
                                    displayDate: order.displayDate,
                                    amount: order.amount,
                                    expireAt: "",
                                    status: order.status
                                )
                            },
                            onContinuePay: {
                                continuePayOrder = SplashService.ReserveResponse(
                                    orderId: order.id,
                                    slotId: 0,
                                    displayDate: order.displayDate,
                                    amount: order.amount,
                                    expireAt: order.createdAt,
                                    status: order.status
                                )
                            }
                        )
                        .buttonStyle(.plain) // 避免行点击高亮
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            // 根据订单状态显示不同的操作按钮
                            if order.status == "PENDING" {
                                // PENDING 状态：显示"取消"
                                Button(role: .destructive) {
                                    cancelPendingOrder(order)
                                } label: {
                                    Label(L10n.cancel, systemImage: "xmark.circle")
                                }
                            } else if order.status == "PAID" {
                                // PAID 状态：显示"删除"（已付款但未展示的可删除）
                                Button(role: .destructive) {
                                    deleteHistoryOrder(order)
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            } else if order.status == "EXPIRED" || order.status == "CANCELLED" || order.status == "REFUNDED" {
                                // 历史订单：显示"删除"
                                Button(role: .destructive) {
                                    deleteHistoryOrder(order)
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            }
                            // ACTIVE 等状态：不显示滑动操作
                        }
                    }
                } header: {
                    Text(L10n.myOrders)
                } footer: {
                    if !splashService.orders.isEmpty {
                        Text(NSLocalizedString("待付款订单左滑可取消，历史订单左滑可删除", comment: ""))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.splashTitle)
        .navigationBarTitleDisplayMode(.large)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            Task {
                // ✅ 修复：审核结果只在首次进入时检查一次
                if !hasCheckedReview {
                    hasCheckedReview = true
                    await checkReviewResults()
                }
                // P2修复：加载当前价格
                let today = Date()
                let nextMonth = Calendar.current.date(byAdding: .day, value: 30, to: today)!
                try? await splashService.fetchQuotas(startDate: today, endDate: nextMonth)
            }
        }
        .navigationDestination(isPresented: $showCalendar) {
            SplashCalendarView()
                .hidesTabBar()
        }
        .navigationDestination(item: $reuploadOrder) { response in
            SplashReuploadView(orderResponse: response)
                .hidesTabBar()
        }
        .navigationDestination(item: $continuePayOrder) { response in
            SplashUploadView(reserveResponse: response)
                .hidesTabBar()
        }
        // 审核通过弹窗
        .alert(NSLocalizedString("🎉 审核通过", comment: ""), isPresented: $showApprovedAlert) {
            Button(NSLocalizedString("太棒了", comment: "")) { }
        } message: {
            Text("您的开屏图片已审核通过！\n\n将在 \(approvedDate) 展示给所有用户。")
        }
        // 审核驳回弹窗
        .alert(NSLocalizedString("审核未通过", comment: ""), isPresented: $showRejectedAlert) {
            Button(NSLocalizedString("我知道了", comment: "")) { }
        } message: {
            Text("很抱歉，您的开屏图片未通过审核。\n\n驳回原因：\(rejectedReason)\n\n费用将自动退还到您的账户。")
        }
    }
    
    // MARK: - 检测审核结果变化
    
    private func checkReviewResults() async {
        // 先获取最新订单
        try? await splashService.fetchOrders()
        
        // 检查每个订单的审核状态
        for order in splashService.orders {
            let currentStatus = order.reviewStatus
            
            // 只检查有明确审核结果的订单
            if currentStatus == "APPROVED" {
                // 检查是否已经通知过（使用 UserDefaults 记录）
                let notifiedKey = "splash_notified_approved_\(order.orderId)"
                if !UserDefaults.standard.bool(forKey: notifiedKey) {
                    approvedDate = order.displayDate
                    showApprovedAlert = true
                    UserDefaults.standard.set(true, forKey: notifiedKey)
                    return // 一次只显示一个弹窗
                }
            } else if currentStatus == "REJECTED" {
                let notifiedKey = "splash_notified_rejected_\(order.orderId)"
                if !UserDefaults.standard.bool(forKey: notifiedKey) {
                    rejectedReason = order.reviewReason ?? NSLocalizedString("不符合展示规范", comment: "")
                    showRejectedAlert = true
                    UserDefaults.standard.set(true, forKey: notifiedKey)
                    return // 一次只显示一个弹窗
                }
            }
            // PENDING 状态不弹窗，等待审核
        }
    }
    
    // MARK: - 头部介绍
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(primaryColor)
                .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("为鸟鸟打造专属开屏", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(NSLocalizedString("选择特别的日期，上传鸟鸟的照片\n让所有用户启动App时都能看到", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var benefits: [(icon: String, title: String, description: String)] {
        [
            ("calendar", NSLocalizedString("自选日期", comment: ""), NSLocalizedString("可预订未来365天内的任意日期", comment: "")),
            ("photo", NSLocalizedString("专属展示", comment: ""), NSLocalizedString("上传鸟鸟照片作为App启动画面", comment: "")),
            ("person.2", NSLocalizedString("全员可见", comment: ""), NSLocalizedString("当天所有用户启动App都能看到", comment: "")),
            ("bolt", NSLocalizedString("即时生效", comment: ""), NSLocalizedString("购买成功后权益立即生效", comment: ""))
        ]
    }
    
    // MARK: - 订单操作逻辑
    
    /// 取消待付款订单（PENDING 状态）
    private func cancelPendingOrder(_ order: SplashService.SplashOrderInfo) {
        Task {
            do {
                try await splashService.cancelOrder(orderId: order.id)
                try? await splashService.fetchOrders()
                await ToastManager.shared.showSuccess(NSLocalizedString("订单已取消", comment: ""))
            } catch {
                await ToastManager.shared.showError("取消失败: \(error.localizedDescription)")
                try? await splashService.fetchOrders()
            }
        }
    }
    
    /// 删除历史订单（EXPIRED/CANCELLED/REFUNDED/PAID 状态）
    private func deleteHistoryOrder(_ order: SplashService.SplashOrderInfo) {
        Task {
            do {
                try await splashService.deleteOrder(orderId: order.id)
                try? await splashService.fetchOrders()
                await ToastManager.shared.showSuccess(NSLocalizedString("订单已删除", comment: ""))
            } catch {
                await ToastManager.shared.showError("删除失败: \(error.localizedDescription)")
                try? await splashService.fetchOrders()
            }
        }
    }
}

// MARK: - 苹果风格订单行 (无手势版)

struct AppleStyleOrderRow: View {
    let order: SplashService.SplashOrderInfo
    let primaryColor: Color
    var onReupload: (() -> Void)? = nil
    var onContinuePay: (() -> Void)? = nil
    
    private var statusInfo: (text: String, color: Color) {
        // 优先显示审核状态
        if let reviewStatus = order.reviewStatus {
            switch reviewStatus {
            case "PENDING":
                return (L10n.pending, .orange)
            case "APPROVED":
                if order.status == "EXPIRED" {
                    return (NSLocalizedString("已过期", comment: ""), .secondary)
                }
                return (NSLocalizedString("审核通过", comment: ""), .green)
            case "REJECTED":
                return (NSLocalizedString("已驳回", comment: ""), .red)
            default:
                break
            }
        }
        
        // 根据订单状态显示
        switch order.status {
        case "PENDING": return (NSLocalizedString("待支付", comment: ""), primaryColor)
        case "PAID": return (order.imageUrl == nil ? NSLocalizedString("待上传", comment: "") : NSLocalizedString("已付款", comment: ""), primaryColor)
        case "PENDING_REVIEW": return (NSLocalizedString("待审核", comment: ""), .orange)
        case "ACTIVE": return (NSLocalizedString("展示中", comment: ""), primaryColor)
        case "DISPLAYED": return (NSLocalizedString("已展示", comment: ""), .secondary)
        case "EXPIRED": return (NSLocalizedString("已过期", comment: ""), .secondary)
        case "CANCELLED": return (NSLocalizedString("已取消", comment: ""), .secondary)
        case "REFUNDED": return (NSLocalizedString("已退款", comment: ""), .purple)
        default: return (order.status, .secondary)
        }
    }
    
    private var needsUpload: Bool {
        order.status == "PAID" && order.imageUrl == nil
    }
    
    private var isPending: Bool {
        order.status == "PENDING"
    }
    
    private var isRejected: Bool {
        order.reviewStatus == "REJECTED"
    }
    
    private var isRefunded: Bool {
        order.status == "REFUNDED"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 主要行内容
            HStack(spacing: 14) {
                // 图片/占位图标
                Group {
                    if let imageUrl = order.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color(uiColor: .tertiarySystemFill)
                        }
                    } else {
                        Color(uiColor: .tertiarySystemFill)
                            .overlay(
                                Image(systemName: isPending ? "clock" : "photo.on.rectangle.angled")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(primaryColor.opacity(0.8))
                            )
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // 订单信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.displayDate)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("¥\(String(format: "%.0f", order.amount))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 操作按钮或状态
                if isPending, let action = onContinuePay {
                    Button(action: action) {
                        Text(NSLocalizedString("去支付", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(primaryColor.opacity(0.1))
                            .foregroundColor(primaryColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if needsUpload, let action = onReupload {
                    Button(action: action) {
                        Text(NSLocalizedString("上传照片", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(primaryColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    // 状态标签 - 苹果极简风格（圆点+文字）
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusInfo.color)
                            .frame(width: 6, height: 6)
                        Text(statusInfo.text)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 底部辅助信息（驳回/退款等），使用轻量级圆角背景块包裹
            if isRejected || isRefunded {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isRejected ? "xmark.shield.fill" : "checkmark.shield.fill")
                        .foregroundColor(isRejected ? .red : .green)
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if isRejected, let reason = order.reviewReason, !reason.isEmpty {
                            Text("由于[\(reason)]，审核已驳回")
                        } else if isRefunded {
                            Text(NSLocalizedString("款项已按原路全部退还至您的账户", comment: ""))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(10)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
                .padding(.leading, 64) // 对齐到图片右侧
            }
        }
        .padding(.vertical, 6)
    }
}

// 移除不再需要的自定义手势组件


#Preview {
    NavigationStack {
        SplashPurchaseView()
    }
}
