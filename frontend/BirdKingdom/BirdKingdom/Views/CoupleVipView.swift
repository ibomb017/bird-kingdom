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
    
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let pinkColor = Color(red: 1.0, green: 0.75, blue: 0.8)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 情侣会员说明
                    coupleVipHeader
                    
                    // 当前状态
                    if isCoupleVip {
                        // 已绑定状态
                        boundStatusSection
                    } else {
                        // 未绑定状态
                        unboundStatusSection
                    }
                    
                    // 特权说明
                    privilegesSection
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [pinkColor.opacity(0.1), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("情侣会员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") { dismiss() }
                }
            }
            .alert("绑定成功", isPresented: $showBindSuccess) {
                Button("确定") {
                    Task {
                        try? await authService.fetchCurrentUser()
                    }
                }
            } message: {
                Text("恭喜你们成为情侣会员！💕")
            }
            .alert("解绑确认", isPresented: $showUnbindConfirm) {
                Button("取消", role: .cancel) {}
                Button("确认解绑", role: .destructive) {
                    unbindPartner()
                }
            } message: {
                Text("解绑后将降级为普通永久会员，情侣标识将永久失效，无法恢复。确定要解绑吗？")
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
        }
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
            
            Text("情侣永久会员")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("专属情侣标识 · 爱的结晶")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // 已绑定状态
    private var boundStatusSection: some View {
        VStack(spacing: 16) {
            Text("已绑定情侣")
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
                                Text(authService.currentUser?.nickname.prefix(1) ?? "我")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            )
                        Text(authService.currentUser?.nickname ?? "我")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    // 爱心连接
                    VStack(spacing: 4) {
                        Text("💕")
                            .font(.title)
                        Text("已绑定")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // 伴侣
                    VStack(spacing: 8) {
                        Circle()
                            .fill(pinkColor.opacity(0.5))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text("TA")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            )
                        Text("情侣伴侣")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: pinkColor.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // 解绑按钮
                Button {
                    showUnbindConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "link.badge.minus")
                        Text("解除绑定")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // 警告提示
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("解绑后将降级为普通永久会员，情侣标识永久失效")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // 未绑定状态
    private var unboundStatusSection: some View {
        VStack(spacing: 16) {
            Text("绑定情侣伴侣")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("伴侣手机号")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("请输入对方手机号", text: $partnerPhone)
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
                            Text("发送绑定请求")
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
                    Text("绑定条件：")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("双方都必须是情侣永久会员")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("双方都未绑定其他伴侣")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color(uiColor: .systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    // 特权说明
    private var privilegesSection: some View {
        VStack(spacing: 16) {
            Text("情侣专属特权")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                privilegeRow(icon: "heart.circle.fill", title: "💕 粉红色泡泡标识", description: "专属情侣标识")
                privilegeRow(icon: "sparkles", title: "💖 爱的结晶", description: "共同鸟儿特殊标记")
                privilegeRow(icon: "paintpalette.fill", title: "🎨 情侣专属主题", description: "粉色浪漫主题")
                privilegeRow(icon: "crown.fill", title: "👑 永久会员权益", description: "所有VIP特权")
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
        .background(Color.white)
        .cornerRadius(10)
    }
    
    // 计算属性
    private var isCoupleVip: Bool {
        guard let user = authService.currentUser else { return false }
        // 检查是否已绑定情侣伴侣
        return user.isCoupleVip == true && user.couplePartnerId != nil
    }
    
    // 绑定伴侣
    private func bindPartner() {
        guard partnerPhone.count == 11 else { return }
        
        isBinding = true
        Task {
            do {
                // 调用API绑定
                // TODO: 实现API调用
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    isBinding = false
                    showBindSuccess = true
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
}

#Preview {
    CoupleVipView()
}
