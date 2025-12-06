import SwiftUI
import Combine

struct ChangePhoneView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    // 两步验证状态
    enum Step {
        case verifyOldPhone  // 第一步：验证当前手机号
        case verifyNewPhone  // 第二步：验证新手机号
    }
    
    @State private var currentStep: Step = .verifyOldPhone
    
    // 第一步：验证当前手机号
    @State private var oldPhoneCode = ""
    @State private var oldPhoneCountdown = 0
    @State private var isSendingOldCode = false
    
    // 第二步：验证新手机号
    @State private var newPhone = ""
    @State private var newPhoneCode = ""
    @State private var newPhoneCountdown = 0
    @State private var isSendingNewCode = false
    
    @State private var isChanging = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 步骤指示器
                    stepIndicator
                    
                    // 根据当前步骤显示不同内容
                    if currentStep == .verifyOldPhone {
                        step1VerifyOldPhone
                    } else {
                        step2VerifyNewPhone
                    }
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
        .alert("修改成功", isPresented: $showSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("手机号已修改，请使用新手机号登录")
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onReceive(timer) { _ in
            if oldPhoneCountdown > 0 {
                oldPhoneCountdown -= 1
            }
            if newPhoneCountdown > 0 {
                newPhoneCountdown -= 1
            }
        }
    }
    
    // 步骤指示器
    private var stepIndicator: some View {
        HStack(spacing: 12) {
            // 步骤1
            HStack(spacing: 8) {
                Circle()
                    .fill(currentStep == .verifyOldPhone ? forestGreen : Color(uiColor: .systemGray4))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("1")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    )
                Text("验证当前手机号")
                    .font(.subheadline)
                    .foregroundColor(currentStep == .verifyOldPhone ? .primary : .secondary)
            }
            
            // 连接线
            Rectangle()
                .fill(Color(uiColor: .systemGray4))
                .frame(height: 2)
            
            // 步骤2
            HStack(spacing: 8) {
                Circle()
                    .fill(currentStep == .verifyNewPhone ? forestGreen : Color(uiColor: .systemGray4))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("2")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    )
                Text("绑定新手机号")
                    .font(.subheadline)
                    .foregroundColor(currentStep == .verifyNewPhone ? .primary : .secondary)
            }
        }
        .padding(.top, 20)
    }
    
    // 第一步：验证当前手机号
    private var step1VerifyOldPhone: some View {
        VStack(spacing: 24) {
            // 说明文字
            VStack(alignment: .leading, spacing: 8) {
                Text("验证当前手机号")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("为了您的账号安全，请先验证当前手机号")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 当前手机号
            VStack(alignment: .leading, spacing: 8) {
                Text("当前手机号")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(maskPhone(authService.currentUser?.phone ?? ""))
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(10)
            }
            
            // 验证码输入
            VStack(alignment: .leading, spacing: 8) {
                Text("验证码")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    TextField("请输入验证码", text: $oldPhoneCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .padding()
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(10)
                    
                    Button {
                        sendOldPhoneCode()
                    } label: {
                        Text(oldPhoneCountdown > 0 ? "\(oldPhoneCountdown)秒" : "发送验证码")
                            .font(.subheadline)
                            .foregroundColor(oldPhoneCountdown > 0 ? .secondary : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(oldPhoneCountdown > 0 ? Color(uiColor: .systemGray4) : forestGreen)
                            .cornerRadius(10)
                    }
                    .disabled(oldPhoneCountdown > 0 || isSendingOldCode)
                }
            }
            
            // 下一步按钮
            Button {
                verifyOldPhone()
            } label: {
                Text("下一步")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(oldPhoneCode.count == 6 ? forestGreen : Color(uiColor: .systemGray4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(oldPhoneCode.count != 6)
            .padding(.top, 12)
        }
    }
    
    // 第二步：验证新手机号
    private var step2VerifyNewPhone: some View {
        VStack(spacing: 24) {
            // 说明文字
            VStack(alignment: .leading, spacing: 8) {
                Text("绑定新手机号")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("请输入新手机号并验证")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 新手机号输入
            VStack(alignment: .leading, spacing: 8) {
                Text("新手机号")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("请输入新手机号", text: $newPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(10)
            }
            
            // 验证码输入
            VStack(alignment: .leading, spacing: 8) {
                Text("验证码")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    TextField("请输入验证码", text: $newPhoneCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .padding()
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(10)
                    
                    Button {
                        sendNewPhoneCode()
                    } label: {
                        Text(newPhoneCountdown > 0 ? "\(newPhoneCountdown)秒" : "发送验证码")
                            .font(.subheadline)
                            .foregroundColor(newPhoneCountdown > 0 ? .secondary : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(newPhoneCountdown > 0 ? Color(uiColor: .systemGray4) : forestGreen)
                            .cornerRadius(10)
                    }
                    .disabled(newPhoneCountdown > 0 || newPhone.count != 11 || isSendingNewCode)
                }
            }
            
            // 按钮组
            HStack(spacing: 12) {
                // 上一步
                Button {
                    currentStep = .verifyOldPhone
                } label: {
                    Text("上一步")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(uiColor: .systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                // 确认修改
                Button {
                    changePhone()
                } label: {
                    if isChanging {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("确认修改")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmitNewPhone ? forestGreen : Color(uiColor: .systemGray4))
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!canSubmitNewPhone || isChanging)
            }
            .padding(.top, 12)
        }
    }
    
    private var canSubmitNewPhone: Bool {
        newPhone.count == 11 && newPhoneCode.count == 6
    }
    
    // 手机号脱敏显示
    private func maskPhone(_ phone: String) -> String {
        guard phone.count == 11 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }
    
    // 发送当前手机号验证码
    private func sendOldPhoneCode() {
        guard let currentPhone = authService.currentUser?.phone else { return }
        
        isSendingOldCode = true
        Task {
            do {
                try await ApiService.shared.sendVerificationCode(phone: currentPhone)
                await MainActor.run {
                    isSendingOldCode = false
                    oldPhoneCountdown = 60
                }
            } catch {
                await MainActor.run {
                    isSendingOldCode = false
                    errorMessage = "发送验证码失败"
                    showError = true
                }
            }
        }
    }
    
    // 验证当前手机号
    private func verifyOldPhone() {
        guard let currentPhone = authService.currentUser?.phone else { return }
        
        Task {
            do {
                // 调用后端验证当前手机号的验证码
                try await ApiService.shared.verifyCode(phone: currentPhone, code: oldPhoneCode)
                
                await MainActor.run {
                    // 验证成功，进入第二步
                    currentStep = .verifyNewPhone
                }
            } catch {
                await MainActor.run {
                    errorMessage = "验证码错误或已过期"
                    showError = true
                }
            }
        }
    }
    
    // 发送新手机号验证码
    private func sendNewPhoneCode() {
        guard newPhone.count == 11 else { return }
        
        isSendingNewCode = true
        Task {
            do {
                try await ApiService.shared.sendVerificationCode(phone: newPhone)
                await MainActor.run {
                    isSendingNewCode = false
                    newPhoneCountdown = 60
                }
            } catch {
                await MainActor.run {
                    isSendingNewCode = false
                    errorMessage = "发送验证码失败"
                    showError = true
                }
            }
        }
    }
    
    // 确认修改手机号
    private func changePhone() {
        isChanging = true
        Task {
            do {
                // 调用后端API，传入新手机号和验证码
                try await ApiService.shared.changePhone(newPhone: newPhone, code: newPhoneCode)
                
                await MainActor.run {
                    isChanging = false
                    showSuccess = true
                    // 修改成功后需要重新登录
                    authService.logout()
                }
            } catch {
                await MainActor.run {
                    isChanging = false
                    errorMessage = "修改失败：\(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    ChangePhoneView()
}
