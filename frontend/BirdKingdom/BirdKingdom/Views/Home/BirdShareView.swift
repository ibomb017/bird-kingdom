import SwiftUI

// MARK: - 鸟类共享管理视图
struct BirdShareView: View {
    let bird: Bird
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @State private var sharedUsers: [BirdCoOwner] = []
    @State private var isLoading = false
    @State private var showShareSheet = false
    @State private var showVipRequired = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 鸟信息卡片
                    birdInfoCard
                    
                    // 主人信息
                    ownerSection
                    
                    // 共享用户列表（原始主人和"主人"角色的共享者都能看到）
                    if bird.canManageSharing {
                        sharedUsersSection
                    }
                    
                    // 操作按钮
                    actionButtons
                }
                .padding(20)
            }
            .themedBackground()
            .themedNavigationBar(title: NSLocalizedString("共享管理", comment: ""))
            .sheet(isPresented: $showShareSheet) {
                ShareInviteView(bird: bird) { success in
                    if success {
                        loadSharedUsers()
                    }
                }
            }
            .alert(NSLocalizedString("错误", comment: ""), isPresented: $showError) {
                Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert(NSLocalizedString("VIP专属功能", comment: ""), isPresented: $showVipRequired) {
                Button(NSLocalizedString("开通VIP", comment: ""), role: .none) {
                    dismiss()
                    // 延迟一下让dismiss完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // 切换到"我的"tab并打开VIP页面
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowVIPPage"),
                            object: nil
                        )
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(NSLocalizedString("共享鸟儿是VIP专属功能，开通VIP后即可邀请他人共同管理你的鸟儿", comment: ""))
            }
            .onAppear {
                loadSharedUsers()
            }
        }
    }
    
    // 鸟信息卡片
    private var birdInfoCard: some View {
        HStack(spacing: 16) {
            // 头像 - 显示实际头像
            if let avatarUrl = bird.avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    default:
                        RoundedRectangle(cornerRadius: 16)
                            .fill(primaryColor.opacity(0.15))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image("bird")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 45, height: 45)
                            )
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(primaryColor.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image("bird")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(bird.nickname)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(bird.species)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 共享状态标签
                if bird.isShared == true {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text(NSLocalizedString("已共享", comment: ""))
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(16)
    }
    
    // 主人信息
    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)
                Text(NSLocalizedString("主人", comment: ""))
                    .font(.headline)
            }
            
            HStack(spacing: 12) {
                Circle()
                    .fill(primaryColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image("bird")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(primaryColor.opacity(0.5))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bird.ownerName ?? NSLocalizedString("我", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if bird.isOwner == true {
                        Text(NSLocalizedString("这是你的鸟", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(NSLocalizedString("鸟的创建者", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(NSLocalizedString("主人", comment: ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(12)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(16)
    }
    
    // 共享用户列表
    private var sharedUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(primaryColor)
                Text(NSLocalizedString("共享给", comment: ""))
                    .font(.headline)
                Spacer()
                Text("\(sharedUsers.count) 人")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if sharedUsers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text(NSLocalizedString("还没有共享给其他人", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(sharedUsers) { user in
                    sharedUserRow(user: user)
                }
            }
        }
        .padding(16)
        .background(Color.adaptiveCard)
        .cornerRadius(16)
    }
    
    // 共享用户行
    private func sharedUserRow(user: BirdCoOwner) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image("bird")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(.blue.opacity(0.6))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(roleText(user.role))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 角色标签
            Text(roleText(user.role))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(roleColor(user.role))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(roleColor(user.role).opacity(0.1))
                .cornerRadius(6)
            
            // 删除按钮（原始主人和"主人"角色的共享者都能删除）
            if bird.canManageSharing {
                Button {
                    removeUser(user)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(10)
    }
    
    // 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if bird.canManageSharing {
                // 有管理权限的用户可以邀请他人（需要VIP）
                Button {
                    if authService.currentUser?.isVipValid == true {
                        showShareSheet = true
                    } else {
                        showVipRequired = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text(NSLocalizedString("添加主人", comment: ""))
                        if authService.currentUser?.isVipValid != true {
                            Image("bird")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(primaryColor)
                    .cornerRadius(12)
                }
            } else {
                // 被共享者可以退出
                Button {
                    leaveShared()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(NSLocalizedString("退出共享", comment: ""))
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func roleText(_ role: ShareRole) -> String {
        switch role {
        case .owner: return NSLocalizedString("主人", comment: "")
        case .viewer: return NSLocalizedString("查看者", comment: "")
        }
    }
    
    private func roleColor(_ role: ShareRole) -> Color {
        switch role {
        case .owner: return .orange
        case .viewer: return .gray
        }
    }
    
    private func loadSharedUsers() {
        guard bird.canManageSharing else { return }
        isLoading = true
        
        Task {
            do {
                let users = try await ApiService.shared.getBirdSharedUsers(birdId: bird.id)
                await MainActor.run {
                    sharedUsers = users
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = NSLocalizedString("加载共享用户失败", comment: "")
                    showError = true
                }
            }
        }
    }
    
    private func removeUser(_ user: BirdCoOwner) {
        Task {
            do {
                try await ApiService.shared.removeSharedUser(birdId: bird.id, userId: user.userId)
                await MainActor.run {
                    sharedUsers.removeAll { $0.id == user.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = NSLocalizedString("移除用户失败", comment: "")
                    showError = true
                }
            }
        }
    }
    
    private func leaveShared() {
        Task {
            do {
                try await ApiService.shared.leaveSharedBird(birdId: bird.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = NSLocalizedString("退出共享失败", comment: "")
                    showError = true
                }
            }
        }
    }
}

// MARK: - 共享邀请视图
struct ShareInviteView: View {
    let bird: Bird
    let onComplete: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var targetPhone = ""
    @State private var selectedRole: ShareRole = .owner
    @State private var isLoading = false
    @State private var isSearching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var foundUser: UserBrief? = nil
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        NavigationStack {
            KeyboardDismissScrollView {
                VStack(spacing: 24) {
                // 说明
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(primaryColor)
                    
                    Text(NSLocalizedString("添加主人", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("输入对方的手机号，邀请TA一起照顾 \(bird.nickname)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 手机号输入
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.phone)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        TextField(NSLocalizedString("输入对方的手机号", comment: ""), text: $targetPhone)
                            .keyboardType(.phonePad)
                            .onChange(of: targetPhone) { _ in
                                foundUser = nil
                            }
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if targetPhone.count == 11 {
                            Button {
                                searchUser()
                            } label: {
                                Text(L10n.search)
                                    .font(.subheadline)
                                    .foregroundColor(primaryColor)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(10)
                    
                    Text(NSLocalizedString("对方需要先注册鸟鸟王国账号", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // 搜索结果
                if let user = foundUser {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(primaryColor.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image("bird")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(primaryColor.opacity(0.5))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.nickname)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(user.maskedPhone)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // 角色选择
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("权限设置", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 10) {
                        roleOption(
                            role: .owner,
                            title: NSLocalizedString("主人", comment: ""),
                            description: NSLocalizedString("可以查看和编辑所有信息，拥有完全权限", comment: ""),
                            icon: "person.fill"
                        )
                        
                        roleOption(
                            role: .viewer,
                            title: NSLocalizedString("查看者", comment: ""),
                            description: NSLocalizedString("只能查看信息，不能编辑", comment: ""),
                            icon: "eye.fill"
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 发送按钮
                Button {
                    sendInvitation()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text(NSLocalizedString("发送邀请", comment: ""))
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(foundUser != nil ? primaryColor : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(foundUser == nil || isLoading)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .themedBackground()
            .themedNavigationBar(title: NSLocalizedString("添加主人", comment: ""))
        }
        }
        .alert(NSLocalizedString("错误", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("确定", comment: ""), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(NSLocalizedString("邀请已发送", comment: ""), isPresented: $showSuccess) {
            Button(NSLocalizedString("确定", comment: "")) {
                onComplete(true)
                dismiss()
            }
        } message: {
            Text("已向 \(foundUser?.nickname ?? targetPhone) 发送共享邀请，等待对方确认")
        }
    }
    
    private func roleOption(role: ShareRole, title: String, description: String, icon: String) -> some View {
        Button {
            selectedRole = role
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(selectedRole == role ? primaryColor : .gray)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedRole == role ? primaryColor : .gray)
            }
            .padding(12)
            .background(selectedRole == role ? primaryColor.opacity(0.1) : Color(uiColor: .systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedRole == role ? primaryColor : Color.clear, lineWidth: 1.5)
            )
        }
    }
    
    private func searchUser() {
        isSearching = true
        Task {
            do {
                let response = try await AuthService.shared.searchUserByPhone(targetPhone)
                await MainActor.run {
                    isSearching = false
                    if response.found, let user = response.user {
                        foundUser = user
                    } else {
                        errorMessage = NSLocalizedString("未找到该用户，请确认对方已注册", comment: "")
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = NSLocalizedString("搜索失败，请稍后重试", comment: "")
                    showError = true
                }
            }
        }
    }
    
    private func sendInvitation() {
        guard let user = foundUser else { return }
        isLoading = true
        
        Task {
            do {
                let response = try await ApiService.shared.shareBird(
                    birdId: bird.id,
                    targetPhone: user.phone,
                    role: selectedRole
                )
                
                await MainActor.run {
                    isLoading = false
                    if response.success {
                        showSuccess = true
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = NSLocalizedString("发送邀请失败，请检查用户名是否正确", comment: "")
                    showError = true
                }
            }
        }
    }
}

// MARK: - 共享邀请列表视图
struct PendingInvitationsView: View {
    @State private var invitations: [ShareInvitation] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView(L10n.loading)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if invitations.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(NSLocalizedString("没有待处理的邀请", comment: ""))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("当有人邀请你共享鸟儿时，会显示在这里", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(invitations) { invitation in
                            invitationRow(invitation)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.adaptiveCard)
                                .cornerRadius(12)
                                .shadow(color: primaryColor.opacity(0.08), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .themedBackground()
        .themedNavigationBar(title: L10n.shareInvitations)
        .onAppear {
            loadInvitations()
        }
    }
    
    private func invitationRow(_ invitation: ShareInvitation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image("bird")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(invitation.birdName)
                    .font(.headline)
                Spacer()
            }
            
            Text("\(invitation.fromUsername) 邀请你成为 \(invitation.birdName) 的\(invitation.role == .owner ? "主人" : "查看者")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button {
                    acceptInvitation(invitation)
                } label: {
                    Text(NSLocalizedString("接受", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(primaryColor)
                        .cornerRadius(8)
                }
                
                Button {
                    rejectInvitation(invitation)
                } label: {
                    Text(NSLocalizedString("拒绝", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func loadInvitations() {
        isLoading = true
        Task {
            do {
                let result = try await ApiService.shared.getPendingInvitations()
                await MainActor.run {
                    invitations = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func acceptInvitation(_ invitation: ShareInvitation) {
        Task {
            do {
                _ = try await ApiService.shared.acceptInvitation(invitationId: invitation.id)
                await MainActor.run {
                    invitations.removeAll { $0.id == invitation.id }
                    ToastManager.shared.showSuccess(NSLocalizedString("已接受邀请", comment: ""))
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshBirds"), object: nil)
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showError(NSLocalizedString("接受邀请失败，请稍后重试", comment: ""))
                }
            }
        }
    }
    
    private func rejectInvitation(_ invitation: ShareInvitation) {
        Task {
            do {
                _ = try await ApiService.shared.rejectInvitation(invitationId: invitation.id)
                await MainActor.run {
                    invitations.removeAll { $0.id == invitation.id }
                }
            } catch {
                await MainActor.run {
                    ToastManager.shared.showError(NSLocalizedString("拒绝邀请失败，请稍后重试", comment: ""))
                }
            }
        }
    }
}
