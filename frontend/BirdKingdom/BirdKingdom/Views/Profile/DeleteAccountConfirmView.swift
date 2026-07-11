//
//  DeleteAccountConfirmView.swift
//  BirdKingdom
//
//  账号删除确认视图 - 需要验证码二次确认
//

import SwiftUI

/// 账号删除确认视图
/// P1 安全修复：账号删除需要验证码二次确认
struct DeleteAccountConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    let onDeleted: () -> Void
    
    @State private var verificationCode = ""
    @State private var countdown = 0
    @State private var isSendingCode = false
    @State private var isDeleting = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showFinalConfirm = false
    
    private var phone: String {
        authService.currentUser?.phone ?? ""
    }
    
    private var maskedPhone: String {
        guard phone.count >= 7 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding(.top, 20)
                    
                    // 标题
                    Text(L10n.deleteAccount)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // 警告信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("⚠️ 注意：此操作不可撤销！", comment: ""))
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(NSLocalizedString("注销账号后，以下数据将被永久删除：", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            warningItem(NSLocalizedString("您的账号信息和个人资料", comment: ""))
                            warningItem(NSLocalizedString("您的所有鸟儿档案和记录", comment: ""))
                            warningItem(NSLocalizedString("您的帖子、评论和收藏", comment: ""))
                            warningItem(NSLocalizedString("您的VIP会员权益", comment: ""))
                            warningItem(NSLocalizedString("所有与此账号相关的数据", comment: ""))
                        }
                        .padding(.leading, 4)
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // 验证码输入区域
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("为确保是您本人操作，请获取并输入验证码", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: NSLocalizedString("验证码将发送至：%@", comment: ""), maskedPhone))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            TextField(NSLocalizedString("请输入验证码", comment: ""), text: $verificationCode)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color.adaptiveCard)
                                .cornerRadius(10)
                            
                            Button {
                                sendVerificationCode()
                            } label: {
                                Text(countdown > 0 ? "\(countdown)s" : NSLocalizedString("获取验证码", comment: ""))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(width: 100)
                                    .padding(.vertical, 16)
                                    .background(countdown > 0 || isSendingCode ? Color.gray : themeManager.primaryColor)
                                    .cornerRadius(10)
                            }
                            .disabled(countdown > 0 || isSendingCode)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer().frame(height: 20)
                    
                    // 确认删除按钮
                    Button {
                        showFinalConfirm = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                Text(NSLocalizedString("确认注销账号", comment: ""))
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(verificationCode.count >= 6 && !isDeleting ? Color.red : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(verificationCode.count < 6 || isDeleting)
                    .padding(.horizontal, 16)
                    
                    // 取消按钮
                    Button(L10n.cancel) {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                }
            }
            .themedBackground()
            .navigationTitle(NSLocalizedString("账号注销", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                }
            }
            .alert(NSLocalizedString("错误", comment: ""), isPresented: $showError) {
                Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert(NSLocalizedString("最终确认", comment: ""), isPresented: $showFinalConfirm) {
                Button(L10n.cancel, role: .cancel) {}
                Button(NSLocalizedString("确认删除", comment: ""), role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text(NSLocalizedString("确定要永久删除您的账号吗？此操作无法撤销。", comment: ""))
            }
        }
    }
    
    private func warningItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.red)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    private func sendVerificationCode() {
        guard !phone.isEmpty else {
            errorMessage = NSLocalizedString("无法获取手机号", comment: "")
            showError = true
            return
        }
        
        isSendingCode = true
        
        Task {
            do {
                try await ApiService.shared.sendVerificationCode(phone: phone)
                await MainActor.run {
                    isSendingCode = false
                    startCountdown()
                }
            } catch {
                await MainActor.run {
                    isSendingCode = false
                    errorMessage = String(format: NSLocalizedString("发送验证码失败: %@", comment: ""), error.localizedDescription)
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
    
    private func deleteAccount() {
        isDeleting = true
        
        Task {
            do {
                try await ApiService.shared.deleteAccount(code: verificationCode)
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                    onDeleted()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = String(format: NSLocalizedString("注销失败: %@", comment: ""), error.localizedDescription)
                    showError = true
                }
            }
        }
    }
}

#Preview {
    DeleteAccountConfirmView(onDeleted: {})
}
