import SwiftUI
import Charts

/// 体重趋势图表组件 - 股票K线风格
/// 设计理念：类似股票走势图，干净优雅，根据时间范围智能控制数据点显示
struct WeightTrendChartView: View {
    let weightPoints: [(date: Date, weight: Double)]
    let speciesWeightMin: Double?
    let speciesWeightMax: Double?
    let primaryColor: Color
    
    // 时间范围类型 - 控制显示策略
    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case year = "1Y"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            }
        }
        
        /// 数据点 ≤ 此值时显示圆点
        var showDotsThreshold: Int {
            switch self {
            case .week: return 14      // 7天内，所有点都显示
            case .month: return 15     // 1月内，最多15个点显示
            case .threeMonths: return 0 // 3月仅显示曲线
            case .year: return 0       // 1年仅显示曲线
            }
        }
        
        /// X轴日期格式
        var dateFormat: String {
            switch self {
            case .week: return "E"        // 周几
            case .month: return "M/d"     // 月/日
            case .threeMonths: return NSLocalizedString("M月", comment: "") // 月
            case .year: return "yyyy/M"   // 年/月
            }
        }
        
        /// X轴期望刻度数
        var desiredAxisCount: Int {
            switch self {
            case .week: return 7
            case .month: return 5
            case .threeMonths: return 4
            case .year: return 6
            }
        }
    }
    
    // 配置项
    var timeRange: TimeRange = .week
    var showHeader: Bool = true
    var showCard: Bool = true
    var showLegend: Bool = true
    var isCompact: Bool = false  // 首页紧凑模式
    var fixedDateRange: (start: Date, end: Date)? = nil  // 固定X轴范围
    
    // MARK: - 交互状态
    @State private var selectedPoint: (date: Date, weight: Double)?
    @State private var dragLocation: CGFloat?
    
    // MARK: - 计算属性
    
    /// 预处理后的数据点：
    /// 1. 日期归一化到当天零点（Asia/Shanghai），避免同一天多条记录出现在不同X位置
    /// 2. 同一天保留最新一条（按时间戳排序后取最后一个）
    /// 3. 按日期升序排列
    private var processedPoints: [(date: Date, weight: Double)] {
        guard !weightPoints.isEmpty else { return [] }
        
        let calendar = Calendar(identifier: .gregorian)
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        
        // 按原始日期分组到同一天，同日取最后一条（假定传入数据按时间排序，后面覆盖前面）
        var latestByDay: [DateComponents: (date: Date, weight: Double)] = [:]
        for point in weightPoints {
            let components = cal.dateComponents([.year, .month, .day], from: point.date)
            latestByDay[components] = point  // 后面的覆盖前面的，即同日取最新
        }
        
        // 将日期归一化到当天零点，按日期升序排列
        return latestByDay.map { (components, point) in
            let normalizedDate = cal.date(from: components) ?? point.date
            return (date: normalizedDate, weight: point.weight)
        }
        .sorted { $0.date < $1.date }
    }
    
    /// 是否显示数据点圆点
    private var shouldShowDots: Bool {
        let threshold = timeRange.showDotsThreshold
        guard threshold > 0 else { return false }
        return processedPoints.count <= threshold
    }
    
    private var yAxisMin: Double {
        guard !processedPoints.isEmpty else { return 0 }
        let minWeight = processedPoints.map { $0.weight }.min() ?? 0
        let specMin = speciesWeightMin ?? minWeight
        let lowest = min(minWeight, specMin)
        let padding = max((yAxisMax_raw - lowest) * 0.1, 1)
        return max(0, lowest - padding)
    }
    
    private var yAxisMax_raw: Double {
        guard !processedPoints.isEmpty else { return 100 }
        let maxWeight = processedPoints.map { $0.weight }.max() ?? 100
        let specMax = speciesWeightMax ?? maxWeight
        return max(maxWeight, specMax)
    }
    
    private var yAxisMax: Double {
        let highest = yAxisMax_raw
        let lowest = processedPoints.map { $0.weight }.min() ?? 0
        let specMin = speciesWeightMin ?? lowest
        let trueLowest = min(lowest, specMin)
        let padding = max((highest - trueLowest) * 0.1, 1)
        return highest + padding
    }
    
    /// 最新体重
    private var latestWeight: Double? {
        processedPoints.last?.weight
    }
    
    /// 体重变化（相对第一个点）
    private var weightChange: (value: Double, percentage: Double)? {
        guard processedPoints.count >= 2,
              let first = processedPoints.first?.weight,
              let last = processedPoints.last?.weight else { return nil }
        let change = last - first
        let pct = first > 0 ? (change / first) * 100 : 0
        return (change, pct)
    }
    
    /// 趋势颜色
    private var trendColor: Color {
        guard let change = weightChange else { return primaryColor }
        if change.value > 0 { return Color(red: 0.2, green: 0.72, blue: 0.45) }  // 涨绿色
        if change.value < 0 { return Color(red: 0.95, green: 0.35, blue: 0.35) }  // 跌红色
        return .secondary
    }
    
    private var xDomain: ClosedRange<Date> {
        if let fixed = fixedDateRange {
            return fixed.start...fixed.end
        }
        let start = processedPoints.first?.date ?? Date()
        let end = processedPoints.last?.date ?? Date()
        // 确保范围至少有1天
        if start == end {
            return start.addingTimeInterval(-86400)...end.addingTimeInterval(86400)
        }
        return start...end
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 2 : 8) {
            if showHeader {
                headerView
            }
            
            if processedPoints.isEmpty {
                emptyState
            } else if processedPoints.count < 2 {
                singlePointState
            } else {
                chartContent
            }
            
            if showLegend && !isCompact && (speciesWeightMin != nil || speciesWeightMax != nil) {
                legendView
            }
        }
        .padding(showCard ? 12 : 0)
        .background(
            Group {
                if showCard {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.adaptiveCard)
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                } else {
                    Color.clear
                }
            }
        )
    }
    
    // MARK: - 头部（股票风格）
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.weightRecord)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if let display = selectedPoint ?? processedPoints.last {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", display.weight))
                            .font(.system(size: isCompact ? 20 : 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("g")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .contentTransition(.numericText())
                }
            }
            
            Spacer()
            
            // 涨跌幅标签
            if let change = weightChange, selectedPoint == nil {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: change.value >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%+.1f g", change.value))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(trendColor)
                    
                    Text(String(format: "%+.1f%%", change.percentage))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(trendColor.opacity(0.8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(trendColor.opacity(0.1))
                )
            }
            
            // 选中状态：显示日期
            if let selected = selectedPoint {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDetailDate(selected.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    if !isHealthy(selected.weight) {
                        Text(NSLocalizedString("⚠️ 异常", comment: ""))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(colors: [primaryColor.opacity(0.6), primaryColor.opacity(0.3)],
                                   startPoint: .top, endPoint: .bottom)
                )
            Text(NSLocalizedString("暂无体重记录", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isCompact ? 80 : 120)
    }
    
    private var singlePointState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(primaryColor.opacity(0.5))
            Text(NSLocalizedString("再记录一次体重即可查看趋势", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isCompact ? 80 : 120)
    }
    
    // MARK: - 图表主体
    @ViewBuilder
    private var chartContent: some View {
        Chart {
            // 1. 健康范围 - 极简渐变带，不用边框线
            if let minW = speciesWeightMin, let maxW = speciesWeightMax {
                // 柔和的健康区间背景
                RectangleMark(
                    xStart: nil, xEnd: nil,
                    yStart: .value("Min", minW),
                    yEnd: .value("Max", maxW)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.06),
                            Color.green.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            // 2. 面积渐变填充 - 轻盈通透
            ForEach(Array(processedPoints.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Baseline", yAxisMin),
                    yEnd: .value("Weight", point.weight)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            primaryColor.opacity(0.18),
                            primaryColor.opacity(0.06),
                            primaryColor.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            
            // 3. 主曲线 - 更粗更平滑
            ForEach(Array(processedPoints.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [primaryColor, primaryColor.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: isCompact ? 2 : 2.5, lineCap: .round, lineJoin: .round))
            }
            
            // 4. 数据点 - 仅短范围显示，白底彩边
            if shouldShowDots {
                ForEach(Array(processedPoints.enumerated()), id: \.offset) { _, point in
                    // 白色底圆
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(Color.white)
                    .symbolSize(28)
                    
                    // 彩色外圈
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(isHealthy(point.weight) ? primaryColor : Color.red)
                    .symbolSize(12)
                }
            }
            
            // 5. 交互指示线
            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.date))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [5, 3]))
                    .foregroundStyle(Color.primary.opacity(0.2))
                
                // 光晕底
                PointMark(
                    x: .value("Date", selected.date),
                    y: .value("Weight", selected.weight)
                )
                .foregroundStyle(primaryColor.opacity(0.2))
                .symbolSize(120)
                
                // 白底
                PointMark(
                    x: .value("Date", selected.date),
                    y: .value("Weight", selected.weight)
                )
                .foregroundStyle(Color.white)
                .symbolSize(50)
                
                // 实心点
                PointMark(
                    x: .value("Date", selected.date),
                    y: .value("Weight", selected.weight)
                )
                .foregroundStyle(isHealthy(selected.weight) ? primaryColor : .red)
                .symbolSize(20)
            }
        }
        .chartYScale(domain: yAxisMin...yAxisMax)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic(desiredCount: timeRange.desiredAxisCount)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Color.gray.opacity(0.06))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatXAxisDate(date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: isCompact ? 3 : 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(Color.gray.opacity(0.06))
                AxisValueLabel {
                    if let w = value.as(Double.self) {
                        Text(w >= 100 ? "\(Int(w))" : String(format: "%.1f", w))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let origin = geometry[proxy.plotAreaFrame].origin
                                let x = value.location.x - origin.x
                                dragLocation = value.location.x
                                
                                if let date: Date = proxy.value(atX: x) {
                                    if let closest = processedPoints.min(by: {
                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                    }) {
                                        if selectedPoint?.date != closest.date {
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                        }
                                        withAnimation(.easeOut(duration: 0.1)) {
                                            selectedPoint = closest
                                        }
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedPoint = nil
                                    dragLocation = nil
                                }
                            }
                    )
            }
        }
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .frame(height: isCompact ? 110 : 200)
    }
    
    // MARK: - 图例
    private var legendView: some View {
        HStack(spacing: 16) {
            legendItem(color: primaryColor, label: NSLocalizedString("体重曲线", comment: ""), isLine: true)
            
            if shouldShowDots {
                legendItem(color: .red, label: NSLocalizedString("异常体重", comment: ""), isDot: true)
            }
            
            if speciesWeightMin != nil && speciesWeightMax != nil {
                legendItem(color: .green.opacity(0.3), label: NSLocalizedString("健康范围", comment: ""), isArea: true)
            }
        }
        .padding(.top, 4)
    }
    
    private func legendItem(color: Color, label: String, isLine: Bool = false, isDot: Bool = false, isArea: Bool = false) -> some View {
        HStack(spacing: 4) {
            if isLine {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 12, height: 2)
            } else if isDot {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            } else if isArea {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 10, height: 6)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 辅助逻辑
    
    private func isHealthy(_ weight: Double) -> Bool {
        guard let min = speciesWeightMin, let max = speciesWeightMax else { return true }
        return weight >= min && weight <= max
    }
    
    private func formatXAxisDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = timeRange.dateFormat
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: date)
    }
    
    private func formatDetailDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = NSLocalizedString("M月d日", comment: "")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: date)
    }
}

#Preview {
    VStack(spacing: 20) {
        // 7天 - 显示数据点
        WeightTrendChartView(
            weightPoints: [
                (date: Date().addingTimeInterval(-6*86400), weight: 35.2),
                (date: Date().addingTimeInterval(-5*86400), weight: 35.8),
                (date: Date().addingTimeInterval(-4*86400), weight: 36.1),
                (date: Date().addingTimeInterval(-3*86400), weight: 42.5),
                (date: Date().addingTimeInterval(-2*86400), weight: 36.3),
                (date: Date().addingTimeInterval(-1*86400), weight: 31.0),
                (date: Date(), weight: 36.5)
            ],
            speciesWeightMin: 32,
            speciesWeightMax: 40,
            primaryColor: Color(red: 0.14, green: 0.42, blue: 0.29),
            timeRange: .week
        )
        .padding(.horizontal)
        
        // 1年 - 仅显示曲线
        WeightTrendChartView(
            weightPoints: (0..<50).map { i in
                (date: Date().addingTimeInterval(Double(-365 + i * 7) * 86400),
                 weight: 35.0 + Double.random(in: -3...5))
            },
            speciesWeightMin: 32,
            speciesWeightMax: 40,
            primaryColor: Color(red: 0.14, green: 0.42, blue: 0.29),
            timeRange: .year
        )
        .padding(.horizontal)
        
        // 紧凑模式（首页）
        WeightTrendChartView(
            weightPoints: [
                (date: Date().addingTimeInterval(-6*86400), weight: 35.2),
                (date: Date().addingTimeInterval(-3*86400), weight: 36.1),
                (date: Date(), weight: 36.5)
            ],
            speciesWeightMin: 32,
            speciesWeightMax: 40,
            primaryColor: .blue,
            timeRange: .week,
            showHeader: false,
            showCard: false,
            showLegend: false,
            isCompact: true
        )
        .padding(.horizontal)
    }
    .padding()
}
