import SwiftUI

// MARK: - 情侣绑定视图（购买情侣永久会员后弹出）
struct CoupleBindingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    @State private var partnerPhone = ""
    @State private var isBinding = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onBindSuccess: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var primaryColor: Color { themeManager.primaryColor }
    private let pinkColor = Color(red: 1.0, green: 0.6, blue: 0.7)
    
    var body: some View {
        NavigationStack {
            
            VStack(spacing: 24) {
                Spacer()
                
                // 图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [pinkColor.opacity(0.3), pinkColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Text("💕")
                        .font(.system(size: 50))
                }
                
                // 标题
                VStack(spacing: 8) {
                    Text(NSLocalizedString("恭喜成为情侣永久会员！", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(pinkColor)
                    
                    Text(NSLocalizedString("请输入伴侣的手机号完成绑定", comment: ""))
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
                        
                        TextField(NSLocalizedString("请输入伴侣的手机号", comment: ""), text: $partnerPhone)
                            .keyboardType(.phonePad)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                
                // 说明
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(pinkColor.opacity(0.7))
                        Text(NSLocalizedString("绑定说明", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(NSLocalizedString("• 绑定后对方将自动升级为情侣永久会员", comment: ""))
                    Text(NSLocalizedString("• 绑定后双方可以共享鸟儿信息", comment: ""))
                    Text(NSLocalizedString("• 绑定后将无法解绑，请谨慎操作", comment: ""))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(pinkColor.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 按钮
                VStack(spacing: 12) {
                    Button {
                        bindPartner()
                    } label: {
                        HStack {
                            if isBinding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(NSLocalizedString("立即绑定", comment: ""))
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
                    .disabled(partnerPhone.isEmpty || isBinding)
                    .opacity(partnerPhone.isEmpty ? 0.6 : 1.0)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("稍后再说", comment: ""))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .themedBackground()
        .themedNavigationBar(title: NSLocalizedString("绑定伴侣", comment: ""))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            }
        }
        .alert(NSLocalizedString("绑定成功", comment: ""), isPresented: $showSuccess) {
                Button(NSLocalizedString("确定", comment: "")) {
                    onBindSuccess()
                    dismiss()
                }
            } message: {
                Text(NSLocalizedString("恭喜你们成为情侣会员！💕 现在可以共享鸟儿信息了", comment: ""))
            }
            .alert(NSLocalizedString("绑定失败", comment: ""), isPresented: $showError) {
                Button(NSLocalizedString("确定", comment: "")) {}
            } message: {
                Text(errorMessage)
            }
    }
    
    // P1-02: 手机号格式校验
    private var isValidPhoneNumber: Bool {
        let phoneRegex = "^1[3-9]\\d{9}$"
        return partnerPhone.range(of: phoneRegex, options: .regularExpression) != nil
    }
    
    // P1-02: 校验是否为自己的手机号
    private var isOwnPhoneNumber: Bool {
        guard let currentUser = authService.currentUser else { return false }
        return partnerPhone == currentUser.phone
    }
    
    // P1-02: 获取校验错误信息
    private var validationError: String? {
        if partnerPhone.isEmpty {
            return nil
        }
        if !isValidPhoneNumber {
            return NSLocalizedString("请输入有效的11位手机号", comment: "")
        }
        if isOwnPhoneNumber {
            return NSLocalizedString("不能绑定自己的手机号", comment: "")
        }
        return nil
    }
    
    private func bindPartner() {
        // P1-02: 前端校验
        guard !partnerPhone.isEmpty else { return }
        
        if !isValidPhoneNumber {
            errorMessage = NSLocalizedString("请输入有效的11位手机号", comment: "")
            showError = true
            return
        }
        
        if isOwnPhoneNumber {
            errorMessage = NSLocalizedString("不能绑定自己的手机号", comment: "")
            showError = true
            return
        }
        
        isBinding = true
        
        Task {
            do {
                let response = try await ApiService.shared.bindCouplePartner(partnerPhone: partnerPhone)
                
                await MainActor.run {
                    isBinding = false
                    if response.success {
                        showSuccess = true
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isBinding = false
                    errorMessage = String(format: NSLocalizedString("绑定失败：%@", comment: ""), error.localizedDescription)
                    showError = true
                }
            }
        }
    }
}

#Preview {
    CoupleBindingView {
        print("绑定成功")
    }
}
