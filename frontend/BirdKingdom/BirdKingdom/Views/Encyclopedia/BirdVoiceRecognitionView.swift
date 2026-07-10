import SwiftUI
import AVFoundation

// MARK: - 鸟类语音识别页面
/// 论文4.3节 & 4.1.7节：语音识别功能的前端界面
/// 基于康奈尔大学 BirdNET V2.4 模型，端侧离线推理
struct BirdVoiceRecognitionView: View {
    @StateObject private var recognitionService = BirdVoiceRecognitionService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var langManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // 动画状态
    @State private var pulseAnimation = false
    @State private var ringRotation: Double = 0
    @State private var hasMicrophone = true
    @State private var checkingDevice = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.pageBackgroundGradient
                    .ignoresSafeArea()
                
                if checkingDevice {
                    ProgressView()
                        .onAppear { checkMicrophoneAvailability() }
                } else if !hasMicrophone {
                    noMicrophoneView
                } else {
                    mainContent
                }
            }
            .navigationTitle(L10n.voiceRecognition)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        recognitionService.reset()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(uiColor: .systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .onDisappear {
            recognitionService.reset()
        }
    }
    
    // MARK: - 检测录音设备
    private func checkMicrophoneAvailability() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            let inputs = session.availableInputs ?? []
            hasMicrophone = !inputs.isEmpty
            try session.setActive(false)
        } catch {
            hasMicrophone = false
        }
        checkingDevice = false
    }
    
    // MARK: - 无麦克风提示
    private var noMicrophoneView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "mic.slash")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(L10n.noMicDetected)
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text(L10n.noMicHint)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                dismiss()
            } label: {
                Text(L10n.back)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.primaryColor)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(themeManager.primaryColor, lineWidth: 1)
                    )
            }
            
            Spacer()
        }
    }
    
    // MARK: - 主内容
    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()
            centerSection
            Spacer()
            bottomSection
        }
    }
    
    // MARK: - 中心区域
    @ViewBuilder
    private var centerSection: some View {
        switch recognitionService.state {
        case .idle:
            idleView
        case .recording:
            recordingView
        case .processing:
            processingView
        case .result(let result):
            resultView(result)
        case .error:
            errorView
        }
    }
    
    // MARK: - 待机视图
    private var idleView: some View {
        VStack(spacing: 32) {
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                recognitionService.startRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(themeManager.primaryColor.opacity(0.08))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeManager.primaryColor, themeManager.primaryColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 20, y: 8)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear { pulseAnimation = true }
            
            VStack(spacing: 6) {
                Text(L10n.startRecording)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(L10n.holdToRecord)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - 录音中视图
    private var recordingView: some View {
        VStack(spacing: 32) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(themeManager.primaryColor.opacity(0.2 - Double(i) * 0.06), lineWidth: 1.5)
                        .frame(width: CGFloat(120 + i * 40), height: CGFloat(120 + i * 40))
                        .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.25),
                            value: pulseAnimation
                        )
                }
                
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                    recognitionService.stopRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(themeManager.primaryColor)
                            .frame(width: 120, height: 120)
                            .shadow(color: themeManager.primaryColor.opacity(0.35), radius: 20, y: 8)
                        
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white)
                                .frame(width: 28, height: 28)
                            
                            Text(String(format: "%.1fs", recognitionService.recordingDuration))
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onAppear { pulseAnimation = true }
            .onDisappear { pulseAnimation = false }
            
            audioLevelView
            
            VStack(spacing: 4) {
                Text(L10n.recording)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(L10n.recordingHint)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 音频电平
    private var audioLevelView: some View {
        HStack(spacing: 3) {
            ForEach(0..<24, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(themeManager.primaryColor.opacity(Float(i) / 24.0 < recognitionService.audioLevel ? 1.0 : 0.15))
                    .frame(width: 4, height: CGFloat.random(in: 12...28))
                    .animation(.easeOut(duration: 0.1), value: recognitionService.audioLevel)
            }
        }
        .frame(height: 32)
    }
    
    // MARK: - 分析中视图
    private var processingView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(themeManager.primaryColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(ringRotation))
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(themeManager.primaryColor.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-ringRotation * 0.7))
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(themeManager.primaryColor)
            }
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            }
            
            VStack(spacing: 6) {
                Text(L10n.analyzing)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("BirdNET V2.4 · \(BirdVoiceRecognitionService.supportedSpecies.count) \(L10n.birdSpeciesCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 结果视图
    private func resultView(_ result: BirdVoiceRecognitionService.BirdRecognitionResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // 主结果
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(result.speciesName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(result.scientificName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    // 置信度环
                    ZStack {
                        Circle()
                            .stroke(Color(uiColor: .systemGray5), lineWidth: 6)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: result.confidence)
                            .stroke(confidenceColor(result.confidence), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Text(String(format: "%.0f%%", result.confidence * 100))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(confidenceColor(result.confidence))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.adaptiveCard)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
                )
                
                // Top-5 候选
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.candidateSpecies)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                    
                    ForEach(Array(result.topCandidates.enumerated()), id: \.offset) { index, candidate in
                        HStack {
                            Text(candidate.name)
                                .font(.subheadline)
                                .foregroundColor(index == 0 ? .primary : .secondary)
                                .fontWeight(index == 0 ? .medium : .regular)
                            
                            Spacer()
                            
                            Text(String(format: "%.1f%%", candidate.confidence * 100))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        
                        if index < result.topCandidates.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.adaptiveCard)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                )
                
                // 技术参数
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.technicalParams)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                    
                    techRow(L10n.inferenceEngine, value: "BirdNET V2.4 (On-device)")
                    techRow(L10n.inferenceTime, value: "\(result.inferenceTimeMs)ms")
                    techRow(L10n.recordDuration, value: String(format: "%.1f\(L10n.seconds)", result.audioFeatures.duration))
                    techRow(L10n.sampleRate, value: "\(result.audioFeatures.sampleRate)Hz")
                    techRow(L10n.peakFrequency, value: String(format: "%.0fHz", result.audioFeatures.peakFrequency), isLast: true)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.adaptiveCard)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                )
                
                // 重新识别
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    recognitionService.reset()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text(L10n.reRecognize)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(themeManager.primaryColor)
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
    
    private func techRow(_ label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            if !isLast {
                Divider().padding(.leading, 16)
            }
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.85 { return .green }
        if confidence >= 0.70 { return themeManager.primaryColor }
        return .orange
    }
    
    // MARK: - 错误视图
    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary)
            
            if case .error(let message) = recognitionService.state {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                recognitionService.reset()
            } label: {
                Text(L10n.retry)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.primaryColor)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(themeManager.primaryColor, lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - 底部信息
    private var bottomSection: some View {
        VStack(spacing: 6) {
            if recognitionService.state == .idle {
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                    Text(L10n.onDeviceInference)
                        .font(.caption2)
                }
                .foregroundColor(.secondary.opacity(0.5))
                
                Text("BirdNET V2.4 · \(BirdVoiceRecognitionService.supportedSpecies.count) \(L10n.birdSpeciesCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.4))
            }
        }
        .padding(.bottom, 24)
    }
}

#Preview {
    BirdVoiceRecognitionView()
        .environmentObject(ThemeManager.shared)
}
