import SwiftUI

/// 联系作者 - 用户反馈表单页面
struct ContactAuthorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    // 表单状态
    @State private var selectedType: FeedbackType = .suggestion
    @State private var content: String = ""
    @State private var contactInfo: String = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    @FocusState private var isContentFocused: Bool
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    // 反馈类型
    enum FeedbackType: String, CaseIterable {
        case bug = "bug"
        case suggestion = "suggestion"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .bug: return NSLocalizedString("问题反馈", comment: "")
            case .suggestion: return NSLocalizedString("功能建议", comment: "")
            case .other: return NSLocalizedString("其他", comment: "")
            }
        }
        
        var icon: String {
            switch self {
            case .bug: return "ladybug.fill"
            case .suggestion: return "lightbulb.fill"
            case .other: return "ellipsis.bubble.fill"
            }
        }
        
        var description: String {
            switch self {
            case .bug: return NSLocalizedString("遇到了问题或Bug", comment: "")
            case .suggestion: return NSLocalizedString("有好的功能建议", comment: "")
            case .other: return NSLocalizedString("其他想说的话", comment: "")
            }
        }
    }
    
    private var canSubmit: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 && !isSubmitting
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部说明
                headerSection
                
                // 反馈类型选择
                feedbackTypeSection
                
                // 反馈内容
                contentSection
                
                // 联系方式（可选）
                contactSection
                
                // 提交按钮
                submitButton
                
                // 底部提示
                footerSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .onTapGesture {
            // 点击空白区域收起键盘
            hideKeyboard()
        }
        .themedBackground()
        .themedNavigationBar(title: NSLocalizedString("联系作者", comment: ""))
        .alert(NSLocalizedString("提交成功", comment: ""), isPresented: $showSuccessAlert) {
            Button(NSLocalizedString("好的", comment: "")) {
                dismiss()
            }
        } message: {
            Text(NSLocalizedString("感谢您的反馈！我们会认真阅读并尽快处理。", comment: ""))
        }
        .alert(NSLocalizedString("提交失败", comment: ""), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // 收起键盘
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - 顶部说明
    private var headerSection: some View {
        VStack(spacing: 12) {
            // 作者头像/图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: themeManager.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .shadow(color: primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text(NSLocalizedString("Hi，我是鸟鸟王国的开发者 👋", comment: ""))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(NSLocalizedString("很高兴收到您的反馈，每一条建议我都会认真阅读！", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - 反馈类型选择
    private var feedbackTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("反馈类型", comment: ""))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(FeedbackType.allCases, id: \.self) { type in
                    feedbackTypeButton(type)
                }
            }
        }
    }
    
    private func feedbackTypeButton(_ type: FeedbackType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedType == type ? primaryColor.opacity(0.15) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedType == type ? primaryColor : Color.clear, lineWidth: 2)
            )
            .foregroundColor(selectedType == type ? primaryColor : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 反馈内容
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("反馈内容", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(content.count)/2000")
                    .font(.caption)
                    .foregroundColor(content.count >= 2000 ? .red : .secondary)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .focused($isContentFocused)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                    .onChange(of: content) { newValue in
                        if newValue.count > 2000 {
                            content = String(newValue.prefix(2000))
                        }
                    }
                
                if content.isEmpty {
                    Text(NSLocalizedString("请详细描述您遇到的问题或建议，至少10个字～", comment: ""))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.top, 20)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }
            
            // 字数提示
            if content.count > 0 && content.count < 10 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(String(format: NSLocalizedString("还需要 %d 个字", comment: ""), 10 - content.count))
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - 联系方式
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("联系方式（可选）", comment: ""))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(NSLocalizedString("方便我们回复您", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            TextField(NSLocalizedString("微信号 / QQ / 邮箱", comment: ""), text: $contactInfo)
                .padding(14)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(12)
        }
    }
    
    // MARK: - 提交按钮
    private var submitButton: some View {
        Button {
            submitFeedback()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSubmitting ? L10n.reportSubmitting : NSLocalizedString("提交反馈", comment: ""))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: canSubmit ? themeManager.gradientColors : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
            .shadow(color: canSubmit ? primaryColor.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!canSubmit)
        .padding(.top, 8)
    }
    
    // MARK: - 底部提示
    private var footerSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 8)
            
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text(NSLocalizedString("您的反馈信息将被安全保护", comment: ""))
                    .font(.caption)
            }
            .foregroundColor(.secondary.opacity(0.7))
            
            Text(NSLocalizedString("也可以通过邮箱直接联系我们：ibomb017@gmail.com", comment: ""))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
    
    // MARK: - 提交反馈
    private func submitFeedback() {
        guard canSubmit else { return }
        
        isSubmitting = true
        isContentFocused = false
        
        Task {
            do {
                let success = try await ApiService.shared.submitFeedback(
                    type: selectedType.rawValue,
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    contactInfo: contactInfo.isEmpty ? nil : contactInfo
                )
                
                await MainActor.run {
                    isSubmitting = false
                    if success {
                        showSuccessAlert = true
                    } else {
                        errorMessage = NSLocalizedString("提交失败，请稍后重试", comment: "")
                        showErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = NSLocalizedString("网络错误，请检查网络连接后重试", comment: "")
                    showErrorAlert = true
                }
                print("提交反馈失败: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContactAuthorView()
    }
}
