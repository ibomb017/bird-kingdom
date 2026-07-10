import SwiftUI

struct BirdDetailView: View {
    @State private var bird: Bird
    
    init(bird: Bird) {
        _bird = State(initialValue: bird)
    }
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isEditing = false
    @State private var logs: [BirdLog] = []
    @State private var isLoadingLogs = false
    @State private var showShareView = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showNewLog = false
    @State private var showRecordWeight = false
    
    private var primaryColor: Color { themeManager.primaryColor }
    private var backgroundColor: Color { themeManager.backgroundColor }
    private let dangerColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    // 主题色卡片背景（淡色半透明）
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundColor.opacity(0.3))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.adaptiveCard)
            )
    }
    
    var body: some View {
        ScrollView {
                VStack(spacing: 20) {
                    // 头像区域
                    avatarSection
                    
                    // 快速操作区域（仅非已故小鸟显示）
                    if !bird.isDead {
                        quickActionsSection
                    }
                    
                    // 主人与共享信息
                    ownershipCard
                    
                    // 基础信息卡片
                    infoCard
                    
                    // 外观与来源卡片
                    appearanceCard
                    
                    // 最近日志
                    recentLogsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .themedBackground()
            .themedNavigationBar(title: bird.nickname)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // 共享按钮
                        Button {
                            showShareView = true
                        } label: {
                            Image(systemName: "person.2")
                                .foregroundColor(primaryColor)
                        }
                        
                        // 编辑按钮（仅主人和共同主人可见）
                        if bird.canEdit {
                            Button(L10n.edit) {
                                isEditing = true
                            }
                            .foregroundColor(primaryColor)
                        }
                        
                        // 删除按钮（仅主人可见，情侣共享的鸟不能删除）
                        if bird.isRealOwner {
                            Menu {
                                Button(role: .destructive) {
                                    showDeleteAlert = true
                                } label: {
                                    Label(NSLocalizedString("删除鸟儿", comment: ""), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(primaryColor)
                            }
                        }
                    }
                }
            }
            .alert(NSLocalizedString("确认删除", comment: ""), isPresented: $showDeleteAlert) {
                Button(L10n.cancel, role: .cancel) {}
                Button(L10n.delete, role: .destructive) {
                    deleteBird()
                }
            } message: {
                Text(NSLocalizedString("删除后，鸟儿信息将移入回收站。VIP用户可在7天内恢复。", comment: ""))
            }
            .navigationDestination(isPresented: $isEditing) {
                EditBirdView(bird: bird)
                    .hidesTabBar()
            }
            // 编辑返回后刷新详情数据
            .onChange(of: isEditing) { _, editing in
                if !editing {
                    Task {
                        await loadBirdDetail()
                        await loadLogs()
                    }
                }
            }
            .navigationDestination(isPresented: $showNewLog) {
                NewLogView(preselectedBirdId: bird.id)
                    .hidesTabBar()
            }
            .navigationDestination(isPresented: $showRecordWeight) {
                RecordWeightView(birds: [bird], preselectedIndex: 0)
                    .hidesTabBar()
            }
            .sheet(isPresented: $showShareView) {
                BirdShareView(bird: bird)
            }
            .task {
                await loadLogs()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBirds"))) { _ in
                Task {
                    await loadBirdDetail()
                    await loadLogs()
                }
            }
            .hidesTabBar()  // 进入详情页时隐藏底部导航栏

    }
    
    // MARK: - 头像区域
    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // 背景圆 - 使用主题色
                Circle()
                    .fill(
                        LinearGradient(
                            colors: bird.isDead 
                                ? [Color(red: 0.45, green: 0.45, blue: 0.47), Color(red: 0.35, green: 0.35, blue: 0.38)]
                                : [primaryColor.opacity(0.7), primaryColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                // 头像图片 - 优先显示实际头像
                if let avatarUrl = bird.avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .saturation(bird.isDead ? 0.3 : 1.0) // 已故鸟儿头像变灰
                                .opacity(bird.isDead ? 0.7 : 1.0)
                        default:
                            // 加载中或失败时显示默认图标
                            Image("bird")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white.opacity(bird.isDead ? 0.5 : 0.8))
                        }
                    }
                } else {
                    // 没有头像时显示默认图标
                    Image("bird")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.white.opacity(bird.isDead ? 0.5 : 0.8))
                }
                
                // 已故标识 - 十字架覆盖在头像上
                if bird.isDead {
                    // 半透明遮罩
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    // 十字架图标
                    VStack(spacing: 2) {
                        Image(systemName: "cross.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        Text("🕯️")
                            .font(.system(size: 12))
                    }
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            HStack(spacing: 6) {
                Text(bird.nickname)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 已故标识
                if bird.isDead {
                    Text(NSLocalizedString("已故", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray)
                        .cornerRadius(10)
                }
            }
            
            if bird.isDead {
                // 显示忌日信息
                VStack(spacing: 4) {
                    Text("\(bird.species)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let deathDate = bird.deathDate {
                        HStack(spacing: 4) {
                            Text("🕯️")
                            Text("忌日: \(formatDeathDate(deathDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(NSLocalizedString("永远怀念 💕", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                }
            } else {
                Text("\(bird.species) · \(bird.ageText)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
    
    // MARK: - 快速操作区域
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            // 写日志按钮
            Button {
                showNewLog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                    Text(L10n.writeLog)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(primaryColor)
                )
            }
            
            // 记录体重按钮
            Button {
                showRecordWeight = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 16, weight: .medium))
                    Text(NSLocalizedString("记录体重", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(primaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(primaryColor, lineWidth: 1.5)
                )
            }
        }
    }
    
    // MARK: - 主人与共享信息卡片
    private var ownershipCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(NSLocalizedString("主人信息", comment: ""), systemImage: "person.crop.circle.fill")
                .font(.headline)
                .foregroundColor(primaryColor)
            
            Divider()
            
            // 原始主人信息
            HStack(spacing: 12) {
                Circle()
                    .fill(backgroundColor.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bird.ownerName ?? NSLocalizedString("我", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(bird.isOwner == true ? NSLocalizedString("原主人（你）", comment: "") : NSLocalizedString("原主人", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 角色标签
                Text(roleText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(roleColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(roleColor.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // 共享主人列表
            if let sharedUsers = bird.sharedWith, !sharedUsers.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("共享主人", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(sharedUsers, id: \.id) { coOwner in
                        HStack(spacing: 12) {
                            // 头像
                            if let avatarUrl = coOwner.avatar, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        )
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(coOwner.nickname)
                                    .font(.subheadline)
                                Text(coOwner.role == .owner ? NSLocalizedString("主人", comment: "") : NSLocalizedString("查看者", comment: ""))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // 角色标签
                            Text(coOwner.role == .owner ? NSLocalizedString("主人", comment: "") : NSLocalizedString("查看者", comment: ""))
                                .font(.caption2)
                                .foregroundColor(coOwner.role == .owner ? .orange : .gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((coOwner.role == .owner ? Color.orange : Color.gray).opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            // 共享状态提示
            if bird.isShared == true {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("此鸟已共享给 \(bird.sharedWith?.count ?? 0) 位用户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        showShareView = true
                    } label: {
                        Text(NSLocalizedString("管理", comment: ""))
                            .font(.caption)
                            .foregroundColor(primaryColor)
                    }
                }
                .padding(10)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    private var roleText: String {
        switch bird.shareRole {
        case .owner, .none: return NSLocalizedString("主人", comment: "")
        case .viewer: return NSLocalizedString("查看者", comment: "")
        }
    }
    
    private var roleColor: Color {
        switch bird.shareRole {
        case .owner, .none: return .orange
        case .viewer: return .gray
        }
    }
    
    // MARK: - 基础信息卡片
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(NSLocalizedString("基础信息", comment: ""), systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(primaryColor)
            
            Divider()
            
            InfoRow(label: L10n.birdName, value: bird.nickname)
            InfoRow(label: L10n.birdSpecies, value: bird.species)
            InfoRow(label: L10n.birdGender, value: genderText)
            InfoRow(label: NSLocalizedString("出生日期", comment: ""), value: birthDateText)
            InfoRow(label: NSLocalizedString("年龄", comment: ""), value: bird.ageText)
        }
        .padding(16)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - 外观与来源卡片
    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(NSLocalizedString("外观与来源", comment: ""), systemImage: "paintbrush.fill")
                .font(.headline)
                .foregroundColor(primaryColor)
            
            Divider()
            
            InfoRow(label: NSLocalizedString("羽色", comment: ""), value: bird.featherColor ?? NSLocalizedString("未填写", comment: ""))
            InfoRow(label: NSLocalizedString("来源", comment: ""), value: bird.source ?? NSLocalizedString("未填写", comment: ""))
            
            if let notes = bird.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("备注", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(notes)
                        .font(.body)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - 最近日志
    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(NSLocalizedString("最近日志", comment: ""), systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundColor(primaryColor)
                Spacer()
            }
            
            if isLoadingLogs {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if logs.isEmpty {
                Text(NSLocalizedString("暂无日志记录", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(logs.prefix(5)) { log in
                    LogRowView(log: log)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Helpers
    private var genderText: String {
        switch bird.gender {
        case "MALE": return NSLocalizedString("公", comment: "")
        case "FEMALE": return NSLocalizedString("母", comment: "")
        case "UNKNOWN": return NSLocalizedString("未知", comment: "")
        default: return bird.gender ?? NSLocalizedString("未填写", comment: "")
        }
    }
    
    private var birthDateText: String {
        let date: Date?
        if bird.birthdayType == "ADOPTION", let adoptionDate = bird.adoptionDate {
            date = adoptionDate
        } else {
            date = bird.hatchDate
        }
        
        guard let validDate = date else { return NSLocalizedString("未填写", comment: "") }
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月d日", comment: "")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: validDate)
    }
    
    private func formatDeathDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年MM月dd日", comment: "")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    private func loadLogs() async {
        isLoadingLogs = true
        do {
            let allLogs = try await ApiService.shared.getLogs()
            // 使用 birdId 而不是 birdName 匹配，这样鸟改名后日志仍然能正确关联
            logs = allLogs.filter { $0.birdId == bird.id }
                .sorted { $0.logDate > $1.logDate }
        } catch {
            print("加载日志失败: \(error)")
        }
        isLoadingLogs = false
    }
    
    private func loadBirdDetail() async {
        do {
            let latestBird = try await ApiService.shared.getBird(id: Int(bird.id))
            await MainActor.run {
                self.bird = latestBird
            }
        } catch {
            print("刷新鸟儿信息失败: \(error)")
        }
    }
    
    // MARK: - 删除鸟儿
    private func deleteBird() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
        isDeleting = true
        Task {
            do {
                try await ApiService.shared.deleteBird(id: bird.id)
                
                // 保存到回收站
                TrashService.shared.addDeletedBird(bird)
                
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    ToastManager.shared.showError(NSLocalizedString("删除失败，请检查网络后重试", comment: ""))
                }
                print("删除失败: \(error)")
            }
        }
    }
}

// 信息行组件
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

// 日志行组件
struct LogRowView: View {
    let log: BirdLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formatDate(log.logDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let weight = log.weight {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", weight))g")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
            Text(log.summary)
                .font(.subheadline)
                .lineLimit(2)
            
            // 显示图片缩略图
            if let imageUrls = log.imageUrls, !imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(imageUrls.prefix(4), id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    case .failure:
                                        Image(systemName: "photo")
                                            .frame(width: 60, height: 60)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 60, height: 60)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        // 超过4张显示更多
                        if imageUrls.count > 4 {
                            Text("+\(imageUrls.count - 4)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, height: 60)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.06))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("M月d日 HH:mm", comment: "")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        BirdDetailView(bird: Bird(
            id: 1,
            nickname: NSLocalizedString("小白", comment: ""),
            species: NSLocalizedString("虎皮鹦鹉", comment: ""),
            gender: "FEMALE",
            hatchDate: Date(),
            adoptionDate: nil,
            birthdayType: "HATCH",
            deathDate: nil,
            featherColor: NSLocalizedString("白色", comment: ""),
            source: NSLocalizedString("自家繁殖", comment: ""),
            avatarUrl: nil,
            notes: NSLocalizedString("爱安静，喜欢晒太阳", comment: ""),
            ageMonths: 612
        ))
    }
}
