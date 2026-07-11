import SwiftUI

struct AllBirdsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var birds: [Bird] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddBird = false
    @State private var birdToMarkFound: Bird? = nil  // 确认找回的鸟
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    var body: some View {
        Group {
            if isLoading {
                UnifiedStateView.loading
            } else if let error = errorMessage {
                UnifiedStateView.error(error) {
                    Task { await loadBirds() }
                }
            } else if birds.isEmpty {
                EmptyBirdsView()
            } else {
                List {
                    ForEach(birds) { bird in
                        NavigationLink(destination: BirdDetailView(bird: bird)) {
                            BirdRowView(bird: bird)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if bird.isLost == true {
                                Button {
                                    birdToMarkFound = bird
                                } label: {
                                    Label(NSLocalizedString("找到了", comment: ""), systemImage: "checkmark.circle.fill")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .themedBackground()
        .navigationTitle(NSLocalizedString("我的鸟舍", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddBird = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(primaryColor)
                }
            }
        }
        .navigationDestination(isPresented: $showAddBird) {
            AddBirdView()
                .hidesTabBar()
        }
        .task {
            await loadBirds()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshBirds"))) { _ in
            Task {
                await loadBirds()
            }
        }
        .hidesTabBar()  // 进入详情页时隐藏底部导航栏
        .alert(NSLocalizedString("确认找回", comment: ""), isPresented: .init(
            get: { birdToMarkFound != nil },
            set: { if !$0 { birdToMarkFound = nil } }
        )) {
            Button(NSLocalizedString("取消", comment: ""), role: .cancel) { birdToMarkFound = nil }
            Button(NSLocalizedString("确认找回", comment: "")) {
                if let bird = birdToMarkFound {
                    markBirdAsFound(bird)
                }
                birdToMarkFound = nil
            }
        } message: {
            let formatStr = NSLocalizedString("确认 %@ 已经找回了吗？", comment: "")
            let name = birdToMarkFound?.nickname ?? ""
            Text(String(format: formatStr, name))
        }
    }
    
    private func loadBirds() async {
        guard AuthService.shared.isLoggedIn else {
            birds = []
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        do {
            birds = try await ApiService.shared.getBirds()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func markBirdAsFound(_ bird: Bird) {
        // 先保存原始状态以便回滚
        guard let index = birds.firstIndex(where: { $0.id == bird.id }) else { return }
        let originalBird = birds[index]
        
        // 乐观更新 UI
        var updatedBird = originalBird
        updatedBird.isLost = false
        updatedBird.lostDate = nil
        updatedBird.lostLocation = nil
        updatedBird.lostPostId = nil
        birds[index] = updatedBird
        
        Task {
            do {
                try await ApiService.shared.updateBirdLostStatus(birdId: bird.id, isLost: false)
            } catch {
                // API 失败：回滚状态
                await MainActor.run {
                    if let idx = birds.firstIndex(where: { $0.id == bird.id }) {
                        birds[idx] = originalBird
                    }
                    ToastManager.shared.showError(NSLocalizedString("操作失败，请检查网络", comment: ""))
                }
                print("❌ 更新鸟儿状态失败: \(error)")
            }
        }
    }
}

// 鸟列表行视图
struct BirdRowView: View {
    let bird: Bird
    @ObservedObject private var themeManager = ThemeManager.shared
    private var primaryColor: Color { themeManager.primaryColor }
    
    private var avatarColors: [Color] {
        if bird.isDead {
            return [Color(red: 0.45, green: 0.45, blue: 0.47), Color(red: 0.38, green: 0.38, blue: 0.40)]
        } else {
            return [primaryColor.opacity(0.7), primaryColor.opacity(0.5)]
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: avatarColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                if let avatarUrl = bird.avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .saturation(bird.isDead ? 0.3 : 1.0)
                                .opacity(bird.isDead ? 0.8 : 1.0)
                        default:
                            Image("bird")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                } else {
                    Image("bird")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if bird.isDead {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "cross.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(bird.nickname)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(bird.isDead ? .gray : .primary)
                    
                    if bird.isDead {
                        Text(NSLocalizedString("已故", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray)
                            .cornerRadius(4)
                    }
                }
                
                Text(bird.species)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(String(format: NSLocalizedString("年龄：%@", comment: ""), bird.ageText))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    AllBirdsView()
}
