import SwiftUI

struct WeightTrendFullView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [BirdLog] = []
    @State private var birds: [Bird] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedBirdIndex: Int = 0  // 0 = 全部
    @State private var selectedRangeIndex: Int = 1  // 0: 1周, 1: 1月, 2: 3月, 3: 1年
    
    private let rangeOptions = ["1 周", "1 月", "3 月", "1 年"]
    private let rangeDays = [7, 30, 90, 365]
    
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
            }
            
            // 时间范围选择
            HStack(spacing: 8) {
                ForEach(Array(rangeOptions.enumerated()), id: \.offset) { index, option in
                    Button {
                        selectedRangeIndex = index
                    } label: {
                        Text(option)
                            .font(.subheadline)
                            .fontWeight(selectedRangeIndex == index ? .semibold : .regular)
                            .foregroundColor(selectedRangeIndex == index ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedRangeIndex == index ? Color.green : Color.gray.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // 图表区域
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
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 主图表
                            chartSection
                            
                            // 只有选中具体小鸟时才显示统计信息
                            if selectedBirdIndex != 0 {
                                statsSection
                            }
                            
                            // 体重记录列表（全部时显示所有鸟，选中时只显示该鸟）
                            recordsSection
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("体重趋势")
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
                NavigationLink(
                    destination: RecordWeightView(
                        birds: birds,
                        preselectedIndex: selectedBirdIndex == 0 ? nil : selectedBirdIndex - 1
                    )
                ) {
                    Text("记录体重")
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - 图表区域
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if selectedBirdIndex == 0 {
                Text("请选择一只小鸟查看体重趋势")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if filteredDataPoints.count < 2 {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title)
                        .foregroundColor(.green.opacity(0.5))
                    Text("暂无足够体重数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("记录至少 2 条体重即可查看趋势")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                GeometryReader { geometry in
                    let dataPoints = filteredDataPoints
                    let weights = dataPoints.map { $0.weight }
                    let minWeight = weights.min() ?? 0
                    let maxWeight = weights.max() ?? 0
                    let padding = max((maxWeight - minWeight) * 0.1, 5)
                    let lowerBound = max(minWeight - padding, 0)
                    let upperBound = maxWeight + padding
                    let range = max(upperBound - lowerBound, 1)
                    
                    let yTicks: [Double] = stride(from: 0, through: 4, by: 1).map { idx in
                        lowerBound + range * (Double(4 - idx) / 4.0)
                    }
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let leadingInset: CGFloat = 50
                    let bottomInset: CGFloat = 30
                    let topInset: CGFloat = 10
                    let trailingInset: CGFloat = 16
                    let plotWidth = width - leadingInset - trailingInset
                    let plotHeight = height - topInset - bottomInset
                    
                    ZStack {
                        // 轴线
                        Path { path in
                            path.move(to: CGPoint(x: leadingInset, y: topInset))
                            path.addLine(to: CGPoint(x: leadingInset, y: height - bottomInset))
                            path.move(to: CGPoint(x: leadingInset, y: height - bottomInset))
                            path.addLine(to: CGPoint(x: width - trailingInset, y: height - bottomInset))
                        }
                        .stroke(Color.green.opacity(0.6), lineWidth: 1)
                        
                        // Y 刻度
                        ForEach(Array(yTicks.enumerated()), id: \.offset) { _, value in
                            let normalized = (value - lowerBound) / range
                            let y = topInset + plotHeight * (1 - CGFloat(normalized))
                            
                            Path { path in
                                path.move(to: CGPoint(x: leadingInset, y: y))
                                path.addLine(to: CGPoint(x: width - trailingInset, y: y))
                            }
                            .stroke(Color.green.opacity(0.15), lineWidth: 1)
                            
                            Text("\(Int(value.rounded()))g")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: leadingInset - 8, alignment: .trailing)
                                .position(x: (leadingInset - 8) / 2, y: y)
                        }
                        
                        // 折线
                        Path { path in
                            for (index, point) in dataPoints.enumerated() {
                                let t = CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                                let x = leadingInset + plotWidth * t
                                let normalizedY = (point.weight - lowerBound) / range
                                let y = topInset + plotHeight * (1 - CGFloat(normalizedY))
                                let cgPoint = CGPoint(x: x, y: y)
                                if index == 0 {
                                    path.move(to: cgPoint)
                                } else {
                                    path.addLine(to: cgPoint)
                                }
                            }
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        
                        // 数据点
                        ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, point in
                            let t = CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                            let x = leadingInset + plotWidth * t
                            let normalizedY = (point.weight - lowerBound) / range
                            let y = topInset + plotHeight * (1 - CGFloat(normalizedY))
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.green, lineWidth: 2))
                                .position(x: x, y: y)
                        }
                        
                        // X 轴日期标签
                        VStack {
                            Spacer()
                            HStack {
                                ForEach(Array(dataPoints.enumerated()), id: \.offset) { _, point in
                                    Text(formatShortDate(point.date))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .frame(width: plotWidth)
                            .padding(.leading, leadingInset)
                            .padding(.trailing, trailingInset)
                            .padding(.bottom, 4)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.08), Color.green.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }
    
    // MARK: - 统计信息
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "最新体重", value: latestWeight, unit: "g", color: .green)
            StatCard(title: "平均体重", value: averageWeight, unit: "g", color: .blue)
            StatCard(title: "记录次数", value: String(filteredDataPoints.count), unit: "次", color: .orange)
        }
    }
    
    // MARK: - 体重记录列表
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("体重记录")
                .font(.headline)
            
            if weightRecordsWithBirdName.isEmpty {
                Text("暂无记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(Array(weightRecordsWithBirdName.prefix(10).enumerated()), id: \.offset) { _, record in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            // 选择"全部"时显示鸟名
                            if selectedBirdIndex == 0 {
                                Text(record.birdName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.38))
                            }
                            Text(formatFullDate(record.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(String(format: "%.1f", record.weight)) g")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.06))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }
    
    // 带鸟名的体重记录（每只鸟每天取最新一条）
    private var weightRecordsWithBirdName: [(birdName: String, date: Date, weight: Double)] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rangeDays[selectedRangeIndex], to: Date()) ?? Date()
        
        let sourceLogs: [BirdLog]
        if selectedBirdIndex == 0 {
            sourceLogs = logs
        } else {
            let birdName = birds[selectedBirdIndex - 1].nickname
            sourceLogs = logs.filter { $0.birdName == birdName }
        }
        
        // 筛选有体重且在时间范围内的日志
        let logsWithWeight = sourceLogs
            .filter { $0.logDate >= cutoffDate }
            .compactMap { log -> (id: Int64, birdName: String, date: Date, weight: Double)? in
                guard let w = log.weight else { return nil }
                return (log.id, log.birdName, log.logDate, w)
            }
        
        // 按 (鸟名+日期) 分组，每组取 id 最大的
        var latestByBirdDate: [String: (birdName: String, date: Date, weight: Double, id: Int64)] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for item in logsWithWeight {
            let key = "\(item.birdName)_\(dateFormatter.string(from: item.date))"
            if let existing = latestByBirdDate[key] {
                if item.id > existing.id {
                    latestByBirdDate[key] = (item.birdName, item.date, item.weight, item.id)
                }
            } else {
                latestByBirdDate[key] = (item.birdName, item.date, item.weight, item.id)
            }
        }
        
        // 按日期倒序排列
        return latestByBirdDate.values
            .sorted { $0.date > $1.date }
            .map { (birdName: $0.birdName, date: $0.date, weight: $0.weight) }
    }
    
    // MARK: - 计算属性
    private var filteredDataPoints: [(date: Date, weight: Double)] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rangeDays[selectedRangeIndex], to: Date()) ?? Date()
        
        let sourceLogs: [BirdLog]
        if selectedBirdIndex == 0 {
            sourceLogs = logs
        } else {
            let birdName = birds[selectedBirdIndex - 1].nickname
            sourceLogs = logs.filter { $0.birdName == birdName }
        }
        
        // 筛选有体重且在时间范围内的日志
        let logsWithWeight = sourceLogs
            .filter { $0.logDate >= cutoffDate }
            .compactMap { log -> (id: Int64, date: Date, weight: Double)? in
                guard let w = log.weight else { return nil }
                return (log.id, log.logDate, w)
            }
        
        // 按日期分组，每天只取 id 最大的那条（最新）
        var latestByDate: [String: (date: Date, weight: Double, id: Int64)] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for item in logsWithWeight {
            let key = dateFormatter.string(from: item.date)
            if let existing = latestByDate[key] {
                if item.id > existing.id {
                    latestByDate[key] = (item.date, item.weight, item.id)
                }
            } else {
                latestByDate[key] = (item.date, item.weight, item.id)
            }
        }
        
        return latestByDate.values
            .sorted { $0.date < $1.date }
            .map { (date: $0.date, weight: $0.weight) }
    }
    
    private var latestWeight: String {
        guard let last = filteredDataPoints.last else { return "--" }
        return String(format: "%.1f", last.weight)
    }
    
    private var averageWeight: String {
        guard !filteredDataPoints.isEmpty else { return "--" }
        let avg = filteredDataPoints.map { $0.weight }.reduce(0, +) / Double(filteredDataPoints.count)
        return String(format: "%.1f", avg)
    }
    
    // MARK: - 辅助方法
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
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

// 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

#Preview {
    NavigationStack {
        WeightTrendFullView()
    }
}
