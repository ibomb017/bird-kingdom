import SwiftUI

struct AllLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [BirdLog] = []
    @State private var birds: [Bird] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedBirdIndex: Int = 0  // 0 = 全部
    
    var body: some View {
        VStack(spacing: 0) {
            // 鸟筛选器
            if !birds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(
                            title: "全部",
                            isSelected: selectedBirdIndex == 0,
                            onTap: { selectedBirdIndex = 0 }
                        )
                        
                        ForEach(Array(birds.enumerated()), id: \.offset) { index, bird in
                            FilterChip(
                                title: bird.nickname,
                                isSelected: selectedBirdIndex == index + 1,
                                onTap: { selectedBirdIndex = index + 1 }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                
                Divider()
            }
            
            // 日志列表
            Group {
                if isLoading {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("加载失败")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("重试") {
                            Task { await loadData() }
                        }
                    }
                    Spacer()
                } else if filteredLogs.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("暂无日志记录")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groupedLogs.keys.sorted().reversed(), id: \.self) { dateKey in
                                Section {
                                    ForEach(groupedLogs[dateKey] ?? []) { log in
                                        TimelineLogRow(log: log)
                                    }
                                } header: {
                                    HStack {
                                        Text(dateKey)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fontWeight(.medium)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 6)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("全部日志")
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
                NavigationLink(destination: NewLogView()) {
                    Text("写新日志")
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private var filteredLogs: [BirdLog] {
        if selectedBirdIndex == 0 {
            return logs.sorted { $0.logDate > $1.logDate }
        } else {
            let birdName = birds[selectedBirdIndex - 1].nickname
            return logs.filter { $0.birdName == birdName }.sorted { $0.logDate > $1.logDate }
        }
    }
    
    private var groupedLogs: [String: [BirdLog]] {
        Dictionary(grouping: filteredLogs) { log in
            formatDateLabel(log.logDate)
        }
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let logDay = calendar.startOfDay(for: date)
        
        if logDay == today {
            return "今天"
        } else if logDay == calendar.date(byAdding: .day, value: -1, to: today) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let logsResult = ApiService.shared.getLogs()
            async let birdsResult = ApiService.shared.getBirds()
            
            let (fetchedLogs, fetchedBirds) = try await (logsResult, birdsResult)
            logs = fetchedLogs
            birds = fetchedBirds
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// 筛选芯片
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(red: 0.15, green: 0.45, blue: 0.38) : Color.gray.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}

// 时间线日志行
struct TimelineLogRow: View {
    let log: BirdLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间线
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(red: 0.15, green: 0.45, blue: 0.38))
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(Color(red: 0.15, green: 0.45, blue: 0.38).opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)
            
            // 日志卡片
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(log.birdName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                    
                    Spacer()
                    
                    Text(formatTime(log.logDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(log.summary)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.85))
                
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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.98, blue: 0.97),
                                Color(red: 0.94, green: 0.96, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        AllLogsView()
    }
}
