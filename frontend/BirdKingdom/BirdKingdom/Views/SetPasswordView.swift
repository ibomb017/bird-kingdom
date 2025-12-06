import SwiftUI

struct SetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 说明文字
                    VStack(alignment: .leading, spacing: 8) {
                        Text(hasPassword ? "修改密码" : "设置密码")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(hasPassword ? "设置后可使用密码快速登录" : "首次设置密码后，可使用密码登录")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    
                    // 密码输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("密码")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if showPassword {
                                TextField("请输入密码（6-20位）", text: $password)
                            } else {
                                SecureField("请输入密码（6-20位）", text: $password)
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
                        Text("确认密码")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if showConfirmPassword {
                                TextField("请再次输入密码", text: $confirmPassword)
                            } else {
                                SecureField("请再次输入密码", text: $confirmPassword)
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
                        setPassword()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("确认")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSubmit ? forestGreen : Color(uiColor: .systemGray4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!canSubmit || isSaving)
                    .padding(.top, 12)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .alert("设置成功", isPresented: $showSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("密码已设置，下次可使用密码登录")
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var hasPassword: Bool {
        // TODO: 从用户信息判断是否已设置密码
        return false
    }
    
    private var canSubmit: Bool {
        password.count >= 6 && password == confirmPassword
    }
    
    private var passwordStrength: (icon: String, text: String, color: Color) {
        if password.count < 6 {
            return ("xmark.circle", "密码长度至少6位", .red)
        } else if password.count < 8 {
            return ("checkmark.circle", "密码强度：弱", .orange)
        } else if password.count < 12 {
            return ("checkmark.circle.fill", "密码强度：中", .blue)
        } else {
            return ("checkmark.circle.fill", "密码强度：强", .green)
        }
    }
    
    private func setPassword() {
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            showError = true
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "密码长度至少6位"
            showError = true
            return
        }
        
        isSaving = true
        Task {
            do {
                try await ApiService.shared.setPassword(password: password)
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
