import SwiftUI

// MARK: - 智能问诊视图
struct AIConsultView: View {
    @ObservedObject var aiService = AIConsultService.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var authService = AuthService.shared
    @State private var inputText = ""
    @State private var showQuickQuestions = true
    @FocusState private var isInputFocused: Bool
    // A-004: 清空对话确认
    @State private var showClearConfirm = false
    @State private var showLoginSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !authService.isLoggedIn {
                loginRequiredView
            } else {
                chatContentView
            }
        }
        .background(Color(.systemGroupedBackground))
        // A-004: 清空对话确认弹窗
        .alert(NSLocalizedString("清空对话", comment: ""), isPresented: $showClearConfirm) {
            Button(L10n.cancel, role: .cancel) {}
            Button(NSLocalizedString("清空", comment: ""), role: .destructive) {
                aiService.clearHistory()
                showQuickQuestions = true
            }
        } message: {
            Text(NSLocalizedString("确定要清空所有对话记录吗？", comment: ""))
        }
        // A-004: 长按屏幕显示清空选项
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if authService.isLoggedIn && aiService.messages.count > 1 {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
    }
    
    // MARK: - 登录提示视图
    private var loginRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(themeManager.primaryColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(themeManager.primaryColor)
            }
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("智能问诊", comment: ""))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(NSLocalizedString("智能问诊功能需要登录后才能使用，登录后即可体验全方位的鸟类健康评估与羽色预测服务。", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                showLoginSheet = true
            } label: {
                Text(NSLocalizedString("立即登录", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.primaryColor)
                    .cornerRadius(12)
                    .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .padding(.horizontal, 48)
            .padding(.top, 8)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - 聊天内容视图
    private var chatContentView: some View {
        VStack(spacing: 0) {
            // A-004 FIX: 对话数量较多时显示清空提示条
            if aiService.messages.count > 5 {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("已有 \(aiService.messages.count) 条对话")
                        .font(.caption)
                    Spacer()
                    Button {
                        showClearConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption2)
                            Text(NSLocalizedString("清空", comment: ""))
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            
            // 聊天消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // 快捷问题（首次显示）
                        if showQuickQuestions && aiService.messages.count <= 1 {
                            quickQuestionsSection
                        }
                        
                        // 消息列表
                        ForEach(aiService.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // 加载指示器
                        if aiService.isLoading {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                .onChange(of: aiService.messages.count) { _ in
                    // 滚动到最新消息
                    withAnimation {
                        if aiService.isLoading {
                            proxy.scrollTo("typing", anchor: .bottom)
                        } else if let lastMessage = aiService.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            
            // 底部输入区域
            inputArea
        }
    }
    
    // MARK: - 快捷问题区域（已移除，保留空实现）
    private var quickQuestionsSection: some View {
        EmptyView()
    }
    
    // MARK: - 输入区域
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // 输入框
                HStack {
                    TextField(NSLocalizedString("描述鸟儿的症状或问题...", comment: ""), text: $inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    if !inputText.isEmpty {
                        Button {
                            inputText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // 发送按钮
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isLoading
                            ? Color(uiColor: .systemGray4)
                            : Color(uiColor: .darkGray)
                        )
                        .clipShape(Circle())
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.adaptiveCard)
        }
    }
    
    // MARK: - 发送消息
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        showQuickQuestions = false
        isInputFocused = false
        
        Task {
            await aiService.sendMessage(text)
        }
    }
    
    // MARK: - 发送快捷问题
    private func sendQuickQuestion(_ question: String) {
        showQuickQuestions = false
        Task {
            await aiService.sendMessage(question)
        }
    }
}

// MARK: - 消息气泡
struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else {
                // AI 医生头像 - 银白色小鸟图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.95), Color(white: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Image("bird")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(white: 0.4))
                    
                    // 医生十字标识
                    Circle()
                        .fill(Color.red.opacity(0.9))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "cross.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 12, y: 10)
                }
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .textSelection(.enabled)  // 允许复制文字
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                        ? AnyView(Color(uiColor: .darkGray))
                        : AnyView(Color.adaptiveCard)  // 深色模式下会自动变成深灰
                    )
                    .cornerRadius(16, corners: message.role == .user
                        ? [.topLeft, .topRight, .bottomLeft]
                        : [.topLeft, .topRight, .bottomRight])
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                // 时间戳
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            } else {
                // 用户头像
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 32, height: 32)
                    Image("bird")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 打字指示器
struct TypingIndicator: View {
    @State private var animationPhase = 0
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // AI 医生头像 - 银白色小鸟图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Image("bird")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color(white: 0.4))
                
                // 医生十字标识
                Circle()
                    .fill(Color.red.opacity(0.9))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: "cross.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 12, y: 10)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(themeManager.primaryColor.opacity(animationPhase == index ? 1 : 0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.adaptiveCard)
            .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

#Preview {
    AIConsultView()
}
