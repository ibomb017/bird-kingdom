import SwiftUI

// MARK: - 丢失模式视图
struct LostBirdView: View {
    let bird: Bird
    let onFound: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    
    @State private var offset: CGFloat = 0
    @State private var showFoundConfirm = false
    @State private var isAnimating = false
    
    private let lostColor = Color(red: 0.6, green: 0.6, blue: 0.7)
    private let hopeColor = Color(red: 0.95, green: 0.85, blue: 0.6)
    
    var body: some View {
        ZStack {
            // 背景渐变 - 柔和的灰蓝色调，表达思念
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.18, blue: 0.25),
                    Color(red: 0.25, green: 0.28, blue: 0.35),
                    Color(red: 0.2, green: 0.22, blue: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 星星背景动画
            StarsBackgroundView()
            
            VStack(spacing: 0) {
                // 顶部导航 - 只显示标题，返回按钮由导航栏提供
                HStack {
                    // 左侧占位（与导航栏返回按钮对齐）
                    Color.clear
                        .frame(width: 44, height: 44)
                    
                    Spacer()
                    
                    Text(NSLocalizedString("祈愿归来", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    // 右侧占位
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
                
                // 主内容区域
                VStack(spacing: 24) {
                    // 蜡烛和祈福光环
                    ZStack {
                        // 光环效果
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [hopeColor.opacity(0.3), hopeColor.opacity(0.1), Color.clear],
                                    center: .center,
                                    startRadius: 60,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 300, height: 300)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                        
                        // 鸟儿头像 - 带有柔和的光晕
                        VStack(spacing: 16) {
                            ZStack {
                                // 外圈光晕
                                Circle()
                                    .stroke(hopeColor.opacity(0.5), lineWidth: 3)
                                    .frame(width: 140, height: 140)
                                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                                
                                // 头像
                                BirdAvatarView(avatarUrl: bird.avatarUrl, size: 120, isDead: false)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                                    .shadow(color: hopeColor.opacity(0.5), radius: 20)
                            }
                            
                            // 鸟儿名字
                            Text(bird.nickname)
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(bird.species)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // 丢失信息卡片
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(hopeColor)
                            Text(NSLocalizedString("我们都在等你回家", comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        if let lostDate = bird.lostDate {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text("走失于 \(formatDate(lostDate))")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white.opacity(0.7))
                            
                            Text("已经 \(daysSinceLost(lostDate)) 天")
                                .font(.caption)
                                .foregroundColor(hopeColor)
                        }
                        
                        if let location = bird.lostLocation, !location.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "location")
                                    .font(.caption)
                                Text(location)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 32)
                    
                    // 祈福文字
                    VStack(spacing: 8) {
                        Text("🕯️")
                            .font(.system(size: 40))
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Text(NSLocalizedString("点一盏心灯，愿你平安归来", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .italic()
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // 底部滑动找回按钮
                VStack(spacing: 12) {
                    Text(NSLocalizedString("找到了？向右滑动确认", comment: ""))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    // 滑动按钮
                    ZStack(alignment: .leading) {
                        // 背景轨道
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 60)
                        
                        // 进度指示
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.primaryColor.opacity(0.5), themeManager.primaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(60, offset + 60), height: 60)
                        
                        // 提示文字
                        HStack {
                            Spacer()
                            Text(NSLocalizedString("滑动确认找到", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                        
                        // 滑块
                        Circle()
                            .fill(Color.adaptiveCard)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "arrow.right")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeManager.primaryColor)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 5)
                            .padding(.leading, 4)
                            .offset(x: offset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let maxOffset = UIScreen.main.bounds.width - 100 - 60
                                        offset = min(max(0, value.translation.width), maxOffset)
                                    }
                                    .onEnded { value in
                                        let maxOffset = UIScreen.main.bounds.width - 100 - 60
                                        if offset > maxOffset * 0.7 {
                                            // 触发找到确认
                                            withAnimation(.spring()) {
                                                offset = maxOffset
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                showFoundConfirm = true
                                            }
                                        } else {
                                            // 回弹
                                            withAnimation(.spring()) {
                                                offset = 0
                                            }
                                        }
                                    }
                            )
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
        .alert(NSLocalizedString("确认找到", comment: ""), isPresented: $showFoundConfirm) {
            Button(L10n.cancel, role: .cancel) {
                withAnimation(.spring()) {
                    offset = 0
                }
            }
            Button(NSLocalizedString("确认找到", comment: "")) {
                onFound()
                dismiss()
            }
        } message: {
            Text("太好了！\(bird.nickname)回来了！\n确认后将取消丢失模式")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("yyyy年M月d日", comment: "")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    private func daysSinceLost(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: Date())
        return components.day ?? 0
    }
}

// MARK: - 星星背景动画
struct StarsBackgroundView: View {
    @State private var stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<30, id: \.self) { index in
                    if index < stars.count {
                        Circle()
                            .fill(Color.adaptiveCard)
                            .frame(width: stars[index].size, height: stars[index].size)
                            .opacity(stars[index].opacity)
                            .position(x: stars[index].x, y: stars[index].y)
                    }
                }
            }
            .onAppear {
                generateStars(in: geometry.size)
            }
        }
    }
    
    private func generateStars(in size: CGSize) {
        stars = (0..<30).map { _ in
            (
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...0.8)
            )
        }
    }
}

// MARK: - 丢失鸟儿卡片视图（用于首页鸟舍）
struct LostBirdCardOverlay: View {
    let bird: Bird
    
    private let lostColor = Color(red: 0.5, green: 0.5, blue: 0.6)
    
    var body: some View {
        ZStack {
            // 半透明遮罩
            Color.black.opacity(0.4)
            
            // 丢失标识
            VStack(spacing: 4) {
                Image(systemName: "heart.slash")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(NSLocalizedString("走失中", comment: ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    LostBirdView(
        bird: Bird(
            id: 1,
            nickname: NSLocalizedString("小黄", comment: ""),
            species: NSLocalizedString("虎皮鹦鹉", comment: ""),
            gender: L10n.male,
            featherColor: NSLocalizedString("黄色", comment: ""),
            source: nil,
            avatarUrl: nil,
            notes: nil,
            ageMonths: 12,
            isLost: true,
            lostDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            lostLocation: NSLocalizedString("北京市朝阳区xxx小区", comment: "")
        ),
        onFound: {}
    )
}
