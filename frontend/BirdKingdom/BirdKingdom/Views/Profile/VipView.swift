import SwiftUI

// MARK: - VIP 会员页面
struct VipView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject private var splashManager = SplashLaunchManager.shared  // 观察广告设置变化
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: VipPlan = .yearly
    @State private var isLoading = false
    @State private var showPurchaseSuccess = false
    @State private var showError = false
    @State private var alertMessage = ""
    @State private var showPayment = false
    @State private var showCoupleBinding = false  // 情侣绑定弹窗
    @State private var lastRestoreTime: Date?  // 恢复购买防抖
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var primaryColor: Color { themeManager.primaryColor }
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let pinkColor = Color(red: 1.0, green: 0.6, blue: 0.7)
    
    // 是否为情侣永久会员（最高等级，无需显示购买选项）
    private var isCoupleLifetimeMember: Bool {
        authService.currentUser?.vipType == .coupleLifetime
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // VIP 状态卡片
                vipStatusCard
                
                // VIP 特权
                privilegesSection
                
                // 情侣永久会员是最高等级，不需要显示套餐和购买按钮
                if !isCoupleLifetimeMember {
                    // 套餐选择
                    plansSection
                    
                    // 购买按钮
                    purchaseButton
                }
                
                // 说明
                notesSection
            }
            .padding(20)
        }
        .themedBackground()
        .themedNavigationBar(title: L10n.vipMember)
        .alert(NSLocalizedString("开通成功", comment: ""), isPresented: $showPurchaseSuccess) {
            Button(NSLocalizedString("确定", comment: "")) { dismiss() }
        } message: {
            Text(NSLocalizedString("恭喜你成为VIP会员！现在可以享受所有特权了", comment: ""))
        }
        .navigationDestination(isPresented: $showPayment) {
            PaymentView(plan: selectedPlan) {
                // 支付成功回调
                Task {
                    try? await authService.fetchCurrentUser()
                }
                // 如果是情侣永久会员，弹出绑定伴侣界面
                if selectedPlan == .coupleLifetime {
                    showCoupleBinding = true
                } else {
                    showPurchaseSuccess = true
                }
            }
            .hidesTabBar()
        }
        .navigationDestination(isPresented: $showCoupleBinding) {
            CoupleBindingView {
                // 绑定成功后刷新用户信息
                Task {
                    try? await authService.fetchCurrentUser()
                }
            }
            .hidesTabBar()
        }
        .hidesTabBar()  // 进入详情页时隐藏底部导航栏
        // #15 修复：进入 VIP 页面时刷新 VIP 状态，确保实时性
        .task {
            do {
                try await authService.fetchCurrentUser()
            } catch {
                print("刷新用户信息失败: \(error)")
            }
        }
    }
    
    // VIP 状态卡片
    private var vipStatusCard: some View {
        VStack(spacing: 16) {
            vipStatusCardContent
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(vipCardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(goldColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // VIP 卡片内容
    @ViewBuilder
    private var vipStatusCardContent: some View {
        if let user = authService.currentUser, user.isVipValid {
            if user.vipType == .coupleLifetime {
                coupleVipCardContent(user: user)
            } else {
                regularVipCardContent(user: user)
            }
        } else {
            nonVipCardContent
        }
    }
    
    // VIP 卡片背景
    private var vipCardBackground: some View {
        Group {
            if themeManager.isDarkTheme {
                LinearGradient(
                    colors: [Color(red: 0.35, green: 0.28, blue: 0.12), Color(red: 0.25, green: 0.2, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.98, blue: 0.92), Color(red: 1.0, green: 0.95, blue: 0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    // 情侣会员卡片内容
    private func coupleVipCardContent(user: User) -> some View {
        VStack(spacing: 16) {
            // 顶部：会员标识
            HStack(spacing: 12) {
                Image("VIPBirdIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .colorMultiply(pinkColor)
                
                Text(NSLocalizedString("情侣会员", comment: ""))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(pinkColor)
                
                Spacer()
            }
            
            // 情侣绑定状态
            coupleBindingStatusView(user: user)
        }
    }
    
    // 情侣绑定状态视图
    @ViewBuilder
    private func coupleBindingStatusView(user: User) -> some View {
        if user.couplePartnerId != nil {
            coupleAvatarSection(user: user)
        } else if user.pendingCouplePhone != nil {
            pendingBindingSection(user: user)
        } else {
            bindPartnerButton
        }
    }
    
    // 已绑定：双头像样式
    private func coupleAvatarSection(user: User) -> some View {
        HStack(spacing: 0) {
            // 自己
            userAvatarView(user: user)
            
            // 连接线和爱心
            ZStack {
                Rectangle()
                    .fill(pinkColor.opacity(0.3))
                    .frame(width: 40, height: 2)
                Text("💕")
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
            
            // 伴侣头像
            partnerAvatarView(user: user)
        }
        .padding(.vertical, 8)
    }
    
    // 用户头像视图
    private func userAvatarView(user: User) -> some View {
        VStack(spacing: 6) {
            if let myAvatarUrl = user.avatarUrl, !myAvatarUrl.isEmpty {
                AsyncImage(url: URL(string: myAvatarUrl)) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle().fill(pinkColor.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(colors: [pinkColor.opacity(0.6), pinkColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(user.nickname.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            Text(NSLocalizedString("我", comment: ""))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // 伴侣头像视图
    private func partnerAvatarView(user: User) -> some View {
        VStack(spacing: 6) {
            if let partnerAvatarUrl = user.couplePartnerAvatar, !partnerAvatarUrl.isEmpty {
                AsyncImage(url: URL(string: partnerAvatarUrl)) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle().fill(goldColor.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(colors: [goldColor.opacity(0.6), goldColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String((user.couplePartnerName ?? "TA").prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            Text(user.couplePartnerName ?? "TA")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // 待绑定状态（苹果原生风格）
    private func pendingBindingSection(user: User) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.isPendingConfirmation == true ? NSLocalizedString("等待对方确认", comment: "") : NSLocalizedString("等待对方注册", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let pendingName = user.pendingCouplePartnerName {
                    Text(pendingName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                showCoupleBinding = true
            } label: {
                Text(NSLocalizedString("修改", comment: ""))
                    .font(.caption)
                    .foregroundColor(pinkColor)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // 绑定伴侣按钮
    private var bindPartnerButton: some View {
        Button {
            showCoupleBinding = true
        } label: {
            HStack {
                Image(systemName: "heart.circle.fill")
                Text(NSLocalizedString("绑定伴侣", comment: ""))
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(pinkColor)
            .cornerRadius(12)
        }
    }
    
    // 普通VIP布局
    private func regularVipCardContent(user: User) -> some View {
        return HStack(spacing: 12) {
            Image("VIPBirdIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.vipMember)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.brown)
                
                // 醒目显示剩余天数
                if let days = user.vipRemainingDays {
                    Text(String(format: NSLocalizedString("剩余 %d 天", comment: ""), days))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.brown)
                } else if user.vipType == .lifetime {
                    Text(NSLocalizedString("永久有效", comment: ""))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.brown)
                }
                
                // 有效期细节
                if let expireDate = user.vipExpireDate {
                    Text(String(format: NSLocalizedString("有效期至 %@", comment: ""), formatDate(expireDate)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    // VIP到期文本
    @ViewBuilder
    private func vipExpiryText(user: User) -> some View {
        if user.vipType == .lifetime || user.vipType == .coupleLifetime {
            Text(NSLocalizedString("永久有效", comment: ""))
                .font(.subheadline)
                .foregroundColor(.brown)
        } else if let days = user.vipRemainingDays {
            HStack(spacing: 2) {
                Text(NSLocalizedString("剩余", comment: ""))
                Text("\(days)")
                    .font(.headline)
                    .foregroundColor(days <= 7 ? .red : .primary)
                Text(NSLocalizedString("天", comment: ""))
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        } else if let expireDate = user.vipExpireDate {
            Text(String(format: NSLocalizedString("有效期至 %@", comment: ""), formatDate(expireDate)))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    // 非VIP内容
    private var nonVipCardContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown")
                .font(.system(size: 50))
                .foregroundColor(goldColor.opacity(0.5))
            
            Text(NSLocalizedString("开通VIP会员", comment: ""))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(NSLocalizedString("解锁全部特权，畅享无限可能", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // VIP 特权
    private var privilegesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("VIP专属特权", comment: ""))
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                privilegeItem(icon: "person.2.fill", title: L10n.sharedBirds, description: NSLocalizedString("邀请他人共同管理", comment: ""))
                
                // 去除广告特权（可点击切换）
                adsToggleItem
                
                privilegeItem(icon: "paintbrush.fill", title: NSLocalizedString("专属主题", comment: ""), description: NSLocalizedString("4种精美主题", comment: ""))
                privilegeItem(icon: "trash.circle", title: L10n.recycleBin, description: NSLocalizedString("7天内可恢复", comment: ""))
            }
        }
        .padding(20)
        .background(Color.adaptiveCard)
        .cornerRadius(16)
    }
    
    /// 去除广告切换项（仅 VIP 可用）
    private var adsToggleItem: some View {
        let isVip = authService.currentUser?.isVipValid == true
        let adsRemoved = !splashManager.vipShowAds  // true = 已去除广告
        
        return Button {
            if isVip {
                splashManager.toggleVipAds()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: adsRemoved ? "bell.slash.fill" : "bell.fill")
                        .font(.title3)
                        .foregroundColor(goldColor)
                        .frame(width: 36, height: 36)
                        .background(goldColor.opacity(0.1))
                        .cornerRadius(8)
                    
                    // 显示状态指示器
                    if isVip {
                        Circle()
                            .fill(adsRemoved ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                            .offset(x: 14, y: -14)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("去除广告", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(isVip ? (adsRemoved ? NSLocalizedString("已去除 · 点击恢复", comment: "") : NSLocalizedString("已恢复 · 点击去除", comment: "")) : NSLocalizedString("纯净无广告体验", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!isVip)
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
        let user = authService.currentUser
        let isLifetimeMember = user?.vipType == .lifetime || user?.vipType == .coupleLifetime
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(NSLocalizedString("选择套餐", comment: ""))
                    .font(.headline)
                
                Spacer()
                
                if let days = user?.vipRemainingDays, !isLifetimeMember {
                    Text(String(format: NSLocalizedString("当前剩余 %d 天", comment: ""), days))
                        .font(.caption)
                        .foregroundColor(days <= 7 ? .red : .secondary)
                }
            }
            
            if isLifetimeMember && user?.vipType != .coupleLifetime {
                // 永久会员只能购买情侣永久会员
                Text(NSLocalizedString("您已是永久会员，可升级为情侣永久会员", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                
                planCard(plan: .coupleLifetime, disabled: false)
            } else if user?.vipType == .coupleLifetime {
                // 情侣永久会员不显示套餐选择
                Text(NSLocalizedString("🎉 您已是情侣永久会员，享受最高权益", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(pinkColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(pinkColor.opacity(0.1))
                    .cornerRadius(12)
            } else {
                // 普通用户显示所有套餐
                VStack(spacing: 12) {
                    planCard(plan: .monthly, disabled: false)
                    planCard(plan: .yearly, disabled: false)
                    planCard(plan: .lifetime, disabled: false)
                    planCard(plan: .coupleLifetime, disabled: false)
                }
            }
        }
    }
    
    private func planCard(plan: VipPlan, disabled: Bool = false) -> some View {
        Button {
            if !disabled {
                selectedPlan = plan
            }
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
                    
                    // 购买后天数预览
                    if (plan == .monthly || plan == .yearly) {
                        let currentDays = authService.currentUser?.vipRemainingDays ?? 0
                        let totalDays = currentDays + plan.days
                        Text(String(format: NSLocalizedString("购买后有效期将延长至 %d 天", comment: ""), totalDays))
                            .font(.caption2)
                            .foregroundColor(goldColor)
                            .padding(.top, 2)
                    } else if (plan == .lifetime || plan == .coupleLifetime) {
                         Text(NSLocalizedString("一次性购买，终身有效", comment: ""))
                            .font(.caption2)
                            .foregroundColor(goldColor)
                            .padding(.top, 2)
                    }

                    // 自动续费提示（苹果原生风格）
                    if plan.isAutoRenewing {
                        Text(NSLocalizedString("自动续费，可随时取消", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
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
            .background(selectedPlan == plan ? goldColor.opacity(0.15) : Color.adaptiveCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPlan == plan ? goldColor : Color.gray.opacity(0.2), lineWidth: selectedPlan == plan ? 2 : 1)
            )
        }
    }
    
    // 购买按钮
    private var purchaseButton: some View {
        VStack(spacing: 12) {
            // 主购买按钮
            Button {
                showPayment = true
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(format: NSLocalizedString("立即开通 ¥%@", comment: ""), selectedPlan.price))
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
            
            // 恢复购买 & 管理订阅
            HStack(spacing: 20) {
                // 恢复购买（苹果审核必须）
                Button {
                    restorePurchases()
                } label: {
                    Text(NSLocalizedString("恢复购买", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .underline()
                }
                
                // 管理订阅（苹果审核必须）
                Button {
                    openSubscriptionManagement()
                } label: {
                    Text(NSLocalizedString("管理订阅", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .underline()
                }
            }
            .padding(.top, 4)
        }
    }
    
    // 恢复购买 - 完整流程：Apple恢复 → 后端同步 → 刷新用户信息
    private func restorePurchases() {
        // 检查登录状态（用例9：用户未登录时提示）
        guard authService.isLoggedIn else {
            alertMessage = NSLocalizedString("请先登录购买时使用的手机号", comment: "")
            showError = true
            return
        }
        
        // 防抖：1秒内不可重复点击
        if let last = lastRestoreTime, Date().timeIntervalSince(last) < 1.0 {
            return
        }
        lastRestoreTime = Date()
        
        isLoading = true
        
        Task {
            let result: (success: Bool, message: String)
            
            // 使用 TaskGroup 实现超时保护：30秒
            do {
                result = try await withThrowingTaskGroup(of: (success: Bool, message: String)?.self) { group in
                    // 任务1: 恢复购买
                    group.addTask {
                        let restoreResult = await StoreManager.shared.restorePurchases()
                        return restoreResult
                    }
                    
                    // 任务2: 超时计时器
                    group.addTask {
                        try await Task.sleep(nanoseconds: 30_000_000_000)
                        return nil  // 超时返回nil
                    }
                    
                    // 等待第一个完成的任务
                    if let firstResult = try await group.next(), let actualResult = firstResult {
                        group.cancelAll()
                        return actualResult
                    }
                    
                    // 如果是超时任务先完成（返回nil），取消其他任务
                    group.cancelAll()
                    return (false, NSLocalizedString("操作超时，请重试", comment: ""))
                }
            } catch {
                result = (false, NSLocalizedString("操作超时，请检查网络后重试", comment: ""))
            }
            
            // 刷新用户信息
            try? await authService.fetchCurrentUser()
            
            await MainActor.run {
                isLoading = false
                alertMessage = result.message
                if result.success {
                    showPurchaseSuccess = true
                } else {
                    showError = true
                }
            }
        }
    }
    
    // 打开系统订阅管理页面
    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    // 说明
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("说明", comment: ""))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("• 会员服务开通后立即生效\n• 月度/年度会员为自动续费订阅，到期前24小时自动扣费续订\n• 如需取消自动续费，请在到期前24小时在「设置-Apple ID-订阅」中取消\n• 永久会员为一次性购买，无需续费\n• 如有问题请联系客服：birdkingdom@163.com", comment: ""))
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
        case .monthly: return NSLocalizedString("月度会员", comment: "")
        case .yearly: return NSLocalizedString("年度会员", comment: "")
        case .lifetime: return NSLocalizedString("永久会员", comment: "")
        case .coupleLifetime: return NSLocalizedString("情侣永久会员", comment: "")
        }
    }
    
    /// 是否为自动续费订阅
    var isAutoRenewing: Bool {
        switch self {
        case .monthly, .yearly: return true
        case .lifetime, .coupleLifetime: return false
        }
    }
    
    /// 套餐包含的天数
    var days: Int {
        switch self {
        case .monthly: return 30
        case .yearly: return 365
        case .lifetime, .coupleLifetime: return 0 // 永久
        }
    }
    
    /// 续费说明
    var renewalInfo: String? {
        switch self {
        case .monthly: return NSLocalizedString("自动续费，可随时取消", comment: "")
        case .yearly: return NSLocalizedString("自动续费，可随时取消", comment: "")
        case .lifetime, .coupleLifetime: return nil
        }
    }
    
    var description: String {
        switch self {
        case .monthly: return NSLocalizedString("连续包月，每月自动续费", comment: "")
        case .yearly: return NSLocalizedString("连续包年，每年自动续费", comment: "")
        case .lifetime: return NSLocalizedString("一次购买，永久使用", comment: "")
        case .coupleLifetime: return NSLocalizedString("一次购买，情侣共享永久会员", comment: "")
        }
    }
    
    var price: Int {
        switch self {
        case .monthly: return 6
        case .yearly: return 66
        case .lifetime: return 198
        case .coupleLifetime: return 520
        }
    }
    
    var originalPrice: Int? {
        switch self {
        case .monthly: return nil
        case .yearly: return 72  // 6元/月 * 12个月 = 72元
        case .lifetime: return 288
        case .coupleLifetime: return 888
        }
    }
    
    var tag: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return NSLocalizedString("推荐", comment: "")
        case .lifetime: return NSLocalizedString("最划算", comment: "")
        case .coupleLifetime: return NSLocalizedString("💕 浪漫", comment: "")
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
    
    // Apple 内购产品ID
    var productId: String {
        switch self {
        case .monthly: return "com.birdkingdom.vip.monthly"
        case .yearly: return "com.birdkingdom.vip.yearly"
        case .lifetime: return "com.birdkingdom.vip.lifetime"
        case .coupleLifetime: return "com.birdkingdom.vip.couple.lifetime"
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
