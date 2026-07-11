import SwiftUI

// MARK: - 情侣会员管理页面
struct CoupleVipView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var partnerPhone = ""
    @State private var isBinding = false
    @State private var showBindSuccess = false
    @State private var showUnbindConfirm = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showEditPending = false  // 修改预留绑定弹窗
    @State private var newPartnerPhone = ""     // 新的伴侣手机号
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // 邀请确认相关
    @State private var hasPendingInvitation = false
    @State private var inviterName: String?
    @State private var inviterAvatarUrl: String?
    @State private var showInvitationAlert = false
    @State private var isProcessingInvitation = false
    
    private var primaryColor: Color { themeManager.primaryColor }
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let pinkColor = Color(red: 1.0, green: 0.75, blue: 0.8)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 情侣会员说明
                coupleVipHeader
                
                // 当前状态
                if isCoupleVip {
                    // 已绑定状态
                    boundStatusSection
                } else if hasPendingBinding {
                    // 预留绑定状态
                    pendingStatusSection
                } else {
                    // 未绑定状态
                    unboundStatusSection
                }
                
                // 特权说明
                privilegesSection
            }
            .padding(20)
        }
        .themedBackground()
        .themedNavigationBar(title: NSLocalizedString("情侣会员", comment: ""))
        .background(
            LinearGradient(
                colors: [pinkColor.opacity(0.1), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .alert(NSLocalizedString("绑定成功", comment: ""), isPresented: $showBindSuccess) {
            Button(NSLocalizedString("确定", comment: "")) {
                Task {
                    try? await authService.fetchCurrentUser()
                }
            }
        } message: {
            Text(NSLocalizedString("恭喜你们成为情侣会员！💕", comment: ""))
        }
        .alert(NSLocalizedString("解绑确认", comment: ""), isPresented: $showUnbindConfirm) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("确认解绑", comment: ""), role: .destructive) {
                unbindPartner()
            }
        } message: {
            Text(NSLocalizedString("解绑后将降级为普通永久会员，情侣标识将永久失效，无法恢复。确定要解绑吗？", comment: ""))
        }
        .alert(NSLocalizedString("错误", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: "")) {}
        } message: {
            Text(errorMessage)
        }
        .navigationDestination(isPresented: $showEditPending) {
            editPendingSheet
                .hidesTabBar()
        }
        .alert(NSLocalizedString("收到情侣邀请 💕", comment: ""), isPresented: $showInvitationAlert) {
            Button(NSLocalizedString("拒绝", comment: ""), role: .destructive) {
                rejectInvitation()
            }
            Button(NSLocalizedString("接受", comment: "")) {
                acceptInvitation()
            }
        } message: {
            let formatStr = NSLocalizedString("%@ 邀请您成为情侣伴侣，接受后将共享会员权益", comment: "")
            let name = inviterName ?? NSLocalizedString("对方", comment: "")
            Text(String(format: formatStr, name))
        }
        .onAppear {
            checkPendingInvitation()
        }
    }
    
    // 修改预留绑定手机号的弹窗
    private var editPendingSheet: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(pinkColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(pinkColor)
            }
            
            // 标题
            VStack(spacing: 8) {
                Text(NSLocalizedString("修改预留绑定", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(NSLocalizedString("请输入正确的伴侣手机号", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 手机号输入
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("伴侣手机号", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(pinkColor)
                    
                    TextField(NSLocalizedString("请输入伴侣的手机号", comment: ""), text: $newPartnerPhone)
                        .keyboardType(.phonePad)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // 按钮
            VStack(spacing: 12) {
                Button {
                    updatePendingBinding()
                } label: {
                    HStack {
                        if isBinding {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(NSLocalizedString("确认修改", comment: ""))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [pinkColor, pinkColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(newPartnerPhone.isEmpty || isBinding)
                .opacity(newPartnerPhone.isEmpty ? 0.6 : 1.0)
                
                Button {
                    showEditPending = false
                } label: {
                    Text(NSLocalizedString("取消", comment: ""))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(
            LinearGradient(
                colors: [pinkColor.opacity(0.08), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .themedNavigationBar(title: NSLocalizedString("修改手机号", comment: ""))
    }
    
    // 情侣会员头部
    private var coupleVipHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [pinkColor, goldColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text("💕")
                    .font(.system(size: 40))
            }
            
            Text(NSLocalizedString("情侣永久会员", comment: ""))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(NSLocalizedString("专属情侣标识 · 爱的结晶", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // 已绑定状态
    private var boundStatusSection: some View {
        let partnerName = authService.currentUser?.couplePartnerName ?? "TA"
        let myPrefix = authService.currentUser?.nickname.isEmpty == false ? String(authService.currentUser!.nickname.prefix(1)) : NSLocalizedString("我", comment: "")
        let myName = authService.currentUser?.nickname ?? NSLocalizedString("我", comment: "")
        let partnerPrefix = String(partnerName.prefix(1))
        
        return VStack(spacing: 16) {
            Text(NSLocalizedString("已绑定情侣", comment: ""))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // 情侣信息卡片
                HStack(spacing: 16) {
                    // 自己
                    VStack(spacing: 8) {
                        Circle()
                            .fill(goldColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(myPrefix)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            )
                        Text(myName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    // 爱心连接
                    VStack(spacing: 4) {
                        Text("💕")
                            .font(.title)
                        Text(NSLocalizedString("已绑定", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // 伴侣 - 显示真实昵称
                    VStack(spacing: 8) {
                        Circle()
                            .fill(pinkColor.opacity(0.5))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(partnerPrefix)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            )
                        Text(partnerName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.adaptiveCard)
                .cornerRadius(16)
                .shadow(color: pinkColor.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // 解绑按钮
                Button {
                    showUnbindConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "link.badge.minus")
                        Text(NSLocalizedString("解除绑定", comment: ""))
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // 警告提示（苹果原生风格）
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("解绑后将降级为普通永久会员，情侣标识永久失效", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // 未绑定状态
    private var unboundStatusSection: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("绑定情侣伴侣", comment: ""))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("伴侣手机号", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField(NSLocalizedString("请输入对方手机号", comment: ""), text: $partnerPhone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(8)
                }
                
                // 绑定按钮
                Button {
                    bindPartner()
                } label: {
                    HStack {
                        if isBinding {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "heart.circle.fill")
                            Text(NSLocalizedString("发送绑定请求", comment: ""))
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [pinkColor, goldColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(partnerPhone.count != 11 || isBinding)
                
                // 绑定条件
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("绑定条件：", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(NSLocalizedString("双方都必须是情侣永久会员", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(NSLocalizedString("双方都未绑定其他伴侣", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            .padding(16)
            .background(Color.adaptiveCard)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    // 特权说明
    private var privilegesSection: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("情侣专属特权", comment: ""))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                privilegeRow(icon: "heart.circle.fill", title: NSLocalizedString("💕 粉红色泡泡标识", comment: ""), description: NSLocalizedString("专属情侣标识", comment: ""))
                privilegeRow(icon: "sparkles", title: NSLocalizedString("💖 爱的结晶", comment: ""), description: NSLocalizedString("共同鸟儿特殊标记", comment: ""))
                privilegeRow(icon: "paintpalette.fill", title: NSLocalizedString("🎨 情侣专属主题", comment: ""), description: NSLocalizedString("粉色浪漫主题", comment: ""))
                privilegeRow(icon: "crown.fill", title: NSLocalizedString("👑 永久会员权益", comment: ""), description: NSLocalizedString("所有VIP特权", comment: ""))
            }
        }
    }
    
    private func privilegeRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(pinkColor)
                .frame(width: 36, height: 36)
                .background(pinkColor.opacity(0.2))
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
        .background(Color.adaptiveCard)
        .cornerRadius(10)
    }
    
    // 计算属性
    private var isCoupleVip: Bool {
        guard let user = authService.currentUser else { return false }
        // 检查是否已绑定情侣伴侣
        return user.isCoupleVip == true && user.couplePartnerId != nil
    }
    
    // 是否有预留绑定
    private var hasPendingBinding: Bool {
        guard let user = authService.currentUser else { return false }
        return user.pendingCouplePhone != nil && !user.pendingCouplePhone!.isEmpty
    }
    
    // 预留绑定状态视图
    private var pendingStatusSection: some View {
        let isPendingConfirmation = authService.currentUser?.isPendingConfirmation ?? false
        let pendingPartnerName = authService.currentUser?.pendingCouplePartnerName
        
        return VStack(spacing: 16) {
            Text(isPendingConfirmation ? NSLocalizedString("等待伴侣确认", comment: "") : NSLocalizedString("等待伴侣注册", comment: ""))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // 等待状态卡片
                VStack(spacing: 16) {
                    // 动画图标
                    ZStack {
                        Circle()
                            .stroke(pinkColor.opacity(0.3), lineWidth: 3)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(pinkColor.opacity(0.1))
                            .frame(width: 70, height: 70)
                        
                        Text(isPendingConfirmation ? "💕" : "⏳")
                            .font(.system(size: 30))
                    }
                    
                    // 根据状态显示不同文案
                    if isPendingConfirmation, let partnerName = pendingPartnerName {
                        // 等待对方确认
                        VStack(spacing: 8) {
                            Text(NSLocalizedString("已邀请", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(partnerName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(pinkColor)
                            
                            Text(NSLocalizedString("等待对方在会员页面确认", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // 等待对方注册
                        VStack(spacing: 8) {
                            Text(NSLocalizedString("已为以下手机号预留情侣绑定", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let pendingPhone = authService.currentUser?.pendingCouplePhone {
                                Text(pendingPhone)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(pinkColor)
                            }
                            
                            Text(NSLocalizedString("对方注册后需确认才能成为您的情侣伴侣", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color.adaptiveCard)
                .cornerRadius(16)
                .shadow(color: pinkColor.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // 操作按钮
                HStack(spacing: 12) {
                    // 修改手机号按钮
                    Button {
                        newPartnerPhone = authService.currentUser?.pendingCouplePhone ?? ""
                        showEditPending = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil.circle")
                            Text(NSLocalizedString("修改手机号", comment: ""))
                        }
                        .font(.subheadline)
                        .foregroundColor(pinkColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(pinkColor.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // 取消预留按钮
                    Button {
                        cancelPendingBinding()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text(NSLocalizedString("取消预留", comment: ""))
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                
                // 提示
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(NSLocalizedString("您可以通知对方使用该手机号注册，注册后将自动绑定。如果手机号填错了，可以点击修改。", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // 取消预留绑定
    private func cancelPendingBinding() {
        Task {
            do {
                try await ApiService.shared.cancelPendingCoupleBinding()
                await MainActor.run {
                    _ = Task {
                        try? await authService.fetchCurrentUser()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "取消失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // 绑定伴侣
    private func bindPartner() {
        guard partnerPhone.count == 11 else { return }
        
        isBinding = true
        Task {
            do {
                let response = try await ApiService.shared.bindCouplePartner(partnerPhone: partnerPhone)
                
                await MainActor.run {
                    isBinding = false
                    if response.success {
                        showBindSuccess = true
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isBinding = false
                    errorMessage = "绑定失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // 解绑伴侣
    private func unbindPartner() {
        Task {
            do {
                try await ApiService.shared.unbindCouplePartner()
                
                await MainActor.run {
                    // 刷新用户信息
                    Task {
                        try? await authService.fetchCurrentUser()
                    }
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "解绑失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // 修改预留绑定手机号
    private func updatePendingBinding() {
        guard !newPartnerPhone.isEmpty else { return }
        
        isBinding = true
        
        Task {
            do {
                let response = try await ApiService.shared.updatePendingCoupleBinding(newPartnerPhone: newPartnerPhone)
                
                await MainActor.run {
                    isBinding = false
                    showEditPending = false
                    
                    if response.success {
                        showBindSuccess = true
                        // 刷新用户信息
                        Task {
                            try? await authService.fetchCurrentUser()
                        }
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isBinding = false
                    errorMessage = "修改失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // 检查是否有待确认的邀请
    private func checkPendingInvitation() {
        Task {
            do {
                let response = try await authService.getPendingCoupleInvitation()
                await MainActor.run {
                    hasPendingInvitation = response.hasPendingInvitation
                    inviterName = response.inviterName
                    inviterAvatarUrl = response.inviterAvatarUrl
                    if hasPendingInvitation {
                        showInvitationAlert = true
                    }
                }
            } catch {
                print("检查邀请失败：\(error)")
            }
        }
    }
    
    // 接受邀请
    private func acceptInvitation() {
        isProcessingInvitation = true
        Task {
            do {
                let response = try await authService.acceptCoupleInvitation()
                await MainActor.run {
                    isProcessingInvitation = false
                    if response.success {
                        showBindSuccess = true
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingInvitation = false
                    errorMessage = "接受邀请失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // 拒绝邀请
    private func rejectInvitation() {
        isProcessingInvitation = true
        Task {
            do {
                _ = try await authService.rejectCoupleInvitation()
                await MainActor.run {
                    isProcessingInvitation = false
                    hasPendingInvitation = false
                }
            } catch {
                await MainActor.run {
                    isProcessingInvitation = false
                    errorMessage = "拒绝邀请失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    CoupleVipView()
}
