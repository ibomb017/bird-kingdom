import SwiftUI

struct BirdDetailView: View {
    let bird: Bird
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var logs: [BirdLog] = []
    @State private var isLoadingLogs = false
    @State private var showShareView = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let dangerColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 头像区域
                avatarSection
                
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
        .navigationTitle(bird.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // 共享按钮
                    Button {
                        showShareView = true
                    } label: {
                        Image(systemName: "person.2")
                    }
                    
                    // 编辑按钮（仅主人和共同主人可见）
                    if bird.canEdit {
                        Button("编辑") {
                            isEditing = true
                        }
                    }
                    
                    // 删除按钮（仅主人可见）
                    if bird.isOwner {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("删除鸟儿", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteBird()
            }
        } message: {
            Text("删除后，鸟儿信息将移入回收站。VIP用户可在7天内恢复。")
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EditBirdView(bird: bird)
            }
        }
        .sheet(isPresented: $showShareView) {
            BirdShareView(bird: bird)
        }
        .task {
            await loadLogs()
        }
    }
    
    // MARK: - 头像区域
    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.72, green: 0.89, blue: 0.78), Color(red: 0.55, green: 0.78, blue: 0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bird.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            Text(bird.nickname)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("\(bird.species) · \(bird.ageText)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
    
    // MARK: - 主人与共享信息卡片
    private var ownershipCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("主人信息", systemImage: "person.crop.circle.fill")
                .font(.headline)
                .foregroundColor(forestGreen)
            
            Divider()
            
            // 主人信息
            HStack(spacing: 12) {
                Circle()
                    .fill(forestGreen.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bird.ownerName ?? "我")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(bird.isOwner ? "主人（你）" : "主人")
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
            
            // 共享状态
            if bird.isShared == true {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("此鸟已共享给其他用户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        showShareView = true
                    } label: {
                        Text("管理")
                            .font(.caption)
                            .foregroundColor(forestGreen)
                    }
                }
                .padding(10)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }
    
    private var roleText: String {
        switch bird.shareRole {
        case .owner, .none: return "主人"
        case .viewer: return "查看者"
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
            Label("基础信息", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
            
            Divider()
            
            InfoRow(label: "昵称", value: bird.nickname)
            InfoRow(label: "品种", value: bird.species)
            InfoRow(label: "性别", value: genderText)
            InfoRow(label: "出生日期", value: birthDateText)
            InfoRow(label: "年龄", value: bird.ageText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - 外观与来源卡片
    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("外观与来源", systemImage: "paintbrush.fill")
                .font(.headline)
                .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
            
            Divider()
            
            InfoRow(label: "羽色", value: bird.featherColor ?? "未填写")
            InfoRow(label: "来源", value: bird.source ?? "未填写")
            
            if let notes = bird.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("备注")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(notes)
                        .font(.body)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - 最近日志
    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("最近日志", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                Spacer()
            }
            
            if isLoadingLogs {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if logs.isEmpty {
                Text("暂无日志记录")
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - Helpers
    private var genderText: String {
        switch bird.gender {
        case "MALE": return "公"
        case "FEMALE": return "母"
        case "UNKNOWN": return "未知"
        default: return bird.gender ?? "未填写"
        }
    }
    
    private var birthDateText: String {
        let date: Date?
        if bird.birthdayType == "ADOPTION", let adoptionDate = bird.adoptionDate {
            date = adoptionDate
        } else {
            date = bird.hatchDate
        }
        
        guard let validDate = date else { return "未填写" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: validDate)
    }
    
    private func loadLogs() async {
        isLoadingLogs = true
        do {
            let allLogs = try await ApiService.shared.getLogs()
            logs = allLogs.filter { $0.birdName == bird.nickname }
                .sorted { $0.logDate > $1.logDate }
        } catch {
            print("加载日志失败: \(error)")
        }
        isLoadingLogs = false
    }
    
    // MARK: - 删除鸟儿
    private func deleteBird() {
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
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        BirdDetailView(bird: Bird(
            id: 1,
            nickname: "小白",
            species: "虎皮鹦鹉",
            gender: "FEMALE",
            hatchDate: Date(),
            adoptionDate: nil,
            birthdayType: "HATCH",
            deathDate: nil,
            featherColor: "白色",
            source: "自家繁殖",
            avatarUrl: nil,
            notes: "爱安静，喜欢晒太阳",
            ageMonths: 612
        ))
    }
}
