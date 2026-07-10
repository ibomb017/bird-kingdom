import SwiftUI

struct SetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    // 验证方式：0 = 原密码验证，1 = 验证码验证
    @State private var verifyMethod = 0
    
    @State private var oldPassword = ""
    @State private var verificationCode = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showOldPassword = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    // 验证码相关
    @State private var isSendingCode = false
    @State private var countdown = 0
    @State private var timer: Timer?
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    private var hasPassword: Bool {
        authService.currentUser?.hasPassword ?? false
    }
    
    private var userPhone: String {
        authService.currentUser?.phone ?? ""
    }
    
    var body: some View {
        NavigationStack {
            
            ScrollView {
                VStack(spacing: 24) {
                    // 说明文字
                    VStack(alignment: .leading, spacing: 8) {
                        Text(hasPassword ? NSLocalizedString("修改密码", comment: "") : NSLocalizedString("设置密码", comment: ""))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(hasPassword ? NSLocalizedString("修改密码后可使用新密码登录", comment: "") : NSLocalizedString("首次设置密码后，可使用密码登录", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    
                    // 验证方式选择（仅修改密码时显示）
                    if hasPassword {
                        Picker(NSLocalizedString("验证方式", comment: ""), selection: $verifyMethod) {
                            Text(NSLocalizedString("原密码验证", comment: "")).tag(0)
                            Text(NSLocalizedString("验证码验证", comment: "")).tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        if verifyMethod == 0 {
                            // 原密码输入
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 2) {
                                    Text(NSLocalizedString("原密码", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("*")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                HStack {
                                    if showOldPassword {
                                        TextField(NSLocalizedString("请输入原密码", comment: ""), text: $oldPassword)
                                    } else {
                                        SecureField(NSLocalizedString("请输入原密码", comment: ""), text: $oldPassword)
                                    }
                                    
                                    Button {
                                        showOldPassword.toggle()
                                    } label: {
                                        Image(systemName: showOldPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(Color(uiColor: .systemGray6))
                                .cornerRadius(10)
                            }
                        } else {
                            // 验证码输入
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 2) {
                                    Text(L10n.verificationCode)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("*")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                HStack {
                                    TextField(NSLocalizedString("请输入验证码", comment: ""), text: $verificationCode)
                                        .keyboardType(.numberPad)
                                    
                                    Button {
                                        sendVerificationCode()
                                    } label: {
                                        Text(countdown > 0 ? "\(countdown)s" : NSLocalizedString("获取验证码", comment: ""))
                                            .font(.subheadline)
                                            .foregroundColor(countdown > 0 ? .gray : primaryColor)
                                    }
                                    .disabled(countdown > 0 || isSendingCode)
                                }
                                .padding()
                                .background(Color(uiColor: .systemGray6))
                                .cornerRadius(10)
                                
                                Text("验证码将发送至 \(maskedPhone)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 新密码输入
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 2) {
                            Text(hasPassword ? NSLocalizedString("新密码", comment: "") : L10n.password)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("*")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            if showPassword {
                                TextField(NSLocalizedString("请输入密码（6-20位）", comment: ""), text: $password)
                            } else {
                                SecureField(NSLocalizedString("请输入密码（6-20位）", comment: ""), text: $password)
                            }
                            
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // 确认密码输入
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 2) {
                            Text(NSLocalizedString("确认密码", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("*")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        HStack {
                            if showConfirmPassword {
                                TextField(NSLocalizedString("请再次输入密码", comment: ""), text: $confirmPassword)
                            } else {
                                SecureField(NSLocalizedString("请再次输入密码", comment: ""), text: $confirmPassword)
                            }
                            
                            Button {
                                showConfirmPassword.toggle()
                            } label: {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // 密码强度提示
                    if !password.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: passwordStrength.icon)
                                .foregroundColor(passwordStrength.color)
                            Text(passwordStrength.text)
                                .font(.caption)
                                .foregroundColor(passwordStrength.color)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 确认按钮
                    Button {
                        savePassword()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(L10n.confirm)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSubmit ? primaryColor : Color(uiColor: .systemGray4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!canSubmit || isSaving)
                    .padding(.top, 12)
                }
                .padding()
            }
            .themedBackground()
            .themedNavigationBar(title: hasPassword ? NSLocalizedString("修改密码", comment: "") : NSLocalizedString("设置密码", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundColor(primaryColor)
                }
            }
        }
        .alert(hasPassword ? NSLocalizedString("修改成功", comment: "") : NSLocalizedString("设置成功", comment: ""), isPresented: $showSuccess) {
            Button(NSLocalizedString("确定", comment: "")) {
                dismiss()
            }
        } message: {
            Text(hasPassword ? NSLocalizedString("密码已修改，下次请使用新密码登录", comment: "") : NSLocalizedString("密码已设置，下次可使用密码登录", comment: ""))
        }
        .alert(NSLocalizedString("错误", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var canSubmit: Bool {
        let baseCheck = password.count >= 6 && password == confirmPassword
        if hasPassword {
            if verifyMethod == 0 {
                return baseCheck && oldPassword.count >= 6
            } else {
                return baseCheck && verificationCode.count >= 4
            }
        }
        return baseCheck
    }
    
    private var maskedPhone: String {
        guard userPhone.count >= 7 else { return userPhone }
        let start = userPhone.prefix(3)
        let end = userPhone.suffix(4)
        return "\(start)****\(end)"
    }
    
    private var passwordStrength: (icon: String, text: String, color: Color) {
        if password.count < 6 {
            return ("xmark.circle", NSLocalizedString("密码长度至少6位", comment: ""), .red)
        } else if password.count < 8 {
            return ("checkmark.circle", NSLocalizedString("密码强度：弱", comment: ""), .orange)
        } else if password.count < 12 {
            return ("checkmark.circle.fill", NSLocalizedString("密码强度：中", comment: ""), .blue)
        } else {
            return ("checkmark.circle.fill", NSLocalizedString("密码强度：强", comment: ""), .green)
        }
    }
    
    private func sendVerificationCode() {
        guard !userPhone.isEmpty else {
            errorMessage = NSLocalizedString("无法获取手机号", comment: "")
            showError = true
            return
        }
        
        isSendingCode = true
        Task {
            do {
                try await ApiService.shared.sendVerificationCode(phone: userPhone)
                await MainActor.run {
                    isSendingCode = false
                    startCountdown()
                }
            } catch {
                await MainActor.run {
                    isSendingCode = false
                    errorMessage = "发送验证码失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
    
    private func savePassword() {
        guard password == confirmPassword else {
            errorMessage = NSLocalizedString("两次输入的密码不一致", comment: "")
            showError = true
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = NSLocalizedString("密码长度至少6位", comment: "")
            showError = true
            return
        }
        
        isSaving = true
        Task {
            do {
                if hasPassword {
                    if verifyMethod == 0 {
                        // 修改密码（需要验证旧密码）
                        try await ApiService.shared.changePassword(oldPassword: oldPassword, newPassword: password)
                    } else {
                        // 修改密码（通过验证码）
                        try await ApiService.shared.resetPassword(phone: userPhone, code: verificationCode, newPassword: password)
                    }
                } else {
                    // 首次设置密码
                    try await ApiService.shared.setPassword(password: password)
                }
                
                // 更新用户信息
                if var user = authService.currentUser {
                    user.hasPassword = true
                    authService.currentUser = user
                }
                
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    SetPasswordView()
}
