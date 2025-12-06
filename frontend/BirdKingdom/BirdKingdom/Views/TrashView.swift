import SwiftUI

// MARK: - 回收站视图
struct TrashView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var trashService = TrashService.shared
    @ObservedObject var authService = AuthService.shared
    
    @State private var showEmptyAlert = false
    @State private var showRestoreAlert = false
    @State private var showVipAlert = false
    @State private var selectedBird: DeletedBird?
    @State private var isRestoring = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let dangerColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    var body: some View {
        NavigationView {
            Group {
                if trashService.deletedBirds.isEmpty {
                    emptyState
                } else {
                    deletedBirdsList
                }
            }
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.secondary)
                }
                
                if !trashService.deletedBirds.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("清空") {
                            showEmptyAlert = true
                        }
                        .foregroundColor(dangerColor)
                    }
                }
            }
            .alert("清空回收站", isPresented: $showEmptyAlert) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    trashService.emptyTrash()
                }
            } message: {
                Text("清空后将无法恢复，确定要清空回收站吗？")
            }
            .alert("恢复鸟儿", isPresented: $showRestoreAlert) {
                Button("取消", role: .cancel) {}
                Button("恢复") {
                    if let bird = selectedBird {
                        restoreBird(bird)
                    }
                }
            } message: {
                if let bird = selectedBird {
                    Text("确定要恢复「\(bird.nickname)」吗？")
                }
            }
            .alert("VIP专属功能", isPresented: $showVipAlert) {
                Button("开通VIP", role: .none) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowVIPPage"),
                            object: nil
                        )
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("恢复已删除的鸟儿是VIP专属功能，开通VIP后即可使用。")
            }
        }
    }
    
    // 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("回收站是空的")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("删除的鸟儿会在这里保留7天")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 已删除鸟儿列表
    private var deletedBirdsList: some View {
        List {
            Section {
                ForEach(trashService.deletedBirds) { bird in
                    deletedBirdRow(bird)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        trashService.permanentlyDelete(trashService.deletedBirds[index])
                    }
                }
            } header: {
                HStack {
                    Text("已删除的鸟儿")
                    Spacer()
                    Text("VIP可在7天内恢复")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text("左滑可永久删除，超过7天将自动清除")
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // 已删除鸟儿行
    private func deletedBirdRow(_ bird: DeletedBird) -> some View {
        HStack(spacing: 14) {
            // 头像
            ZStack {
                Circle()
                    .fill(forestGreen.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "bird.fill")
                    .font(.title3)
                    .foregroundColor(forestGreen.opacity(0.5))
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(bird.nickname)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(bird.species)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(bird.remainingDays > 0 ? "剩余\(bird.remainingDays)天" : "即将过期")
                        .font(.caption2)
                }
                .foregroundColor(bird.remainingDays <= 1 ? dangerColor : .secondary)
            }
            
            Spacer()
            
            // 恢复按钮
            Button {
                selectedBird = bird
                if authService.currentUser?.isVipValid == true {
                    showRestoreAlert = true
                } else {
                    showVipAlert = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption)
                    Text("恢复")
                        .font(.caption)
                }
                .foregroundColor(authService.currentUser?.isVipValid == true ? forestGreen : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (authService.currentUser?.isVipValid == true ? forestGreen : Color.gray).opacity(0.1)
                )
                .cornerRadius(14)
            }
            .disabled(isRestoring)
        }
        .padding(.vertical, 4)
    }
    
    // 恢复鸟儿
    private func restoreBird(_ bird: DeletedBird) {
        isRestoring = true
        Task {
            do {
                _ = try await trashService.restoreBird(bird)
                await MainActor.run {
                    isRestoring = false
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                }
                print("恢复失败: \(error)")
            }
        }
    }
}

#Preview {
    TrashView()
}
