import SwiftUI

// MARK: - 登录模式
enum AuthMode {
    case login      // 登录
    case register   // 注册
}

// MARK: - 登录方式
enum LoginMethod {
    case password   // 密码登录（默认）
    case smsCode    // 验证码登录
}

// MARK: - 登录/注册视图
struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var authMode: AuthMode = .login
    @State private var loginMethod: LoginMethod = .password  // 默认密码登录
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var verificationCode = ""
    @State private var isCodeSent = false
    @State private var countdown = 0
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUserAgreement = false
    @State private var showPrivacyPolicy = false
    @State private var showPassword = false
    @State private var showForgotPassword = false
    @State private var isAgreed = false // P0 合规：用户主动勾选服务协议与隐私政策
    
    private var primaryColor: Color { themeManager.primaryColor }
    private var backgroundColor: Color { themeManager.backgroundColor }
    
    var body: some View {
        NavigationStack {
            KeyboardDismissScrollView {
                VStack(spacing: 32) {
                    // Logo 和标题
                    VStack(spacing: 16) {
                        Image("bird")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            
                        Text(NSLocalizedString("鸟鸟王国", comment: ""))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(NSLocalizedString("记录每一个与鸟儿相伴的日子", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // 登录/注册切换
                    HStack(spacing: 0) {
                        Button {
                            withAnimation {
                                authMode = .login
                                resetForm()
                            }
                        } label: {
                            Text(L10n.login)
                                .font(.headline)
                                .foregroundColor(authMode == .login ? primaryColor : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    VStack {
                                        Spacer()
                                        if authMode == .login {
                                            Rectangle()
                                                .fill(primaryColor)
                                                .frame(height: 2)
                                        }
                                    }
                                )
                        }
                        
                        Button {
                            withAnimation {
                                authMode = .register
                                resetForm()
                            }
                        } label: {
                            Text(L10n.register)
                                .font(.headline)
                                .foregroundColor(authMode == .register ? primaryColor : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    VStack {
                                        Spacer()
                                        if authMode == .register {
                                            Rectangle()
                                                .fill(primaryColor)
                                                .frame(height: 2)
                                        }
                                    }
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 输入区域
                    VStack(spacing: 20) {
                        // 手机号输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.phone)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("+86")
                                    .foregroundColor(.secondary)
                                
                                TextField(NSLocalizedString("请输入手机号", comment: ""), text: $phone)
                                    .keyboardType(.phonePad)
                                    .disabled(loginMethod == .smsCode && isCodeSent)
                            }
                            .padding()
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // 密码登录模式
                        if authMode == .login && loginMethod == .password {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.password)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    if showPassword {
                                        TextField(NSLocalizedString("请输入密码", comment: ""), text: $password)
                                    } else {
                                        SecureField(NSLocalizedString("请输入密码", comment: ""), text: $password)
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
                                .cornerRadius(12)
                            }
                        }
                        
                        // 注册模式 - 密码
                        if authMode == .register {
                            if isCodeSent {
                                Group {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(NSLocalizedString("设置密码", comment: ""))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
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
                                        .cornerRadius(12)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(NSLocalizedString("确认密码", comment: ""))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        SecureField(NSLocalizedString("请再次输入密码", comment: ""), text: $confirmPassword)
                                            .padding()
                                            .background(Color(uiColor: .systemGray6))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(passwordMismatch ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                                            )
                                        
                                        // P1-4 FIX: 实时密码匹配校验提示
                                        if passwordMismatch {
                                            HStack(spacing: 4) {
                                                Image(systemName: "exclamationmark.circle.fill")
                                                    .font(.caption2)
                                                Text(NSLocalizedString("两次输入的密码不一致", comment: ""))
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.red)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }
                                    
                                    // 注册需要验证码
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(L10n.verificationCode)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        HStack {
                                            TextField(NSLocalizedString("请输入验证码", comment: ""), text: $verificationCode)
                                                .keyboardType(.numberPad)
                                            
                                            Button {
                                                if countdown == 0 {
                                                    // 重发验证码时清空已输入的验证码
                                                    verificationCode = ""
                                                    sendCode()
                                                }
                                            } label: {
                                                Text(countdown > 0 ? "\(countdown)s" : NSLocalizedString("重新发送", comment: ""))
                                                    .font(.subheadline)
                                                    .foregroundColor(countdown > 0 ? .gray : primaryColor)
                                            }
                                            .disabled(countdown > 0)
                                        }
                                        .padding()
                                        .background(Color(uiColor: .systemGray6))
                                        .cornerRadius(12)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        
                        // 验证码登录模式
                        if authMode == .login && loginMethod == .smsCode {
                            if isCodeSent {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(L10n.verificationCode)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        TextField(NSLocalizedString("请输入验证码", comment: ""), text: $verificationCode)
                                            .keyboardType(.numberPad)
                                        
                                        Button {
                                            if countdown == 0 {
                                                // 重发验证码时清空已输入的验证码
                                                verificationCode = ""
                                                sendCode()
                                            }
                                        } label: {
                                            Text(countdown > 0 ? "\(countdown)s" : NSLocalizedString("重新发送", comment: ""))
                                                .font(.subheadline)
                                                .foregroundColor(countdown > 0 ? .gray : primaryColor)
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
                        
                        // 切换登录方式和忘记密码（仅登录模式显示）
                        if authMode == .login {
                            HStack {
                                Button {
                                    withAnimation {
                                        loginMethod = loginMethod == .password ? .smsCode : .password
                                        resetForm()
                                    }
                                } label: {
                                    Text(loginMethod == .password ? NSLocalizedString("验证码登录", comment: "") : NSLocalizedString("密码登录", comment: ""))
                                        .font(.subheadline)
                                        .foregroundColor(primaryColor)
                                }
                                
                                Spacer()
                                
                                // 忘记密码按钮（仅密码登录模式显示）
                                if loginMethod == .password {
                                    Button {
                                        showForgotPassword = true
                                    } label: {
                                        Text(NSLocalizedString("忘记密码？", comment: ""))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .themedBackground()
            .themedNavigationBar(title: NSLocalizedString("登录/注册", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
            // 底部按钮
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    Button {
                        handleMainButtonTap()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(mainButtonText)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isButtonEnabled ? primaryColor : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(!isButtonEnabled || isLoading)
                    
                    // 协议
                    HStack(alignment: .top, spacing: 6) {
                        Button {
                            isAgreed.toggle()
                        } label: {
                            Image(systemName: isAgreed ? "checkmark.square.fill" : "square")
                                .foregroundColor(isAgreed ? primaryColor : .secondary)
                                .font(.system(size: 16))
                        }
                        .padding(.top, 1)
                        
                        HStack(spacing: 0) {
                            Text(NSLocalizedString("eulaReadAndAgree", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button(NSLocalizedString("eulaUserAgreement", comment: "")) {
                                showUserAgreement = true
                            }
                            .font(.caption)
                            .foregroundColor(primaryColor)
                            Text(NSLocalizedString("和", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button(NSLocalizedString("eulaPrivacyPolicy", comment: "")) {
                                showPrivacyPolicy = true
                            }
                            .font(.caption)
                            .foregroundColor(primaryColor)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10) // Small padding from safe area edge
                .background(Color(uiColor: .systemBackground).opacity(0.9)) // Slight background for clarity
            }
        }
        .sheet(isPresented: $showUserAgreement) {
            UserAgreementView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .alert(L10n.hintTitle, isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // P1-4 FIX: 密码确认实时匹配校验
    private var passwordMismatch: Bool {
        // 只有在确认密码输入了内容后才进行匹配校验
        authMode == .register && !confirmPassword.isEmpty && password != confirmPassword
    }
    
    // 主按钮文字
    private var mainButtonText: String {
        if authMode == .login {
            if loginMethod == .password {
                return L10n.login
            } else {
                return isCodeSent ? L10n.login : L10n.getCode
            }
        } else {
            return isCodeSent ? L10n.register : L10n.getCode
        }
    }
    
    // P0 安全修复：密码登录时，只要有输入就允许点击，验证逻辑在点击后由后端完成
    // 这可以防止攻击者通过按钮状态推测密码是否满足特定条件
    private var isButtonEnabled: Bool {
        guard phone.count == 11 else { return false }
        
        if authMode == .login {
            if loginMethod == .password {
                // 只要密码不为空就允许点击，具体验证在loginWithPassword中进行
                return !password.isEmpty
            } else {
                if isCodeSent {
                    return verificationCode.count >= 4
                } else {
                    return true
                }
            }
        } else {
            // 注册模式
            if isCodeSent {
                return password.count >= 6 && password == confirmPassword && verificationCode.count >= 4
            } else {
                return true
            }
        }
    }
    
    private func resetForm() {
        isCodeSent = false
        verificationCode = ""
        password = ""
        confirmPassword = ""
        countdown = 0
        showPassword = false
    }
    
    private func handleMainButtonTap() {
        guard isAgreed else {
            errorMessage = NSLocalizedString("eulaPleaseAgree", comment: "")
            showError = true
            return
        }
        
        if authMode == .login {
            if loginMethod == .password {
                // 密码登录
                loginWithPassword()
            } else {
                // 验证码登录
                if isCodeSent {
                    submitAuth()
                } else {
                    sendCode()
                }
            }
        } else {
            // 注册
            if isCodeSent {
                submitAuth()
            } else {
                sendCode()
            }
        }
    }
    
    private func loginWithPassword() {
        guard phone.count == 11 else {
            errorMessage = NSLocalizedString("请输入正确的手机号", comment: "")
            showError = true
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = NSLocalizedString("密码至少6位", comment: "")
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authService.loginWithPassword(phone: phone, password: password)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func sendCode() {
        guard phone.count == 11 else {
            errorMessage = NSLocalizedString("请输入正确的手机号", comment: "")
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let response: SendCodeResponse
                if authMode == .login {
                    response = try await authService.sendLoginCode(phone: phone)
                } else {
                    response = try await authService.sendRegisterCode(phone: phone)
                }
                
                await MainActor.run {
                    isLoading = false
                    if response.success {
                        withAnimation {
                            isCodeSent = true
                        }
                        startCountdown()
                    } else {
                        errorMessage = response.message ?? NSLocalizedString("发送失败", comment: "")
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = NSLocalizedString("发送验证码失败，请稍后重试", comment: "")
                    showError = true
                }
            }
        }
    }
    
    private func submitAuth() {
        isLoading = true
        
        Task {
            do {
                let response: LoginResponse
                if authMode == .login {
                    // 验证码登录
                    response = try await authService.login(phone: phone, code: verificationCode)
                } else {
                    // 注册（带密码）
                    response = try await authService.register(phone: phone, code: verificationCode, password: password)
                }
                
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
                    errorMessage = authMode == .login ? NSLocalizedString("登录失败，请稍后重试", comment: "") : NSLocalizedString("注册失败，请稍后重试", comment: "")
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

// MARK: - 注册后设置密码视图
struct RegisterSetPasswordView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void
    
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(primaryColor)
                    
                    Text(NSLocalizedString("设置登录密码", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(NSLocalizedString("设置密码后可以使用密码快速登录", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.password)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField(NSLocalizedString("请输入密码（至少6位）", comment: ""), text: $password)
                            .padding()
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("确认密码", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField(NSLocalizedString("请再次输入密码", comment: ""), text: $confirmPassword)
                            .padding()
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button {
                    setPassword()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(NSLocalizedString("完成设置", comment: ""))
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isButtonEnabled ? primaryColor : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(!isButtonEnabled || isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .themedBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("跳过", comment: "")) {
                        dismiss()
                        onComplete()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .alert(L10n.hintTitle, isPresented: $showError) {
                Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .interactiveDismissDisabled()
    }
    
    private var isButtonEnabled: Bool {
        password.count >= 6 && password == confirmPassword
    }
    
    private func setPassword() {
        guard password.count >= 6 else {
            errorMessage = NSLocalizedString("密码至少需要6位", comment: "")
            showError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = NSLocalizedString("两次输入的密码不一致", comment: "")
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authService.setPassword(password: password)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = NSLocalizedString("设置密码失败，请稍后重试", comment: "")
                    showError = true
                }
            }
        }
    }
}

// MARK: - 忘记密码视图
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var step: ForgotPasswordStep = .phone
    @State private var phone = ""
    @State private var verificationCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var countdown = 0
    @State private var showPassword = false
    
    // 固定使用默认森林绿主题色（未登录页面）- but updated to use themeManager if preferred, though comment says fixed.
    // I will respect the original code's preference or use themeManager if appropriate. 
    // The original code used a hardcoded color. I'll stick to themeManager for consistency if it's the right choice, 
    // but the original code said "Fixed use default forest green (unlogged page)". 
    // Let's use ThemeManager but fallback to a default if theme manager isn't applicable? 
    // Actually, LoginView uses ThemeManager, so ForgotPasswordView should too.
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    enum ForgotPasswordStep {
        case phone       // 输入手机号
        case code        // 输入验证码
        case password    // 设置新密码
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // 标题
                VStack(spacing: 16) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 50))
                        .foregroundColor(primaryColor)
                    
                    Text(NSLocalizedString("重置密码", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(stepDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // 输入区域
                VStack(spacing: 20) {
                    switch step {
                    case .phone:
                        phoneInputSection
                    case .code:
                        codeInputSection
                    case .password:
                        passwordInputSection
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // 底部按钮
                Button {
                    handleNextStep()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(buttonText)
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isButtonEnabled ? primaryColor : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(!isButtonEnabled || isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .themedBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if step == .phone {
                            dismiss()
                        } else {
                            withAnimation {
                                step = step == .password ? .code : .phone
                            }
                        }
                    } label: {
                        Image(systemName: step == .phone ? "xmark" : "chevron.left")
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert(L10n.hintTitle, isPresented: $showError) {
                Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert(NSLocalizedString("重置成功", comment: ""), isPresented: $showSuccess) {
                Button(NSLocalizedString("确定", comment: "")) {
                    dismiss()
                }
            } message: {
                Text(NSLocalizedString("密码已重置，请使用新密码登录", comment: ""))
            }
        }
    }
    
    private var stepDescription: String {
        switch step {
        case .phone:
            return NSLocalizedString("请输入您的注册手机号", comment: "")
        case .code:
            return String(format: NSLocalizedString("验证码已发送至 %@", comment: ""), phone)
        case .password:
            return NSLocalizedString("请设置您的新密码", comment: "")
        }
    }
    
    private var buttonText: String {
        switch step {
        case .phone:
            return L10n.getCode
        case .code:
            return NSLocalizedString("验证", comment: "")
        case .password:
            return NSLocalizedString("确认重置", comment: "")
        }
    }
    
    private var isButtonEnabled: Bool {
        switch step {
        case .phone:
            return phone.count == 11
        case .code:
            return verificationCode.count == 6
        case .password:
            return newPassword.count >= 6 && newPassword == confirmPassword
        }
    }
    
    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.phone)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text("+86")
                    .foregroundColor(.secondary)
                
                TextField(NSLocalizedString("请输入手机号", comment: ""), text: $phone)
                    .keyboardType(.phonePad)
            }
            .padding()
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var codeInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.verificationCode)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                TextField(NSLocalizedString("请输入验证码", comment: ""), text: $verificationCode)
                    .keyboardType(.numberPad)
                
                Button {
                    resendCode()
                } label: {
                    Text(countdown > 0 ? "\(countdown)s" : NSLocalizedString("重新发送", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(countdown > 0 ? .gray : primaryColor)
                }
                .disabled(countdown > 0)
            }
            .padding()
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var passwordInputSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("新密码", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    if showPassword {
                        TextField(NSLocalizedString("请输入新密码（6-20位）", comment: ""), text: $newPassword)
                    } else {
                        SecureField(NSLocalizedString("请输入新密码（6-20位）", comment: ""), text: $newPassword)
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
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("确认密码", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                SecureField(NSLocalizedString("请再次输入新密码", comment: ""), text: $confirmPassword)
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    private func handleNextStep() {
        switch step {
        case .phone:
            sendCode()
        case .code:
            verifyCode()
        case .password:
            resetPassword()
        }
    }
    
    private func sendCode() {
        guard phone.count == 11 else {
            errorMessage = NSLocalizedString("请输入正确的手机号", comment: "")
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                _ = try await AuthService.shared.sendLoginCode(phone: phone)
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        step = .code
                    }
                    startCountdown()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = NSLocalizedString("发送验证码失败，请稍后重试", comment: "")
                    showError = true
                }
            }
        }
    }
    
    private func verifyCode() {
        // 调用 API 即时校验验证码
        isLoading = true
        Task {
            do {
                _ = try await ApiService.shared.verifyCode(phone: phone, code: verificationCode)
                await MainActor.run {
                    isLoading = false
                    withAnimation {
                        step = .password
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func resetPassword() {
        guard newPassword.count >= 6 else {
            errorMessage = NSLocalizedString("密码至少需要6位", comment: "")
            showError = true
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = NSLocalizedString("两次输入的密码不一致", comment: "")
            showError = true
            return
        }
        
        isLoading = true
        Task {
            do {
                try await ApiService.shared.resetPassword(phone: phone, code: verificationCode, newPassword: newPassword)
                await MainActor.run {
                    isLoading = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func resendCode() {
        // 重发验证码时清空已输入的验证码，避免用户使用旧验证码验证失败
        verificationCode = ""
        sendCode()
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
