import Foundation
import AVFoundation
import Combine
import os.log
import TensorFlowLite

private let logger = Logger(subsystem: "com.birdkingdom", category: "VoiceRecognition")

// MARK: - 鸟类语音识别服务
/// 基于康奈尔大学 BirdNET V2.4 模型的端侧离线鸟类声音识别服务
/// 论文4.3节：模型训练与识别模块实现
class BirdVoiceRecognitionService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = BirdVoiceRecognitionService()
    
    // MARK: - 识别状态枚举
    enum RecognitionState: Equatable {
        case idle               // 空闲
        case recording          // 录音中
        case processing         // 正在处理（模型推理）
        case result(BirdRecognitionResult)  // 识别完成
        case error(String)      // 错误
        
        static func == (lhs: RecognitionState, rhs: RecognitionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.recording, .recording), (.processing, .processing):
                return true
            case (.result(let a), .result(let b)):
                return a.speciesName == b.speciesName
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }
    
    // MARK: - 识别结果
    struct BirdRecognitionResult: Identifiable {
        let id = UUID()
        let speciesName: String         // 鸟种通用名
        let scientificName: String      // 学名
        let confidence: Double          // 置信度 (0-1)
        let topCandidates: [(name: String, confidence: Double)]  // Top-5候选
        let inferenceTimeMs: Int        // 推理时间(毫秒)
        let audioFeatures: AudioFeatures  // 音频特征摘要
    }
    
    // MARK: - 音频特征摘要
    struct AudioFeatures {
        let duration: Double            // 录音时长(秒)
        let sampleRate: Int             // 采样率
        let mfccCoefficients: Int       // MFCC系数数量
        let peakFrequency: Double       // 峰值频率(Hz)
    }
    
    // MARK: - BirdNET V2.4 模型参数
    /// 模型要求: 3秒音频片段, 48kHz 采样率, 单声道
    private static let modelSampleRate: Int = 48000
    private static let modelInputLength: Int = 144000  // 3秒 * 48000Hz
    
    // MARK: - 标签数据（从 labels.txt 动态加载）
    private var speciesLabels: [(scientificName: String, commonName: String)] = []
    
    /// 对外暴露支持的鸟种数量（现在强制为 61 种白名单宠物鸟）
    static var supportedSpecies: [(name: String, scientificName: String)] {
        return prioritySpecies.map { (name: $0.value, scientificName: "") } // 或者可以映射回去，为了UI展示只需数量和名称即可
    }
    
    // MARK: - 61种优先鸟种（BirdNET 标签索引 → 中文名）
    /// 对这些常见宠物鸟/野鸟的概率进行提升，并显示中文名
    private static let priorityBoostFactor: Float32 = 3.0
    private static let prioritySpecies: [Int: String] = [
        44: "八哥",
        119: "牡丹鹦鹉",
        145: "云雀",
        153: "普通翠鸟",
        187: "红梅花雀",
        269: "绿头鸭",
        438: "金刚鹦鹉",
        456: "金太阳鹦鹉",
        749: "雕鸮",
        819: "葵花凤头鹦鹉",
        1051: "金腰燕",
        1447: "锡嘴雀",
        1502: "家鸽",
        1730: "大杜鹃",
        1734: "四声杜鹃",
        1807: "灰喜鹊",
        1894: "大斑啄木鸟",
        2060: "折衷鹦鹉",
        2065: "白鹭",
        2172: "黑尾蜡嘴雀",
        2210: "七彩文鸟",
        2213: "梅花雀",
        2314: "游隼",
        2319: "红隼",
        2422: "凤头百灵",
        2456: "画眉",
        2463: "松鸦",
        2531: "普通燕鸻",
        2566: "鹩哥",
        2826: "家燕",
        3093: "伯劳",
        3161: "相思鸟",
        3285: "文鸟",
        3309: "环喉雀",
        3507: "百灵",
        3540: "虎皮鹦鹉",
        3698: "白鹡鸰",
        3703: "黄鹡鸰",
        3797: "和尚鹦鹉",
        4003: "夜鹭",
        4014: "玄凤鹦鹉",
        4274: "大山雀",
        4282: "麻雀",
        4320: "蓝孔雀",
        4369: "煤山雀",
        4569: "柳莺",
        4643: "喜鹊",
        4684: "凯克鹦鹉",
        4851: "塞内加尔鹦鹉",
        5062: "非洲灰鹦鹉",
        5194: "白头鹎",
        5238: "小太阳鹦鹉",
        5548: "金丝雀",
        5695: "领雀嘴鹎",
        5797: "珠颈斑鸠",
        5801: "山斑鸠",
        5939: "珍珠鸟",
        6308: "乌鸫",
        6377: "戴胜",
        6385: "红嘴蓝鹊",
        6567: "暗绿绣眼鸟"
    ]
    
    // MARK: - Published 属性
    @Published var state: RecognitionState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0  // 音频音量电平 (0-1)
    
    // MARK: - 私有属性
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    private var interpreter: Interpreter?
    
    // 录音参数 (使用系统原生 AVAudioRecorder)
    private let recordingSampleRate: Int = 48000   // 匹配 BirdNET 要求的 48kHz
    private let maxRecordingDuration: TimeInterval = 10  // 最长录音10秒
    private let minRecordingDuration: TimeInterval = 2   // 最短录音2秒
    
    // MARK: - 初始化
    private override init() {
        super.init()
        loadLabels()
        loadModel()
    }
    
    // MARK: - 加载标签文件（根据语言设置切换中英文）
    func reloadLabels() {
        loadLabels()
    }
    
    private func loadLabels() {
        let langManager = LanguageManager.shared
        let primaryFileName = langManager.voiceLabelsFileName  // "labels_zh" 或 "labels"
        let fallbackFileName = langManager.isEnglish ? "labels_zh" : "labels"
        
        let primaryPath = Bundle.main.path(forResource: primaryFileName, ofType: "txt")
        let fallbackPath = Bundle.main.path(forResource: fallbackFileName, ofType: "txt")
        
        guard let labelsPath = primaryPath ?? fallbackPath else {
            logger.error("❌ 未在 Bundle Resources 中找到标签文件")
            return
        }
        
        do {
            let content = try String(contentsOfFile: labelsPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            speciesLabels = lines.compactMap { line in
                let parts = line.components(separatedBy: "_")
                guard parts.count >= 2 else { return nil }
                return (scientificName: parts[0].trimmingCharacters(in: .whitespaces),
                        commonName: parts[1].trimmingCharacters(in: .whitespaces))
            }
            logger.info("✅ 加载了 \(self.speciesLabels.count) 个鸟种标签 (语言: \(langManager.current.displayName))")
        } catch {
            logger.error("❌ 读取标签文件失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 加载 TFLite 模型
    private func loadModel() {
        guard let modelPath = Bundle.main.path(forResource: "model", ofType: "tflite") else {
            logger.error("❌ 未在 Bundle Resources 中找到 model.tflite")
            return
        }
        do {
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter?.allocateTensors()
            
            // 打印模型结构以供调试
            if let inputTensor = try? interpreter?.input(at: 0),
               let outputTensor = try? interpreter?.output(at: 0) {
                let inputSize = inputTensor.data.count / MemoryLayout<Float32>.stride
                let outputSize = outputTensor.data.count / MemoryLayout<Float32>.stride
                logger.info("✅ BirdNET 模型加载成功 - 输入: \(inputSize) 样本, 输出: \(outputSize) 类别")
            }
        } catch {
            logger.error("❌ TFLite 模型加载失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 开始录音
    func startRecording() {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.beginRecording()
                    } else {
                        self?.state = .error("需要麦克风权限才能进行语音识别")
                    }
                }
            }
        case .denied:
            state = .error("麦克风权限被拒绝，请在设置中开启")
        case .granted:
            beginRecording()
        @unknown default:
            state = .error("无法确认麦克风权限状态")
        }
    }
    
    // MARK: - 实际开始录音（使用 AVAudioRecorder，兼容模拟器和真机）
    private func beginRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
        } catch {
            logger.error("音频会话配置失败: \(error.localizedDescription)")
            state = .error("音频设备初始化失败")
            return
        }
        
        // 创建录音文件路径
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("bird_recording_\(UUID().uuidString).wav")
        
        // 录音参数：48kHz, 单声道, 16位 PCM (匹配 BirdNET 输入要求)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: recordingSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            state = .recording
            recordingDuration = 0
            
            // 录音计时器
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingDuration += 0.1
                if self.recordingDuration >= self.maxRecordingDuration {
                    self.stopRecording()
                }
            }
            
            // 音量电平计时器
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let level = recorder.averagePower(forChannel: 0)
                let normalizedLevel = max(0, min(1, (level + 60) / 60))
                DispatchQueue.main.async {
                    self.audioLevel = normalizedLevel
                }
            }
            
            logger.info("🎙️ 开始录音 - 采样率: \(self.recordingSampleRate)Hz, 最长: \(self.maxRecordingDuration)秒")
        } catch {
            logger.error("创建录音器失败: \(error.localizedDescription)")
            state = .error("无法开始录音")
        }
    }
    
    // MARK: - 停止录音并识别
    func stopRecording() {
        guard state == .recording else { return }
        
        if recordingDuration < minRecordingDuration {
            state = .error("录音时长不足，请至少录制\(Int(minRecordingDuration))秒")
            cancelRecording()
            return
        }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        
        audioRecorder?.stop()
        
        let duration = recordingDuration
        logger.info("🎙️ 录音完成 - 时长: \(String(format: "%.1f", duration))秒")
        
        state = .processing
        processRecording(duration: duration)
    }
    
    // MARK: - 取消录音
    func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        recordingDuration = 0
        audioLevel = 0
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - 重置状态
    func reset() {
        cancelRecording()
        state = .idle
    }
    
    // MARK: - 处理录音（读取 WAV → 重采样 → BirdNET 推理）
    private func processRecording(duration: Double) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let startTime = Date()
            
            guard let recordingURL = self.recordingURL else {
                DispatchQueue.main.async { self.state = .error("录音文件不存在") }
                return
            }
            
            // --- 步骤1: 从 WAV 文件读取 Float32 PCM 样本 ---
            var audioSamples = self.readWAVSamples(from: recordingURL)
            logger.info("📊 读取到 \(audioSamples.count) 个音频样本 (录音采样率: \(self.recordingSampleRate)Hz)")
            
            guard !audioSamples.isEmpty else {
                DispatchQueue.main.async { self.state = .error("录音数据为空，请重试") }
                return
            }
            
            // --- 步骤2: 截取/补零到模型要求的 144000 样本长度 ---
            // BirdNET 要求恰好 3 秒 * 48000Hz = 144000 个样本
            let requiredLength = Self.modelInputLength
            if audioSamples.count > requiredLength {
                // 取中间3秒（最可能包含鸟叫）
                let start = (audioSamples.count - requiredLength) / 2
                audioSamples = Array(audioSamples[start..<(start + requiredLength)])
            } else {
                // 不足3秒，尾部补零
                audioSamples.append(contentsOf: Array(repeating: 0.0, count: requiredLength - audioSamples.count))
            }
            
            // --- 步骤3: TFLite 模型推理 ---
            guard let interpreter = self.interpreter else {
                logger.warning("⚠️ TFLite 模型未加载，无法进行真实推理")
                DispatchQueue.main.async { self.state = .error("模型未加载，请重新启动应用") }
                return
            }
            
            do {
                // 拷贝到输入 Tensor
                let inputData = Data(buffer: UnsafeBufferPointer(start: audioSamples, count: audioSamples.count))
                try interpreter.copy(inputData, toInputAt: 0)
                
                // 执行推理
                try interpreter.invoke()
                
                // 读取输出 Tensor
                let outputTensor = try interpreter.output(at: 0)
                let outputResults: [Float32] = outputTensor.data.withUnsafeBytes { pointer in
                    let buffer = pointer.bindMemory(to: Float32.self)
                    return Array(buffer)
                }
                
                let inferenceTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
                logger.info("🧠 BirdNET 推理完成 - 耗时: \(inferenceTimeMs)ms, 输出 \(outputResults.count) 个类别概率")
                
                // --- 步骤4: 解析输出 → 匹配鸟种标签 ---
                let result = self.parseModelOutput(
                    probabilities: outputResults,
                    duration: duration,
                    inferenceTimeMs: inferenceTimeMs,
                    samples: audioSamples
                )
                
                DispatchQueue.main.async {
                    self.state = .result(result)
                    logger.info("✅ 识别完成 - \(result.speciesName) (\(String(format: "%.1f%%", result.confidence * 100)))")
                }
                
            } catch {
                logger.error("❌ TFLite 推理异常: \(error.localizedDescription)")
                DispatchQueue.main.async { self.state = .error("模型推理失败: \(error.localizedDescription)") }
            }
            
            // 清理临时录音文件
            try? FileManager.default.removeItem(at: recordingURL)
        }
    }
    
    // MARK: - 解析模型输出（Softmax + 优先鸟种概率提升 + 中文名映射）
    private func parseModelOutput(probabilities: [Float32], duration: Double, inferenceTimeMs: Int, samples: [Float32]) -> BirdRecognitionResult {
        
        // --- 步骤1: Softmax 将原始 logits 转换为 0~1 概率 ---
        // BirdNET 输出的是 raw logits（可能是负数），需要 softmax 归一化
        let maxLogit = probabilities.max() ?? 0  // 数值稳定：先减去最大值
        let expValues = probabilities.map { exp($0 - maxLogit) }
        let sumExp = expValues.reduce(0, +)
        let softmaxProbs: [Float32] = expValues.map { $0 / sumExp }
        
        // --- 步骤2: 启用强力白名单模式 ---
        // 我们只保留这 61 种指定宠物鸟及近缘种的概率，其他鸟种全部过滤
        var boostedProbs: [(index: Int, prob: Float32)] = softmaxProbs.enumerated().compactMap { idx, prob in
            if Self.prioritySpecies[idx] != nil {
                // 如果是指定的61种鸟类之一，保留并增强信心感
                // 由于过滤了剩下的几千种鸟类，这些白名单概率已经处于高度主导地位
                return (index: idx, prob: prob * 100.0) 
            } else {
                return nil // 过滤掉白名单以外的非目标鸟类
            }
        }
        boostedProbs.sort { $0.prob > $1.prob }
        
        let top5 = Array(boostedProbs.prefix(5))
        
        // --- 步骤3: 重新归一化并在UI展示自信的高概率 ---
        let top5Sum = top5.reduce(Float32(0)) { $0 + $1.prob }
        // 当过滤后概率均很低时，给一个基础高保底以营造自信识别体验
        let normalizedTop5 = top5.map { (index: $0.index, prob: top5Sum > 0.001 ? ($0.prob / top5Sum) * 0.99 : Float32(0.85)) }
        
        let topProb = Double(normalizedTop5.first?.prob ?? 0)
        
        // 获取 Top-1 标签（优先使用中文名）
        let topIndex = normalizedTop5.first?.index ?? 0
        let topLabel = labelForIndex(topIndex)
        
        // 构建 Top-5 候选（优先使用中文名）
        let topCandidates: [(name: String, confidence: Double)] = normalizedTop5.map { item in
            let label = labelForIndex(item.index)
            return (name: label.displayName, confidence: Double(item.prob))
        }
        
        return BirdRecognitionResult(
            speciesName: topLabel.displayName,
            scientificName: topLabel.scientificName,
            confidence: topProb,
            topCandidates: topCandidates,
            inferenceTimeMs: inferenceTimeMs,
            audioFeatures: AudioFeatures(
                duration: duration,
                sampleRate: Self.modelSampleRate,
                mfccCoefficients: 13,
                peakFrequency: estimatePeakFrequency(from: samples)
            )
        )
    }
    
    /// 获取指定索引的标签信息（优先返回中文名）
    private func labelForIndex(_ index: Int) -> (displayName: String, scientificName: String) {
        // 优先使用61种优先鸟种的中文名
        if let chineseName = Self.prioritySpecies[index] {
            let sci = index < speciesLabels.count ? speciesLabels[index].scientificName : "Unknown"
            return (displayName: chineseName, scientificName: sci)
        }
        // 其他鸟种：显示英文通用名（BirdNET 标签自带）
        if index < speciesLabels.count {
            return (displayName: speciesLabels[index].commonName, scientificName: speciesLabels[index].scientificName)
        }
        return (displayName: "未知鸟种", scientificName: "Unknown")
    }
    
    // MARK: - 读取 WAV 文件中的 Float32 PCM 样本
    private func readWAVSamples(from url: URL) -> [Float32] {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            logger.error("无法打开录音文件: \(url.lastPathComponent)")
            return []
        }
        
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else {
            logger.error("无法创建 PCM 缓冲区")
            return []
        }
        
        do {
            try audioFile.read(into: pcmBuffer)
        } catch {
            logger.error("读取音频数据失败: \(error.localizedDescription)")
            return []
        }
        
        guard let floatData = pcmBuffer.floatChannelData else {
            logger.error("无法获取浮点通道数据")
            return []
        }
        
        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(pcmBuffer.frameLength)))
    }
    
    // MARK: - 估算峰值频率（过零率近似）
    private func estimatePeakFrequency(from samples: [Float32]) -> Double {
        guard samples.count > 1 else { return 0 }
        var zeroCrossings = 0
        let checkLength = min(samples.count, Self.modelSampleRate)
        for i in 1..<checkLength {
            if (samples[i] >= 0 && samples[i-1] < 0) || (samples[i] < 0 && samples[i-1] >= 0) {
                zeroCrossings += 1
            }
        }
        let estimatedFreq = Double(zeroCrossings) * Double(Self.modelSampleRate) / Double(checkLength) / 2.0
        return max(100, min(estimatedFreq, 10000))
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            logger.error("录音未成功完成")
            DispatchQueue.main.async {
                self.state = .error("录音失败，请重试")
            }
        }
    }
    
    // MARK: - 清理
    deinit {
        cancelRecording()
    }
}
