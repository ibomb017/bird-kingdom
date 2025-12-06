import SwiftUI

struct AllBirdsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var birds: [Bird] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Text("加载失败")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task { await loadBirds() }
                    }
                }
            } else if birds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bird")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("还没有任何鸟档案")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(birds) { bird in
                        NavigationLink(destination: BirdDetailView(bird: bird)) {
                            BirdRowView(bird: bird)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("我的鸟舍")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddBirdView()) {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadBirds()
        }
    }
    
    private func loadBirds() async {
        isLoading = true
        errorMessage = nil
        do {
            birds = try await ApiService.shared.getBirds()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// 鸟列表行视图
struct BirdRowView: View {
    let bird: Bird
    
    var body: some View {
        HStack(spacing: 14) {
            // 头像
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.72, green: 0.89, blue: 0.78), Color(red: 0.60, green: 0.82, blue: 0.70)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "bird.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(bird.nickname)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(bird.species)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("年龄：\(bird.ageText)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        AllBirdsView()
    }
}
