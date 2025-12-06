import SwiftUI

// MARK: - 登录/注册视图
struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var phone = ""
    @State private var verificationCode = ""
    @State private var isCodeSent = false
    @State private var countdown = 0
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUserAgreement = false
    @State private var showPrivacyPolicy = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        // Logo 和标题
                        VStack(spacing: 16) {
                            Image(systemName: "bird.fill")
                                .font(.system(size: 60))
                                .foregroundColor(forestGreen)
                            
                            Text("鸟鸟王国")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("记录每一个与鸟儿相伴的日子")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // 输入区域
                        VStack(spacing: 20) {
                            // 手机号输入
                            VStack(alignment: .leading, spacing: 8) {
                                Text("手机号")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Text("+86")
                                        .foregroundColor(.secondary)
                                    
                                    TextField("请输入手机号", text: $phone)
                                        .keyboardType(.phonePad)
                                        .disabled(isCodeSent)
                                }
                                .padding()
                                .background(Color(uiColor: .systemGray6))
                                .cornerRadius(12)
                            }
                            
                            // 验证码输入
                            if isCodeSent {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("验证码")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        TextField("请输入验证码", text: $verificationCode)
                                            .keyboardType(.numberPad)
                                        
                                        Button {
                                            if countdown == 0 {
                                                sendCode()
                                            }
                                        } label: {
                                            Text(countdown > 0 ? "\(countdown)s" : "重新发送")
                                                .font(.subheadline)
                                                .foregroundColor(countdown > 0 ? .gray : forestGreen)
                                        }
                                        .disabled(countdown > 0)
                                    }
                                    .padding()
                                    .background(Color(uiColor: .systemGray6))
                                    .cornerRadius(12)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // 提示信息
                        if !isCodeSent {
                            Text("未注册的手机号将自动创建账号")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 底部按钮
                VStack(spacing: 16) {
                    Button {
                        if isCodeSent {
                            login()
                        } else {
                            sendCode()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isCodeSent ? "登录 / 注册" : "获取验证码")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isButtonEnabled ? forestGreen : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(!isButtonEnabled || isLoading)
                    
                    // 协议
                    HStack(spacing: 4) {
                        Text("登录即表示同意")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("用户协议") {
                            showUserAgreement = true
                        }
                            .font(.caption)
                            .foregroundColor(forestGreen)
                        Text("和")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("隐私政策") {
                            showPrivacyPolicy = true
                        }
                            .font(.caption)
                            .foregroundColor(forestGreen)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showUserAgreement) {
                UserAgreementView()
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isButtonEnabled: Bool {
        if isCodeSent {
            return phone.count == 11 && verificationCode.count >= 4
        } else {
            return phone.count == 11
        }
    }
    
    private func sendCode() {
        guard phone.count == 11 else {
            errorMessage = "请输入正确的手机号"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let response = try await authService.sendVerificationCode(phone: phone)
                await MainActor.run {
                    isLoading = false
                    if response.success {
                        withAnimation {
                            isCodeSent = true
                        }
                        startCountdown()
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // 开发环境：模拟发送成功
                    withAnimation {
                        isCodeSent = true
                    }
                    startCountdown()
                }
            }
        }
    }
    
    private func login() {
        isLoading = true
        
        Task {
            do {
                let response = try await authService.login(phone: phone, code: verificationCode)
                await MainActor.run {
                    isLoading = false
                    if response.success {
                        dismiss()
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "登录失败，请稍后重试"
                    showError = true
                }
            }
        }
    }
    
    private func startCountdown() {
        countdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    LoginView()
}
