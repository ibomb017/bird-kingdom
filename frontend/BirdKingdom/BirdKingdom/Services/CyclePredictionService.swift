import Foundation

/// 周期预测服务
/// 提供企业级的周期预测算法，包含置信度计算、异常检测、年龄调整和解释性输出
class CyclePredictionService {
    static let shared = CyclePredictionService()
    
    private init() {}
    
    // MARK: - 配置参数
    
    /// 最小预测所需记录数
    private let minRecordsForPrediction = 3
    
    /// 变异系数阈值（超过此值降低置信度）
    private let lowConfidenceCVThreshold = 0.15
    private let unreliableCVThreshold = 0.25
    
    /// 预测区间的标准差倍数
    private let predictionWindowSigma = 1.5
    
    /// 各周期类型的合理间隔范围（天）
    private let validIntervalRanges: [CycleType: ClosedRange<Int>] = [
        .EGG_LAYING: 14...60,    // 产蛋期：2 周 - 2 个月
        .BATHING: 1...14         // 洗澡周期：1-14 天
    ]
    
    // MARK: - 年龄阶段定义（月龄）
    
    /// 各物种的性成熟月龄（开始具备繁殖能力）
    /// 小型鸟：4-10月，中型鸟：10-18月，大型鸟：24-48月
    private let maturityAgeMonths: [String: Int] = [
        // 小型鹦鹉（4-10月龄成熟）
        "虎皮鹦鹉": 4,          // 最早可4月龄，建议8月龄后繁殖
        "牡丹鹦鹉": 10,
        "桃脸牡丹鹦鹉": 10,
        "面罩牡丹鹦鹉": 10,
        "小太阳鹦鹉": 10,
        "绿颊锥尾鹦鹉": 10,
        "和尚鹦鹉": 10,
        "太平洋鹦鹉": 8,
        "横斑鹦鹉": 10,
        
        // 中型鹦鹉（10-18月龄成熟）
        "玄凤鹦鹉": 12,
        "鸡尾鹦鹉": 12,
        "金太阳鹦鹉": 18,
        "太阳锥尾鹦鹉": 18,
        "月轮鹦鹉": 18,
        "亚历山大鹦鹉": 24,
        "环颈鹦鹉": 18,
        "塞内加尔鹦鹉": 24,
        "迈耶氏鹦鹉": 24,
        "凯克鹦鹉": 24,
        "白腹凯克鹦鹉": 24,
        "黑头凯克鹦鹉": 24,
        
        // 大型鹦鹉（24-48月龄成熟）
        "非洲灰鹦鹉": 36,
        "灰鹦鹉": 36,
        "亚马逊鹦鹉": 36,
        "蓝帽亚马逊": 36,
        "折衷鹦鹉": 36,
        "吸蜜鹦鹉": 24,
        "彩虹吸蜜鹦鹉": 24,
        "葵花凤头鹦鹉": 48,
        "白凤头鹦鹉": 48,
        "鲑色凤头鹦鹉": 48,
        "金刚鹦鹉": 48,
        "蓝黄金刚鹦鹉": 48,
        "绿翅金刚鹦鹉": 48,
        "红绿金刚鹦鹉": 48,
        
        "default": 12  // 默认使用中型鸟的标准
    ]
    
    /// 各物种的老年期月龄（生理机能开始下降）
    /// 小型鸟：5-8年，中型鸟：7-15年，大型鸟：15-40年
    private let seniorAgeMonths: [String: Int] = [
        // 小型鹦鹉（5-8年进入老年）
        "虎皮鹦鹉": 60,         // 寿命7-10年
        "牡丹鹦鹉": 60,         // 寿命10-15年
        "桃脸牡丹鹦鹉": 60,
        "面罩牡丹鹦鹉": 60,
        "小太阳鹦鹉": 72,
        "绿颊锥尾鹦鹉": 72,
        "和尚鹦鹉": 72,
        "太平洋鹦鹉": 60,
        "横斑鹦鹉": 60,
        
        // 中型鹦鹉（7-15年进入老年）
        "玄凤鹦鹉": 84,         // 寿命15-25年
        "鸡尾鹦鹉": 84,
        "金太阳鹦鹉": 180,      // 寿命25-30年
        "太阳锥尾鹦鹉": 180,
        "月轮鹦鹉": 120,
        "亚历山大鹦鹉": 180,
        "环颈鹦鹉": 120,
        "塞内加尔鹦鹉": 180,
        "迈耶氏鹦鹉": 180,
        "凯克鹦鹉": 180,
        "白腹凯克鹦鹉": 180,
        "黑头凯克鹦鹉": 180,
        
        // 大型鹦鹉（15-40年进入老年）
        "非洲灰鹦鹉": 240,      // 寿命40-60年
        "灰鹦鹉": 240,
        "亚马逊鹦鹉": 300,
        "蓝帽亚马逊": 300,
        "折衷鹦鹉": 240,
        "吸蜜鹦鹉": 180,
        "彩虹吸蜜鹦鹉": 180,
        "葵花凤头鹦鹉": 360,    // 寿命50-70年
        "白凤头鹦鹉": 360,
        "鲑色凤头鹦鹉": 360,
        "金刚鹦鹉": 420,        // 寿命50-80年
        "蓝黄金刚鹦鹉": 420,
        "绿翅金刚鹦鹉": 420,
        "红绿金刚鹦鹉": 420,
        
        "default": 60  // 默认使用小型鸟的标准（保守）
    ]
    
    // MARK: - 主预测方法
    
    /// 生成周期预测结果
    /// - Parameters:
    ///   - cycles: 历史周期记录
    ///   - cycleType: 周期类型
    ///   - speciesReference: 品种参考值
    ///   - birdAgeMonths: 鸟的月龄（可选，用于年龄调整）
    ///   - speciesName: 物种名称（可选，用于年龄阈值查询）
    func predict(
        cycles: [BirdCycleRecord],
        cycleType: CycleType,
        speciesReference: (min: Int, max: Int)? = nil,
        birdAgeMonths: Int? = nil,
        speciesName: String? = nil
    ) -> CyclePredictionResult {
        
        // 1. 年龄相关检查
        let ageAnalysis = analyzeAge(
            ageMonths: birdAgeMonths,
            cycleType: cycleType,
            speciesName: speciesName
        )
        
        // 如果年龄不适合该周期类型，返回特殊结果
        if let ageWarning = ageAnalysis.blockingWarning {
            return CyclePredictionResult(
                status: .unreliable,
                confidence: .low,
                source: .unknown,
                reasoning: ageWarning,
                ageStage: ageAnalysis.stage
            )
        }
        
        // 2. 过滤出指定类型的已结束周期
        let completedCycles = cycles
            .filter { $0.cycleType == cycleType && $0.endDate != nil }
            .sorted { $0.startDate > $1.startDate }  // 按开始日期倒序
        
        // 3. 检查最小数据量
        guard completedCycles.count >= minRecordsForPrediction else {
            return createInsufficientDataResult(
                cycles: completedCycles,
                speciesReference: speciesReference,
                ageAnalysis: ageAnalysis
            )
        }
        
        // 4. 计算间隔
        let intervals = calculateIntervals(completedCycles)
        guard !intervals.isEmpty else {
            return CyclePredictionResult(
                status: .noData,
                reasoning: "无法计算周期间隔"
            )
        }
        
        // 5. 统计分析
        let stats = calculateStatistics(intervals)
        
        // 6. 检查是否有异常周期
        let anomalousCycles = completedCycles.filter { $0.isAnomalous }
        
        // 7. 计算置信度（考虑年龄因素）
        var confidence = calculateConfidence(
            recordCount: completedCycles.count,
            cv: stats.cv,
            hasAnomalies: !anomalousCycles.isEmpty
        )
        
        // 年龄调整置信度
        confidence = adjustConfidenceForAge(confidence, ageAnalysis: ageAnalysis)
        
        // 8. 生成预测
        guard let lastCycle = completedCycles.first,
              let lastEndDate = lastCycle.endDate else {
            return CyclePredictionResult(status: .noData, reasoning: "无最近周期数据")
        }
        
        // 年龄调整预测间隔（传递 intervals 以支持老年期趋势检测）
        let adjustedMean = adjustIntervalForAge(stats.mean, ageAnalysis: ageAnalysis, cycleType: cycleType, intervals: intervals)
        
        let expectedDate = Calendar.current.date(byAdding: .day, value: adjustedMean, to: lastEndDate)!
        let earliestDate = Calendar.current.date(byAdding: .day, value: max(1, adjustedMean - Int(stats.stdDev * predictionWindowSigma)), to: lastEndDate)!
        let latestDate = Calendar.current.date(byAdding: .day, value: adjustedMean + Int(stats.stdDev * predictionWindowSigma), to: lastEndDate)!
        
        // 9. 生成解释
        let reasoning = generateReasoning(
            cycleType: cycleType,
            recordCount: completedCycles.count,
            stats: stats,
            lastEndDate: lastEndDate,
            confidence: confidence,
            anomalyCount: anomalousCycles.count,
            ageAnalysis: ageAnalysis,
            intervalAdjustment: adjustedMean - stats.mean
        )
        
        return CyclePredictionResult(
            status: .predicted,
            earliestDate: earliestDate,
            expectedDate: expectedDate,
            latestDate: latestDate,
            confidence: confidence,
            source: .individualHistory,
            reasoning: reasoning,
            statistics: stats,
            ageStage: ageAnalysis.stage
        )
    }
    
    // MARK: - 辅助方法
    
    /// 计算周期间隔数组
    private func calculateIntervals(_ cycles: [BirdCycleRecord]) -> [Int] {
        guard cycles.count >= 2 else { return [] }
        var intervals: [Int] = []
        
        for i in 0..<(cycles.count - 1) {
            let days = Calendar.current.dateComponents(
                [.day],
                from: cycles[i + 1].startDate,
                to: cycles[i].startDate
            ).day ?? 0
            intervals.append(abs(days))
        }
        
        return intervals
    }
    
    /// 计算统计指标
    private func calculateStatistics(_ intervals: [Int]) -> PredictionStatistics {
        guard !intervals.isEmpty else {
            return PredictionStatistics(mean: 0, stdDev: 0, cv: 1.0, min: 0, max: 0)
        }
        
        let mean = intervals.reduce(0, +) / intervals.count
        let variance = intervals.map { Double(($0 - mean) * ($0 - mean)) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? stdDev / Double(mean) : 1.0
        
        return PredictionStatistics(
            mean: mean,
            stdDev: stdDev,
            cv: cv,
            min: intervals.min() ?? 0,
            max: intervals.max() ?? 0
        )
    }
    
    /// 计算置信度
    private func calculateConfidence(recordCount: Int, cv: Double, hasAnomalies: Bool) -> CycleConfidence {
        // 有异常数据时降低置信度
        if hasAnomalies {
            return .anomalous
        }
        
        // 变异系数过高
        if cv > unreliableCVThreshold {
            return .low
        }
        
        // 根据数据量和稳定性判断
        if recordCount >= 5 {
            if cv <= lowConfidenceCVThreshold {
                return .high
            }
            return .medium
        } else if recordCount >= 3 {
            if cv <= lowConfidenceCVThreshold {
                return .medium
            }
            return .low
        }
        
        return .low
    }
    
    /// 数据不足时的处理
    private func createInsufficientDataResult(
        cycles: [BirdCycleRecord],
        speciesReference: (min: Int, max: Int)?,
        ageAnalysis: AgeAnalysisResult
    ) -> CyclePredictionResult {
        
        // 如果有品种参考值，使用它
        if let ref = speciesReference,
           let lastCycle = cycles.first,
           let lastEndDate = lastCycle.endDate {
            
            let avgDays = (ref.min + ref.max) / 2
            let expectedDate = Calendar.current.date(byAdding: .day, value: avgDays, to: lastEndDate)!
            let earliestDate = Calendar.current.date(byAdding: .day, value: ref.min, to: lastEndDate)!
            let latestDate = Calendar.current.date(byAdding: .day, value: ref.max, to: lastEndDate)!
            
            var reasoning = "历史数据不足（仅 \(cycles.count) 条），使用品种参考值（\(ref.min)-\(ref.max) 天）进行预测"
            if ageAnalysis.stage != .unknown {
                reasoning += "\n• 年龄阶段：\(ageAnalysis.stage.displayName)"
            }
            
            return CyclePredictionResult(
                status: .predicted,
                earliestDate: earliestDate,
                expectedDate: expectedDate,
                latestDate: latestDate,
                confidence: .low,
                source: .speciesReference,
                reasoning: reasoning,
                ageStage: ageAnalysis.stage
            )
        }
        
        // 完全无法预测
        let reason: String
        if cycles.isEmpty {
            reason = "无历史记录，无法预测"
        } else if cycles.count == 1 {
            reason = "仅有 1 条记录，至少需要 \(minRecordsForPrediction) 条才能预测"
        } else {
            reason = "仅有 \(cycles.count) 条记录，至少需要 \(minRecordsForPrediction) 条才能预测"
        }
        
        return CyclePredictionResult(
            status: .insufficientData,
            confidence: .unknown,
            source: .unknown,
            reasoning: reason,
            ageStage: ageAnalysis.stage
        )
    }
    
    /// 生成预测解释
    private func generateReasoning(
        cycleType: CycleType,
        recordCount: Int,
        stats: PredictionStatistics,
        lastEndDate: Date,
        confidence: CycleConfidence,
        anomalyCount: Int,
        ageAnalysis: AgeAnalysisResult,
        intervalAdjustment: Int
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var parts: [String] = []
        
        parts.append("基于过去 \(recordCount) 次\(cycleType.displayName)记录：")
        parts.append("• 平均间隔：\(stats.mean) 天（标准差 ±\(Int(stats.stdDev)) 天）")
        parts.append("• 间隔范围：\(stats.min)-\(stats.max) 天")
        parts.append("• 上次结束：\(formatter.string(from: lastEndDate))")
        parts.append("• 变异系数：\(String(format: "%.1f%%", stats.cv * 100))")
        parts.append("• 预测置信度：\(confidence.displayName)")
        
        // 年龄信息
        if ageAnalysis.stage != .unknown {
            parts.append("• 年龄阶段：\(ageAnalysis.stage.displayName)")
            
            if intervalAdjustment != 0 {
                let direction = intervalAdjustment > 0 ? "延长" : "缩短"
                parts.append("• 年龄调整：\(direction) \(abs(intervalAdjustment)) 天")
            }
        }
        
        if anomalyCount > 0 {
            parts.append("⚠️ 注意：检测到 \(anomalyCount) 条异常记录，可能影响预测准确性")
        }
        
        if stats.cv > lowConfidenceCVThreshold {
            parts.append("⚠️ 周期间隔波动较大，预测仅供参考")
        }
        
        return parts.joined(separator: "\n")
    }
    
    // MARK: - 验证预测
    
    /// 验证预测结果（用于测试）
    func validatePrediction(
        prediction: CyclePredictionResult,
        actualStartDate: Date
    ) -> PredictionValidationResult {
        
        guard prediction.status == .predicted,
              let expectedDate = prediction.expectedDate,
              let earliestDate = prediction.earliestDate,
              let latestDate = prediction.latestDate else {
            return PredictionValidationResult(
                matchLevel: .noValidation,
                errorDays: nil,
                isConfidenceCalibrated: true
            )
        }
        
        let errorDays = Calendar.current.dateComponents([.day], from: expectedDate, to: actualStartDate).day ?? 0
        
        let matchLevel: PredictionMatchLevel
        if errorDays == 0 {
            matchLevel = .exactMatch
        } else if actualStartDate >= earliestDate && actualStartDate <= latestDate {
            matchLevel = .windowMatch
        } else if errorDays == 1 || errorDays == -1 {
            matchLevel = .edgeMatch
        } else if abs(errorDays) <= 3 {
            matchLevel = .missButReasonable
        } else {
            matchLevel = .missUnacceptable
        }
        
        // 检查置信度是否校准
        let isCalibrated: Bool
        switch prediction.confidence {
        case .high:
            isCalibrated = matchLevel == .exactMatch || matchLevel == .windowMatch || matchLevel == .edgeMatch
        case .medium:
            isCalibrated = matchLevel != .missUnacceptable
        case .low, .unknown, .anomalous:
            isCalibrated = true  // 低置信度时任何结果都可接受
        }
        
        return PredictionValidationResult(
            matchLevel: matchLevel,
            errorDays: errorDays,
            isConfidenceCalibrated: isCalibrated
        )
    }
    
    // MARK: - 年龄分析方法
    
    /// 分析年龄对周期的影响
    private func analyzeAge(
        ageMonths: Int?,
        cycleType: CycleType,
        speciesName: String?
    ) -> AgeAnalysisResult {
        guard let age = ageMonths else {
            return AgeAnalysisResult(stage: .unknown, blockingWarning: nil, adjustmentFactor: 1.0)
        }
        
        let maturity = maturityAgeMonths[speciesName ?? ""] ?? maturityAgeMonths["default"]!
        let senior = seniorAgeMonths[speciesName ?? ""] ?? seniorAgeMonths["default"]!
        
        // 确定年龄阶段
        let stage: BirdAgeStage
        if age < maturity / 2 {
            stage = .juvenile      // 幼鸟
        } else if age < maturity {
            stage = .subAdult      // 亚成鸟
        } else if age < senior {
            stage = .adult         // 成年
        } else {
            stage = .senior        // 老年
        }
        
        // 根据年龄阶段和周期类型判断是否有阻断性警告
        var blockingWarning: String? = nil
        var adjustmentFactor: Double = 1.0
        
        switch cycleType {
        case .EGG_LAYING:
            if stage == .juvenile {
                blockingWarning = "⚠️ 该鸟仅 \(age) 月龄，尚未性成熟，不应产蛋。如有产蛋行为请关注健康状况。"
            } else if stage == .subAdult {
                blockingWarning = "⚠️ 该鸟 \(age) 月龄，接近但未完全性成熟。过早产蛋可能影响健康，预测仅供参考。"
            } else if stage == .senior {
                adjustmentFactor = 1.3  // 老年鸟间隔延长 30%
            }
            
        case .BATHING:
            // 洗澡周期没有年龄限制，不需要调整
            break
        }
        
        return AgeAnalysisResult(
            stage: stage,
            blockingWarning: blockingWarning,
            adjustmentFactor: adjustmentFactor
        )
    }
    
    /// 根据年龄调整置信度
    private func adjustConfidenceForAge(
        _ confidence: CycleConfidence,
        ageAnalysis: AgeAnalysisResult
    ) -> CycleConfidence {
        switch ageAnalysis.stage {
        case .juvenile, .subAdult:
            // 未成熟鸟，降低置信度
            if confidence == .high {
                return .medium
            }
        case .senior:
            // 老年鸟，略微降低置信度
            if confidence == .high {
                return .medium
            }
        case .adult, .unknown:
            break
        }
        return confidence
    }
    
    /// 根据年龄调整预测间隔（智能调整）
    /// 老年期优化：如果历史数据已经呈现延长趋势，则不再额外调整
    private func adjustIntervalForAge(
        _ interval: Int,
        ageAnalysis: AgeAnalysisResult,
        cycleType: CycleType,
        intervals: [Int]? = nil
    ) -> Int {
        // 非老年期直接使用调整系数
        if ageAnalysis.stage != .senior {
            return Int(Double(interval) * ageAnalysis.adjustmentFactor)
        }
        
        // 老年期智能调整
        guard let intervals = intervals, intervals.count >= 3 else {
            // 数据不足时使用较温和的调整
            return Int(Double(interval) * 1.1)  // 仅延长 10%
        }
        
        // 检测历史数据是否已经呈现延长趋势
        let trend = detectIntervalTrend(intervals)
        
        switch trend {
        case .increasing:
            // 间隔已经在延长，不再额外调整
            // 只需要保持原有趋势即可
            return interval
            
        case .stable:
            // 间隔稳定，可能刚进入老年期，适度调整
            return Int(Double(interval) * 1.15)  // 延长 15%
            
        case .decreasing:
            // 间隔在缩短（异常情况），不调整
            return interval
        }
    }
    
    /// 检测间隔趋势
    private func detectIntervalTrend(_ intervals: [Int]) -> IntervalTrend {
        guard intervals.count >= 3 else { return .stable }
        
        // 取最近 3-5 个间隔
        let recentIntervals = Array(intervals.prefix(min(5, intervals.count)))
        
        // 计算趋势：比较前半部分和后半部分的平均值
        let midpoint = recentIntervals.count / 2
        let firstHalf = Array(recentIntervals.prefix(midpoint))
        let secondHalf = Array(recentIntervals.suffix(recentIntervals.count - midpoint))
        
        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return .stable }
        
        let firstAvg = Double(firstHalf.reduce(0, +)) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.reduce(0, +)) / Double(secondHalf.count)
        
        // 变化超过 10% 才认为有趋势
        let changeRatio = (firstAvg - secondAvg) / secondAvg
        
        if changeRatio > 0.10 {
            // 早期间隔更长 → 间隔在缩短
            return .decreasing
        } else if changeRatio < -0.10 {
            // 早期间隔更短 → 间隔在延长
            return .increasing
        }
        return .stable
    }
}

/// 间隔趋势
private enum IntervalTrend {
    case increasing  // 间隔延长中
    case stable      // 间隔稳定
    case decreasing  // 间隔缩短中
}

// MARK: - 数据结构

/// 鸟的年龄阶段
enum BirdAgeStage: String {
    case juvenile = "JUVENILE"      // 幼鸟（未成熟）
    case subAdult = "SUB_ADULT"     // 亚成鸟（接近成熟）
    case adult = "ADULT"            // 成年
    case senior = "SENIOR"          // 老年
    case unknown = "UNKNOWN"        // 未知
    
    var displayName: String {
        switch self {
        case .juvenile: return "幼鸟期"
        case .subAdult: return "亚成期"
        case .adult: return "成年期"
        case .senior: return "老年期"
        case .unknown: return "未知"
        }
    }
}

/// 年龄分析结果
struct AgeAnalysisResult {
    let stage: BirdAgeStage
    let blockingWarning: String?   // 阻断性警告（如有则不进行预测）
    let adjustmentFactor: Double   // 间隔调整系数
}

/// 预测结果
struct CyclePredictionResult {
    enum Status: String {
        case predicted          // 成功预测
        case insufficientData   // 数据不足
        case noData             // 无数据
        case unreliable         // 不可靠
    }
    
    let status: Status
    var earliestDate: Date?
    var expectedDate: Date?
    var latestDate: Date?
    var confidence: CycleConfidence = .unknown
    var source: PredictionSource = .unknown
    var reasoning: String = ""
    var statistics: PredictionStatistics?
    var ageStage: BirdAgeStage?    // 年龄阶段
    
    /// 是否已过期
    var isPastDue: Bool {
        guard let expected = expectedDate else { return false }
        return expected < Date()
    }
    
    /// 过期天数
    var daysPastDue: Int {
        guard isPastDue, let expected = expectedDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: expected, to: Date()).day ?? 0
    }
}

/// 预测统计指标
struct PredictionStatistics {
    let mean: Int           // 平均间隔
    let stdDev: Double      // 标准差
    let cv: Double          // 变异系数
    let min: Int            // 最小间隔
    let max: Int            // 最大间隔
}

/// 预测匹配等级
enum PredictionMatchLevel: String {
    case exactMatch = "EXACT_MATCH"              // 完全匹配
    case windowMatch = "WINDOW_MATCH"            // 落在预测区间内
    case edgeMatch = "EDGE_MATCH"                // 边界匹配
    case missButReasonable = "MISS_BUT_REASONABLE"  // 未命中但合理
    case missUnacceptable = "MISS_UNACCEPTABLE"    // 不可接受的偏差
    case noValidation = "NO_VALIDATION"          // 无法验证
    
    var displayName: String {
        switch self {
        case .exactMatch: return "精确匹配"
        case .windowMatch: return "区间命中"
        case .edgeMatch: return "边界命中"
        case .missButReasonable: return "轻微偏差"
        case .missUnacceptable: return "预测失败"
        case .noValidation: return "无法验证"
        }
    }
    
    var isSuccess: Bool {
        switch self {
        case .exactMatch, .windowMatch, .edgeMatch, .missButReasonable:
            return true
        case .missUnacceptable, .noValidation:
            return false
        }
    }
}

/// 预测验证结果
struct PredictionValidationResult {
    let matchLevel: PredictionMatchLevel
    let errorDays: Int?
    let isConfidenceCalibrated: Bool
}

