//
//  BirdKingdomApp.swift
//  BirdKingdom
//
//  Created by 陈丽倩 on 2025/12/6.
//

import SwiftUI
import UserNotifications
import CoreLocation
import PhotosUI

@main
struct BirdKingdomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

// App代理，用于处理通知
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = self
        
        // 请求通知权限
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
        
        return true
    }
    
    // 在前台时也显示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // 用户点击通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("用户点击了通知: \(userInfo)")
        
        // TODO: 根据通知类型跳转到相应页面
        
        completionHandler()
    }
}

// 主 TabView
struct MainTabView: View {
    @State private var selectedTab = 0
    
    init() {
        // TabBar 样式 - 白色背景
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.08)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = false
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BirdListView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            
            EncyclopediaView()
                .tabItem {
                    Label("百科", systemImage: "book.fill")
                }
                .tag(1)
            
            ForumView()
                .tabItem {
                    Label("广场", systemImage: "globe.asia.australia.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(Color(red: 0.25, green: 0.42, blue: 0.35))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            selectedTab = 0
        }
    }
}

// MARK: - 百科页面
struct EncyclopediaView: View {
    @State private var selectedMode = 0
    @State private var selectedBird: BirdSpecies? = nil
    @State private var showBirdDetail = false
    
    private let modes = ["鸟类百科", "食物查询", "症状查询", "配色预测", "语音识别"]
    private let modeIcons = ["book.fill", "leaf.fill", "cross.case.fill", "paintpalette.fill", "waveform"]
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 模式切换
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<modes.count, id: \.self) { index in
                            Button {
                                selectedMode = index
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: modeIcons[index])
                                        .font(.system(size: 14))
                                    Text(modes[index])
                                        .font(.system(size: 13))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(selectedMode == index ? forestGreen.opacity(0.12) : Color(uiColor: .systemGray6))
                                .foregroundColor(selectedMode == index ? forestGreen : .gray)
                                .fontWeight(selectedMode == index ? .semibold : .regular)
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                
                // 内容
                encyclopediaContent
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGray6).opacity(0.5))
        .sheet(item: $selectedBird) { bird in
            BirdSpeciesDetailView(bird: bird)
        }
    }
    
    @ViewBuilder
    private var encyclopediaContent: some View {
        switch selectedMode {
        case 0: // 鸟类百科
            birdEncyclopediaView
            
        case 1: // 食物查询
            FoodQueryView()
            
        case 2: // 症状查询
            SymptomQueryView()
            
        case 3: // 配色预测
            ColorPredictionView()
            
        default: // 语音识别
            VStack(spacing: 24) {
                Spacer().frame(height: 40)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(forestGreen.opacity(0.6))
                
                Text("点击开始识别鸟叫声")
                    .font(.headline)
                
                Text("将手机靠近鸟儿，录制清晰的叫声")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button {
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("开始识别")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(forestGreen)
                    .cornerRadius(25)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 鸟类百科视图
    private var birdEncyclopediaView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 分类标签
            ForEach(BirdCategory.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: 12) {
                    // 分类标题
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(forestGreen)
                        Text(category.rawValue)
                            .font(.headline)
                            .foregroundColor(forestGreen)
                        Spacer()
                        Text("\(birdSpeciesData.filter { $0.category == category }.count) 种")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                    
                    // 该分类下的鸟类
                    ForEach(birdSpeciesData.filter { $0.category == category }) { bird in
                        Button {
                            selectedBird = bird
                        } label: {
                            birdCard(bird: bird)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
    
    // 鸟类卡片
    private func birdCard(bird: BirdSpecies) -> some View {
        HStack(spacing: 14) {
            // 图片占位符（之后替换为真实图片）
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [forestGreen.opacity(0.12), forestGreen.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "bird.fill")
                        .font(.title2)
                        .foregroundColor(forestGreen.opacity(0.6))
                )
            
            // 信息
            VStack(alignment: .leading, spacing: 5) {
                Text(bird.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(bird.scientificName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                HStack(spacing: 4) {
                    Image(systemName: "ruler")
                        .font(.caption2)
                    Text(bird.size)
                        .font(.caption2)
                    Text("·")
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(bird.lifespan)
                        .font(.caption2)
                }
                .foregroundColor(forestGreen.opacity(0.7))
            }
            
            Spacer()
            
            // 价格标签
            HStack(spacing: 2) {
                Text("¥")
                    .font(.caption2)
                Text(bird.priceRange)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(forestGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(forestGreen.opacity(0.1))
            .cornerRadius(8)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(forestGreen.opacity(0.4))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(forestGreen.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - 鸟类分类枚举
enum BirdCategory: String, CaseIterable {
    case parrot = "鹦鹉类"
    case finch = "雀类"
    case other = "其他宠物鸟"
    
    var icon: String {
        switch self {
        case .parrot: return "leaf.fill"
        case .finch: return "leaf.circle.fill"
        case .other: return "bird.fill"
        }
    }
}

// MARK: - 鸟类品种数据结构
struct BirdSpecies: Identifiable {
    let id = UUID()
    let name: String
    let scientificName: String
    let category: BirdCategory
    let size: String
    let lifespan: String
    let priceRange: String      // 价格区间
    let themeColor: Color
    let description: String
    let origin: String
    let temperament: String
    let diet: [String]
    let housing: String
    let temperature: String
    let humidity: String
    let carePoints: [String]
    let healthTips: [String]
    let breedingInfo: String
}

// MARK: - 鸟类品种数据
let birdSpeciesData: [BirdSpecies] = [
    // ===== 鹦鹉类 =====
    BirdSpecies(
        name: "虎皮鹦鹉",
        scientificName: "Melopsittacus undulatus",
        category: .parrot,
        size: "18-20cm",
        lifespan: "5-10年",
        priceRange: "30-100",
        themeColor: Color.green,
        description: "虎皮鹦鹉是最受欢迎的宠物鸟之一，因其背部有类似虎皮的条纹而得名。性格活泼好动，容易驯养，适合新手饲养。",
        origin: "澳大利亚",
        temperament: "活泼好动、聪明伶俐、喜欢互动、可学说话",
        diet: ["谷物混合粮（小米、黍子、燕麦）", "新鲜蔬菜（青菜、胡萝卜）", "水果（苹果、葡萄）", "墨鱼骨补钙", "偶尔给予蛋小米"],
        housing: "笼子至少40×30×40cm，横向空间要足够飞行。配备栖木、秋千、玩具。",
        temperature: "18-28°C",
        humidity: "50-70%",
        carePoints: ["每天更换饮水和食物", "每周清洁笼子2-3次", "每天放飞1-2小时", "提供啃咬玩具磨嘴", "避免厨房油烟和香水"],
        healthTips: ["观察粪便是否正常（绿色带白色尿酸）", "注意羽毛是否蓬松无光泽", "检查鼻孔是否有分泌物", "定期修剪指甲", "每年体检一次"],
        breedingInfo: "繁殖期4-8月，每窝4-8枚蛋，孵化期18天，离巢期约30天。需提供繁殖箱。"
    ),
    
    BirdSpecies(
        name: "牡丹鹦鹉",
        scientificName: "Agapornis roseicollis",
        category: .parrot,
        size: "13-17cm",
        lifespan: "10-15年",
        priceRange: "80-300",
        themeColor: Color(red: 0.9, green: 0.4, blue: 0.5),
        description: "牡丹鹦鹉又称爱情鸟，因其成对生活、感情专一而得名。体型小巧，羽色艳丽，性格温顺，是非常受欢迎的小型鹦鹉。",
        origin: "非洲",
        temperament: "温顺亲人、成对饲养更佳、领地意识强、喜欢啃咬",
        diet: ["小型鹦鹉混合粮", "新鲜蔬菜（西兰花、菠菜）", "水果（苹果、梨、浆果）", "发芽种子", "墨鱼骨和矿物块"],
        housing: "笼子至少50×40×40cm，成对饲养需更大空间。提供繁殖箱、栖木、玩具。",
        temperature: "20-30°C",
        humidity: "50-65%",
        carePoints: ["成对饲养更健康快乐", "提供大量啃咬材料", "每天互动至少30分钟", "定期更换玩具保持新鲜感", "注意配对后的领地行为"],
        healthTips: ["检查眼睛是否明亮有神", "观察呼吸是否平稳", "注意体重变化", "羽毛应紧贴光滑", "脚趾应灵活有力"],
        breedingInfo: "全年可繁殖，每窝4-6枚蛋，孵化期23天。需要安静环境和充足营养。"
    ),
    
    BirdSpecies(
        name: "玄凤鹦鹉",
        scientificName: "Nymphicus hollandicus",
        category: .parrot,
        size: "30-33cm",
        lifespan: "15-25年",
        priceRange: "150-500",
        themeColor: Color.orange,
        description: "玄凤鹦鹉又称鸡尾鹦鹉，以其标志性的黄色冠羽和橙色脸颊斑闻名。性格温和，善于学习口哨和简单词语。",
        origin: "澳大利亚",
        temperament: "温和友善、喜欢陪伴、善于模仿口哨、较为安静",
        diet: ["中型鹦鹉混合粮", "新鲜蔬菜水果", "煮熟的豆类和谷物", "少量坚果", "钙质补充剂"],
        housing: "笼子至少60×45×60cm，需要足够的飞行空间。配备多根栖木和玩具。",
        temperature: "18-28°C",
        humidity: "40-60%",
        carePoints: ["每天至少2小时笼外活动", "定期洗澡或喷水", "提供多样化玩具", "注意冠羽状态反映情绪", "避免惊吓导致夜惊"],
        healthTips: ["注意夜惊症状", "检查羽粉是否正常", "观察食欲和活动量", "定期称重", "注意呼吸道健康"],
        breedingInfo: "繁殖期春秋季，每窝4-7枚蛋，孵化期18-21天。亲鸟共同孵化和育雏。"
    ),
    
    BirdSpecies(
        name: "金太阳鹦鹉",
        scientificName: "Aratinga solstitialis",
        category: .parrot,
        size: "30cm",
        lifespan: "25-30年",
        priceRange: "2000-5000",
        themeColor: Color(red: 1.0, green: 0.7, blue: 0.0),
        description: "金太阳鹦鹉以其鲜艳的金黄色羽毛著称，是中型鹦鹉中最美丽的品种之一。性格活泼，但叫声较大。",
        origin: "南美洲",
        temperament: "活泼好动、聪明好奇、叫声响亮、需要大量互动",
        diet: ["中型鹦鹉滋养丸", "新鲜蔬果", "发芽种子", "坚果（适量）", "煮熟的全谷物"],
        housing: "笼子至少80×60×80cm，需要大量玩具和活动空间。",
        temperature: "20-28°C",
        humidity: "50-70%",
        carePoints: ["每天3-4小时互动时间", "提供智力玩具", "训练降低叫声", "定期社交活动", "注意噪音可能影响邻居"],
        healthTips: ["定期血液检查", "注意羽毛啄咬行为", "保持环境丰富防止无聊", "监测体重", "每年兽医检查"],
        breedingInfo: "繁殖需要专业知识，每窝3-4枚蛋，孵化期24-26天。"
    ),
    
    BirdSpecies(
        name: "凯克鹦鹉",
        scientificName: "Pionites melanocephalus",
        category: .parrot,
        size: "23-25cm",
        lifespan: "25-30年",
        priceRange: "3000-8000",
        themeColor: Color(red: 1.0, green: 0.8, blue: 0.0),
        description: "凯克鹦鹉又称白腹凯克，以其活泼好动的性格和独特的\"跳舞\"行为闻名。羽色鲜艳，黑头、白腹、绿背，是非常受欢迎的中型鹦鹉。",
        origin: "南美洲亚马逊流域",
        temperament: "极度活泼、精力充沛、喜欢玩耍、好奇心强、叫声响亮",
        diet: ["中型鹦鹉滋养丸", "新鲜蔬果（木瓜、芒果、浆果）", "坚果（核桃、杏仁）", "煮熟的豆类", "少量种子"],
        housing: "笼子至少70×60×70cm，需要大量玩具和攀爬设施。凯克非常活跃，需要充足的活动空间。",
        temperature: "22-28°C",
        humidity: "50-70%",
        carePoints: ["每天至少3小时互动", "提供大量玩具防止无聊", "定期洗澡（凯克喜欢水）", "需要大量运动和玩耍", "注意其破坏力强"],
        healthTips: ["定期检查喙和爪", "注意肥胖问题", "监测活动量", "检查羽毛状态", "每年兽医体检"],
        breedingInfo: "繁殖期春季，每窝3-4枚蛋，孵化期26天。亲鸟共同育雏，雏鸟约10周离巢。"
    ),
    
    BirdSpecies(
        name: "葵花鹦鹉",
        scientificName: "Cacatua galerita",
        category: .parrot,
        size: "45-55cm",
        lifespan: "40-70年",
        priceRange: "8000-20000",
        themeColor: Color(red: 1.0, green: 0.95, blue: 0.7),
        description: "葵花鹦鹉是大型凤头鹦鹉，以其标志性的黄色冠羽而得名。全身雪白，冠羽金黄，极具观赏价值。智商高，情感丰富，需要大量陪伴。",
        origin: "澳大利亚、新几内亚",
        temperament: "聪明敏感、情感丰富、需要陪伴、叫声响亮、破坏力强",
        diet: ["大型鹦鹉滋养丸", "新鲜蔬果", "坚果（适量）", "煮熟的全谷物和豆类", "钙质补充"],
        housing: "笼子至少120×90×150cm，需要非常坚固的笼子。配备大型玩具和攀爬架。",
        temperature: "18-28°C",
        humidity: "40-60%",
        carePoints: ["每天至少4-5小时陪伴", "需要大量智力刺激", "定期洗澡", "提供可啃咬的玩具", "建立固定作息", "注意羽粉过敏"],
        healthTips: ["定期兽医检查", "注意自残行为", "监测体重", "检查羽毛状态", "预防肥胖和脂肪肝"],
        breedingInfo: "繁殖需要专业知识和大型设施，每窝2-3枚蛋，孵化期25-27天。寿命长，繁殖是长期承诺。"
    ),
    
    BirdSpecies(
        name: "和尚鹦鹉",
        scientificName: "Myiopsitta monachus",
        category: .parrot,
        size: "28-30cm",
        lifespan: "20-30年",
        priceRange: "500-1500",
        themeColor: Color(red: 0.4, green: 0.7, blue: 0.4),
        description: "和尚鹦鹉是唯一会筑巢的鹦鹉，以其灰色的「僧侣帽」般的头部羽毛得名。聪明活泼，学语能力强。",
        origin: "南美洲",
        temperament: "聪明活泼、学语能力强、有领地意识、喜欢筑巢",
        diet: ["鹦鹉滋养丸为主", "新鲜蔬菜水果", "发芽种子", "全谷物", "少量坚果"],
        housing: "笼子至少70×50×70cm，提供筑巢材料和大量玩具。",
        temperature: "15-28°C（耐寒性较强）",
        humidity: "40-60%",
        carePoints: ["提供筑巢材料满足本能", "每天互动训练", "注意领地攻击行为", "定期修剪飞羽（如需要）", "提供啃咬木块"],
        healthTips: ["注意脂肪肝问题", "控制高脂食物", "保持活动量", "定期体检", "观察羽毛状态"],
        breedingInfo: "会建造大型群巢，每窝5-8枚蛋，孵化期24天。"
    ),
    
    BirdSpecies(
        name: "小太阳鹦鹉",
        scientificName: "Pyrrhura molinae",
        category: .parrot,
        size: "24-26cm",
        lifespan: "20-30年",
        priceRange: "800-2000",
        themeColor: Color(red: 0.2, green: 0.6, blue: 0.4),
        description: "小太阳鹦鹉体型适中，性格温顺，叫声相对安静，是公寓饲养的理想选择。羽色丰富多变。",
        origin: "南美洲",
        temperament: "温顺亲人、叫声较小、喜欢拥抱、适合公寓",
        diet: ["小型鹦鹉滋养丸", "新鲜蔬果", "发芽种子", "偶尔坚果", "全谷物"],
        housing: "笼子至少60×45×60cm，提供多样玩具和栖木。",
        temperature: "18-28°C",
        humidity: "50-65%",
        carePoints: ["每天亲密互动", "提供觅食玩具", "定期洗澡", "保持环境安静", "训练简单技巧"],
        healthTips: ["注意呼吸道感染", "保持环境清洁", "避免温度骤变", "定期修剪指甲", "观察食欲变化"],
        breedingInfo: "每窝4-6枚蛋，孵化期22-25天，需要繁殖箱。"
    ),
    
    BirdSpecies(
        name: "亚历山大鹦鹉",
        scientificName: "Psittacula eupatria",
        category: .parrot,
        size: "56-62cm",
        lifespan: "25-40年",
        priceRange: "1500-4000",
        themeColor: Color(red: 0.3, green: 0.7, blue: 0.3),
        description: "亚历山大鹦鹉是大型鹦鹉，以亚历山大大帝命名。体型优雅，羽色翠绿，雄鸟颈部有粉红色环。",
        origin: "印度、斯里兰卡",
        temperament: "独立自信、需要耐心训练、可学说话、较为安静",
        diet: ["大型鹦鹉滋养丸", "大量新鲜蔬果", "坚果和种子", "煮熟的豆类", "全谷物"],
        housing: "笼子至少100×80×120cm或鸟舍，需要大量飞行空间。",
        temperature: "18-30°C",
        humidity: "50-70%",
        carePoints: ["需要大空间活动", "每天至少4小时笼外时间", "提供大型玩具", "耐心建立信任", "定期修剪喙和指甲"],
        healthTips: ["注意PBFD病毒", "定期血液检查", "保持羽毛健康", "监测体重", "注意呼吸道健康"],
        breedingInfo: "繁殖较困难，每窝2-4枚蛋，孵化期26-28天。"
    ),
    
    BirdSpecies(
        name: "灰鹦鹉",
        scientificName: "Psittacus erithacus",
        category: .parrot,
        size: "33cm",
        lifespan: "40-60年",
        priceRange: "8000-20000",
        themeColor: Color.gray,
        description: "非洲灰鹦鹉被认为是最聪明的鹦鹉，学语能力极强，能理解和运用词汇。需要经验丰富的饲主。",
        origin: "非洲中西部",
        temperament: "极其聪明、敏感、需要大量互动、可能有羽毛啄咬问题",
        diet: ["高品质滋养丸", "大量新鲜蔬果", "坚果（适量）", "发芽种子", "钙质补充"],
        housing: "笼子至少90×60×120cm，需要丰富的环境刺激。",
        temperature: "20-28°C",
        humidity: "50-70%",
        carePoints: ["每天至少4-6小时互动", "提供智力挑战玩具", "建立稳定日程", "避免环境变化", "学习鸟类行为学"],
        healthTips: ["注意钙质缺乏", "预防羽毛啄咬", "定期血液检查", "注意呼吸道感染", "心理健康同样重要"],
        breedingInfo: "繁殖极其困难，需要专业环境，每窝2-4枚蛋，孵化期28-30天。"
    ),
    
    // ===== 雀类 =====
    BirdSpecies(
        name: "文鸟",
        scientificName: "Lonchura oryzivora",
        category: .finch,
        size: "14-17cm",
        lifespan: "5-8年",
        priceRange: "20-50",
        themeColor: Color(red: 0.6, green: 0.6, blue: 0.6),
        description: "文鸟又称禾雀，是最受欢迎的雀类宠物鸟。体型圆润可爱，叫声悦耳，容易饲养。",
        origin: "印度尼西亚",
        temperament: "温顺安静、群居性强、不喜欢单独饲养、较少互动",
        diet: ["雀类混合粮（稻谷、小米）", "新鲜蔬菜", "蛋小米", "墨鱼骨", "少量水果"],
        housing: "笼子至少45×30×45cm，群养需更大空间。横向栖木为主。",
        temperature: "20-28°C",
        humidity: "50-70%",
        carePoints: ["建议成对或群养", "提供水浴盆", "保持环境安静", "避免频繁惊扰", "定期清洁笼子"],
        healthTips: ["注意气囊螨", "观察呼吸是否正常", "检查脚趾健康", "保持羽毛整洁", "避免过度肥胖"],
        breedingInfo: "全年可繁殖，每窝4-6枚蛋，孵化期14天，离巢期约21天。"
    ),
    
    BirdSpecies(
        name: "珍珠鸟",
        scientificName: "Taeniopygia guttata",
        category: .finch,
        size: "10-12cm",
        lifespan: "5-7年",
        priceRange: "15-40",
        themeColor: Color(red: 0.8, green: 0.5, blue: 0.3),
        description: "珍珠鸟又称斑胸草雀，因胸部有珍珠般的白色斑点而得名。体型娇小，繁殖容易，适合新手。",
        origin: "澳大利亚",
        temperament: "活泼好动、群居性强、叫声清脆、观赏性强",
        diet: ["小米为主的混合粮", "蛋小米", "新鲜蔬菜", "墨鱼骨", "沙砾助消化"],
        housing: "笼子至少40×25×35cm，群养需更大。提供草窝或繁殖箱。",
        temperature: "18-28°C",
        humidity: "40-60%",
        carePoints: ["成对饲养最佳", "提供筑巢材料", "每天更换饮水", "保持环境温暖", "避免潮湿"],
        healthTips: ["注意呼吸道感染", "检查眼睛是否有分泌物", "观察羽毛状态", "保持脚趾清洁", "定期驱虫"],
        breedingInfo: "繁殖力强，每窝4-8枚蛋，孵化期12-14天，离巢期约18天。"
    ),
    
    BirdSpecies(
        name: "金丝雀",
        scientificName: "Serinus canaria",
        category: .finch,
        size: "12-14cm",
        lifespan: "10-15年",
        priceRange: "200-600",
        themeColor: Color.yellow,
        description: "金丝雀以其美妙的歌声闻名于世，是最古老的宠物鸟之一。雄鸟善于鸣唱，羽色金黄亮丽。",
        origin: "加那利群岛",
        temperament: "独立安静、雄鸟善鸣、不喜欢触摸、观赏为主",
        diet: ["金丝雀专用粮", "新鲜蔬菜（生菜、西兰花）", "蛋粮", "水果", "矿物质补充"],
        housing: "笼子至少50×30×40cm，单独饲养雄鸟歌声更好。",
        temperature: "15-25°C",
        humidity: "50-65%",
        carePoints: ["单独饲养雄鸟促进鸣唱", "提供充足光照", "避免噪音干扰", "定期修剪指甲", "保持空气流通"],
        healthTips: ["注意呼吸道疾病", "避免肥胖", "检查羽毛是否脱落", "观察精神状态", "定期清洁笼具"],
        breedingInfo: "春季繁殖，每窝3-5枚蛋，孵化期13-14天。需要繁殖笼和巢材。"
    ),
    
    BirdSpecies(
        name: "十姐妹",
        scientificName: "Lonchura striata domestica",
        category: .finch,
        size: "11-12cm",
        lifespan: "5-8年",
        priceRange: "10-30",
        themeColor: Color.brown,
        description: "十姐妹是人工培育的家养雀类，性格温顺，常被用作其他雀类的保姆鸟。繁殖能力强。",
        origin: "人工培育（源自白腰文鸟）",
        temperament: "温顺友善、群居性强、优秀的保姆鸟、容易繁殖",
        diet: ["雀类混合粮", "蛋小米", "新鲜蔬菜", "墨鱼骨", "沙砾"],
        housing: "笼子至少40×25×35cm，群养更佳。提供繁殖箱。",
        temperature: "18-28°C",
        humidity: "50-65%",
        carePoints: ["适合群养", "提供筑巢材料", "可作为保姆鸟", "饲养简单", "定期清洁"],
        healthTips: ["注意肠道健康", "避免过度繁殖", "保持环境卫生", "观察食欲", "定期检查"],
        breedingInfo: "全年可繁殖，每窝5-8枚蛋，孵化期12-14天。常用于代孵其他雀类的蛋。"
    ),
    
    // ===== 其他宠物鸟 =====
    BirdSpecies(
        name: "八哥",
        scientificName: "Acridotheres cristatellus",
        category: .other,
        size: "25-28cm",
        lifespan: "10-15年",
        priceRange: "200-500",
        themeColor: Color.black,
        description: "八哥是著名的学语鸟，模仿能力极强，能学会多种声音和词语。性格活泼，需要大量互动。",
        origin: "中国南方、东南亚",
        temperament: "聪明活泼、学语能力强、需要大量互动、较为吵闹",
        diet: ["八哥专用粮", "昆虫（面包虫、蟋蟀）", "水果", "蔬菜", "煮熟的蛋黄"],
        housing: "笼子至少60×45×60cm，需要足够活动空间。",
        temperature: "15-30°C",
        humidity: "50-70%",
        carePoints: ["每天语言训练", "提供活食", "定期洗澡", "保持互动", "注意叫声可能扰民"],
        healthTips: ["注意脚趾健康", "避免肥胖", "检查羽毛状态", "保持环境清洁", "定期驱虫"],
        breedingInfo: "春夏繁殖，每窝4-6枚蛋，孵化期14天。需要较大繁殖笼。"
    ),
    
    BirdSpecies(
        name: "鹩哥",
        scientificName: "Gracula religiosa",
        category: .other,
        size: "28-30cm",
        lifespan: "15-25年",
        priceRange: "1000-3000",
        themeColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        description: "鹩哥是学语能力最强的鸟类之一，声音清晰洪亮，能模仿人声和各种声音。需要专业饲养。",
        origin: "东南亚",
        temperament: "聪明好学、声音洪亮、需要专业护理、较为敏感",
        diet: ["鹩哥专用粮", "大量水果", "昆虫", "蔬菜", "蛋白质补充"],
        housing: "笼子至少80×60×80cm，需要宽敞环境。",
        temperature: "20-30°C",
        humidity: "60-80%",
        carePoints: ["每天语言训练", "提供大量水果", "保持高湿度", "定期洗澡", "避免应激"],
        healthTips: ["注意铁储存病", "控制高铁食物", "保持环境湿润", "定期体检", "注意呼吸道"],
        breedingInfo: "人工繁殖困难，野外每窝2-3枚蛋，孵化期14-15天。"
    ),
    
    BirdSpecies(
        name: "相思鸟",
        scientificName: "Leiothrix lutea",
        category: .other,
        size: "14-15cm",
        lifespan: "8-12年",
        priceRange: "100-300",
        themeColor: Color(red: 0.9, green: 0.6, blue: 0.2),
        description: "相思鸟又称红嘴相思，羽色艳丽，叫声婉转动听。是传统的观赏笼鸟，深受鸟友喜爱。",
        origin: "中国、印度、缅甸",
        temperament: "活泼好动、叫声悦耳、较为胆小、需要安静环境",
        diet: ["雀类混合粮", "昆虫", "水果", "蔬菜", "蛋粮"],
        housing: "笼子至少50×35×50cm，提供多层栖木。",
        temperature: "15-28°C",
        humidity: "50-70%",
        carePoints: ["保持环境安静", "提供活食", "避免惊吓", "定期洗澡", "注意温度变化"],
        healthTips: ["注意呼吸道感染", "避免应激", "保持羽毛健康", "检查脚趾", "定期驱虫"],
        breedingInfo: "春夏繁殖，每窝3-5枚蛋，孵化期12-14天。需要安静环境。"
    ),
    
    BirdSpecies(
        name: "画眉",
        scientificName: "Garrulax canorus",
        category: .other,
        size: "21-25cm",
        lifespan: "10-15年",
        priceRange: "300-800",
        themeColor: Color(red: 0.6, green: 0.4, blue: 0.2),
        description: "画眉是中国传统名鸟，以其婉转悠扬的歌声著称。眼周有白色眉纹，故名画眉。需要专业饲养。",
        origin: "中国",
        temperament: "善于鸣唱、较为胆小、需要耐心驯养、领地意识强",
        diet: ["画眉专用粮", "昆虫（蟋蟀、面包虫）", "水果", "蛋黄", "肉类"],
        housing: "传统画眉笼或大型笼子，需要遮光布。",
        temperature: "15-28°C",
        humidity: "50-70%",
        carePoints: ["每天遛鸟促进鸣唱", "提供活食", "使用遮光布调节", "保持安静环境", "耐心驯养"],
        healthTips: ["注意脚趾健康", "避免肥胖", "检查羽毛状态", "保持清洁", "定期驱虫"],
        breedingInfo: "人工繁殖较困难，野外春夏繁殖，每窝3-5枚蛋。"
    )
]

// MARK: - 鸟类品种详情视图
struct BirdSpeciesDetailView: View {
    let bird: BirdSpecies
    @Environment(\.dismiss) private var dismiss
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 头部信息卡片
                    headerCard
                    
                    // 基本信息
                    infoSection(title: "基本信息", icon: "info.circle.fill") {
                        infoRow(label: "学名", value: bird.scientificName)
                        infoRow(label: "原产地", value: bird.origin)
                        infoRow(label: "体型", value: bird.size)
                        infoRow(label: "寿命", value: bird.lifespan)
                        infoRow(label: "参考价格", value: "¥\(bird.priceRange)")
                    }
                    
                    // 性格特点
                    infoSection(title: "性格特点", icon: "heart.fill") {
                        Text(bird.temperament)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 饮食建议
                    infoSection(title: "饮食建议", icon: "leaf.fill") {
                        ForEach(bird.diet, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(forestGreen)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(item)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 居住环境
                    infoSection(title: "居住环境", icon: "house.fill") {
                        Text(bird.housing)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 20) {
                            VStack {
                                Image(systemName: "thermometer")
                                    .foregroundColor(.orange)
                                Text(bird.temperature)
                                    .font(.caption)
                            }
                            VStack {
                                Image(systemName: "humidity.fill")
                                    .foregroundColor(.blue)
                                Text(bird.humidity)
                                    .font(.caption)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // 饲养要点
                    infoSection(title: "饲养要点", icon: "checkmark.circle.fill") {
                        ForEach(bird.carePoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(forestGreen)
                                    .padding(.top, 2)
                                Text(point)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 健康提示
                    infoSection(title: "健康提示", icon: "cross.case.fill") {
                        ForEach(bird.healthTips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 繁殖信息
                    infoSection(title: "繁殖信息", icon: "heart.circle.fill") {
                        Text(bird.breedingInfo)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .navigationTitle(bird.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(forestGreen)
                }
            }
        }
    }
    
    // 头部卡片
    private var headerCard: some View {
        VStack(spacing: 16) {
            // 图标
            RoundedRectangle(cornerRadius: 20)
                .fill(bird.themeColor.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "bird.fill")
                        .font(.system(size: 36))
                        .foregroundColor(bird.themeColor)
                )
            
            // 名称
            Text(bird.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(bird.scientificName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
            
            // 描述
            Text(bird.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // 信息区块
    private func infoSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(forestGreen)
                Text(title)
                    .font(.headline)
            }
            
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
    }
    
    // 信息行
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 牡丹鹦鹉配色预测视图
struct ColorPredictionView: View {
    @State private var fatherColor: String = ""
    @State private var motherColor: String = ""
    
    // 森林主题色
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let leafGreen = Color(red: 0.35, green: 0.55, blue: 0.40)
    private let softGreen = Color(red: 0.85, green: 0.92, blue: 0.85)
    
    // 牡丹鹦鹉羽色分类
    private let colorCategories: [(category: String, colors: [String])] = [
        ("绿色系", ["绿桃", "绿金顶", "绿银顶"]),
        ("蓝色系", ["蓝桃", "蓝金顶", "蓝银顶", "松石蓝", "松石蓝银"]),
        ("紫罗兰系", ["紫罗兰", "墨银"]),
        ("澳桂系", ["红头澳桂", "金头澳桂", "白头澳桂", "苹果绿澳桂", "薄荷绿澳桂"]),
        ("美桂系", ["红头美桂", "金头美桂", "白头美桂"]),
        ("闪光系", ["绿闪", "蓝闪", "紫闪", "松石蓝闪", "红头绿闪", "金头绿闪"]),
        ("澳桂闪光系", ["红头澳闪", "金头澳闪", "黄澳闪", "苹果绿澳闪", "薄荷绿澳闪"]),
        ("伊莎系", ["蓝面伊", "松石面伊", "紫面伊", "绿面伊"]),
        ("薰衣草系", ["紫薰衣草", "蓝薰衣草", "松石薰衣草"]),
        ("派特系", ["绿派特", "蓝派特", "紫罗兰派特", "澳桂派特"])
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // 父母选择区域
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // 父亲选择器
                    parentSelector(
                        title: "父亲",
                        icon: "♂",
                        iconColor: Color(red: 0.3, green: 0.5, blue: 0.7),
                        selection: $fatherColor
                    )
                    
                    // 配对符号
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundColor(forestGreen.opacity(0.6))
                    
                    // 母亲选择器
                    parentSelector(
                        title: "母亲",
                        icon: "♀",
                        iconColor: Color(red: 0.8, green: 0.5, blue: 0.6),
                        selection: $motherColor
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: forestGreen.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            
            // 预测结果
            if !fatherColor.isEmpty && !motherColor.isEmpty {
                predictionResultView
            } else {
                emptyStateView
            }
        }
    }
    
    // 父母选择器
    private func parentSelector(title: String, icon: String, iconColor: Color, selection: Binding<String>) -> some View {
        VStack(spacing: 10) {
            // 图标和标题
            VStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // 下拉选择
            Menu {
                ForEach(colorCategories, id: \.category) { category in
                    Section(category.category) {
                        ForEach(category.colors, id: \.self) { color in
                            Button(color) {
                                selection.wrappedValue = color
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "选择羽色" : selection.wrappedValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(selection.wrappedValue.isEmpty ? .secondary : forestGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(softGreen)
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 44))
                .foregroundColor(forestGreen.opacity(0.3))
            
            Text("选择父母羽色开始预测")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: forestGreen.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // 预测结果视图
    private var predictionResultView: some View {
        let prediction = getBreedingResult(father: fatherColor, mother: motherColor)
        
        return VStack(spacing: 16) {
            // 配对信息
            HStack(spacing: 8) {
                Text(fatherColor)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.7))
                Text("×")
                    .foregroundColor(.secondary)
                Text(motherColor)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.8, green: 0.5, blue: 0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(softGreen)
            )
            
            // 后代结果
            HStack(alignment: .top, spacing: 12) {
                // 公鸟后代
                offspringCard(
                    title: "公鸟后代",
                    icon: "♂",
                    iconColor: Color(red: 0.3, green: 0.5, blue: 0.7),
                    results: prediction.male
                )
                
                // 母鸟后代
                offspringCard(
                    title: "母鸟后代",
                    icon: "♀",
                    iconColor: Color(red: 0.8, green: 0.5, blue: 0.6),
                    results: prediction.female
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: forestGreen.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    // 后代卡片
    private func offspringCard(title: String, icon: String, iconColor: Color, results: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack(spacing: 6) {
                Text(icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(iconColor)
            }
            
            // 结果列表
            VStack(alignment: .leading, spacing: 8) {
                ForEach(results, id: \.self) { result in
                    resultRow(result: result, accentColor: iconColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(iconColor.opacity(0.05))
        )
    }
    
    // 结果行
    private func resultRow(result: String, accentColor: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(accentColor.opacity(0.6))
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            
            Text(result)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // ==================== 遗传学计算系统 ====================
    // 基于: 公鸟ZZ, 母鸟ZW 的性染色体系统
    // 位点: Base(G/b), Turq(+/t), Violet(+/v), AusF(Z连锁), AmF(Z连锁), Opaline(Z连锁), Pied(P/+)
    
    struct BreedingResult {
        let male: [String]
        let female: [String]
    }
    
    // ==================== 性别依赖穿透率参数（可调）====================
    // 基于育种圈经验值，分性别的异合子表现概率
    // 关键改进：紫罗兰等位点在雄雌有不同穿透率
    struct PenetranceParams {
        // 紫罗兰 (v) - 性别差异显著：雄性高穿透，雌性低穿透
        var p_v_homo_male: Double = 1.0       // 纯合雄 v/v
        var p_v_homo_female: Double = 0.85    // 纯合雌 v/v (略低)
        var p_v_het_male: Double = 0.80       // 异合雄 v/+ (高穿透)
        var p_v_het_female: Double = 0.25     // 异合雌 v/+ (低穿透)
        
        // 松石 (t) - 轻微性别差异
        var p_t_homo: Double = 1.0            // 纯合 t/t
        var p_t_het_male: Double = 0.30       // 异合雄
        var p_t_het_female: Double = 0.20     // 异合雌
        
        // 伊莎 (isa) - 无明显性别差异
        var p_isa_homo: Double = 1.0          // 纯合 isa/isa
        var p_isa_het: Double = 0.10          // 异合 isa/+
        
        // 闪光 (S) - 显性，无性别差异
        var p_S_expr: Double = 0.90           // S/+ 或 S/S
        
        // 派特 (P) - 不完全显性
        var p_pied_het: Double = 0.60         // P/+
    }
    
    // 默认穿透率参数
    private let penetrance = PenetranceParams()
    
    // 基因型结构
    struct Genotype {
        // 常染色体 (每个位点两个等位基因)
        var base: (String, String)      // B=绿(显), b=蓝(隐)
        var turq: (String, String)      // +=野生, t=松石(隐/半显)
        var violet: (String, String)    // +=野生, v=紫罗兰(隐/半显)
        var isa: (String, String)       // +=野生, isa=伊莎(隐)
        var spark: (String, String)     // +=野生, S=闪(显性修饰)
        var pied: (String, String)      // +=野生, P=派特(不完全显性)
        var headCap: String             // 头色: none/Red/Gold/White/Apple/Mint/Silver/Yellow
        
        // Z连锁位点 (公鸟两个Z, 母鸟一个Z一个W)
        var sexChr: (String, String)    // (Z,Z)=公, (Z,W)=母
        var zAusF: (String, String?)    // aus=澳桂(Z连锁隐), 母鸟第二个为nil
        var zAmF: (String, String?)     // am=美桂(Z连锁隐)
        var zIno: (String, String?)     // ino=Lutino(Z连锁隐)
        
        var isMale: Bool { sexChr.0 == "Z" && sexChr.1 == "Z" }
        
        // 判断各位点是否为纯合突变
        var isHomoViolet: Bool { violet.0 == "v" && violet.1 == "v" }
        var isHetViolet: Bool { (violet.0 == "v") != (violet.1 == "v") }
        var isHomoTurq: Bool { turq.0 == "t" && turq.1 == "t" }
        var isHetTurq: Bool { (turq.0 == "t") != (turq.1 == "t") }
        var isHomoIsa: Bool { isa.0 == "isa" && isa.1 == "isa" }
        var isHetIsa: Bool { (isa.0 == "isa") != (isa.1 == "isa") }
        var hasSpark: Bool { spark.0 == "S" || spark.1 == "S" }
        var hasPied: Bool { pied.0 == "P" || pied.1 == "P" }
        var isBlue: Bool { base.0 == "b" && base.1 == "b" }
    }
    
    // 后代结果
    struct Offspring: Hashable {
        let phenotype: String
        let isMale: Bool
        let carriers: [String]
        var probability: Double
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(phenotype)
            hasher.combine(isMale)
            hasher.combine(carriers.sorted())
        }
        
        static func == (lhs: Offspring, rhs: Offspring) -> Bool {
            lhs.phenotype == rhs.phenotype && lhs.isMale == rhs.isMale && lhs.carriers.sorted() == rhs.carriers.sorted()
        }
    }
    
    // 颜色名 → 基因型
    // 基因代码标准:
    // Base: B/b (绿/蓝), Turquoise: t/+ (松石), Violet: v/+ (紫罗兰)
    // Isabella: isa/+ (伊莎-常染色体隐性), Spark: S/+ (闪-显性修饰)
    private func colorToGenotype(_ name: String, isMale: Bool) -> Genotype {
        var g = Genotype(
            base: ("b", "b"), turq: ("+", "+"), violet: ("+", "+"),
            isa: ("+", "+"), spark: ("+", "+"), pied: ("+", "+"), headCap: "none",
            sexChr: isMale ? ("Z", "Z") : ("Z", "W"),
            zAusF: isMale ? ("+", "+") : ("+", nil),
            zAmF: isMale ? ("+", "+") : ("+", nil),
            zIno: isMale ? ("+", "+") : ("+", nil)
        )
        
        // 解析颜色名设置基因
        // 绿色系 (需要B基因)
        if name.contains("绿") { g.base = ("B", "B") }
        
        // 松石 (t/t)
        if name.contains("松石") { g.turq = ("t", "t") }
        
        // 紫罗兰 (v/v) - 包括紫面伊、紫闪、紫薰衣草等
        if name.contains("紫罗兰") || name.contains("紫面伊") || name.contains("紫薰衣草") || name.contains("紫闪") {
            g.violet = ("v", "v")
        }
        
        // 伊莎 (isa/isa) - 常染色体隐性，纯合才表现
        // 蓝面伊、松石面伊、紫面伊 等
        if name.contains("面伊") {
            g.isa = ("isa", "isa")
        }
        
        // 闪光 (S/+) - 常染色体显性修饰
        if name.contains("闪") {
            g.spark = ("S", "+")
        }
        
        // 薰衣草 (美桂+闪)
        if name.contains("薰衣草") {
            g.spark = ("S", "+")
        }
        
        // 头色
        if name.contains("红头") { g.headCap = "Red" }
        else if name.contains("金头") || name.contains("金顶") { g.headCap = "Gold" }
        else if name.contains("白头") { g.headCap = "White" }
        else if name.contains("苹果绿") { g.headCap = "Apple" }
        else if name.contains("薄荷绿") { g.headCap = "Mint" }
        else if name.contains("银顶") || name.contains("银") { g.headCap = "Silver" }
        else if name.contains("黄") { g.headCap = "Yellow" }
        
        // 澳桂 (Z连锁隐性)
        if name.contains("澳桂") || name.contains("澳闪") {
            g.zAusF = isMale ? ("aus", "aus") : ("aus", nil)
        }
        // 美桂 (Z连锁隐性)
        if name.contains("美桂") || name.contains("薰衣草") {
            g.zAmF = isMale ? ("am", "am") : ("am", nil)
        }
        // 派特 (显性)
        if name.contains("派特") { g.pied = ("P", "+") }
        
        return g
    }
    
    // 基因型 → 表型名称
    // 基因代码: Base(B/b), Turquoise(t/+), Violet(v/+), Isabella(isa/+), Spark(S/+)
    private func genotypeToPheno(_ g: Genotype) -> (name: String, carriers: [String]) {
        var carriers: [String] = []
        let isMale = g.isMale
        
        // 判断常染色体表型
        let isBlue = g.base.0 == "b" && g.base.1 == "b"
        let isTurq = g.turq.0 == "t" && g.turq.1 == "t"
        let isViolet = g.violet.0 == "v" && g.violet.1 == "v"
        let isIsa = g.isa.0 == "isa" && g.isa.1 == "isa"  // 伊莎是隐性，需要纯合
        let hasSpark = g.spark.0 == "S" || g.spark.1 == "S"  // 闪是显性，有一个即表现
        let isPied = g.pied.0 == "P" || g.pied.1 == "P"
        
        // 携带信息(常染色体)
        if g.base.0 != g.base.1 { carriers.append("蓝") }
        if (g.turq.0 == "t") != (g.turq.1 == "t") { carriers.append("松石") }
        if (g.violet.0 == "v") != (g.violet.1 == "v") { carriers.append("紫罗兰") }
        // 伊莎携带检测
        let hasIsa = g.isa.0 == "isa" || g.isa.1 == "isa"
        if hasIsa && !isIsa { carriers.append("伊莎") }
        
        // Z连锁表型判断
        let showAusF = isMale ? (g.zAusF.0 == "aus" && g.zAusF.1 == "aus") : (g.zAusF.0 == "aus")
        let showAmF = isMale ? (g.zAmF.0 == "am" && g.zAmF.1 == "am") : (g.zAmF.0 == "am")
        
        // Z连锁携带(仅公鸟可携带)
        if isMale {
            let hasAus = g.zAusF.0 == "aus" || g.zAusF.1 == "aus"
            let homAus = g.zAusF.0 == "aus" && g.zAusF.1 == "aus"
            if hasAus && !homAus { carriers.append("澳桂") }
            
            let hasAm = g.zAmF.0 == "am" || g.zAmF.1 == "am"
            let homAm = g.zAmF.0 == "am" && g.zAmF.1 == "am"
            if hasAm && !homAm { carriers.append("美桂") }
        }
        
        // 构建表型名称
        var name = ""
        let head = g.headCap
        var headPrefix = ""
        switch head {
        case "Red": headPrefix = "红头"
        case "Gold": headPrefix = "金头"
        case "White": headPrefix = "白头"
        case "Apple": headPrefix = "苹果绿"
        case "Mint": headPrefix = "薄荷绿"
        case "Yellow": headPrefix = "黄"
        default: break
        }
        
        // ===== 伊莎系列 (isa/isa 常染色体隐性) =====
        // 紫面伊 = b/b + v/v + isa/isa
        if isIsa && isViolet && isBlue {
            name = "紫面伊"
        }
        // 松石面伊 = b/b + t/t + isa/isa
        else if isIsa && isTurq && isBlue {
            name = "松石面伊"
        }
        // 蓝面伊 = b/b + isa/isa
        else if isIsa && isBlue {
            name = "蓝面伊"
        }
        // 绿面伊 (如果有绿+伊莎)
        else if isIsa && !isBlue {
            name = "绿面伊"
        }
        // ===== 薰衣草系列 (美桂+闪) =====
        else if showAmF && hasSpark && isBlue {
            if isViolet { name = "紫薰衣草" }
            else if isTurq { name = "松石薰衣草" }
            else { name = "蓝薰衣草" }
        }
        // ===== 澳闪 = 澳桂+闪 =====
        else if showAusF && hasSpark {
            name = "\(headPrefix)澳闪"
        }
        // ===== 单独澳桂 =====
        else if showAusF {
            name = "\(headPrefix)澳桂"
        }
        // ===== 单独美桂 =====
        else if showAmF {
            name = "\(headPrefix)美桂"
        }
        // ===== 闪光系列 (Spark显性) =====
        else if hasSpark {
            if isViolet { name = "\(headPrefix)紫闪" }
            else if isTurq { name = "\(headPrefix)松石蓝闪" }
            else if isBlue { name = "\(headPrefix)蓝闪" }
            else { name = "\(headPrefix)绿闪" }
        }
        // ===== 紫罗兰 =====
        else if isViolet && isBlue {
            name = "紫罗兰"
        }
        // ===== 松石蓝 =====
        else if isTurq && isBlue {
            if head == "Silver" { name = "松石蓝银" }
            else if head == "Gold" { name = "松石蓝金" }
            else { name = "松石蓝" }
        }
        // ===== 蓝色系 =====
        else if isBlue {
            if head == "Gold" { name = "蓝金顶" }
            else if head == "Silver" { name = "蓝银顶" }
            else { name = "蓝桃" }
        }
        // ===== 绿色系 =====
        else {
            if head == "Gold" { name = "绿金顶" }
            else if head == "Silver" { name = "绿银顶" }
            else { name = "绿桃" }
        }
        
        // 派特后缀
        if isPied { name += "派特" }
        if name.isEmpty { name = "蓝桃" }
        
        return (name, carriers)
    }
    
    // 配子结构
    struct Gamete {
        let base: String
        let turq: String
        let violet: String
        let isa: String
        let spark: String
        let pied: String
        let head: String
        let sexChr: String
        let ausF: String?
        let amF: String?
        let prob: Double
    }
    
    // 生成配子
    private func generateGametes(_ g: Genotype) -> [Gamete] {
        var gametes: [Gamete] = []
        
        let baseOpts = [g.base.0, g.base.1]
        let turqOpts = [g.turq.0, g.turq.1]
        let violetOpts = [g.violet.0, g.violet.1]
        let isaOpts = [g.isa.0, g.isa.1]
        let sparkOpts = [g.spark.0, g.spark.1]
        let piedOpts = [g.pied.0, g.pied.1]
        
        if g.isMale {
            // 公鸟ZZ: 产生Z配子
            let zOpts: [(String, String?, String?)] = [
                ("Z", g.zAusF.0, g.zAmF.0),
                ("Z", g.zAusF.1, g.zAmF.1)
            ]
            let total = Double(baseOpts.count * turqOpts.count * violetOpts.count * isaOpts.count * sparkOpts.count * piedOpts.count * zOpts.count)
            for b in baseOpts { for t in turqOpts { for v in violetOpts { for i in isaOpts { for s in sparkOpts { for p in piedOpts { for z in zOpts {
                gametes.append(Gamete(base: b, turq: t, violet: v, isa: i, spark: s, pied: p, head: g.headCap, sexChr: z.0, ausF: z.1, amF: z.2, prob: 1.0/total))
            }}}}}}}
        } else {
            // 母鸟ZW: 产生Z或W配子
            let total = Double(baseOpts.count * turqOpts.count * violetOpts.count * isaOpts.count * sparkOpts.count * piedOpts.count * 2)
            for b in baseOpts { for t in turqOpts { for v in violetOpts { for i in isaOpts { for s in sparkOpts { for p in piedOpts {
                // Z配子
                gametes.append(Gamete(base: b, turq: t, violet: v, isa: i, spark: s, pied: p, head: g.headCap, sexChr: "Z", ausF: g.zAusF.0, amF: g.zAmF.0, prob: 1.0/total))
                // W配子
                gametes.append(Gamete(base: b, turq: t, violet: v, isa: i, spark: s, pied: p, head: g.headCap, sexChr: "W", ausF: nil, amF: nil, prob: 1.0/total))
            }}}}}}
        }
        return gametes
    }
    
    // 合并配子生成后代
    private func combine(_ fg: Gamete, _ mg: Gamete) -> Genotype? {
        let sexChr: (String, String)
        if fg.sexChr == "Z" && mg.sexChr == "Z" { sexChr = ("Z", "Z") }
        else if fg.sexChr == "Z" && mg.sexChr == "W" { sexChr = ("Z", "W") }
        else { return nil }
        
        let isMale = sexChr.0 == "Z" && sexChr.1 == "Z"
        let head = fg.head != "none" ? fg.head : mg.head
        
        return Genotype(
            base: (fg.base, mg.base),
            turq: (fg.turq, mg.turq),
            violet: (fg.violet, mg.violet),
            isa: (fg.isa, mg.isa),
            spark: (fg.spark, mg.spark),
            pied: (fg.pied, mg.pied),
            headCap: head,
            sexChr: sexChr,
            zAusF: isMale ? (fg.ausF ?? "+", mg.ausF ?? "+") : (fg.ausF ?? "+", nil),
            zAmF: isMale ? (fg.amF ?? "+", mg.amF ?? "+") : (fg.amF ?? "+", nil),
            zIno: isMale ? ("+", "+") : ("+", nil)
        )
    }
    
    // ==================== 性别依赖穿透率表型计算 ====================
    // 表型表达状态结构
    struct PhenoExpression {
        var showViolet: Bool = false
        var showTurq: Bool = false
        var showIsa: Bool = false
        var showSpark: Bool = false
        var showPied: Bool = false
        var probability: Double = 1.0
    }
    
    // 根据基因型和穿透率计算所有可能的表型表达组合
    // 关键改进：使用性别依赖的穿透率 (p_male vs p_female)
    private func calculatePhenoExpressions(_ g: Genotype) -> [PhenoExpression] {
        let p = penetrance
        let isMale = g.isMale
        
        // ===== 性别依赖穿透率计算 =====
        // 紫罗兰：雄性高穿透，雌性低穿透
        let pViolet: Double
        if g.isHomoViolet {
            pViolet = isMale ? p.p_v_homo_male : p.p_v_homo_female
        } else if g.isHetViolet {
            pViolet = isMale ? p.p_v_het_male : p.p_v_het_female
        } else {
            pViolet = 0.0
        }
        
        // 松石：轻微性别差异
        let pTurq: Double
        if g.isHomoTurq {
            pTurq = p.p_t_homo
        } else if g.isHetTurq {
            pTurq = isMale ? p.p_t_het_male : p.p_t_het_female
        } else {
            pTurq = 0.0
        }
        
        // 伊莎：无性别差异
        let pIsa: Double = g.isHomoIsa ? p.p_isa_homo : (g.isHetIsa ? p.p_isa_het : 0.0)
        
        // 闪光：显性，无性别差异
        let pSpark: Double = g.hasSpark ? p.p_S_expr : 0.0
        
        // 派特：不完全显性
        let pPied: Double = g.hasPied ? p.p_pied_het : 0.0
        
        // 生成所有可能的表达组合 (2^5 = 32种，但只保留概率>0的)
        var expressions: [PhenoExpression] = []
        
        for vExp in [false, true] {
            for tExp in [false, true] {
                for iExp in [false, true] {
                    for sExp in [false, true] {
                        for pExp in [false, true] {
                            // 计算这个组合的概率
                            let probV = vExp ? pViolet : (1.0 - pViolet)
                            let probT = tExp ? pTurq : (1.0 - pTurq)
                            let probI = iExp ? pIsa : (1.0 - pIsa)
                            let probS = sExp ? pSpark : (1.0 - pSpark)
                            let probP = pExp ? pPied : (1.0 - pPied)
                            
                            let totalProb = probV * probT * probI * probS * probP
                            
                            if totalProb > 0.0001 {  // 忽略极小概率
                                var expr = PhenoExpression()
                                expr.showViolet = vExp && (g.isHomoViolet || g.isHetViolet)
                                expr.showTurq = tExp && (g.isHomoTurq || g.isHetTurq)
                                expr.showIsa = iExp && (g.isHomoIsa || g.isHetIsa)
                                expr.showSpark = sExp && g.hasSpark
                                expr.showPied = pExp && g.hasPied
                                expr.probability = totalProb
                                expressions.append(expr)
                            }
                        }
                    }
                }
            }
        }
        
        return expressions
    }
    
    // 根据表达状态生成表型名称
    private func expressionToPheno(_ expr: PhenoExpression, _ g: Genotype) -> (name: String, carriers: [String]) {
        var carriers: [String] = []
        let isBlue = g.isBlue
        
        // 携带信息 (基因上有但未表达的)
        if g.base.0 != g.base.1 { carriers.append("蓝") }
        if g.isHetTurq && !expr.showTurq { carriers.append("松石") }
        if g.isHomoTurq && !expr.showTurq { carriers.append("松石") }
        if g.isHetViolet && !expr.showViolet { carriers.append("紫罗兰") }
        if g.isHetIsa && !expr.showIsa { carriers.append("伊莎") }
        if g.isHomoIsa && !expr.showIsa { carriers.append("伊莎") }
        
        // Z连锁携带
        if g.isMale {
            let hasAus = g.zAusF.0 == "aus" || g.zAusF.1 == "aus"
            let homAus = g.zAusF.0 == "aus" && g.zAusF.1 == "aus"
            if hasAus && !homAus { carriers.append("澳桂") }
            
            let hasAm = g.zAmF.0 == "am" || g.zAmF.1 == "am"
            let homAm = g.zAmF.0 == "am" && g.zAmF.1 == "am"
            if hasAm && !homAm { carriers.append("美桂") }
        }
        
        // Z连锁表型
        let showAusF = g.isMale ? (g.zAusF.0 == "aus" && g.zAusF.1 == "aus") : (g.zAusF.0 == "aus")
        let showAmF = g.isMale ? (g.zAmF.0 == "am" && g.zAmF.1 == "am") : (g.zAmF.0 == "am")
        
        // 构建表型名称 (按优先级)
        var name = ""
        
        // 伊莎系列优先 (isa表达)
        if expr.showIsa && isBlue {
            if expr.showViolet && expr.showTurq { name = "紫松石面伊" }
            else if expr.showViolet { name = "紫面伊" }
            else if expr.showTurq { name = "松石面伊" }
            else { name = "蓝面伊" }
        }
        // 薰衣草 (美桂+闪)
        else if showAmF && expr.showSpark && isBlue {
            if expr.showViolet { name = "紫薰衣草" }
            else if expr.showTurq { name = "松石薰衣草" }
            else { name = "蓝薰衣草" }
        }
        // 澳闪
        else if showAusF && expr.showSpark {
            name = "澳闪"
        }
        // 澳桂
        else if showAusF {
            name = "澳桂"
        }
        // 美桂
        else if showAmF {
            name = "美桂"
        }
        // 闪光系列
        else if expr.showSpark {
            if expr.showViolet && expr.showTurq { name = "紫松石闪" }
            else if expr.showViolet { name = "紫闪" }
            else if expr.showTurq { name = "松石蓝闪" }
            else if isBlue { name = "蓝闪" }
            else { name = "绿闪" }
        }
        // 紫罗兰+松石
        else if expr.showViolet && expr.showTurq && isBlue {
            name = "紫带松石"
        }
        // 紫罗兰
        else if expr.showViolet && isBlue {
            name = "紫罗兰"
        }
        // 松石
        else if expr.showTurq && isBlue {
            name = "松石蓝"
        }
        // 蓝色系
        else if isBlue {
            name = "蓝桃"
        }
        // 绿色系
        else {
            name = "绿桃"
        }
        
        // 派特后缀
        if expr.showPied { name += "派特" }
        
        return (name, carriers)
    }
    
    // 主计算函数 - 使用穿透率模型
    // 步骤: 1. Punnett得到基因型 2. 对每个基因型用穿透率计算表型概率
    private func computeOffspring(father: String, mother: String) -> [Offspring] {
        let fatherG = colorToGenotype(father, isMale: true)
        let motherG = colorToGenotype(mother, isMale: false)
        let fGametes = generateGametes(fatherG)
        let mGametes = generateGametes(motherG)
        
        var results: [String: Offspring] = [:]
        
        for fg in fGametes {
            for mg in mGametes {
                guard let child = combine(fg, mg) else { continue }
                let genotypeProb = fg.prob * mg.prob
                
                // 对这个基因型，计算所有可能的表型表达组合
                let expressions = calculatePhenoExpressions(child)
                
                for expr in expressions {
                    let (pheno, carriers) = expressionToPheno(expr, child)
                    let totalProb = genotypeProb * expr.probability
                    let key = "\(pheno)-\(child.isMale)-\(carriers.sorted())"
                    
                    if var existing = results[key] {
                        existing.probability += totalProb
                        results[key] = existing
                    } else {
                        results[key] = Offspring(phenotype: pheno, isMale: child.isMale, carriers: carriers, probability: totalProb)
                    }
                }
            }
        }
        
        // 过滤掉概率太小的结果，并排序
        return Array(results.values)
            .filter { $0.probability > 0.005 }  // 只显示>0.5%的结果
            .sorted { $0.probability > $1.probability }
    }
    
    // 格式化输出 - 使用遗传计算系统
    private func getBreedingResult(father: String, mother: String) -> BreedingResult {
        let offspring = computeOffspring(father: father, mother: mother)
        
        var maleResults: [String] = []
        var femaleResults: [String] = []
        
        for o in offspring {
            let probStr = String(format: "%.1f%%", o.probability * 100)
            var desc = "\(probStr) \(o.phenotype)"
            if !o.carriers.isEmpty {
                desc += "(携带\(o.carriers.joined(separator: "+")))"
            }
            
            if o.isMale {
                maleResults.append(desc)
            } else {
                femaleResults.append(desc)
            }
        }
        
        if maleResults.isEmpty { maleResults = ["无"] }
        if femaleResults.isEmpty { femaleResults = ["无"] }
        
        return BreedingResult(male: maleResults, female: femaleResults)
    }
    
    private func colorForName(_ name: String) -> Color {
        if name.contains("绿") && !name.contains("蓝") && !name.contains("黄") {
            return Color.green
        } else if name.contains("蓝") {
            return Color.blue
        } else if name.contains("黄") || name.contains("Lutino") {
            return Color.yellow
        } else if name.contains("紫") || name.contains("Violet") {
            return Color.purple
        } else if name.contains("白") || name.contains("Albino") {
            return Color.white
        } else if name.contains("肉桂") || name.contains("桃") || name.contains("澳") {
            return Color.orange
        } else if name.contains("橄榄") {
            return Color(red: 0.5, green: 0.5, blue: 0.0)
        } else if name.contains("钴") {
            return Color(red: 0.0, green: 0.3, blue: 0.7)
        } else if name.contains("闪") {
            return Color(red: 0.9, green: 0.4, blue: 0.4)
        } else if name.contains("伊莎") || name.contains("薰衣草") {
            return Color(red: 0.7, green: 0.5, blue: 0.8)
        } else {
            return Color.gray
        }
    }
    
    // 旧的预测函数（保留以防编译错误，但不再使用）
    private func predictOffspring(father: String, mother: String) -> [(color: String, probability: String, gender: String, note: String)] {
        var results: [(color: String, probability: String, gender: String, note: String)] = []
        
        // ==================== 绿色系配对 ====================
        // 绿桃 × 绿桃
        if father == "绿桃" && mother == "绿桃" {
            results = [("绿桃", "100%", "公母均可", "纯绿配对")]
        }
        else if father == "绿金顶" && mother == "绿金顶" {
            results = [("绿金顶", "100%", "公母均可", "纯金顶配对")]
        }
        else if father == "绿银顶" && mother == "绿银顶" {
            results = [("绿银顶", "100%", "公母均可", "纯银顶配对")]
        }
        else if (father == "绿桃" && mother == "绿金顶") || (father == "绿金顶" && mother == "绿桃") {
            results = [("绿桃(携带金顶)", "100%", "公母均可", "外观绿色，携带金顶基因")]
        }
        else if (father == "绿桃" && mother == "绿银顶") || (father == "绿银顶" && mother == "绿桃") {
            results = [("绿桃(携带银顶)", "100%", "公母均可", "外观绿色，携带银顶基因")]
        }
        else if (father == "绿金顶" && mother == "绿银顶") || (father == "绿银顶" && mother == "绿金顶") {
            results = [("松石蓝银", "100%", "公母均可", "金顶+银顶共显性")]
        }
        
        // ==================== 蓝色系配对 ====================
        else if father == "蓝桃" && mother == "蓝桃" {
            results = [("蓝桃", "100%", "公母均可", "纯蓝配对")]
        }
        else if father == "蓝金顶" && mother == "蓝金顶" {
            results = [("蓝金顶", "100%", "公母均可", "纯蓝金顶配对")]
        }
        else if father == "蓝银顶" && mother == "蓝银顶" {
            results = [("蓝银顶", "100%", "公母均可", "纯蓝银顶配对")]
        }
        else if father == "松石蓝银" && mother == "松石蓝银" {
            results = [("松石蓝银", "100%", "公母均可", "纯松石蓝银配对")]
        }
        
        // ==================== 绿×蓝配对（蓝为隐性） ====================
        else if (father == "绿桃" && mother == "蓝桃") || (father == "蓝桃" && mother == "绿桃") {
            results = [("绿桃(携带蓝)", "100%", "公母均可", "外观绿色，全部携带蓝色基因")]
        }
        else if (father == "绿金顶" && mother == "蓝桃") || (father == "蓝桃" && mother == "绿金顶") {
            results = [("绿金顶(携带蓝)", "100%", "公母均可", "外观绿金顶，携带蓝色基因")]
        }
        else if (father == "绿银顶" && mother == "蓝桃") || (father == "蓝桃" && mother == "绿银顶") {
            results = [("绿银顶(携带蓝)", "100%", "公母均可", "外观绿银顶，携带蓝色基因")]
        }
        else if (father == "绿桃" && mother == "蓝银顶") || (father == "蓝银顶" && mother == "绿桃") {
            results = [("绿桃(携带蓝银顶)", "100%", "公母均可", "外观绿色，携带蓝银顶基因")]
        }
        
        // ==================== 帽子系配对（隐性遗传） ====================
        // 紫罗兰、墨银为隐性基因，绿桃为显性
        else if father == "紫罗兰" && mother == "紫罗兰" {
            results = [
                ("紫罗兰", "100%", "公母均可", "双方都是隐性纯合，后代全为紫罗兰")
            ]
        }
        else if (father == "紫罗兰" && mother == "绿桃") || (father == "绿桃" && mother == "紫罗兰") {
            // 绿桃(显性纯合) × 紫罗兰(隐性纯合) = 绿桃(携带紫罗兰)
            results = [
                ("绿桃(携带紫罗兰)", "99%", "公母均可", "外观绿色，携带紫罗兰隐性基因"),
                ("紫罗兰", "1%", "公母均可", "极少数情况")
            ]
        }
        else if (father == "紫罗兰" && mother == "蓝桃") || (father == "蓝桃" && mother == "紫罗兰") {
            results = [
                ("绿桃(携带紫罗兰+蓝)", "99%", "公母均可", "外观绿色，携带双隐性基因"),
                ("紫罗兰(携带蓝)", "1%", "公母均可", "极少数情况")
            ]
        }
        else if father == "墨银" && mother == "墨银" {
            results = [
                ("墨银", "100%", "公母均可", "双方都是隐性纯合，后代全为墨银")
            ]
        }
        else if (father == "墨银" && mother == "绿桃") || (father == "绿桃" && mother == "墨银") {
            results = [
                ("绿桃(携带墨银)", "99%", "公母均可", "外观绿色，携带墨银隐性基因"),
                ("墨银", "1%", "公母均可", "极少数情况")
            ]
        }
        else if (father == "紫罗兰" && mother == "墨银") || (father == "墨银" && mother == "紫罗兰") {
            results = [
                ("绿桃(携带紫罗兰+墨银)", "99%", "公母均可", "外观绿色，携带双隐性基因"),
                ("紫罗兰", "0.5%", "公母均可", "极少数"),
                ("墨银", "0.5%", "公母均可", "极少数")
            ]
        }
        
        // ==================== 澳桂系配对（伴性遗传） ====================
        else if father == "红头澳桂" && mother == "红头澳桂" {
            results = [("红头澳桂", "100%", "公母均可", "纯澳桂配对")]
        }
        else if father == "金头澳桂" && mother == "金头澳桂" {
            results = [("金头澳桂", "100%", "公母均可", "纯金头澳桂配对")]
        }
        else if father == "白头澳桂" && mother == "白头澳桂" {
            results = [("白头澳桂", "100%", "公母均可", "纯白头澳桂配对")]
        }
        else if father == "苹果绿澳桂" && mother == "苹果绿澳桂" {
            results = [("苹果绿澳桂", "100%", "公母均可", "纯苹果绿澳桂配对")]
        }
        else if father == "薄荷绿澳桂" && mother == "薄荷绿澳桂" {
            results = [("薄荷绿澳桂", "100%", "公母均可", "纯薄荷绿澳桂配对")]
        }
        // 澳桂公 × 绿桃母（伴性遗传：公鸟携带，母鸟不携带）
        else if father == "红头澳桂" && mother == "绿桃" {
            results = [
                ("绿桃(携带澳桂)", "100%", "仅公鸟", "公鸟全部携带澳桂基因"),
                ("绿桃", "100%", "仅母鸟", "母鸟不携带")
            ]
        }
        else if father == "金头澳桂" && mother == "绿桃" {
            results = [
                ("绿桃(携带澳桂)", "100%", "仅公鸟", "公鸟全部携带澳桂基因"),
                ("绿桃", "100%", "仅母鸟", "母鸟不携带")
            ]
        }
        else if father == "苹果绿澳桂" && mother == "绿桃" {
            results = [
                ("绿桃(携带澳桂)", "100%", "仅公鸟", "公鸟全部携带澳桂基因"),
                ("绿桃", "100%", "仅母鸟", "母鸟不携带")
            ]
        }
        // 绿桃公 × 澳桂母（伴性遗传：公鸟携带，母鸟表现）
        else if father == "绿桃" && mother == "红头澳桂" {
            results = [
                ("绿桃(携带澳桂)", "50%", "仅公鸟", ""),
                ("红头澳桂", "50%", "仅母鸟", "伴性遗传，母鸟直接表现")
            ]
        }
        else if father == "绿桃" && mother == "金头澳桂" {
            results = [
                ("绿桃(携带澳桂)", "50%", "仅公鸟", ""),
                ("金头澳桂", "50%", "仅母鸟", "伴性遗传，母鸟直接表现")
            ]
        }
        else if father == "绿桃" && mother == "苹果绿澳桂" {
            results = [
                ("绿桃(携带澳桂)", "50%", "仅公鸟", ""),
                ("苹果绿澳桂", "50%", "仅母鸟", "伴性遗传，母鸟直接表现")
            ]
        }
        
        // ==================== 美桂系配对（伴性遗传） ====================
        else if father == "红头美桂" && mother == "红头美桂" {
            results = [("红头美桂", "100%", "公母均可", "纯美桂配对")]
        }
        else if father == "金头美桂" && mother == "金头美桂" {
            results = [("金头美桂", "100%", "公母均可", "纯金头美桂配对")]
        }
        else if father == "白头美桂" && mother == "白头美桂" {
            results = [("白头美桂", "100%", "公母均可", "纯白头美桂配对")]
        }
        else if father == "红头美桂" && mother == "绿桃" {
            results = [
                ("绿桃(携带美桂)", "100%", "仅公鸟", "公鸟全部携带美桂基因"),
                ("绿桃", "100%", "仅母鸟", "母鸟不携带")
            ]
        }
        else if father == "绿桃" && mother == "红头美桂" {
            results = [
                ("绿桃(携带美桂)", "50%", "仅公鸟", ""),
                ("红头美桂", "50%", "仅母鸟", "伴性遗传，母鸟直接表现")
            ]
        }
        
        // ==================== 闪光系配对（伴性遗传） ====================
        else if father == "绿闪" && mother == "绿闪" {
            results = [("绿闪", "100%", "公母均可", "纯绿闪配对")]
        }
        else if father == "蓝闪" && mother == "蓝闪" {
            results = [("蓝闪", "100%", "公母均可", "纯蓝闪配对")]
        }
        else if father == "紫闪" && mother == "紫闪" {
            results = [("紫闪", "100%", "公母均可", "纯紫闪配对")]
        }
        else if father == "松石蓝闪" && mother == "松石蓝闪" {
            results = [("松石蓝闪", "100%", "公母均可", "纯松石蓝闪配对")]
        }
        else if father == "红头绿闪" && mother == "红头绿闪" {
            results = [("红头绿闪", "100%", "公母均可", "纯红头绿闪配对")]
        }
        else if father == "金头绿闪" && mother == "金头绿闪" {
            results = [("金头绿闪", "100%", "公母均可", "纯金头绿闪配对")]
        }
        else if father == "绿闪" && mother == "绿桃" {
            results = [
                ("绿桃(携带闪光)", "100%", "仅公鸟", "公鸟全部携带闪光基因"),
                ("绿桃", "100%", "仅母鸟", "母鸟不携带")
            ]
        }
        else if father == "绿桃" && mother == "绿闪" {
            results = [
                ("绿桃(携带闪光)", "50%", "仅公鸟", ""),
                ("绿闪", "50%", "仅母鸟", "伴性遗传，母鸟直接表现")
            ]
        }
        else if father == "蓝闪" && mother == "蓝桃" {
            results = [
                ("蓝桃(携带闪光)", "100%", "仅公鸟", "公鸟全部携带闪光基因"),
                ("蓝桃", "100%", "仅母鸟", "母鸟不携带")
            ]
        }
        else if father == "蓝桃" && mother == "蓝闪" {
            results = [
                ("蓝桃(携带闪光)", "50%", "仅公鸟", ""),
                ("蓝闪", "50%", "仅母鸟", "伴性遗传，母鸟直接表现")
            ]
        }
        
        // ==================== 澳桂闪光系配对 ====================
        else if father == "红头澳闪" && mother == "红头澳闪" {
            results = [("红头澳闪", "100%", "公母均可", "纯红头澳闪配对")]
        }
        else if father == "金头澳闪" && mother == "金头澳闪" {
            results = [("金头澳闪", "100%", "公母均可", "纯金头澳闪配对")]
        }
        else if father == "黄澳闪" && mother == "黄澳闪" {
            results = [("黄澳闪", "100%", "公母均可", "纯黄澳闪配对")]
        }
        else if father == "苹果绿澳闪" && mother == "苹果绿澳闪" {
            results = [("苹果绿澳闪", "100%", "公母均可", "纯苹果绿澳闪配对")]
        }
        else if father == "薄荷绿澳闪" && mother == "薄荷绿澳闪" {
            results = [("薄荷绿澳闪", "100%", "公母均可", "纯薄荷绿澳闪配对")]
        }
        
        // ==================== 伊莎系配对 ====================
        else if father == "紫伊莎" && mother == "紫伊莎" {
            results = [("紫伊莎", "100%", "公母均可", "纯紫伊莎配对")]
        }
        else if father == "蓝伊莎" && mother == "蓝伊莎" {
            results = [("蓝伊莎", "100%", "公母均可", "纯蓝伊莎配对")]
        }
        else if father == "松石伊莎" && mother == "松石伊莎" {
            results = [("松石伊莎", "100%", "公母均可", "纯松石伊莎配对")]
        }
        
        // ==================== 薰衣草系配对 ====================
        else if father == "紫薰衣草" && mother == "紫薰衣草" {
            results = [("紫薰衣草", "100%", "公母均可", "纯紫薰衣草配对")]
        }
        else if father == "蓝薰衣草" && mother == "蓝薰衣草" {
            results = [("蓝薰衣草", "100%", "公母均可", "纯蓝薰衣草配对")]
        }
        else if father == "松石薰衣草" && mother == "松石薰衣草" {
            results = [("松石薰衣草", "100%", "公母均可", "纯松石薰衣草配对")]
        }
        
        // ==================== 派特系配对（显性遗传） ====================
        else if father == "绿派特" && mother == "绿派特" {
            results = [
                ("绿派特(双因子)", "25%", "公母均可", "派度更高"),
                ("绿派特(单因子)", "50%", "公母均可", ""),
                ("绿桃", "25%", "公母均可", "无派特基因")
            ]
        }
        else if father == "蓝派特" && mother == "蓝派特" {
            results = [
                ("蓝派特(双因子)", "25%", "公母均可", "派度更高"),
                ("蓝派特(单因子)", "50%", "公母均可", ""),
                ("蓝桃", "25%", "公母均可", "无派特基因")
            ]
        }
        else if (father == "绿派特" && mother == "绿桃") || (father == "绿桃" && mother == "绿派特") {
            results = [
                ("绿派特(单因子)", "50%", "公母均可", ""),
                ("绿桃", "50%", "公母均可", "")
            ]
        }
        else if (father == "蓝派特" && mother == "蓝桃") || (father == "蓝桃" && mother == "蓝派特") {
            results = [
                ("蓝派特(单因子)", "50%", "公母均可", ""),
                ("蓝桃", "50%", "公母均可", "")
            ]
        }
        else if (father == "绿派特" && mother == "蓝桃") || (father == "蓝桃" && mother == "绿派特") {
            results = [
                ("绿派特(单因子,携带蓝)", "50%", "公母均可", ""),
                ("绿桃(携带蓝)", "50%", "公母均可", "")
            ]
        }
        
        // ==================== 跨系配对 ====================
        // 绿闪 × 澳桂（双伴性基因）
        else if father == "绿闪" && mother == "红头澳桂" {
            results = [
                ("绿桃(携带闪光+澳桂)", "50%", "仅公鸟", "携带双伴性基因"),
                ("绿闪", "25%", "仅母鸟", ""),
                ("红头澳桂", "25%", "仅母鸟", "")
            ]
        }
        else if father == "红头澳桂" && mother == "绿闪" {
            results = [
                ("绿桃(携带闪光+澳桂)", "50%", "仅公鸟", "携带双伴性基因"),
                ("绿闪", "25%", "仅母鸟", ""),
                ("红头澳桂", "25%", "仅母鸟", "")
            ]
        }
        // 紫罗兰 × 蓝银顶
        else if (father == "紫罗兰" && mother == "蓝银顶") || (father == "蓝银顶" && mother == "紫罗兰") {
            results = [
                ("紫罗兰(单因子,携带蓝银顶)", "50%", "公母均可", ""),
                ("绿桃(携带蓝银顶)", "50%", "公母均可", "")
            ]
        }
        
        // ==================== 紫罗兰 × 伊莎系配对 ====================
        else if (father == "紫罗兰" && mother == "紫伊莎") || (father == "紫伊莎" && mother == "紫罗兰") {
            // 紫罗兰(半显性) × 紫伊莎(澳桂+闪光+紫罗兰复合)
            results = [
                ("紫罗兰(单因子,携带澳桂+闪光)", "25%", "公母均可", ""),
                ("绿桃(携带澳桂+闪光)", "25%", "公母均可", ""),
                ("紫伊莎", "25%", "公母均可", "需要双伴性基因表现"),
                ("紫罗兰闪光(携带澳桂)", "25%", "公母均可", "")
            ]
        }
        else if (father == "紫罗兰" && mother == "蓝伊莎") || (father == "蓝伊莎" && mother == "紫罗兰") {
            results = [
                ("紫罗兰(单因子,携带蓝+澳桂+闪光)", "25%", "公母均可", ""),
                ("绿桃(携带蓝+澳桂+闪光)", "25%", "公母均可", ""),
                ("紫罗兰蓝(携带澳桂+闪光)", "25%", "公母均可", ""),
                ("蓝桃(携带澳桂+闪光)", "25%", "公母均可", "")
            ]
        }
        else if (father == "紫罗兰" && mother == "松石伊莎") || (father == "松石伊莎" && mother == "紫罗兰") {
            results = [
                ("紫罗兰(单因子,携带松石+澳桂+闪光)", "25%", "公母均可", ""),
                ("绿桃(携带松石+澳桂+闪光)", "25%", "公母均可", ""),
                ("紫罗兰松石(携带澳桂+闪光)", "25%", "公母均可", ""),
                ("松石蓝银(携带澳桂+闪光)", "25%", "公母均可", "")
            ]
        }
        
        // ==================== 紫罗兰 × 薰衣草系配对 ====================
        else if (father == "紫罗兰" && mother == "紫薰衣草") || (father == "紫薰衣草" && mother == "紫罗兰") {
            results = [
                ("紫罗兰(双因子,携带美桂+闪光)", "12.5%", "公母均可", "颜色最深"),
                ("紫罗兰(单因子,携带美桂+闪光)", "25%", "公母均可", ""),
                ("紫薰衣草", "25%", "公母均可", ""),
                ("紫闪(携带美桂)", "25%", "公母均可", ""),
                ("绿桃(携带美桂+闪光)", "12.5%", "公母均可", "")
            ]
        }
        else if (father == "紫罗兰" && mother == "蓝薰衣草") || (father == "蓝薰衣草" && mother == "紫罗兰") {
            results = [
                ("紫罗兰(单因子,携带蓝+美桂+闪光)", "25%", "公母均可", ""),
                ("绿桃(携带蓝+美桂+闪光)", "25%", "公母均可", ""),
                ("紫罗兰蓝(携带美桂+闪光)", "25%", "公母均可", ""),
                ("蓝桃(携带美桂+闪光)", "25%", "公母均可", "")
            ]
        }
        else if (father == "紫罗兰" && mother == "松石薰衣草") || (father == "松石薰衣草" && mother == "紫罗兰") {
            results = [
                ("紫罗兰(单因子,携带松石+美桂+闪光)", "25%", "公母均可", ""),
                ("绿桃(携带松石+美桂+闪光)", "25%", "公母均可", ""),
                ("紫罗兰松石(携带美桂+闪光)", "25%", "公母均可", ""),
                ("松石蓝银(携带美桂+闪光)", "25%", "公母均可", "")
            ]
        }
        
        // ==================== 紫罗兰 × 闪光系配对 ====================
        else if (father == "紫罗兰" && mother == "绿闪") {
            results = [
                ("紫罗兰(单因子,携带闪光)", "25%", "仅公鸟", ""),
                ("绿桃(携带闪光)", "25%", "仅公鸟", ""),
                ("紫闪", "25%", "仅母鸟", ""),
                ("绿闪", "25%", "仅母鸟", "")
            ]
        }
        else if (father == "绿闪" && mother == "紫罗兰") {
            results = [
                ("紫罗兰(单因子,携带闪光)", "50%", "仅公鸟", "公鸟全部携带闪光"),
                ("绿桃(携带闪光)", "50%", "仅公鸟", ""),
                ("紫罗兰(单因子)", "50%", "仅母鸟", "母鸟不携带闪光"),
                ("绿桃", "50%", "仅母鸟", "")
            ]
        }
        else if (father == "紫罗兰" && mother == "紫闪") {
            results = [
                ("紫罗兰(双因子,携带闪光)", "12.5%", "仅公鸟", ""),
                ("紫罗兰(单因子,携带闪光)", "25%", "仅公鸟", ""),
                ("绿桃(携带闪光)", "12.5%", "仅公鸟", ""),
                ("紫闪(双因子)", "12.5%", "仅母鸟", ""),
                ("紫闪(单因子)", "25%", "仅母鸟", ""),
                ("绿闪", "12.5%", "仅母鸟", "")
            ]
        }
        else if (father == "紫罗兰" && mother == "蓝闪") {
            results = [
                ("紫罗兰(单因子,携带蓝+闪光)", "25%", "仅公鸟", ""),
                ("绿桃(携带蓝+闪光)", "25%", "仅公鸟", ""),
                ("紫闪(携带蓝)", "25%", "仅母鸟", ""),
                ("蓝闪", "25%", "仅母鸟", "")
            ]
        }
        else if (father == "紫罗兰" && mother == "松石蓝闪") {
            results = [
                ("紫罗兰(单因子,携带松石+闪光)", "25%", "仅公鸟", ""),
                ("绿桃(携带松石+闪光)", "25%", "仅公鸟", ""),
                ("紫闪(携带松石)", "25%", "仅母鸟", ""),
                ("松石蓝闪", "25%", "仅母鸟", "")
            ]
        }
        
        // ==================== 紫罗兰 × 澳桂系配对 ====================
        else if (father == "紫罗兰" && mother == "红头澳桂") {
            results = [
                ("紫罗兰(单因子,携带澳桂)", "25%", "仅公鸟", ""),
                ("绿桃(携带澳桂)", "25%", "仅公鸟", ""),
                ("紫罗兰澳桂", "25%", "仅母鸟", ""),
                ("红头澳桂", "25%", "仅母鸟", "")
            ]
        }
        else if (father == "红头澳桂" && mother == "紫罗兰") {
            results = [
                ("紫罗兰(单因子,携带澳桂)", "50%", "仅公鸟", "公鸟全部携带澳桂"),
                ("绿桃(携带澳桂)", "50%", "仅公鸟", ""),
                ("紫罗兰(单因子)", "50%", "仅母鸟", "母鸟不携带澳桂"),
                ("绿桃", "50%", "仅母鸟", "")
            ]
        }
        else if (father == "紫罗兰" && mother == "苹果绿澳桂") {
            results = [
                ("紫罗兰(单因子,携带澳桂+金顶)", "25%", "仅公鸟", ""),
                ("绿桃(携带澳桂+金顶)", "25%", "仅公鸟", ""),
                ("紫罗兰苹果绿澳桂", "25%", "仅母鸟", ""),
                ("苹果绿澳桂", "25%", "仅母鸟", "")
            ]
        }
        
        // ==================== 墨银 × 各系配对 ====================
        else if (father == "墨银" && mother == "蓝桃") || (father == "蓝桃" && mother == "墨银") {
            results = [
                ("墨银(单因子,携带蓝)", "50%", "公母均可", ""),
                ("绿桃(携带蓝)", "50%", "公母均可", "")
            ]
        }
        else if (father == "墨银" && mother == "紫伊莎") || (father == "紫伊莎" && mother == "墨银") {
            results = [
                ("墨银(单因子,携带澳桂+闪光)", "25%", "公母均可", ""),
                ("绿桃(携带澳桂+闪光)", "25%", "公母均可", ""),
                ("墨银伊莎", "25%", "公母均可", ""),
                ("紫伊莎(携带墨银)", "25%", "公母均可", "")
            ]
        }
        
        // ==================== 伊莎系 × 薰衣草系配对 ====================
        else if (father == "紫伊莎" && mother == "紫薰衣草") || (father == "紫薰衣草" && mother == "紫伊莎") {
            results = [
                ("紫伊莎", "25%", "公母均可", "澳桂+闪光+紫罗兰"),
                ("紫薰衣草", "25%", "公母均可", "美桂+闪光+紫罗兰"),
                ("紫闪(携带澳桂+美桂)", "25%", "公母均可", ""),
                ("紫罗兰(携带澳桂+美桂+闪光)", "25%", "公母均可", "")
            ]
        }
        
        // ==================== 闪光系 × 澳桂系配对 ====================
        else if (father == "蓝闪" && mother == "红头澳桂") || (father == "红头澳桂" && mother == "蓝闪") {
            results = [
                ("绿桃(携带蓝+闪光+澳桂)", "25%", "仅公鸟", "携带多重基因"),
                ("蓝桃(携带闪光+澳桂)", "25%", "仅公鸟", ""),
                ("蓝闪", "12.5%", "仅母鸟", ""),
                ("绿闪(携带蓝)", "12.5%", "仅母鸟", ""),
                ("红头澳桂", "12.5%", "仅母鸟", ""),
                ("蓝澳桂", "12.5%", "仅母鸟", "")
            ]
        }
        
        // ==================== 派特系 × 其他系配对 ====================
        else if (father == "绿派特" && mother == "紫罗兰") || (father == "紫罗兰" && mother == "绿派特") {
            results = [
                ("紫罗兰派特(单因子)", "25%", "公母均可", ""),
                ("绿派特(单因子)", "25%", "公母均可", ""),
                ("紫罗兰(单因子)", "25%", "公母均可", ""),
                ("绿桃", "25%", "公母均可", "")
            ]
        }
        else if (father == "蓝派特" && mother == "紫罗兰") || (father == "紫罗兰" && mother == "蓝派特") {
            results = [
                ("紫罗兰派特(单因子,携带蓝)", "25%", "公母均可", ""),
                ("绿派特(单因子,携带蓝)", "25%", "公母均可", ""),
                ("紫罗兰(单因子,携带蓝)", "25%", "公母均可", ""),
                ("绿桃(携带蓝)", "25%", "公母均可", "")
            ]
        }
        else if (father == "绿派特" && mother == "绿闪") {
            results = [
                ("绿派特(单因子,携带闪光)", "25%", "仅公鸟", ""),
                ("绿桃(携带闪光)", "25%", "仅公鸟", ""),
                ("绿派特闪光", "25%", "仅母鸟", "派特+闪光"),
                ("绿闪", "25%", "仅母鸟", "")
            ]
        }
        
        // ==================== 默认结果（智能分析） ====================
        if results.isEmpty {
            results = generateSmartPrediction(father: father, mother: mother)
        }
        
        return results
    }
    
    // 智能预测（根据基因类型分析）
    private func generateSmartPrediction(father: String, mother: String) -> [(color: String, probability: String, gender: String, note: String)] {
        var results: [(color: String, probability: String, gender: String, note: String)] = []
        
        let fatherGenes = analyzeGenes(father)
        let motherGenes = analyzeGenes(mother)
        
        // 判断是否涉及伴性遗传（澳桂、美桂、闪光）
        let fatherHasSexLinked = fatherGenes.contains("澳桂") || fatherGenes.contains("美桂") || fatherGenes.contains("闪光")
        let motherHasSexLinked = motherGenes.contains("澳桂") || motherGenes.contains("美桂") || motherGenes.contains("闪光")
        
        // 判断是否涉及隐性遗传（紫罗兰、墨银、蓝色系等）
        let fatherHasRecessive = fatherGenes.contains("紫罗兰") || fatherGenes.contains("墨银") || fatherGenes.contains("蓝") || fatherGenes.contains("松石")
        let motherHasRecessive = motherGenes.contains("紫罗兰") || motherGenes.contains("墨银") || motherGenes.contains("蓝") || motherGenes.contains("松石")
        
        if fatherHasSexLinked && motherHasSexLinked {
            // 双方都有伴性基因
            results = [
                ("\(father)型后代", "25%", "公母均可", "双亲伴性基因组合"),
                ("\(mother)型后代", "25%", "公母均可", ""),
                ("混合伴性后代", "25%", "仅公鸟", "公鸟携带双方伴性基因"),
                ("单一伴性后代", "25%", "仅母鸟", "母鸟表现其中一种")
            ]
        } else if fatherHasSexLinked && !motherHasSexLinked {
            // 父方有伴性基因(表现型，即双基因XX) × 母方无伴性基因
            // 伴性遗传：公鸟XX，母鸟XY
            // 公鸟后代从父亲得X(有基因)，从母亲得X(无基因) → 携带不表现
            // 母鸟后代从父亲得X(有基因)，从母亲得Y → 表现！
            let sexLinkedGenes = fatherGenes.filter { ["澳桂", "美桂", "闪光"].contains($0) }.joined(separator: "+")
            
            results = [
                ("\(mother)(携带\(sexLinkedGenes))", "100%", "仅公鸟", "公鸟全部携带父方伴性基因，但不表现"),
                ("\(father)", "100%", "仅母鸟", "母鸟全部表现父方伴性基因")
            ]
        } else if !fatherHasSexLinked && motherHasSexLinked {
            // 父方无伴性基因 × 母方有伴性基因
            // 伴性遗传：公鸟XX，母鸟XY
            // 公鸟后代从母亲得X(有基因)，从父亲得X(无基因) → 携带不表现
            // 母鸟后代从父亲得X(无基因)，从母亲得Y → 不携带伴性基因
            let sexLinkedGenes = motherGenes.filter { ["澳桂", "美桂", "闪光"].contains($0) }.joined(separator: "+")
            let recessiveGenes = motherGenes.filter { ["蓝", "松石", "金顶", "银顶"].contains($0) }
            
            // 隐性基因（如蓝/松石）：后代都会携带但不表现
            var sonDesc = "\(father)(携带\(sexLinkedGenes)"
            var daughterDesc = "\(father)"
            
            if !recessiveGenes.isEmpty {
                let recessiveStr = recessiveGenes.joined(separator: "+")
                sonDesc += "+\(recessiveStr)"
                daughterDesc += "(携带\(recessiveStr))"
            }
            sonDesc += ")"
            
            results = [
                (sonDesc, "100%", "仅公鸟", "公鸟携带母方伴性基因但不表现"),
                (daughterDesc, "100%", "仅母鸟", "母鸟不携带伴性基因，只携带隐性基因")
            ]
        } else if fatherHasRecessive && motherHasRecessive {
            // 双方都有隐性基因
            let fatherRec = fatherGenes.filter { ["紫罗兰", "墨银", "蓝", "松石"].contains($0) }
            let motherRec = motherGenes.filter { ["紫罗兰", "墨银", "蓝", "松石"].contains($0) }
            
            if fatherRec == motherRec {
                // 相同隐性基因
                results = [
                    ("\(fatherRec.first ?? "隐性")后代", "100%", "公母均可", "双方都是相同隐性纯合，后代全部表现")
                ]
            } else {
                // 不同隐性基因
                results = [
                    ("绿桃(携带双隐性)", "99%", "公母均可", "外观绿色，携带双方隐性基因"),
                    ("\(fatherRec.first ?? "")或\(motherRec.first ?? "")", "1%", "公母均可", "极少数表现其中一种")
                ]
            }
        } else if fatherHasRecessive || motherHasRecessive {
            // 单方有隐性基因（显性×隐性）
            let recessiveGene = fatherHasRecessive ? fatherGenes.filter { ["紫罗兰", "墨银", "蓝", "松石"].contains($0) }.first ?? "隐性" : motherGenes.filter { ["紫罗兰", "墨银", "蓝", "松石"].contains($0) }.first ?? "隐性"
            results = [
                ("绿桃(携带\(recessiveGene))", "99%", "公母均可", "外观绿色，携带隐性基因"),
                ("\(recessiveGene)", "1%", "公母均可", "极少数情况")
            ]
        } else {
            // 都是绿色系显性
            results = [
                ("绿桃", "100%", "公母均可", "双方都是显性纯合，后代全为绿桃")
            ]
        }
        
        return results
    }
    
    // 分析颜色包含的基因
    private func analyzeGenes(_ color: String) -> [String] {
        var genes: [String] = []
        
        if color.contains("澳桂") || color.contains("澳闪") || color.contains("伊莎") { genes.append("澳桂") }
        if color.contains("美桂") || color.contains("薰衣草") { genes.append("美桂") }
        if color.contains("闪") || color.contains("伊莎") || color.contains("薰衣草") { genes.append("闪光") }
        if color.contains("紫罗兰") || color.contains("紫伊莎") || color.contains("紫薰衣草") || color.contains("紫闪") { genes.append("紫罗兰") }
        if color.contains("墨银") { genes.append("墨银") }
        if color.contains("蓝") || color.contains("松石") { genes.append("蓝") }
        if color.contains("派特") { genes.append("派特") }
        if color.contains("金顶") || color.contains("苹果绿") { genes.append("金顶") }
        if color.contains("银顶") || color.contains("薄荷绿") { genes.append("银顶") }
        
        return genes
    }
    
    // 获取基础色系
    private func getBaseColor(_ color: String) -> String {
        if color.contains("蓝") || color.contains("松石") {
            return "蓝"
        } else if color.contains("紫") {
            return "紫"
        } else {
            return "绿"
        }
    }
}

// MARK: - 广场页面
struct ForumView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var locationService = LocationService.shared
    @ObservedObject var socialService = SocialService.shared
    @State private var selectedTab = 2
    @State private var showCreatePost = false
    @State private var showLoginAlert = false
    @State private var showSearch = false
    @State private var showLocationPicker = false
    @State private var searchText = ""
    @State private var selectedSort = "综合排序"
    @State private var selectedRange = "附近" // 附近/同城/全国 - 仅影响"附近"标签页
    @State private var isLoading = false
    
    // 帖子数据
    @State private var allPosts: [ForumPost] = ForumPost.samplePosts
    @State private var followingPosts: [ForumPost] = []
    @State private var nearbyPosts: [ForumPost] = []
    @State private var recommendedPosts: [ForumPost] = []
    
    private let tabs = ["关注", "附近", "推荐"]
    private let sortOptions = ["综合排序", "最新发布", "最多点赞", "最多评论"]
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    // 当前显示的帖子
    private var currentPosts: [ForumPost] {
        var posts: [ForumPost]
        switch selectedTab {
        case 0: posts = followingPosts
        case 1: posts = nearbyPosts
        default: posts = recommendedPosts
        }
        
        // 搜索过滤
        if !searchText.isEmpty {
            posts = posts.filter { post in
                post.content.localizedCaseInsensitiveContains(searchText) ||
                post.authorName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 排序
        switch selectedSort {
        case "最新发布":
            return posts // 已按时间排序
        case "最多点赞":
            return posts.sorted { $0.likeCount > $1.likeCount }
        case "最多评论":
            return posts.sorted { $0.commentCount > $1.commentCount }
        default:
            return posts
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 顶部导航栏
                headerView
                
                // 搜索栏（展开时显示）
                if showSearch {
                    searchBar
                }
                
                // Tab 标签
                tabBar
                
                // 帖子列表
                postsListView
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            
            // 发帖按钮
            createPostButton
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView { newPost in
                // 添加到所有列表
                allPosts.insert(newPost, at: 0)
                recommendedPosts.insert(newPost, at: 0)
                nearbyPosts.insert(newPost, at: 0)
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(selectedRange: $selectedRange)
        }
        .alert("请先登录", isPresented: $showLoginAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("登录后才能发布帖子，快去登录吧～")
        }
        .onAppear {
            loadInitialData()
            // 请求定位权限
            locationService.startLocating()
        }
    }
    
    // MARK: - 顶部导航栏
    private var headerView: some View {
        HStack(spacing: 12) {
            // 位置选择 - 只在"附近"标签页显示
            if selectedTab == 1 {
                Button {
                    showLocationPicker = true
                } label: {
                    HStack(spacing: 4) {
                        if locationService.isLocating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 13))
                        }
                        Text(selectedRange)
                            .font(.subheadline)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(forestGreen)
                }
            }
            
            Spacer()
            
            // 排序选择
            Menu {
                ForEach(sortOptions, id: \.self) { option in
                    Button {
                        selectedSort = option
                    } label: {
                        HStack {
                            Text(option)
                            if selectedSort == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedSort)
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(14)
            }
            
            // 搜索按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSearch.toggle()
                    if !showSearch {
                        searchText = ""
                    }
                }
            } label: {
                Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(forestGreen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索帖子、用户...", text: $searchText)
                .font(.subheadline)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color.white)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Tab 标签栏
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tabs[index])
                            .font(.system(size: 15))
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? forestGreen : .gray)
                        
                        // 下划线指示器
                        Rectangle()
                            .fill(selectedTab == index ? forestGreen : Color.clear)
                            .frame(width: 24, height: 3)
                            .cornerRadius(1.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.white)
    }
    
    // MARK: - 帖子列表
    private var postsListView: some View {
        Group {
            if isLoading {
                // 加载中
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if currentPosts.isEmpty {
                // 空状态
                emptyStateView
            } else {
                // 帖子网格
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(currentPosts) { post in
                            PostCard(post: post, forestGreen: forestGreen)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 80)
                }
                .refreshable {
                    await refreshPosts()
                }
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 50))
                .foregroundColor(forestGreen.opacity(0.3))
            
            Text(emptyStateTitle)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(emptyStateSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
            
            if selectedTab == 0 && !authService.isLoggedIn {
                Button {
                    // 跳转登录
                } label: {
                    Text("去登录")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(forestGreen)
                        .cornerRadius(20)
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateIcon: String {
        switch selectedTab {
        case 0: return "person.2"
        case 1: return "location.slash"
        default: return "doc.text"
        }
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "未找到相关内容"
        }
        switch selectedTab {
        case 0: return authService.isLoggedIn ? "还没有关注的人" : "登录后查看关注"
        case 1: return "附近暂无动态"
        default: return "暂无推荐内容"
        }
    }
    
    private var emptyStateSubtitle: String {
        if !searchText.isEmpty {
            return "换个关键词试试吧"
        }
        switch selectedTab {
        case 0: return authService.isLoggedIn ? "去发现更多有趣的鸟友吧" : "登录后可以关注其他鸟友"
        case 1: return "成为第一个分享的人吧"
        default: return "下拉刷新试试"
        }
    }
    
    // MARK: - 发帖按钮
    @State private var showPostMenu = false
    @State private var showFindBirdPost = false
    
    private var createPostButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    // 展开的菜单
                    if showPostMenu {
                        // 寻鸟按钮
                        Button {
                            showPostMenu = false
                            if authService.isLoggedIn {
                                showFindBirdPost = true
                            } else {
                                showLoginAlert = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                Text("寻鸟")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.85, green: 0.35, blue: 0.35))
                            .cornerRadius(20)
                            .shadow(color: Color.red.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .transition(.scale.combined(with: .opacity))
                        
                        // 发帖按钮
                        Button {
                            showPostMenu = false
                            if authService.isLoggedIn {
                                showCreatePost = true
                            } else {
                                showLoginAlert = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 14))
                                Text("发帖")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(forestGreen)
                            .cornerRadius(20)
                            .shadow(color: forestGreen.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 主按钮
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPostMenu.toggle()
                        }
                    } label: {
                        Image(systemName: showPostMenu ? "xmark" : "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [forestGreen, Color(red: 0.35, green: 0.55, blue: 0.45)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(28)
                            .shadow(color: forestGreen.opacity(0.4), radius: 8, x: 0, y: 4)
                            .rotationEffect(.degrees(showPostMenu ? 45 : 0))
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showFindBirdPost) {
            CreateFindBirdPostView { newPost in
                // 寻鸟帖子只添加到附近列表
                allPosts.insert(newPost, at: 0)
                nearbyPosts.insert(newPost, at: 0)
            }
        }
    }
    
    // MARK: - 数据加载
    private func loadInitialData() {
        Task {
            await loadPostsFromServer()
        }
    }
    
    private func loadPostsFromServer() async {
        do {
            let page = try await ApiService.shared.getPosts(page: 0, size: 50)
            let serverPosts = page.content.map { ForumPost.from(dto: $0) }
            
            // 更新 SocialService 中的点赞/收藏状态
            let likedIds = Set(serverPosts.filter { $0.isLiked }.map { $0.id })
            let favoritedIds = Set(serverPosts.filter { $0.isFavorited }.map { $0.id })
            
            await MainActor.run {
                socialService.likedPostIds = likedIds
                socialService.favoritePostIds = favoritedIds
                
                allPosts = serverPosts
                
                // 推荐：只显示普通帖子，按热度（点赞+评论）排序
                recommendedPosts = serverPosts
                    .filter { $0.postType == .normal }
                    .sorted { ($0.likeCount + $0.commentCount) > ($1.likeCount + $1.commentCount) }
                
                // 附近：寻鸟帖子置顶 + 普通帖子
                let findBirdPosts = serverPosts.filter { $0.postType == .findBird }
                let normalPosts = serverPosts.filter { $0.postType == .normal }
                nearbyPosts = findBirdPosts + normalPosts
                
                // 关注的帖子（需要登录）
                if authService.isLoggedIn {
                    followingPosts = Array(serverPosts.filter { $0.postType == .normal }.prefix(5))
                }
            }
        } catch {
            print("加载帖子失败: \(error)")
            // 加载失败时清空数据
            await MainActor.run {
                allPosts = []
                recommendedPosts = []
                nearbyPosts = []
                followingPosts = []
            }
        }
    }
    
    private func refreshPosts() async {
        isLoading = true
        await loadPostsFromServer()
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - 位置选择视图
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationService = LocationService.shared
    @Binding var selectedRange: String
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let ranges = [
        ("附近", "location.fill", "当前位置3公里内", 3.0),
        ("同城", "building.2.fill", "同一城市的鸟友", 50.0),
        ("全国", "map.fill", "全国各地的鸟友", -1.0),
    ]
    
    var body: some View {
        NavigationView {
            List {
                // 当前位置
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(forestGreen.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            if locationService.isLocating {
                                ProgressView()
                            } else {
                                Image(systemName: "location.fill")
                                    .foregroundColor(forestGreen)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前位置")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if locationService.isLocating {
                                Text("正在获取位置...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let error = locationService.locationError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text(locationService.fullAddress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            locationService.refreshLocation()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                                .foregroundColor(forestGreen)
                        }
                        .disabled(locationService.isLocating)
                    }
                    .padding(.vertical, 4)
                    
                    // 定位权限提示
                    if locationService.authorizationStatus == .denied {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("请在系统设置中开启定位权限")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("去设置") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(forestGreen)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("我的位置")
                }
                
                // 范围选择
                Section {
                    ForEach(ranges, id: \.0) { range in
                        Button {
                            selectedRange = range.0
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: range.1)
                                    .font(.title3)
                                    .foregroundColor(forestGreen)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(range.0)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text(range.2)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedRange == range.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(forestGreen)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("选择范围")
                } footer: {
                    Text("选择范围后，将只显示该范围内的帖子")
                }
            }
            .navigationTitle("位置设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(forestGreen)
                }
            }
        }
    }
}

// MARK: - 帖子卡片
struct PostCard: View {
    let post: ForumPost
    let forestGreen: Color
    @ObservedObject var socialService = SocialService.shared
    @State private var likeCount: Int
    @State private var showDetail = false
    
    private let urgentColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    init(post: ForumPost, forestGreen: Color) {
        self.post = post
        self.forestGreen = forestGreen
        self._likeCount = State(initialValue: post.likeCount)
    }
    
    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // 寻鸟帖子顶部标签 - 红色主题
                if post.postType == .findBird {
                    HStack(spacing: 6) {
                        Text("🔍 寻鸟启事")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        if let reward = post.reward {
                            Text("悬赏 ¥\(reward)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // 图片区域 - 支持多图
                    imageSection
                    
                    // 作者信息
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(uiColor: .systemGray5))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            if post.postType == .findBird, let location = post.lostLocation {
                                HStack(spacing: 3) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 9))
                                    Text(location)
                                        .lineLimit(1)
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            } else {
                                Text(post.timeAgo)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // 内容
                    if post.postType == .findBird {
                        VStack(alignment: .leading, spacing: 6) {
                            if let species = post.birdSpecies {
                                Text(species)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                            
                            Text(post.content)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                    } else {
                        Text(post.content)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                    
                    // 互动栏
                    interactionBar
                }
                .padding(10)
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(uiColor: .systemGray5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            PostDetailView(post: post, forestGreen: forestGreen)
        }
    }
    
    // 图片区域
    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            if post.images.isEmpty {
                // 无图片时显示图标
                RoundedRectangle(cornerRadius: post.postType == .findBird ? 0 : 12)
                    .fill(post.postType == .findBird ? Color.red.opacity(0.08) : forestGreen.opacity(0.1))
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: post.postType == .findBird ? "bird.fill" : post.imageIcon)
                                .font(.system(size: 36))
                                .foregroundColor(post.postType == .findBird ? Color.red.opacity(0.5) : forestGreen.opacity(0.4))
                            
                            if post.postType == .findBird, let birdName = post.birdName {
                                Text(birdName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.red.opacity(0.7))
                            }
                        }
                    )
            } else {
                // 有图片时显示图片 - 寻鸟启事纯图片显示
                if post.postType == .findBird {
                    Rectangle()
                        .fill(Color.clear)
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.3))
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(forestGreen.opacity(0.1))
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 30))
                                    .foregroundColor(forestGreen.opacity(0.4))
                                
                                Text("\(post.images.count)张图片")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        )
                }
            }
            
            // 移除悬赏标签（已在顶部显示）
            if false, post.postType == .findBird, let reward = post.reward {
                Text("悬赏\(reward)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, urgentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(0)
            }
            
            // 多图标识
            if post.images.count > 1 {
                HStack(spacing: 2) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 10))
                    Text("\(post.images.count)")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
                .padding(6)
            }
        }
    }
    
    // 互动栏
    private var interactionBar: some View {
        HStack(spacing: 16) {
            // 点赞按钮
            Button {
                let wasLiked = socialService.isLiked(postId: post.id)
                withAnimation(.spring(response: 0.3)) {
                    socialService.toggleLike(postId: post.id)
                    likeCount += wasLiked ? -1 : 1
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: socialService.isLiked(postId: post.id) ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundColor(socialService.isLiked(postId: post.id) ? .red : .gray)
                    Text(formatCount(likeCount))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            
            // 评论
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.caption)
                Text(formatCount(post.commentCount))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(.gray)
            
            Spacer()
        }
    }
    
    // 格式化数字显示
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fw", Double(count) / 10000)
        } else if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - 帖子详情页
struct PostDetailView: View {
    let post: ForumPost
    let forestGreen: Color
    @ObservedObject var socialService = SocialService.shared
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var likeCount: Int
    @State private var commentText = ""
    @State private var comments: [PostComment] = PostComment.sampleComments
    @State private var showShareSheet = false
    @State private var selectedImageIndex = 0
    @State private var showImageViewer = false
    @State private var showAuthorProfile = false
    
    private let urgentColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    
    // 从帖子创建用户资料
    private var authorProfile: UserProfile {
        UserProfile(
            id: post.authorId,
            nickname: post.authorName,
            avatar: post.authorAvatar,
            bio: nil,
            birdCount: Int.random(in: 1...10),
            postCount: Int.random(in: 5...50),
            followerCount: Int.random(in: 10...500),
            followingCount: Int.random(in: 5...100)
        )
    }
    
    init(post: ForumPost, forestGreen: Color) {
        self.post = post
        self.forestGreen = forestGreen
        self._likeCount = State(initialValue: post.likeCount)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 图片区域
                        imageSection
                        
                        // 内容区域
                        contentSection
                            .padding(.horizontal, 16)
                        
                        // 寻鸟详细信息
                        if post.postType == .findBird {
                            findBirdDetailSection
                                .padding(.horizontal, 16)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // 评论区
                        commentsSection
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 80)
                }
                
                // 底部互动栏
                bottomBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [post.content])
            }
        }
    }
    
    // 图片区域 - 支持多图浏览
    private var imageSection: some View {
        VStack(spacing: 0) {
            if post.images.isEmpty {
                // 无图片时显示占位
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(post.postType == .findBird ? urgentColor.opacity(0.1) : forestGreen.opacity(0.1))
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: post.postType == .findBird ? "bird.fill" : post.imageIcon)
                                    .font(.system(size: 60))
                                    .foregroundColor(post.postType == .findBird ? urgentColor.opacity(0.4) : forestGreen.opacity(0.3))
                                
                                if post.postType == .findBird, let birdName = post.birdName {
                                    Text(birdName)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(urgentColor.opacity(0.6))
                                }
                            }
                        )
                    
                    // 寻鸟标签
                    if post.postType == .findBird {
                        findBirdBadge
                    }
                }
            } else {
                // 有图片时显示图片网格
                ZStack(alignment: .topLeading) {
                    imageGrid
                    
                    // 寻鸟标签
                    if post.postType == .findBird {
                        findBirdBadge
                    }
                }
            }
        }
    }
    
    // 寻鸟标签
    private var findBirdBadge: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("寻鸟启事")
                    .fontWeight(.bold)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(urgentColor)
            .cornerRadius(8)
            
            if let reward = post.reward {
                Text("悬赏 \(reward)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
        }
        .padding(16)
    }
    
    // 图片轮播（小红书风格左右滑动）
    private var imageGrid: some View {
        TabView(selection: $selectedImageIndex) {
            ForEach(post.images.indices, id: \.self) { index in
                Rectangle()
                    .fill(post.postType == .findBird ? urgentColor.opacity(0.1) : forestGreen.opacity(0.1))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(post.postType == .findBird ? urgentColor.opacity(0.4) : forestGreen.opacity(0.4))
                            Text("图片 \(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: post.images.count > 1 ? .always : .never))
        .aspectRatio(1.0, contentMode: .fit)
    }
    
    // 内容区域
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 作者信息
            HStack(spacing: 12) {
                // 头像可点击进入主页
                Button {
                    showAuthorProfile = true
                } label: {
                    Circle()
                        .fill(post.postType == .findBird ? urgentColor.opacity(0.15) : forestGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(post.postType == .findBird ? urgentColor : forestGreen)
                        )
                }
                
                // 用户名可点击进入主页
                Button {
                    showAuthorProfile = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.authorName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text(post.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        let currentUserId = authService.currentUser?.id
                        socialService.toggleFollow(userId: post.authorId, currentUserId: currentUserId)
                    }
                } label: {
                    Text(socialService.isFollowing(userId: post.authorId) ? "已关注" : "关注")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(socialService.isFollowing(userId: post.authorId) ? .secondary : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(socialService.isFollowing(userId: post.authorId) ? Color(uiColor: .systemGray5) : (post.postType == .findBird ? urgentColor : forestGreen))
                        .cornerRadius(14)
                }
            }
            
            // 正文
            Text(post.content)
                .font(.body)
                .lineSpacing(6)
        }
        .sheet(isPresented: $showAuthorProfile) {
            UserProfileView(user: authorProfile)
        }
    }
    
    // 寻鸟详细信息
    private var findBirdDetailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏 - 简洁样式
            Text("寻鸟信息")
                .font(.headline)
                .fontWeight(.bold)
            
            // 信息列表 - 简洁样式
            VStack(alignment: .leading, spacing: 12) {
                if let birdName = post.birdName {
                    simpleInfoRow(title: "鸟儿名字", value: birdName)
                }
                if let species = post.birdSpecies {
                    simpleInfoRow(title: "鸟儿品种", value: species)
                }
                if let location = post.lostLocation {
                    simpleInfoRow(title: "走失地点", value: location)
                }
                if let phone = post.contactPhone {
                    simpleInfoRow(title: "联系电话", value: phone)
                }
                if let reward = post.reward {
                    simpleInfoRow(title: "悬赏金额", value: "¥\(reward)")
                }
            }
            .padding(16)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
            
            // 帮助按钮 - 改进样式
            HStack(spacing: 12) {
                Button {
                    callPhoneNumber()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                        Text("联系失主")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [urgentColor, urgentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: urgentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(post.contactPhone == nil)
                
                Button {
                    shareToWeChat()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .font(.system(size: 16))
                        Text("帮忙转发")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(urgentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(urgentColor, lineWidth: 2)
                    )
                    .shadow(color: urgentColor.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
        }
    }
    
    private func infoRow(icon: String, title: String, value: String, isPhone: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(urgentColor)
                .frame(width: 20)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(isPhone ? .semibold : .regular)
                .foregroundColor(isPhone ? urgentColor : .primary)
        }
    }
    
    // 现代化信息行 - 左对齐，更美观
    private func modernInfoRow(icon: String, title: String, value: String, color: Color, isHighlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // 文字信息 - 左对齐
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(isHighlight ? .bold : .medium)
                    .foregroundColor(isHighlight ? color : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
    
    // 评论区
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("评论")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(comments.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("暂无评论，快来抢沙发～")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(comments) { comment in
                    CommentRow(comment: comment, forestGreen: forestGreen)
                }
            }
        }
    }
    
    // 底部互动栏
    private var bottomBar: some View {
        HStack(spacing: 16) {
            // 评论输入框
            HStack {
                TextField("说点什么...", text: $commentText)
                    .font(.subheadline)
                
                if !commentText.isEmpty {
                    Button {
                        submitComment()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(forestGreen)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(20)
            
            // 点赞
            Button {
                let wasLiked = socialService.isLiked(postId: post.id)
                withAnimation(.spring(response: 0.3)) {
                    socialService.toggleLike(postId: post.id)
                    likeCount += wasLiked ? -1 : 1
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: socialService.isLiked(postId: post.id) ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(socialService.isLiked(postId: post.id) ? .red : .gray)
                    Text("\(likeCount)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // 收藏
            Button {
                withAnimation(.spring(response: 0.3)) {
                    socialService.toggleFavorite(postId: post.id)
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: socialService.isFavorited(postId: post.id) ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundColor(socialService.isFavorited(postId: post.id) ? forestGreen : .gray)
                    Text(socialService.isFavorited(postId: post.id) ? "已收藏" : "收藏")
                        .font(.caption2)
                        .foregroundColor(socialService.isFavorited(postId: post.id) ? forestGreen : .gray)
                }
            }
            
            // 分享
            Button {
                showShareSheet = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("分享")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
    }
    
    // 简洁的信息行
    private func simpleInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    // 提交评论
    private func submitComment() {
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        Task {
            do {
                // 调用后端API添加评论
                let commentDTO = try await ApiService.shared.addComment(
                    postId: post.id,
                    content: content
                )
                
                // 转换为本地模型并添加到列表
                let newComment = PostComment.from(dto: commentDTO)
                
                await MainActor.run {
                    comments.insert(newComment, at: 0)
                    commentText = ""
                }
            } catch {
                print("发送评论失败: \(error)")
                await MainActor.run {
                    // 可以显示错误提示
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 拨打电话
    private func callPhoneNumber() {
        guard let phoneNumber = post.contactPhone else { return }
        
        // 清理电话号码（移除空格、横线等）
        let cleanedNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        if let url = URL(string: "tel://\(cleanedNumber)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // 分享到微信
    private func shareToWeChat() {
        // 构建分享内容
        var shareText = "【寻鸟启事】\n\n"
        
        if let birdName = post.birdName {
            shareText += "鸟儿名字：\(birdName)\n"
        }
        if let species = post.birdSpecies {
            shareText += "品种：\(species)\n"
        }
        if let location = post.lostLocation {
            shareText += "走失地点：\(location)\n"
        }
        if let phone = post.contactPhone {
            shareText += "联系电话：\(phone)\n"
        }
        if let reward = post.reward {
            shareText += "悬赏：\(reward)\n"
        }
        
        shareText += "\n\(post.content)\n\n"
        shareText += "如果您看到这只鸟儿，请联系失主！"
        
        // 使用系统分享
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // 获取当前的 window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // 找到最顶层的 view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            // iPad 需要设置 popover
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topController.present(activityVC, animated: true)
        }
    }
}

// MARK: - 分享Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    let maxCount: Int
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                if parent.images.count < parent.maxCount {
                    parent.images.append(image)
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - 评论数据模型
struct PostComment: Identifiable {
    let id: Int64
    let localId = UUID() // 本地唯一标识
    let authorName: String
    let content: String
    let timeAgo: String
    var likeCount: Int
    var isLiked: Bool
    
    init(id: Int64 = 0, authorName: String, content: String, timeAgo: String, likeCount: Int, isLiked: Bool = false) {
        self.id = id
        self.authorName = authorName
        self.content = content
        self.timeAgo = timeAgo
        self.likeCount = likeCount
        self.isLiked = isLiked
    }
    
    // 从 DTO 创建
    static func from(dto: CommentDTO) -> PostComment {
        PostComment(
            id: dto.id,
            authorName: dto.authorName ?? "用户",
            content: dto.content,
            timeAgo: dto.timeAgo ?? "刚刚",
            likeCount: dto.likeCount ?? 0,
            isLiked: dto.isLiked ?? false
        )
    }
    
    static let sampleComments: [PostComment] = []
}

// MARK: - 评论行
struct CommentRow: View {
    let comment: PostComment
    let forestGreen: Color
    @ObservedObject var socialService = SocialService.shared
    @State private var likeCount: Int
    
    init(comment: PostComment, forestGreen: Color) {
        self.comment = comment
        self.forestGreen = forestGreen
        self._likeCount = State(initialValue: comment.likeCount)
    }
    
    private var isLiked: Bool {
        socialService.isCommentLiked(commentId: comment.id)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(forestGreen.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(forestGreen)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.authorName)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.content)
                    .font(.subheadline)
                
                // 点赞按钮
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        let wasLiked = isLiked
                        socialService.toggleCommentLike(commentId: comment.id)
                        likeCount += wasLiked ? -1 : 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.caption2)
                        Text("\(likeCount)")
                            .font(.caption2)
                    }
                    .foregroundColor(isLiked ? .red : .gray)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - 帖子类型
enum PostType: String {
    case normal = "普通"
    case findBird = "寻鸟"
}

// MARK: - 帖子数据模型
struct ForumPost: Identifiable {
    let id: Int64 // 后端ID
    let localId = UUID() // 本地唯一标识
    let authorId: Int64 // 作者ID
    let authorName: String
    let authorAvatar: String?
    let content: String
    let images: [String] // 支持最多9张图片
    let imageIcon: String // 无图片时显示的图标
    var likeCount: Int
    var commentCount: Int
    var favoriteCount: Int
    let timeAgo: String
    let distance: Double?
    let postType: PostType
    var isLiked: Bool
    var isFavorited: Bool
    
    // 视频相关字段
    let mediaType: String // IMAGE, VIDEO
    let videoUrl: String?
    let videoCover: String?
    let videoDuration: Int?
    
    // 寻鸟专属字段
    let birdName: String?
    let birdSpecies: String?
    let lostLocation: String?
    let contactPhone: String?
    let reward: String?
    let isFound: Bool
    
    init(id: Int64 = 0, authorId: Int64 = 0, authorName: String, authorAvatar: String?, content: String, images: [String] = [], imageIcon: String, likeCount: Int, commentCount: Int, favoriteCount: Int = 0, timeAgo: String, distance: Double?, postType: PostType = .normal, isLiked: Bool = false, isFavorited: Bool = false, mediaType: String = "IMAGE", videoUrl: String? = nil, videoCover: String? = nil, videoDuration: Int? = nil, birdName: String? = nil, birdSpecies: String? = nil, lostLocation: String? = nil, contactPhone: String? = nil, reward: String? = nil, isFound: Bool = false) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatar = authorAvatar
        self.content = content
        self.images = images
        self.imageIcon = imageIcon
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.favoriteCount = favoriteCount
        self.timeAgo = timeAgo
        self.distance = distance
        self.postType = postType
        self.isLiked = isLiked
        self.isFavorited = isFavorited
        self.mediaType = mediaType
        self.videoUrl = videoUrl
        self.videoCover = videoCover
        self.videoDuration = videoDuration
        self.birdName = birdName
        self.birdSpecies = birdSpecies
        self.lostLocation = lostLocation
        self.contactPhone = contactPhone
        self.reward = reward
        self.isFound = isFound
    }
    
    // 从 DTO 创建
    static func from(dto: ForumPostDTO) -> ForumPost {
        ForumPost(
            id: dto.id,
            authorId: dto.authorId ?? 0,
            authorName: dto.authorName ?? "用户",
            authorAvatar: dto.authorAvatar,
            content: dto.content,
            images: dto.images ?? [],
            imageIcon: dto.postType == "FIND_BIRD" ? "magnifyingglass" : (dto.mediaType == "VIDEO" ? "play.circle" : "text.bubble"),
            likeCount: dto.likeCount ?? 0,
            commentCount: dto.commentCount ?? 0,
            favoriteCount: 0,
            timeAgo: dto.timeAgo ?? "刚刚",
            distance: dto.distance,
            postType: dto.postType == "FIND_BIRD" ? .findBird : .normal,
            isLiked: dto.isLiked ?? false,
            isFavorited: dto.isFavorited ?? false,
            mediaType: dto.mediaType ?? "IMAGE",
            videoUrl: dto.videoUrl,
            videoCover: dto.videoCover,
            videoDuration: dto.videoDuration,
            birdName: dto.birdName,
            birdSpecies: dto.birdSpecies,
            lostLocation: dto.lostLocation,
            contactPhone: dto.contactPhone,
            reward: dto.reward,
            isFound: dto.isFound ?? false
        )
    }
    
    // 空数据
    static let samplePosts: [ForumPost] = []
}

// MARK: - 发帖视图
struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    @State private var content = ""
    @State private var selectedBird: String? = nil
    @State private var isPosting = false
    @State private var showSuccess = false
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    
    let onPost: (ForumPost) -> Void
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let maxLength = 500
    private let maxImages = 9
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 内容输入
                VStack(alignment: .leading, spacing: 12) {
                    // 用户信息
                    HStack(spacing: 10) {
                        Circle()
                            .fill(forestGreen.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(forestGreen)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authService.currentUser?.nickname ?? "用户")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("发布到广场")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // 文本输入
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .padding(.horizontal, 12)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    
                    // 字数统计
                    HStack {
                        Spacer()
                        Text("\(content.count)/\(maxLength)")
                            .font(.caption)
                            .foregroundColor(content.count > maxLength ? .red : .secondary)
                    }
                    .padding(.horizontal, 16)
                }
                
                Divider()
                    .padding(.vertical, 12)
                
                // 添加图片（最多9张）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("添加图片")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(selectedImages.count)/\(maxImages)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // 已选择的图片
                            ForEach(selectedImages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    // 删除按钮
                                    Button {
                                        selectedImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                            
                            // 添加图片按钮 - 支持多选
                            if selectedImages.count < maxImages {
                                PhotosPicker(
                                    selection: $selectedItems,
                                    maxSelectionCount: maxImages - selectedImages.count,
                                    matching: .images
                                ) {
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.title2)
                                        Text("添加")
                                            .font(.caption)
                                    }
                                    .foregroundColor(forestGreen)
                                    .frame(width: 80, height: 80)
                                    .background(forestGreen.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                Divider()
                    .padding(.vertical, 12)
                
                // 关联鸟儿
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bird.fill")
                            .foregroundColor(forestGreen)
                        Text("关联我的鸟儿")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("可选")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(["小黄", "小绿", "小白"], id: \.self) { bird in
                                Button {
                                    if selectedBird == bird {
                                        selectedBird = nil
                                    } else {
                                        selectedBird = bird
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bird.fill")
                                            .font(.caption)
                                        Text(bird)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedBird == bird ? forestGreen : Color(uiColor: .systemGray6))
                                    .foregroundColor(selectedBird == bird ? .white : .primary)
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                Spacer()
                
                // 发布按钮
                Button {
                    postContent()
                } label: {
                    HStack {
                        if isPosting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("发布")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canPost ? forestGreen : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(!canPost || isPosting)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Color.white)
            .navigationTitle("发布帖子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .alert("发布成功", isPresented: $showSuccess) {
                Button("确定") { dismiss() }
            } message: {
                Text("你的帖子已发布到广场")
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(images: $selectedImages, maxCount: maxImages)
            }
            .onChange(of: selectedItems) { newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                if selectedImages.count < maxImages {
                                    selectedImages.append(image)
                                }
                            }
                        }
                    }
                    await MainActor.run {
                        selectedItems = []
                    }
                }
            }
        }
    }
    
    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && content.count <= maxLength
    }
    
    private func postContent() {
        isPosting = true
        
        // 生成图片标识符（实际应用中会上传图片并获取URL）
        let imageIds = selectedImages.indices.map { "user_post_\(UUID().uuidString.prefix(8))_\($0)" }
        
        Task {
            do {
                // 调用后端 API 创建帖子
                let postDTO = try await ApiService.shared.createPost(
                    content: content,
                    postType: "NORMAL",
                    images: imageIds
                )
                
                // 转换为本地 ForumPost 模型
                let newPost = ForumPost.from(dto: postDTO)
                
                await MainActor.run {
                    onPost(newPost)
                    isPosting = false
                    showSuccess = true
                }
            } catch {
                print("发帖失败: \(error)")
                await MainActor.run {
                    isPosting = false
                    // 可以添加错误提示
                }
            }
        }
    }
}

// MARK: - 寻鸟发帖视图
struct CreateFindBirdPostView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var locationService = LocationService.shared
    
    @State private var birdName = ""
    @State private var birdSpecies = ""
    @State private var description = ""
    @State private var contactPhone = ""
    @State private var reward = ""
    @State private var isPosting = false
    @State private var showSuccess = false
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    
    let onPost: (ForumPost) -> Void
    
    private let urgentColor = Color(red: 0.85, green: 0.35, blue: 0.35)
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    // 常见鸟类品种
    private let birdSpeciesList = ["虎皮鹦鹉", "玄凤鹦鹉", "牡丹鹦鹉", "金太阳鹦鹉", "和尚鹦鹉", "文鸟", "珍珠鸟", "金丝雀", "八哥", "其他"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 紧急提示
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundColor(urgentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("发布寻鸟启事")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("信息将推送给附近5公里内的鸟友")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(urgentColor.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 添加鸟儿照片
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("鸟儿照片", required: true)
                        Text("上传清晰照片帮助他人识别")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // 已选择的图片
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        // 删除按钮
                                        Button {
                                            selectedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.5)))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                                
                                // 添加图片按钮
                                if selectedImages.count < 9 {
                                    Button {
                                        showImagePicker = true
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.title2)
                                            Text("添加照片")
                                                .font(.caption)
                                            Text("\(selectedImages.count)/9")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .foregroundColor(urgentColor)
                                        .frame(width: 100, height: 100)
                                        .background(urgentColor.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(urgentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // 走失地点（自动定位）
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("走失地点", required: true)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(urgentColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if locationService.isLocating {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("正在获取位置...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                } else if let error = locationService.locationError {
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                } else {
                                    Text(locationService.fullAddress)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("将推送给该位置附近的鸟友")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                locationService.refreshLocation()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline)
                                    .foregroundColor(urgentColor)
                            }
                            .disabled(locationService.isLocating)
                        }
                        .padding(14)
                        .background(urgentColor.opacity(0.08))
                        .cornerRadius(10)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // 鸟儿信息
                    VStack(alignment: .leading, spacing: 16) {
                        sectionTitle("鸟儿信息", required: true)
                        
                        // 鸟儿名字
                        inputField(title: "鸟儿名字", placeholder: "如：小黄", text: $birdName)
                        
                        // 鸟儿品种
                        VStack(alignment: .leading, spacing: 8) {
                            Text("鸟儿品种")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(birdSpeciesList, id: \.self) { species in
                                        Button {
                                            birdSpecies = species
                                        } label: {
                                            Text(species)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(birdSpecies == species ? urgentColor : Color(uiColor: .systemGray6))
                                                .foregroundColor(birdSpecies == species ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 详细描述
                        VStack(alignment: .leading, spacing: 8) {
                            Text("外观特征")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $description)
                                .frame(minHeight: 100)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(Color(uiColor: .systemGray6))
                                .cornerRadius(10)
                                .overlay(
                                    Group {
                                        if description.isEmpty {
                                            Text("描述鸟儿的颜色、体型、特殊标记等特征...")
                                                .font(.subheadline)
                                                .foregroundColor(.gray.opacity(0.5))
                                                .padding(.leading, 14)
                                                .padding(.top, 18)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // 联系方式
                    VStack(alignment: .leading, spacing: 16) {
                        sectionTitle("联系方式", required: true)
                        
                        inputField(title: "联系电话", placeholder: "方便鸟友联系您", text: $contactPhone, keyboardType: .phonePad)
                        
                        Text("电话将部分隐藏显示，保护您的隐私")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // 悬赏金额（可选）
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            sectionTitle("悬赏金额", required: false)
                            Text("可选")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("¥")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            TextField("输入金额", text: $reward)
                                .font(.title3)
                                .keyboardType(.numberPad)
                        }
                        .padding(12)
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(10)
                        
                        Text("设置悬赏可以提高帖子曝光度和响应速度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // 发布按钮
                    Button {
                        postFindBird()
                    } label: {
                        HStack {
                            if isPosting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "megaphone.fill")
                                Text("立即发布寻鸟启事")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canPost ? urgentColor : Color.gray)
                        .cornerRadius(14)
                    }
                    .disabled(!canPost || isPosting)
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .navigationTitle("寻鸟启事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .alert("发布成功", isPresented: $showSuccess) {
                Button("确定") { dismiss() }
            } message: {
                Text("寻鸟启事已发布，将推送给附近5公里内的鸟友")
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(images: $selectedImages, maxCount: 9)
            }
            .onAppear {
                // 开始定位
                locationService.startLocating()
            }
        }
    }
    
    private func sectionTitle(_ title: String, required: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            if required {
                Text("*")
                    .foregroundColor(urgentColor)
            }
        }
    }
    
    private func inputField(title: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: text)
                .font(.subheadline)
                .padding(12)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
                .keyboardType(keyboardType)
        }
    }
    
    private var canPost: Bool {
        !birdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !birdSpecies.isEmpty &&
        !locationService.isLocating && locationService.locationError == nil && // 定位完成且无错误
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !contactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func postFindBird() {
        isPosting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let rewardText = reward.isEmpty ? nil : "\(reward)元"
            let maskedPhone = contactPhone.count >= 7 ?
                String(contactPhone.prefix(3)) + "****" + String(contactPhone.suffix(4)) :
                contactPhone
            
            // 生成图片标识符
            let imageIds = selectedImages.indices.map { "find_bird_\(UUID().uuidString.prefix(8))_\($0)" }
            let authorId = authService.currentUser?.id ?? 0
            
            let newPost = ForumPost(
                authorId: authorId,
                authorName: authService.currentUser?.nickname ?? "用户",
                authorAvatar: nil,
                content: description,
                images: imageIds,
                imageIcon: "bird.fill",
                likeCount: 0,
                commentCount: 0,
                timeAgo: "刚刚",
                distance: 0.1,
                postType: .findBird,
                birdName: birdName,
                birdSpecies: birdSpecies,
                lostLocation: locationService.fullAddress,
                contactPhone: maskedPhone,
                reward: rewardText,
                isFound: false
            )
            
            onPost(newPost)
            isPosting = false
            showSuccess = true
        }
    }
}

// MARK: - 我的页面
struct ProfileView: View {
    @ObservedObject var authService = AuthService.shared
    @ObservedObject var trashService = TrashService.shared
    @ObservedObject var socialService = SocialService.shared
    @ObservedObject var themeService = ThemeService.shared
    @State private var showLogin = false
    @State private var showEditProfile = false
    @State private var showInvitations = false
    @State private var showVip = false
    @State private var showAvatarPicker = false
    @State private var showTrash = false
    @State private var showFollowing = false
    @State private var showFollowers = false
    @State private var showMyPosts = false
    @State private var showMyFavorites = false
    @State private var showHelp = false
    @State private var showAbout = false
    @State private var showDeleteAccount = false
    @State private var showThemeSelection = false
    
    // 实时统计数据
    @State private var birdCount: Int = 0
    @State private var logCount: Int = 0
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.13)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if authService.isLoggedIn, let user = authService.currentUser {
                    // 已登录状态
                    loggedInContent(user: user)
                } else {
                    // 未登录状态
                    notLoggedInContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGray6).opacity(0.5))
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showEditProfile) {
            if let user = authService.currentUser {
                EditProfileView(user: user)
            }
        }
        .sheet(isPresented: $showInvitations) {
            PendingInvitationsView()
        }
        .sheet(isPresented: $showVip) {
            VipView()
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerView()
        }
        .sheet(isPresented: $showTrash) {
            TrashView()
        }
        .sheet(isPresented: $showFollowing) {
            FollowListView(title: "我的关注", users: socialService.followingUsers, isFollowingList: true)
        }
        .sheet(isPresented: $showFollowers) {
            FollowListView(title: "我的粉丝", users: socialService.followerUsers, isFollowingList: false)
        }
        .sheet(isPresented: $showMyPosts) {
            MyPostsView()
        }
        .sheet(isPresented: $showMyFavorites) {
            MyFavoritesView()
        }
        .sheet(isPresented: $showThemeSelection) {
            ThemeSelectionView()
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .onAppear {
            loadStats()
            // 监听VIP页面打开通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowVIPPage"),
                object: nil,
                queue: .main
            ) { _ in
                showVip = true
            }
        }
    }
    
    // 加载统计数据
    private func loadStats() {
        Task {
            do {
                let birds = try await ApiService.shared.getBirds()
                let logs = try await ApiService.shared.getLogs()
                await MainActor.run {
                    birdCount = birds.count
                    logCount = logs.count
                }
                
                // 加载关注统计和列表
                if let userId = authService.currentUser?.id {
                    await socialService.loadFollowStats(userId: Int64(userId))
                    await socialService.loadFollowingUsers(userId: Int64(userId))
                    await socialService.loadFollowerUsers(userId: Int64(userId))
                    await socialService.loadMyPosts(userId: Int64(userId))
                    await socialService.loadMyFavorites()
                }
            } catch {
                print("加载统计数据失败: \(error)")
            }
        }
    }
    
    // MARK: - 已登录内容
    private func loggedInContent(user: User) -> some View {
        VStack(spacing: 16) {
            // 用户信息卡片
            userInfoCard(user: user)
            
            // VIP 卡片
            vipCard(user: user)
            
            // 统计数据
            statsSection(user: user)
            
            // 功能菜单
            menuSection
            
            // 设置
            settingsSection
            
            // 退出登录
            logoutButton
        }
    }
    
    // VIP 卡片
    private func vipCard(user: User) -> some View {
        Button {
            showVip = true
        } label: {
            if user.isVipValid {
                // 已是VIP - 显示会员详情
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.title3)
                            .foregroundColor(goldColor)
                        
                        Text("我的VIP特权")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // 会员类型和剩余时间
                        HStack(spacing: 4) {
                            if user.vipType == .lifetime {
                                Text("永久会员")
                                    .font(.caption)
                                    .foregroundColor(goldColor)
                            } else if let days = user.vipRemainingDays {
                                Text("剩余\(days)天")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("续费")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(goldColor)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // VIP 特权图标
                    HStack(spacing: 0) {
                        vipPrivilegeIcon(icon: "person.2.fill", title: "共享鸟儿")
                        vipPrivilegeIcon(icon: "xmark.circle", title: "去广告")
                        vipPrivilegeIcon(icon: "cloud.fill", title: "云备份")
                        vipPrivilegeIcon(icon: "chart.line.uptrend.xyaxis", title: "数据统计")
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.98, blue: 0.92), Color(red: 1.0, green: 0.95, blue: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(goldColor.opacity(0.3), lineWidth: 1)
                )
            } else {
                // 非VIP - 显示开通入口
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(goldColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("开通VIP会员")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("解锁共享鸟儿、去广告等特权")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("立即开通")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(goldColor)
                        .cornerRadius(12)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.98, blue: 0.92), Color(red: 1.0, green: 0.96, blue: 0.88)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(goldColor.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // VIP 特权小图标
    private func vipPrivilegeIcon(icon: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(goldColor)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // 用户信息卡片
    private func userInfoCard(user: User) -> some View {
        HStack(spacing: 16) {
            // 头像（点击可修改）
            Button {
                showAvatarPicker = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    // 头像主体
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(forestGreen.opacity(0.15))
                            .frame(width: 70, height: 70)
                            .overlay(
                                avatarContent(for: user)
                            )
                            .overlay(
                                Circle()
                                    .stroke(user.isVipValid ? goldColor : Color.clear, lineWidth: 2.5)
                            )
                        
                        // 相机图标
                        ZStack {
                            Circle()
                                .fill(forestGreen)
                                .frame(width: 24, height: 24)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                        }
                        .offset(x: 2, y: 2)
                    }
                    
                    // VIP 皇冠徽章
                    if user.isVipValid {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                            .foregroundColor(goldColor)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 22, height: 22)
                                    .shadow(color: goldColor.opacity(0.3), radius: 2, x: 0, y: 1)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(user.nickname)
                    .font(.title3)
                    .fontWeight(.bold)
                
                // VIP 专属标识
                if user.isVipValid {
                    HStack(spacing: 4) {
                        Image(systemName: "bird.fill")
                            .font(.system(size: 10))
                        Text(user.vipType?.displayName ?? "VIP会员")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(goldColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        LinearGradient(
                            colors: [goldColor.opacity(0.15), goldColor.opacity(0.08)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                } else {
                    Text(user.maskedPhone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button {
                showEditProfile = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(forestGreen.opacity(0.6))
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: forestGreen.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    // 头像内容
    @ViewBuilder
    private func avatarContent(for user: User) -> some View {
        if let avatarUrl = user.avatarUrl, !avatarUrl.isEmpty {
            if avatarUrl.hasPrefix("preset:") {
                // 预设头像
                let iconName = String(avatarUrl.dropFirst(7))
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(forestGreen)
            } else if avatarUrl.hasPrefix("http") {
                // 网络头像
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 28))
                        .foregroundColor(forestGreen)
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
            } else {
                // 其他情况显示默认
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundColor(forestGreen)
            }
        } else {
            // 无头像时显示默认图标
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundColor(forestGreen)
        }
    }
    
    // 统计数据
    private func statsSection(user: User) -> some View {
        HStack(spacing: 12) {
            statTile(icon: "bird.fill", label: "鸟儿", value: "\(birdCount)", action: { 
                // 切换到首页
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            })
            statTile(icon: "person.2.fill", label: "关注", value: "\(socialService.followingCount)", action: { showFollowing = true })
            statTile(icon: "heart.fill", label: "粉丝", value: "\(socialService.followerCount)", action: { showFollowers = true })
        }
    }
    
    private func statTile(icon: String, label: String, value: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(forestGreen)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
    
    // 功能菜单
    private var menuSection: some View {
        VStack(spacing: 0) {
            // 专属主题 - VIP功能
            menuRow(
                icon: "paintpalette.fill",
                title: "专属主题",
                badge: nil,
                vipIcon: authService.currentUser?.isVipValid != true
            ) {
                showThemeSelection = true
            }
            Divider().padding(.leading, 50)
            
            // 共享邀请 - VIP功能
            menuRow(
                icon: "envelope.badge",
                title: "共享邀请",
                badge: nil,
                vipIcon: authService.currentUser?.isVipValid != true
            ) {
                showInvitations = true
            }
            Divider().padding(.leading, 50)
            
            menuRow(icon: "doc.text", title: "我的帖子", badge: nil) {
                showMyPosts = true
            }
            Divider().padding(.leading, 50)
            
            menuRow(icon: "bookmark", title: "我的收藏", badge: socialService.favoritePostIds.isEmpty ? nil : "\(socialService.favoritePostIds.count)") {
                showMyFavorites = true
            }
            Divider().padding(.leading, 50)
            
            // 回收站 - VIP功能
            Button {
                showTrash = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .foregroundColor(forestGreen)
                        .frame(width: 24)
                    
                    Text("回收站")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // VIP王冠标识
                    if authService.currentUser?.isVipValid != true {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(goldColor)
                    }
                    
                    // 显示回收站数量
                    if !trashService.deletedBirds.isEmpty {
                        Text("\(trashService.deletedBirds.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(forestGreen)
                            .cornerRadius(10)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
    }
    
    // 设置区域
    private var settingsSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "questionmark.circle", title: "使用帮助", badge: nil) { showHelp = true }
            Divider().padding(.leading, 50)
            menuRow(icon: "info.circle", title: "关于鸟鸟王国", badge: "v1.0.0") { showAbout = true }
        }
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
    }
    
    private func menuRow(icon: String, title: String, badge: String?, vipIcon: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(forestGreen)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                
                // VIP王冠标识
                if vipIcon {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundColor(goldColor)
                }
                
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
    
    // 退出登录和注销账号按钮
    private var logoutButton: some View {
        VStack(spacing: 12) {
            // 退出登录
            Button {
                authService.logout()
            } label: {
                Text("退出登录")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(14)
            }
            .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
            
            // 注销账号
            Button {
                showDeleteAccount = true
            } label: {
                Text("注销账号")
                    .font(.subheadline)
                    .foregroundColor(.red.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(14)
            }
            .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
            .alert("确认注销账号", isPresented: $showDeleteAccount) {
                Button("取消", role: .cancel) {}
                Button("确认注销", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("注销账号后，您的所有数据将被永久删除且无法恢复。此操作不可撤销，请谨慎操作。")
            }
        }
    }
    
    // 注销账号
    private func deleteAccount() {
        Task {
            do {
                // 调用后端 API 注销账号
                try await ApiService.shared.deleteAccount()
                
                // 清除本地数据
                await MainActor.run {
                    authService.logout()
                    // 可以添加提示
                }
            } catch {
                print("注销账号失败: \(error)")
                // 可以显示错误提示
            }
        }
    }
    
    // MARK: - 未登录内容
    private var notLoggedInContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            
            // 图标
            Image(systemName: "bird.fill")
                .font(.system(size: 70))
                .foregroundColor(forestGreen.opacity(0.3))
            
            Text("登录鸟鸟王国")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("登录后可以同步数据、共享鸟儿信息")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showLogin = true
            } label: {
                Text("手机号登录 / 注册")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(forestGreen)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 关注/粉丝列表视图
struct FollowListView: View {
    let title: String
    let users: [UserProfile]
    let isFollowingList: Bool
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    @State private var selectedUser: UserProfile?
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            Group {
                if users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: isFollowingList ? "person.2" : "heart")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(isFollowingList ? "还没有关注任何人" : "还没有粉丝")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(users, id: \.id) { user in
                            Button {
                                selectedUser = user
                            } label: {
                                UserRowView(user: user, forestGreen: forestGreen)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedUser) { user in
                UserProfileView(user: user)
            }
        }
    }
}

// MARK: - 用户行视图
struct UserRowView: View {
    let user: UserProfile
    let forestGreen: Color
    @ObservedObject var socialService = SocialService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(forestGreen.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(forestGreen)
                )
            
            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                Text(user.nickname)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    Label("\(user.birdCount)只鸟", systemImage: "bird.fill")
                    Label("\(user.postCount)帖子", systemImage: "doc.text")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 关注按钮
            Button {
                withAnimation(.spring(response: 0.3)) {
                    socialService.toggleFollow(userId: user.id)
                }
            } label: {
                Text(socialService.isFollowing(userId: user.id) ? "已关注" : "关注")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(socialService.isFollowing(userId: user.id) ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(socialService.isFollowing(userId: user.id) ? Color(uiColor: .systemGray5) : forestGreen)
                    .cornerRadius(14)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 用户主页视图
struct UserProfileView: View {
    let user: UserProfile
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户头像和基本信息
                    VStack(spacing: 12) {
                        Circle()
                            .fill(forestGreen.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(forestGreen)
                            )
                        
                        Text(user.nickname)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let bio = user.bio {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // 关注按钮
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                socialService.toggleFollow(userId: user.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: socialService.isFollowing(userId: user.id) ? "checkmark" : "plus")
                                Text(socialService.isFollowing(userId: user.id) ? "已关注" : "关注")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(socialService.isFollowing(userId: user.id) ? .secondary : .white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(socialService.isFollowing(userId: user.id) ? Color(uiColor: .systemGray5) : forestGreen)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.top, 20)
                    
                    // 统计数据
                    HStack(spacing: 0) {
                        userStatItem(value: "\(user.birdCount)", label: "鸟儿")
                        Divider().frame(height: 40)
                        userStatItem(value: "\(user.postCount)", label: "帖子")
                        Divider().frame(height: 40)
                        userStatItem(value: "\(user.followerCount)", label: "粉丝")
                        Divider().frame(height: 40)
                        userStatItem(value: "\(user.followingCount)", label: "关注")
                    }
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                    .padding(.horizontal, 16)
                    
                    // TA的帖子
                    VStack(spacing: 12) {
                        HStack {
                            Text("TA的帖子")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        if userPosts.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.4))
                                Text("暂无帖子")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(userPosts) { post in
                                    PostCard(post: post, forestGreen: forestGreen)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    // 用户的帖子（模拟数据）
    private var userPosts: [ForumPost] {
        // 为该用户生成模拟帖子
        guard user.postCount > 0 else { return [] }
        
        let contents = [
            "今天我家的小鸟学会了新技能，太开心了！🎉",
            "分享一下我的养鸟心得，希望对新手有帮助",
            "求助：鸟儿最近不太爱吃东西，有经验的朋友帮忙看看",
            "周末带鸟儿出去晒太阳，心情超好！"
        ]
        
        return (0..<min(user.postCount, 4)).map { index in
            ForumPost(
                authorId: user.id,
                authorName: user.nickname,
                authorAvatar: user.avatar,
                content: contents[index % contents.count],
                images: index % 2 == 0 ? ["img1"] : [],
                imageIcon: "bird.fill",
                likeCount: Int.random(in: 5...100),
                commentCount: Int.random(in: 1...30),
                timeAgo: ["\(index + 1)小时前", "\(index + 1)天前", "刚刚"][index % 3],
                distance: nil
            )
        }
    }
    
    private func userStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 我的帖子视图
struct MyPostsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    // 从后端获取的我的帖子
    private var myPosts: [ForumPost] {
        socialService.myPosts.map { ForumPost.from(dto: $0) }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if myPosts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("还没有发布过帖子")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("去广场发布你的第一条帖子吧")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(myPosts, id: \.id) { post in
                                PostCard(post: post, forestGreen: forestGreen)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .navigationTitle("我的帖子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 我的收藏视图
struct MyFavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var socialService = SocialService.shared
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    // 从后端获取的收藏帖子
    private var favoritePosts: [ForumPost] {
        socialService.myFavorites.map { ForumPost.from(dto: $0) }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if favoritePosts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("还没有收藏任何帖子")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("在广场浏览时点击收藏按钮")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(favoritePosts, id: \.id) { post in
                                PostCard(post: post, forestGreen: forestGreen)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .navigationTitle("我的收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 编辑个人资料视图
struct EditProfileView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService = AuthService.shared
    
    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showChangePhone = false
    @State private var showSetPassword = false
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    HStack {
                        Text("昵称")
                        Spacer()
                        TextField("请输入昵称", text: $nickname)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Button {
                        showChangePhone = true
                    } label: {
                        HStack {
                            Text("手机号")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(user.maskedPhone)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("账号安全") {
                    Button {
                        showSetPassword = true
                    } label: {
                        HStack {
                            Text("设置密码")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("用于快速登录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("个人简介") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading || nickname.isEmpty)
                }
            }
            .onAppear {
                nickname = user.nickname
                bio = user.bio ?? ""
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showChangePhone) {
                ChangePhoneView()
            }
            .sheet(isPresented: $showSetPassword) {
                SetPasswordView()
            }
        }
    }
    
    private func saveProfile() {
        isLoading = true
        Task {
            do {
                try await authService.updateProfile(nickname: nickname, bio: bio.isEmpty ? nil : bio)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "保存失败"
                    showError = true
                }
            }
        }
    }
}

// MARK: - 食物安全等级
enum FoodSafetyLevel: String, CaseIterable {
    case safe = "可以吃"
    case caution = "少量吃"
    case dangerous = "不能吃"
    
    var color: Color {
        switch self {
        case .safe: return Color(red: 0.25, green: 0.65, blue: 0.35)
        case .caution: return Color(red: 0.9, green: 0.7, blue: 0.1)
        case .dangerous: return Color(red: 0.85, green: 0.3, blue: 0.3)
        }
    }
    
    var icon: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .dangerous: return "xmark.circle.fill"
        }
    }
}

// MARK: - 食物分类
enum FoodCategory: String, CaseIterable {
    case fruits = "水果"
    case vegetables = "蔬菜"
    case grains = "谷物种子"
    case proteins = "蛋白质"
    case nuts = "坚果"
    case herbs = "草本植物"
    case humanFood = "人类食品"
    case drinks = "饮品"
    case seasonings = "调味品"
    case snacks = "零食甜点"
    case others = "其他"
    
    var icon: String {
        switch self {
        case .fruits: return "apple.logo"
        case .vegetables: return "leaf.fill"
        case .grains: return "wheat"
        case .proteins: return "fish.fill"
        case .nuts: return "tree.fill"
        case .herbs: return "leaf.arrow.triangle.circlepath"
        case .humanFood: return "fork.knife"
        case .drinks: return "cup.and.saucer.fill"
        case .seasonings: return "salt.fill"
        case .snacks: return "birthday.cake.fill"
        case .others: return "questionmark.circle.fill"
        }
    }
}

// MARK: - 食物数据模型
struct BirdFood: Identifiable {
    let id = UUID()
    let name: String
    let category: FoodCategory
    let safetyLevel: FoodSafetyLevel
    let description: String
    let notes: String
    let nutrients: [String]
    // allFoods 数据已移至 Data/BirdFoodDatabase.swift
}


// MARK: - 食物查询视图
struct FoodQueryView: View {
    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory? = nil
    @State private var selectedSafetyLevel: FoodSafetyLevel? = nil
    @State private var selectedFood: BirdFood? = nil
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    private var filteredFoods: [BirdFood] {
        var foods = BirdFood.allFoods
        
        // 按分类筛选
        if let category = selectedCategory {
            foods = foods.filter { $0.category == category }
        }
        
        // 按安全等级筛选
        if let level = selectedSafetyLevel {
            foods = foods.filter { $0.safetyLevel == level }
        }
        
        // 按搜索词筛选
        if !searchText.isEmpty {
            foods = foods.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return foods
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 搜索栏
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("搜索食物名称...", text: $searchText)
                    .font(.subheadline)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            
            // 安全等级筛选
            HStack(spacing: 8) {
                ForEach(FoodSafetyLevel.allCases, id: \.self) { level in
                    Button {
                        if selectedSafetyLevel == level {
                            selectedSafetyLevel = nil
                        } else {
                            selectedSafetyLevel = level
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: level.icon)
                                .font(.caption)
                            Text(level.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedSafetyLevel == level ? level.color : Color.white)
                        .foregroundColor(selectedSafetyLevel == level ? .white : level.color)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(level.color, lineWidth: 1)
                        )
                    }
                }
                Spacer()
            }
            
            // 分类筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 全部按钮
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text("全部")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == nil ? forestGreen : Color.white)
                            .foregroundColor(selectedCategory == nil ? .white : .primary)
                            .cornerRadius(14)
                    }
                    
                    ForEach(FoodCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                Text(category.rawValue)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedCategory == category ? forestGreen : Color.white)
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .cornerRadius(14)
                        }
                    }
                }
            }
            
            // 统计信息
            HStack {
                Text("共 \(filteredFoods.count) 种食物")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                // 各等级数量
                HStack(spacing: 12) {
                    let safeCount = filteredFoods.filter { $0.safetyLevel == .safe }.count
                    let cautionCount = filteredFoods.filter { $0.safetyLevel == .caution }.count
                    let dangerCount = filteredFoods.filter { $0.safetyLevel == .dangerous }.count
                    
                    Label("\(safeCount)", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(FoodSafetyLevel.safe.color)
                    Label("\(cautionCount)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(FoodSafetyLevel.caution.color)
                    Label("\(dangerCount)", systemImage: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(FoodSafetyLevel.dangerous.color)
                }
            }
            
            // 食物列表
            if filteredFoods.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("没有找到相关食物")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredFoods) { food in
                        FoodCard(food: food)
                            .onTapGesture {
                                selectedFood = food
                            }
                    }
                }
            }
        }
        .sheet(item: $selectedFood) { food in
            FoodDetailView(food: food)
        }
    }
}

// MARK: - 食物卡片
struct FoodCard: View {
    let food: BirdFood
    
    var body: some View {
        HStack(spacing: 12) {
            // 安全等级图标
            ZStack {
                Circle()
                    .fill(food.safetyLevel.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: food.safetyLevel.icon)
                    .font(.title3)
                    .foregroundColor(food.safetyLevel.color)
            }
            
            // 食物信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(food.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(food.safetyLevel.rawValue)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(food.safetyLevel.color)
                        .cornerRadius(4)
                }
                
                Text(food.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 分类标签
            Text(food.category.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(food.safetyLevel.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 食物详情视图
struct FoodDetailView: View {
    let food: BirdFood
    @Environment(\.dismiss) private var dismiss
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 头部
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(food.safetyLevel.color.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: food.safetyLevel.icon)
                                .font(.system(size: 44))
                                .foregroundColor(food.safetyLevel.color)
                        }
                        
                        Text(food.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // 安全等级标签
                        HStack(spacing: 8) {
                            Image(systemName: food.safetyLevel.icon)
                            Text(food.safetyLevel.rawValue)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(food.safetyLevel.color)
                        .cornerRadius(20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(food.safetyLevel.color.opacity(0.08))
                    
                    VStack(spacing: 16) {
                        // 分类信息
                        infoCard(title: "食物分类", icon: food.category.icon) {
                            Text(food.category.rawValue)
                                .font(.subheadline)
                        }
                        
                        // 描述
                        infoCard(title: "简介", icon: "info.circle.fill") {
                            Text(food.description)
                                .font(.subheadline)
                        }
                        
                        // 注意事项
                        infoCard(title: "注意事项", icon: "exclamationmark.circle.fill") {
                            Text(food.notes)
                                .font(.subheadline)
                                .foregroundColor(food.safetyLevel == .dangerous ? .red : .primary)
                        }
                        
                        // 营养成分
                        if !food.nutrients.isEmpty {
                            infoCard(title: "主要营养", icon: "leaf.fill") {
                                FlowLayout(spacing: 8) {
                                    ForEach(food.nutrients, id: \.self) { nutrient in
                                        Text(nutrient)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(forestGreen.opacity(0.1))
                                            .foregroundColor(forestGreen)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        
                        // 安全提示
                        if food.safetyLevel == .dangerous {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("危险警告")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                }
                                
                                Text("此食物对鸟类有毒或有害，请绝对不要喂食！如果鸟儿误食，请立即联系兽医。")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .padding(14)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("食物详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(forestGreen)
                }
            }
        }
    }
    
    private func infoCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(forestGreen)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - 症状查询视图
struct SymptomQueryView: View {
    @State private var selectedSymptom: BirdSymptom? = nil
    @State private var searchText = ""
    @State private var selectedCategory: String = "全部"
    
    private let symptoms = BirdSymptom.allSymptoms
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let leafGreen = Color(red: 0.35, green: 0.55, blue: 0.40)
    private let softGreen = Color(red: 0.85, green: 0.92, blue: 0.85)
    
    // 分类列表
    private let categories: [(name: String, icon: String)] = [
        ("全部", "leaf.fill"),
        ("消化系统", "leaf"),
        ("呼吸系统", "wind"),
        ("病毒性疾病", "bolt.shield"),
        ("细菌性疾病", "staroflife"),
        ("真菌感染", "allergens"),
        ("寄生虫病", "ant"),
        ("营养代谢", "carrot"),
        ("繁殖相关", "egg"),
        ("神经系统", "brain.head.profile"),
        ("外伤中毒", "bandage"),
        ("行为异常", "figure.walk"),
        ("肿瘤", "circle.fill")
    ]
    
    private var filteredSymptoms: [BirdSymptom] {
        var result = symptoms
        
        // 按分类筛选
        if selectedCategory != "全部" {
            result = result.filter { symptom in
                switch selectedCategory {
                case "消化系统":
                    return symptom.category.contains("消化")
                case "呼吸系统":
                    return symptom.category.contains("呼吸")
                case "病毒性疾病":
                    return symptom.category.contains("病毒")
                case "细菌性疾病":
                    return symptom.category.contains("细菌")
                case "真菌感染":
                    return symptom.category.contains("真菌")
                case "寄生虫病":
                    return symptom.category.contains("寄生虫")
                case "营养代谢":
                    return symptom.category.contains("营养") || symptom.category.contains("代谢")
                case "繁殖相关":
                    return symptom.category.contains("繁殖")
                case "神经系统":
                    return symptom.category.contains("神经")
                case "外伤中毒":
                    return symptom.category.contains("外伤") || symptom.category.contains("中毒")
                case "行为异常":
                    return symptom.category.contains("行为")
                case "肿瘤":
                    return symptom.category.contains("肿瘤")
                default:
                    return true
                }
            }
        }
        
        // 按搜索词筛选
        if !searchText.isEmpty {
            result = result.filter { symptom in
                symptom.name.contains(searchText) ||
                symptom.description.contains(searchText) ||
                symptom.possibleCauses.contains { $0.contains(searchText) }
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题区域
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [forestGreen, leafGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "stethoscope")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("症状速查")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(forestGreen)
                        Text("快速了解鸟儿健康状况")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 搜索框
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(forestGreen.opacity(0.6))
                    TextField("搜索症状名称...", text: $searchText)
                        .font(.subheadline)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: forestGreen.opacity(0.08), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(forestGreen.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [softGreen.opacity(0.5), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // 症状分类筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.name) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category.name
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 11))
                                Text(category.name)
                                    .font(.caption)
                                    .fontWeight(selectedCategory == category.name ? .semibold : .regular)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category.name ?
                                LinearGradient(colors: [forestGreen, leafGreen], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.white, Color.white], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(selectedCategory == category.name ? .white : forestGreen)
                            .cornerRadius(20)
                            .shadow(color: selectedCategory == category.name ? forestGreen.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedCategory == category.name ? Color.clear : forestGreen.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.white)
            
            // 结果统计
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.caption)
                        .foregroundColor(forestGreen)
                    Text("找到 \(filteredSymptoms.count) 个相关症状")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selectedCategory != "全部" || !searchText.isEmpty {
                    Button {
                        withAnimation {
                            selectedCategory = "全部"
                            searchText = ""
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                            Text("重置")
                                .font(.caption)
                        }
                        .foregroundColor(forestGreen)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            
            // 症状列表
            if filteredSymptoms.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bird")
                        .font(.system(size: 50))
                        .foregroundColor(forestGreen.opacity(0.3))
                    Text("未找到相关症状")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text("试试其他关键词或分类吧")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredSymptoms) { symptom in
                        SymptomCard(symptom: symptom, forestGreen: forestGreen) {
                            selectedSymptom = symptom
                        }
                    }
                }
                .padding(16)
            }
            
            // 底部提示区域
            VStack(spacing: 12) {
                // 温馨提示
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(forestGreen.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(forestGreen)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("温馨提示")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(forestGreen)
                        Text("以上信息仅供参考，如症状严重或持续请咨询专业兽医")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(forestGreen.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(forestGreen.opacity(0.15), lineWidth: 1)
                        )
                )
                
                // 就医提示
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(leafGreen.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 16))
                            .foregroundColor(leafGreen)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("需要就医")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(leafGreen)
                        Text("抽搐、出血、呼吸困难等情况请及时联系兽医")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(leafGreen.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(leafGreen.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGray6).opacity(0.3))
        .sheet(item: $selectedSymptom) { symptom in
            SymptomDetailView(symptom: symptom)
        }
    }
}

// 症状卡片
struct SymptomCard: View {
    let symptom: BirdSymptom
    let forestGreen: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 图标（保持绿色主题）
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [forestGreen.opacity(0.12), forestGreen.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: symptom.icon)
                        .font(.system(size: 22))
                        .foregroundColor(forestGreen)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(symptom.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // 严重程度标签（用红黄绿区分）
                        HStack(spacing: 3) {
                            Circle()
                                .fill(symptom.severityColor)
                                .frame(width: 6, height: 6)
                            Text(symptom.severityText)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(symptom.severityColor.opacity(0.12))
                        .foregroundColor(symptom.severityColor)
                        .cornerRadius(10)
                    }
                    
                    Text(symptom.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(forestGreen.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(forestGreen.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// 症状详情视图
struct SymptomDetailView: View {
    let symptom: BirdSymptom
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 头部
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(symptom.severityColor.opacity(0.15))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: symptom.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(symptom.severityColor)
                            )
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(symptom.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 8) {
                                Text(symptom.severityText)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(symptom.severityColor.opacity(0.15))
                                    .foregroundColor(symptom.severityColor)
                                    .cornerRadius(6)
                                
                                Text(symptom.category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // 症状描述
                    DetailSection(title: "症状描述", icon: "doc.text") {
                        Text(symptom.description)
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.85))
                    }
                    
                    // 可能原因
                    DetailSection(title: "可能原因", icon: "questionmark.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(symptom.possibleCauses, id: \.self) { cause in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(cause)
                                        .font(.subheadline)
                                        .foregroundColor(.primary.opacity(0.85))
                                }
                            }
                        }
                    }
                    
                    // 处理建议
                    DetailSection(title: "处理建议", icon: "lightbulb") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(symptom.suggestions.enumerated()), id: \.offset) { index, suggestion in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Color(red: 0.25, green: 0.42, blue: 0.35))
                                        .cornerRadius(10)
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .foregroundColor(.primary.opacity(0.85))
                                }
                            }
                        }
                    }
                    
                    // 何时就医
                    DetailSection(title: "何时需要就医", icon: "cross.case") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(symptom.whenToSeeVet, id: \.self) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 14))
                                        .padding(.top, 2)
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundColor(.primary.opacity(0.85))
                                }
                            }
                        }
                    }
                    
                    // 预防措施
                    if !symptom.prevention.isEmpty {
                        DetailSection(title: "预防措施", icon: "shield.checkered") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(symptom.prevention, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14))
                                            .padding(.top, 2)
                                        Text(item)
                                            .font(.subheadline)
                                            .foregroundColor(.primary.opacity(0.85))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("症状详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 详情区块
struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Color(red: 0.25, green: 0.42, blue: 0.35))
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// 鸟类症状数据模型
struct BirdSymptom: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let severity: Severity
    let category: String
    let possibleCauses: [String]
    let suggestions: [String]
    let whenToSeeVet: [String]
    let prevention: [String]
    
    enum Severity {
        case low, medium, high
    }
    
    // 标签颜色（红黄绿）
    var severityColor: Color {
        switch severity {
        case .low: return Color(red: 0.35, green: 0.65, blue: 0.45)    // 绿色 - 轻微
        case .medium: return Color(red: 0.90, green: 0.70, blue: 0.20) // 黄色 - 留意
        case .high: return Color(red: 0.85, green: 0.35, blue: 0.35)   // 红色 - 关注
        }
    }
    
    var severityText: String {
        switch severity {
        case .low: return "轻微"
        case .medium: return "留意"
        case .high: return "关注"
        }
    }
    
    // 所有症状和疾病数据（基于专业兽医资料整理）
    static let allSymptoms: [BirdSymptom] = [
        // ========== 常见症状 ==========
        BirdSymptom(
            name: "羽毛蓬松/炸毛",
            description: "鸟儿羽毛持续蓬松、炸毛，看起来像个毛球。这是鸟类身体不适的重要信号，通过蓬松羽毛来保持体温。健康的鸟只有在休息或睡觉时才会短暂蓬松羽毛。",
            icon: "wind",
            severity: .medium,
            category: "综合症状",
            possibleCauses: [
                "环境温度过低，鸟儿通过蓬松羽毛保暖（正常温度应在20-28°C）",
                "感冒或呼吸道感染的早期症状",
                "消化系统疾病如肠炎、嗉囊炎",
                "寄生虫感染（体内或体外）",
                "细菌或病毒感染",
                "营养不良或维生素缺乏",
                "受到惊吓或应激反应（短暂性）"
            ],
            suggestions: [
                "立即检查环境温度，保持在22-28°C之间",
                "将鸟笼移至避风温暖处，可用布部分遮盖保温",
                "仔细观察是否伴随其他症状：拉稀、不吃东西、呕吐、打喷嚏等",
                "检查粪便颜色和形状是否正常",
                "提供温水和易消化的食物",
                "减少惊扰，保持环境安静"
            ],
            whenToSeeVet: [
                "持续蓬松超过6-12小时且无好转",
                "伴随食欲下降或完全拒食",
                "伴随腹泻、呕吐或异常粪便",
                "精神极度萎靡，眼睛无神",
                "站立不稳或趴在笼底",
                "呼吸急促或张嘴呼吸"
            ],
            prevention: [
                "保持适宜稳定的环境温度（22-28°C）",
                "避免将鸟笼放在空调直吹或窗边",
                "定期清洁消毒鸟笼",
                "提供均衡营养的饮食",
                "定期观察鸟的精神状态"
            ]
        ),
        BirdSymptom(
            name: "食欲下降/拒食",
            description: "鸟儿进食量明显减少或完全不吃东西。由于鸟类新陈代谢快，24小时不进食可能危及生命。食欲下降往往是多种疾病的早期信号。",
            icon: "fork.knife",
            severity: .high,
            category: "消化系统",
            possibleCauses: [
                "嗉囊炎或嗉囊积食（嗉囊膨大、有酸臭味）",
                "肠炎（常伴随腹泻）",
                "念珠菌感染（口腔可能有白色斑点）",
                "呼吸道感染影响进食",
                "口腔溃疡或喙部问题",
                "寄生虫感染（滴虫、球虫等）",
                "食物变质或不新鲜",
                "环境应激（新环境、惊吓等）",
                "中毒"
            ],
            suggestions: [
                "检查嗉囊是否膨大或有硬块（正常应柔软）",
                "检查口腔是否有白色斑点或异味",
                "更换新鲜食物和干净饮水",
                "尝试喂食鸟儿平时最喜欢的食物",
                "观察并记录粪便情况",
                "保持环境温暖（25-28°C）",
                "可尝试用注射器（去针头）滴喂少量温葡萄糖水"
            ],
            whenToSeeVet: [
                "超过12-24小时不进食（紧急！）",
                "嗉囊肿胀、有酸臭味或触摸有硬块",
                "体重明显下降（超过10%）",
                "伴随呕吐或严重腹泻",
                "口腔有白色斑点或溃疡",
                "精神萎靡，反应迟钝"
            ],
            prevention: [
                "每天提供新鲜食物和干净饮水",
                "定期清洗消毒食盆和水盆",
                "保持规律的喂食时间",
                "定期称重监测健康状况",
                "避免喂食变质或不适合的食物"
            ]
        ),
        BirdSymptom(
            name: "腹泻/拉稀",
            description: "粪便呈水样或稀糊状，颜色可能异常（绿色、黄色、白色或带血），排便次数增多。正常鸟粪应该是成形的，中间白色（尿酸）周围深色（粪便）。",
            icon: "drop.triangle",
            severity: .high,
            category: "消化系统",
            possibleCauses: [
                "细菌性肠炎（大肠杆菌、沙门氏菌等）",
                "病毒感染",
                "寄生虫感染（球虫、滴虫等）",
                "念珠菌或其他真菌感染",
                "食物不洁、变质或中毒",
                "饮食突然改变",
                "应激反应",
                "摄入过多水分或水果",
                "抗生素使用后菌群失调"
            ],
            suggestions: [
                "立即停止喂食水果、蔬菜和油性食物",
                "只提供干净的谷物和清水",
                "可在饮水中加入少量电解质补充液",
                "保持环境温暖（25-28°C），避免受凉",
                "及时清理粪便，保持笼内清洁干燥",
                "观察并记录粪便颜色、性状和频率",
                "隔离病鸟，防止传染"
            ],
            whenToSeeVet: [
                "腹泻持续超过12-24小时",
                "粪便带血或呈黑色（可能内出血）",
                "粪便呈黄绿色水样且恶臭",
                "伴随呕吐或完全拒食",
                "精神萎靡，羽毛蓬松",
                "体重快速下降",
                "肛门周围被粪便污染严重"
            ],
            prevention: [
                "每天更换新鲜食物和饮水",
                "定期清洗消毒食盆、水盆和鸟笼",
                "避免突然更换食物种类",
                "新鸟隔离观察2-4周后再合群",
                "定期驱虫（遵医嘱）",
                "夏季特别注意食物保鲜"
            ]
        ),
        BirdSymptom(
            name: "呕吐/甩头吐食",
            description: "鸟儿频繁甩头并吐出食物或粘液。需区分正常的求偶喂食行为和病理性呕吐。病理性呕吐通常伴随精神萎靡，呕吐物可能有异味。",
            icon: "arrow.up.heart",
            severity: .high,
            category: "消化系统",
            possibleCauses: [
                "嗉囊炎（最常见原因）",
                "嗉囊积食或阻塞",
                "念珠菌感染",
                "细菌性感染",
                "寄生虫感染（滴虫等）",
                "中毒（重金属、有毒植物等）",
                "异物吞入",
                "胃部酵母菌过度繁殖"
            ],
            suggestions: [
                "立即停止喂食，让嗉囊休息",
                "检查嗉囊是否膨大、有硬块或异味",
                "轻轻触摸嗉囊，正常应柔软无硬块",
                "检查呕吐物的颜色和气味",
                "保持环境温暖安静",
                "如嗉囊积食，可轻柔按摩帮助消化（需谨慎）"
            ],
            whenToSeeVet: [
                "频繁呕吐超过2-3次",
                "呕吐物有酸臭味或异常颜色",
                "嗉囊明显肿胀或有硬块",
                "伴随腹泻或拒食",
                "精神萎靡，羽毛蓬松",
                "怀疑吞入异物或中毒"
            ],
            prevention: [
                "控制喂食量，避免过度喂食",
                "手养幼鸟时注意奶温和喂食速度",
                "确保嗉囊排空后再喂下一餐",
                "提供易消化的食物",
                "避免接触有毒物质"
            ]
        ),
        BirdSymptom(
            name: "呼吸困难/张嘴呼吸",
            description: "鸟儿张嘴呼吸、呼吸急促、尾巴随呼吸上下摆动，可能有喘息声或呼吸杂音。这是紧急情况，需立即处理。",
            icon: "lungs",
            severity: .high,
            category: "呼吸系统",
            possibleCauses: [
                "呼吸道感染（细菌、病毒、真菌）",
                "曲霉菌病（真菌性肺炎，常见且危险）",
                "气囊炎",
                "肺炎",
                "鹦鹉热/衣原体感染",
                "异物卡住气管",
                "心脏疾病",
                "特氟龙中毒（不粘锅过热产生的烟雾）",
                "过度肥胖压迫呼吸系统",
                "窦炎（眼睛下方肿胀）"
            ],
            suggestions: [
                "这是紧急情况，应尽快就医！",
                "立即将鸟儿移至安静、温暖、通风的环境",
                "远离任何烟雾、香水、清洁剂等刺激源",
                "保持空气流通但避免冷风直吹",
                "不要强迫喂食或喂水",
                "减少惊扰，让鸟保持安静"
            ],
            whenToSeeVet: [
                "出现呼吸困难症状应立即就医！",
                "张嘴呼吸持续不缓解",
                "呼吸时有明显杂音或喘息声",
                "尾巴随呼吸明显上下摆动",
                "嘴唇、舌头或脚爪发紫（缺氧）",
                "眼睛下方或鼻孔周围肿胀"
            ],
            prevention: [
                "绝对避免使用不粘锅等含特氟龙的厨具（过热会释放致命毒气）",
                "保持空气清新，避免烟雾、香水、杀虫剂",
                "定期清洁鸟笼，避免霉菌滋生",
                "保持适宜的温湿度",
                "定期体检，早期发现问题"
            ]
        ),
        BirdSymptom(
            name: "打喷嚏/流鼻涕",
            description: "鸟儿打喷嚏，鼻孔周围可能有分泌物或结痂。偶尔打喷嚏可能是灰尘刺激，但频繁打喷嚏需要重视。",
            icon: "nose",
            severity: .medium,
            category: "呼吸系统",
            possibleCauses: [
                "感冒（受凉、温度变化）",
                "上呼吸道感染",
                "窦炎",
                "空气中灰尘或异物刺激",
                "环境过于干燥",
                "对某些物质过敏",
                "维生素A缺乏",
                "鹦鹉热/衣原体感染（人畜共患病）"
            ],
            suggestions: [
                "检查鼻孔是否通畅，有无分泌物",
                "将鸟笼移至避风温暖处（22-25°C）",
                "保持适当的空气湿度（50-60%）",
                "避免在鸟儿附近使用香水、清洁剂、杀虫剂",
                "如鼻孔有分泌物，可用棉签轻轻清理",
                "确保通风良好但避免直吹冷风"
            ],
            whenToSeeVet: [
                "频繁打喷嚏，每天多次",
                "鼻孔有明显分泌物或结痂",
                "伴随呼吸困难或张嘴呼吸",
                "伴随眼睛红肿或流泪",
                "精神萎靡，食欲下降",
                "症状持续超过2-3天"
            ],
            prevention: [
                "保持环境清洁，定期除尘",
                "避免使用有刺激性气味的物品",
                "保持适宜的温湿度，避免温差过大",
                "提供富含维生素A的食物（如胡萝卜）"
            ]
        ),
        
        // ========== 常见疾病 ==========
        BirdSymptom(
            name: "嗉囊炎/嗉囊积食",
            description: "嗉囊是鸟类食道的膨大部分，用于暂存和软化食物。嗉囊炎是最常见的消化道疾病之一，尤其多发于幼鸟。表现为嗉囊膨大、食物不消化、有酸臭味。",
            icon: "stomach",
            severity: .high,
            category: "消化系统疾病",
            possibleCauses: [
                "过度喂食或喂食过快（尤其是手养幼鸟）",
                "食物温度不当（过冷或过热）",
                "食物变质或不洁",
                "细菌感染（大肠杆菌等）",
                "念珠菌感染",
                "寄生虫（滴虫）感染",
                "异物吞入",
                "维生素和无机盐缺乏",
                "嗉囊肌肉功能障碍"
            ],
            suggestions: [
                "立即停止喂食，让嗉囊休息6-12小时",
                "轻轻触摸嗉囊检查：正常应柔软，积食时有硬块",
                "轻症可喂服酵母片或乳酶生助消化",
                "可滴入少量温水或植物油软化食物",
                "轻柔按摩嗉囊帮助消化（从上往下）",
                "保持环境温暖（25-28°C）",
                "严重时需要洗胃，必须就医处理"
            ],
            whenToSeeVet: [
                "嗉囊明显膨大超过12小时不消退",
                "嗉囊有酸臭味",
                "口腔有粘稠液体流出",
                "完全拒食或频繁呕吐",
                "精神极度萎靡",
                "怀疑吞入异物"
            ],
            prevention: [
                "手养幼鸟时控制喂食量和速度",
                "确保食物温度适宜（38-40°C）",
                "等嗉囊排空后再喂下一餐",
                "保持食物和器具清洁",
                "提供易消化的食物"
            ]
        ),
        BirdSymptom(
            name: "肠炎",
            description: "肠炎是鸟类最常见的消化道疾病，主要表现为腹泻。由细菌、病毒、寄生虫感染或食物不洁引起。夏季高发。",
            icon: "microbe",
            severity: .high,
            category: "消化系统疾病",
            possibleCauses: [
                "细菌感染（大肠杆菌、沙门氏菌等）",
                "病毒感染",
                "寄生虫感染（球虫、滴虫等）",
                "食物不洁、变质或发霉",
                "饮水不清洁",
                "季节变化、气候突变",
                "受寒"
            ],
            suggestions: [
                "立即隔离病鸟",
                "停止喂食水果蔬菜，只给干净谷物",
                "提供干净饮水，可加入少量电解质",
                "保持环境温暖干燥",
                "及时清理粪便，消毒鸟笼",
                "可在饮水中加入0.1%土霉素（遵医嘱）",
                "严重脱水时需补充葡萄糖盐水"
            ],
            whenToSeeVet: [
                "腹泻持续超过24小时",
                "粪便带血或呈黑色",
                "严重水样便",
                "伴随呕吐",
                "精神萎靡，羽毛蓬松",
                "体重快速下降"
            ],
            prevention: [
                "每天更换新鲜食物和饮水",
                "夏季特别注意食物保鲜",
                "定期清洗消毒食盆水盆",
                "保持鸟笼清洁干燥",
                "新鸟隔离观察后再合群"
            ]
        ),
        BirdSymptom(
            name: "念珠菌感染",
            description: "白色念珠菌是一种机会性真菌，正常存在于鸟类消化道。当鸟抵抗力下降或菌群失调时会过度繁殖致病。幼鸟和使用抗生素后的鸟更易感染。",
            icon: "allergens",
            severity: .high,
            category: "真菌感染",
            possibleCauses: [
                "抵抗力下降",
                "长期使用抗生素导致菌群失调",
                "营养不良",
                "环境卫生差",
                "手养幼鸟喂食器具不洁",
                "应激",
                "其他疾病继发"
            ],
            suggestions: [
                "检查口腔是否有白色斑点或假膜",
                "检查嗉囊是否有异味",
                "停止使用抗生素（如正在使用）",
                "保持环境清洁干燥",
                "提供均衡营养",
                "需使用抗真菌药物治疗（制霉菌素等，遵医嘱）",
                "同时补充益生菌和维生素B族"
            ],
            whenToSeeVet: [
                "口腔有白色斑点或假膜",
                "嗉囊有酸臭味",
                "频繁呕吐，食物未消化",
                "严重腹泻",
                "精神萎靡，消瘦",
                "幼鸟生长迟缓"
            ],
            prevention: [
                "保持食物和器具清洁",
                "避免滥用抗生素",
                "提供均衡营养",
                "保持环境干燥通风",
                "定期消毒鸟笼和用具"
            ]
        ),
        BirdSymptom(
            name: "感冒/上呼吸道感染",
            description: "鸟类感冒多发于秋冬季节，由温度变化、受凉或细菌感染引起。表现为打喷嚏、流鼻涕、精神萎靡。如不及时治疗可能发展为肺炎。",
            icon: "thermometer.snowflake",
            severity: .medium,
            category: "呼吸系统疾病",
            possibleCauses: [
                "气温急剧变化",
                "受凉或淋雨",
                "冷风直吹",
                "环境温度过低",
                "细菌感染"
            ],
            suggestions: [
                "立即将鸟笼移至避风温暖处",
                "保持室内温度稳定在22-25°C",
                "如鼻孔有分泌物，用棉签轻轻清理",
                "可用1%麻黄素溶液或植物油滴鼻通畅呼吸",
                "可在饲料中加入0.1-0.2%磺胺嘧啶，连喂3天",
                "或在饮水中加0.2%感冒通，连喂3-5天",
                "多喂些面包虫等营养食物"
            ],
            whenToSeeVet: [
                "症状持续超过3天不见好转",
                "出现呼吸困难或张嘴呼吸",
                "鼻孔被粘稠分泌物堵塞",
                "精神极度萎靡",
                "伴随其他症状如腹泻"
            ],
            prevention: [
                "避免将鸟笼放在空调直吹或窗边",
                "秋冬季节注意保暖",
                "避免温度剧烈变化",
                "保持环境通风但避免冷风直吹"
            ]
        ),
        BirdSymptom(
            name: "肺炎",
            description: "肺炎是严重的呼吸道疾病，可由感冒发展而来，也可由细菌、真菌或病毒直接感染引起。死亡率较高，需及时治疗。",
            icon: "waveform.path.ecg",
            severity: .high,
            category: "呼吸系统疾病",
            possibleCauses: [
                "感冒治疗不及时恶化",
                "细菌感染（多杀性巴氏杆菌、大肠杆菌、肺炎双球菌等）",
                "曲霉菌等真菌感染",
                "病毒感染",
                "体质下降、抗病力降低"
            ],
            suggestions: [
                "这是严重疾病，应尽快就医！",
                "将鸟放在暖和避风处，温度保持在22-25°C",
                "加强护理，喂给易消化的食物和活虫",
                "可用泰乐菌素治疗（混料0.05-0.08%，连服5天）",
                "或用庆大霉素加在饮水中（每次5-10滴，每天2次，连喂5-7天）",
                "补充体液：用滴管滴入葡萄糖水，每次0.5ml，每天2-3次"
            ],
            whenToSeeVet: [
                "呼吸急促、气喘",
                "身体随呼吸颤抖",
                "全身缩起呈球状",
                "精神极度萎靡，食欲废绝",
                "体温明显升高"
            ],
            prevention: [
                "感冒要及时治疗，防止恶化",
                "保持环境温暖稳定",
                "加强营养，提高抵抗力",
                "保持环境清洁卫生"
            ]
        ),
        BirdSymptom(
            name: "曲霉菌病",
            description: "曲霉菌病是由曲霉菌引起的真菌性呼吸道感染，主要侵害气囊和肺部。环境潮湿、通风不良、饲料发霉是主要诱因。此病较难治愈，重在预防。",
            icon: "aqi.medium",
            severity: .high,
            category: "真菌感染",
            possibleCauses: [
                "环境潮湿、通风不良",
                "饲料发霉",
                "垫料潮湿发霉",
                "鸟笼清洁不彻底",
                "抵抗力下降",
                "长期使用抗生素"
            ],
            suggestions: [
                "此病治疗困难，必须就医！",
                "改善环境通风，降低湿度",
                "彻底清洁消毒鸟笼",
                "更换所有饲料和垫料",
                "检查并丢弃任何发霉的食物",
                "需使用抗真菌药物治疗（两性霉素B、伊曲康唑等，遵医嘱）"
            ],
            whenToSeeVet: [
                "呼吸困难、张嘴呼吸",
                "呼吸时有杂音",
                "精神萎靡，食欲下降",
                "消瘦",
                "症状持续不见好转"
            ],
            prevention: [
                "保持环境干燥通风（这是最重要的！）",
                "定期检查饲料，丢弃任何发霉的食物",
                "定期清洁消毒鸟笼",
                "保持垫料干燥，定期更换",
                "避免滥用抗生素"
            ]
        ),
        BirdSymptom(
            name: "滴虫病",
            description: "滴虫病是由毛滴虫引起的寄生虫病，主要侵害消化道和呼吸道。通过污染的饮水和食物传播，也可通过亲鸟喂食传给幼鸟。",
            icon: "ant",
            severity: .high,
            category: "寄生虫病",
            possibleCauses: [
                "饮水或食物被滴虫污染",
                "与感染鸟接触",
                "亲鸟喂食传播给幼鸟",
                "环境卫生差"
            ],
            suggestions: [
                "需要显微镜检查确诊",
                "隔离病鸟",
                "使用甲硝唑治疗（遵医嘱）",
                "彻底清洁消毒环境",
                "更换所有饮水和食物",
                "治疗期间注意环境消毒"
            ],
            whenToSeeVet: [
                "口腔有黄白色干酪样物质",
                "吞咽困难",
                "频繁呕吐",
                "嗉囊肿胀",
                "呼吸困难（严重时）",
                "消瘦、精神萎靡"
            ],
            prevention: [
                "保持饮水清洁，每天更换",
                "定期清洁消毒水盆",
                "新鸟隔离检疫",
                "避免与野鸟接触",
                "定期驱虫检查"
            ]
        ),
        BirdSymptom(
            name: "啄羽症/自残",
            description: "鸟儿频繁啄自己或同伴的羽毛，导致羽毛脱落、皮肤裸露甚至出血。这是一种复杂的行为问题，可能由生理或心理因素引起。",
            icon: "hand.raised.slash",
            severity: .medium,
            category: "行为异常",
            possibleCauses: [
                "营养缺乏（氨基酸、维生素B族、锌、硫等）",
                "体外寄生虫（羽虱、螨虫）刺激",
                "皮肤病",
                "无聊、缺乏刺激",
                "焦虑、压力过大",
                "笼内密度过大",
                "光照过强或过热",
                "激素变化（发情期）"
            ],
            suggestions: [
                "检查是否有体外寄生虫",
                "调整饲料配比，增加蛋黄、维生素、微量元素",
                "加喂羽毛粉和钙粉",
                "提供新鲜水果蔬菜",
                "增加玩具和互动时间",
                "如有寄生虫，使用相应药物治疗",
                "保持适当的光照和温度"
            ],
            whenToSeeVet: [
                "皮肤出现伤口或出血",
                "大面积羽毛脱落",
                "发现寄生虫",
                "伴随其他异常症状",
                "行为持续恶化"
            ],
            prevention: [
                "提供均衡营养的饮食",
                "定期检查和预防体外寄生虫",
                "提供丰富的环境刺激",
                "保持规律的互动时间",
                "避免笼内过度拥挤"
            ]
        ),
        BirdSymptom(
            name: "结膜炎/眼炎",
            description: "眼睛红肿、流泪、有分泌物，眼睑可能肿胀粘连。可由外伤、异物、感染或维生素缺乏引起。",
            icon: "eye",
            severity: .medium,
            category: "眼部疾病",
            possibleCauses: [
                "细菌或病毒感染",
                "异物进入眼睛",
                "眼部外伤",
                "维生素A缺乏",
                "上呼吸道感染蔓延",
                "窦炎继发"
            ],
            suggestions: [
                "将鸟笼移至暗处，减少光线刺激",
                "用1-2%硼酸溶液或生理盐水冲洗患眼",
                "滴入金霉素、氯霉素或土霉素眼药水/眼膏",
                "每天3-6次",
                "在饲料中添加维生素A或鱼肝油"
            ],
            whenToSeeVet: [
                "眼睛明显红肿或有脓性分泌物",
                "眼睛无法睁开",
                "上下眼睑粘连",
                "视力似乎受到影响",
                "症状持续超过2-3天",
                "伴随其他症状"
            ],
            prevention: [
                "保持环境清洁，减少灰尘",
                "提供富含维生素A的食物",
                "避免尖锐物品伤害",
                "定期检查眼睛健康"
            ]
        ),
        BirdSymptom(
            name: "中暑",
            description: "夏季高温时，如果环境闷热、通风差、饮水不足，鸟类容易中暑。鸟没有汗腺，散热困难，中暑可在几分钟内致死。",
            icon: "sun.max.trianglebadge.exclamationmark",
            severity: .high,
            category: "环境相关",
            possibleCauses: [
                "环境温度过高",
                "通风不良、闷热",
                "阳光直射",
                "饮水供给不足",
                "运输过程中拥挤闷热"
            ],
            suggestions: [
                "这是紧急情况！",
                "立即将鸟笼移至阴凉通风处",
                "每隔一段时间喷洒冷水降温",
                "提供清凉的饮水",
                "可在绿豆汤中加1-2滴十滴水灌服",
                "严重时可在翅膀静脉处放血（需专业操作）"
            ],
            whenToSeeVet: [
                "出现中暑症状应紧急处理",
                "呼吸急促、张口喘气",
                "翅膀张开下垂",
                "站立不稳、虚脱",
                "抽搐或痉挛"
            ],
            prevention: [
                "夏季将鸟笼放在凉爽通风处",
                "避免阳光直射",
                "每天提供充足清凉的饮水",
                "闷热天气可每天给鸟洗浴1次",
                "经常观察鸟的状态"
            ]
        ),
        BirdSymptom(
            name: "尾脂腺炎（生黄）",
            description: "尾脂腺位于鸟尾部上方，分泌油脂用于梳理羽毛。当腺体阻塞发炎时，会红肿化脓。常见于画眉、百灵等鸟类。",
            icon: "drop.fill",
            severity: .medium,
            category: "皮肤疾病",
            possibleCauses: [
                "缺乏沙浴或水浴",
                "尾部受伤感染",
                "长期不理羽毛导致腺体阻塞",
                "患病期间不梳理羽毛"
            ],
            suggestions: [
                "用5%碘酊和75%酒精消毒患处",
                "用消毒针刺破尾脂腺尖",
                "轻轻挤压排出阻塞的分泌物",
                "用脱脂棉擦净后涂5%碘酊消毒",
                "半天内不要喂水",
                "痊愈前停止沙浴、水浴",
                "多喂营养丰富的食物"
            ],
            whenToSeeVet: [
                "尾脂腺明显红肿化脓",
                "有大量脓性分泌物",
                "伴随发热、精神萎靡",
                "自行处理后不见好转"
            ],
            prevention: [
                "定期提供沙浴或水浴",
                "保持鸟笼清洁",
                "观察鸟是否正常梳理羽毛"
            ]
        ),
        BirdSymptom(
            name: "趾炎/脚部感染",
            description: "脚趾红肿、发热、疼痛，严重时化脓甚至趾骨脱落。多因脚部受伤后被粪便污染感染引起。",
            icon: "figure.stand",
            severity: .medium,
            category: "外伤感染",
            possibleCauses: [
                "脚掌被粗糙的栖木或笼底划伤",
                "伤口被粪便污染感染",
                "葡萄球菌感染",
                "冻伤",
                "笼内卫生差"
            ],
            suggestions: [
                "用0.5%高锰酸钾水或盐水浸泡患脚1-2分钟",
                "涂抹碘酒或红药水",
                "可涂四环素、金霉素或红霉素软膏",
                "在饲料中加喂螺旋霉素或氟哌酸（遵医嘱）",
                "保持鸟笼清洁"
            ],
            whenToSeeVet: [
                "脚趾明显肿胀化脓",
                "无法正常站立或抓握",
                "有干酪样渗出物",
                "症状持续恶化"
            ],
            prevention: [
                "使用光滑适当粗细的栖木",
                "每天清理鸟笼粪便",
                "定期消毒鸟笼",
                "冬季注意保暖防冻"
            ]
        ),
        
        // ========== 病毒性疾病 ==========
        BirdSymptom(
            name: "鹦鹉喙羽症(PBFD)",
            description: "由圆环病毒引起的致死性传染病，主要影响羽毛和喙部。病毒攻击羽毛毛囊、喙和爪基质，导致进行性羽毛、爪和喙的畸形和坏死。多见于3岁以下幼鸟，目前无法治愈。",
            icon: "exclamationmark.shield",
            severity: .high,
            category: "病毒性疾病",
            possibleCauses: [
                "圆环病毒(Circovirus)感染",
                "通过粪便、羽毛屑、嗉囊分泌物传播",
                "垂直传播（母鸟传给幼鸟）",
                "与感染鸟接触"
            ],
            suggestions: [
                "目前无法治愈，只能支持性治疗",
                "立即隔离疑似感染鸟",
                "加强营养支持，提高免疫力",
                "保持环境清洁",
                "定期检测，早期发现",
                "考虑安乐死以防止传播（严重情况）"
            ],
            whenToSeeVet: [
                "羽毛异常脱落或变形",
                "新长出的羽毛畸形、卷曲或断裂",
                "喙部变形、过度生长或断裂",
                "羽毛颜色异常改变",
                "免疫力下降，反复感染"
            ],
            prevention: [
                "新鸟隔离检疫至少30天",
                "购买前进行PBFD检测",
                "避免与野鸟接触",
                "定期消毒鸟笼和用具",
                "不与来源不明的鸟混养"
            ]
        ),
        BirdSymptom(
            name: "多瘤病毒感染",
            description: "多瘤病毒(APV)主要影响幼鸟，可导致突然死亡。成年鸟可能携带病毒但无症状。幼鸟感染后死亡率极高，存活者可能出现羽毛发育异常。",
            icon: "bolt.trianglebadge.exclamationmark",
            severity: .high,
            category: "病毒性疾病",
            possibleCauses: [
                "多瘤病毒感染",
                "通过粪便、羽毛、嗉囊分泌物传播",
                "垂直传播",
                "与感染鸟或其排泄物接触"
            ],
            suggestions: [
                "目前无特效治疗",
                "立即隔离病鸟",
                "支持性治疗：保温、补液、营养支持",
                "彻底消毒环境",
                "存活幼鸟可能终身携带病毒"
            ],
            whenToSeeVet: [
                "幼鸟突然死亡",
                "食欲废绝、呕吐",
                "体重下降、消瘦",
                "皮下出血点",
                "羽毛发育异常（存活者）",
                "腹部肿胀"
            ],
            prevention: [
                "可接种疫苗预防",
                "新鸟严格隔离检疫",
                "繁殖前进行病毒检测",
                "保持严格的卫生管理",
                "避免不同来源的鸟混养"
            ]
        ),
        BirdSymptom(
            name: "前胃扩张症(PDD)",
            description: "又称鸟类博尔纳病，由禽博尔纳病毒引起，主要影响消化系统和神经系统。病毒导致前胃（腺胃）扩张，食物无法正常消化。此病目前无法治愈，预后较差。",
            icon: "waveform.path.ecg.rectangle",
            severity: .high,
            category: "病毒性疾病",
            possibleCauses: [
                "禽博尔纳病毒(ABV)感染",
                "通过粪便传播",
                "可能通过羽毛屑传播",
                "发病机制尚未完全明确"
            ],
            suggestions: [
                "目前无法治愈",
                "使用非甾体抗炎药可能缓解症状",
                "提供易消化的食物",
                "少量多餐",
                "保持环境安静，减少应激",
                "隔离病鸟"
            ],
            whenToSeeVet: [
                "频繁呕吐，吐出未消化的食物",
                "粪便中有未消化的种子",
                "体重持续下降",
                "嗉囊排空缓慢",
                "神经症状：共济失调、震颤、抽搐",
                "头部倾斜或转圈"
            ],
            prevention: [
                "新鸟隔离检疫",
                "避免与感染鸟接触",
                "保持良好的卫生习惯",
                "定期健康检查"
            ]
        ),
        
        // ========== 细菌性疾病 ==========
        BirdSymptom(
            name: "鹦鹉热/衣原体病",
            description: "由鹦鹉热衣原体引起的人畜共患病，可传染给人类。病鸟可能长期带菌排毒。人感染后出现类似流感的症状，严重可致肺炎。养鸟者需特别注意防护。",
            icon: "person.badge.shield.checkmark",
            severity: .high,
            category: "细菌性疾病",
            possibleCauses: [
                "鹦鹉热衣原体(Chlamydia psittaci)感染",
                "吸入含病原体的粉尘（干燥粪便、羽毛屑）",
                "与感染鸟密切接触",
                "应激可激活潜伏感染"
            ],
            suggestions: [
                "立即隔离病鸟",
                "使用抗生素治疗（四环素类，遵医嘱）",
                "治疗周期通常需要45天",
                "人员接触时戴口罩",
                "彻底消毒环境（2%漂白粉或5%甲酚皂液）",
                "如人出现流感样症状需就医并告知养鸟史"
            ],
            whenToSeeVet: [
                "绿色腹泻",
                "鼻腔分泌物",
                "呼吸困难",
                "眼睛红肿、流泪",
                "精神萎靡、食欲下降",
                "羽毛蓬松"
            ],
            prevention: [
                "新鸟隔离检疫并检测",
                "保持良好通风",
                "清理鸟笼时戴口罩",
                "定期消毒",
                "避免鸟粪干燥后扬尘"
            ]
        ),
        BirdSymptom(
            name: "禽分枝杆菌病",
            description: "由禽分枝杆菌引起的慢性消耗性疾病，病程长，治疗困难。主要影响消化系统，导致慢性消瘦。有潜在的人畜共患风险。",
            icon: "staroflife",
            severity: .high,
            category: "细菌性疾病",
            possibleCauses: [
                "禽分枝杆菌感染",
                "通过粪便-口腔途径传播",
                "污染的食物和饮水",
                "免疫力低下时易感"
            ],
            suggestions: [
                "治疗非常困难，需长期抗生素",
                "隔离病鸟",
                "彻底消毒环境",
                "考虑安乐死（严重情况）",
                "接触病鸟后注意个人卫生"
            ],
            whenToSeeVet: [
                "慢性消瘦，体重持续下降",
                "腹泻",
                "精神萎靡",
                "羽毛质量下降",
                "腹部可能有肿块"
            ],
            prevention: [
                "新鸟隔离检疫",
                "保持环境清洁",
                "避免与野鸟接触",
                "定期健康检查"
            ]
        ),
        
        // ========== 寄生虫病 ==========
        BirdSymptom(
            name: "球虫病",
            description: "由球虫（艾美耳球虫）引起的肠道寄生虫病，主要通过粪便-口腔途径传播。幼鸟和免疫力低下的鸟更易感染，可导致严重腹泻和死亡。",
            icon: "ant.circle",
            severity: .high,
            category: "寄生虫病",
            possibleCauses: [
                "艾美耳球虫感染",
                "摄入被球虫卵囊污染的食物或水",
                "环境卫生差",
                "免疫力低下"
            ],
            suggestions: [
                "使用抗球虫药物治疗（遵医嘱）",
                "隔离病鸟",
                "彻底清洁消毒环境",
                "保持环境干燥",
                "补充电解质和营养"
            ],
            whenToSeeVet: [
                "血便或带血腹泻",
                "严重腹泻、脱水",
                "体重下降",
                "精神萎靡",
                "幼鸟生长迟缓"
            ],
            prevention: [
                "保持环境清洁干燥",
                "定期清理粪便",
                "避免粪便污染食物和水",
                "新鸟隔离检疫",
                "定期粪便检查"
            ]
        ),
        BirdSymptom(
            name: "贾第虫病",
            description: "由贾第鞭毛虫引起的肠道寄生虫病，可导致皮肤瘙痒、羽毛问题和腹泻。此病为人畜共患病，可通过污染的水源传播给人。",
            icon: "drop.degreesign",
            severity: .medium,
            category: "寄生虫病",
            possibleCauses: [
                "贾第鞭毛虫感染",
                "饮用被污染的水",
                "与感染鸟接触",
                "环境卫生差"
            ],
            suggestions: [
                "使用抗寄生虫药物治疗（甲硝唑等，遵医嘱）",
                "更换干净的饮水",
                "彻底清洁消毒水盆",
                "保持环境清洁"
            ],
            whenToSeeVet: [
                "频繁瘙痒、啄羽",
                "皮肤干燥",
                "腹泻",
                "羽毛质量下降",
                "体重下降"
            ],
            prevention: [
                "提供干净的饮水",
                "定期清洗消毒水盆",
                "保持环境卫生",
                "定期粪便检查"
            ]
        ),
        BirdSymptom(
            name: "气囊螨",
            description: "气囊螨寄生在鸟类的气囊和气管中，导致呼吸困难。常见于雀类和小型鹦鹉。感染严重时可导致窒息死亡。",
            icon: "wind.circle",
            severity: .high,
            category: "寄生虫病",
            possibleCauses: [
                "气囊螨寄生",
                "与感染鸟接触",
                "通过呼吸道传播"
            ],
            suggestions: [
                "需要兽医治疗",
                "使用伊维菌素等药物（遵医嘱）",
                "隔离病鸟",
                "彻底消毒环境"
            ],
            whenToSeeVet: [
                "呼吸时有喘息声或咔嗒声",
                "张嘴呼吸",
                "声音嘶哑或改变",
                "呼吸困难",
                "尾巴随呼吸摆动"
            ],
            prevention: [
                "新鸟隔离检疫",
                "避免与野鸟接触",
                "定期健康检查",
                "保持环境清洁"
            ]
        ),
        BirdSymptom(
            name: "羽虱/羽螨",
            description: "羽虱和羽螨是常见的体外寄生虫，寄生在羽毛和皮肤上，吸食血液或啃食羽毛。导致鸟儿瘙痒、烦躁、羽毛损坏。",
            icon: "ladybug",
            severity: .medium,
            category: "寄生虫病",
            possibleCauses: [
                "与感染鸟接触",
                "从野鸟传播",
                "环境中存在寄生虫",
                "鸟笼和巢箱不清洁"
            ],
            suggestions: [
                "使用鸟类专用杀虫剂或药浴",
                "可用神奇药笔涂抹（注意安全）",
                "彻底清洁消毒鸟笼和巢箱",
                "用开水烫洗巢箱",
                "阳光暴晒鸟笼"
            ],
            whenToSeeVet: [
                "频繁瘙痒、啄羽",
                "羽毛损坏、脱落",
                "皮肤可见寄生虫或虫卵",
                "贫血（严重感染时）",
                "烦躁不安、睡眠差"
            ],
            prevention: [
                "定期检查羽毛和皮肤",
                "保持鸟笼清洁",
                "定期消毒巢箱",
                "新鸟隔离检疫",
                "避免与野鸟接触"
            ]
        ),
        BirdSymptom(
            name: "疥螨病(脸部疥癣)",
            description: "由疥螨(Knemidokoptes)引起，主要侵害喙部、蜡膜、眼周和脚部。形成灰白色蜂窝状或海绵状痂皮，严重时导致喙部变形。常见于虎皮鹦鹉。",
            icon: "face.dashed",
            severity: .medium,
            category: "寄生虫病",
            possibleCauses: [
                "疥螨感染",
                "与感染鸟接触",
                "免疫力低下时易发病",
                "很多鸟携带但不发病"
            ],
            suggestions: [
                "使用伊维菌素治疗（遵医嘱）",
                "可涂抹凡士林或矿物油窒息螨虫",
                "隔离病鸟",
                "彻底消毒鸟笼",
                "治疗需要持续数周"
            ],
            whenToSeeVet: [
                "喙部、蜡膜出现灰白色痂皮",
                "眼周出现结痂",
                "脚部出现鳞片状增厚",
                "喙部变形",
                "严重瘙痒"
            ],
            prevention: [
                "保持鸟儿健康，增强免疫力",
                "新鸟隔离检疫",
                "定期检查喙部和脚部",
                "保持环境清洁"
            ]
        ),
        BirdSymptom(
            name: "蛔虫/绦虫感染",
            description: "肠道寄生虫感染，蛔虫和绦虫是最常见的类型。通过粪便-口腔途径传播，可导致消瘦、腹泻和营养不良。",
            icon: "arrow.triangle.2.circlepath",
            severity: .medium,
            category: "寄生虫病",
            possibleCauses: [
                "摄入被虫卵污染的食物或水",
                "摄入中间宿主（如昆虫）",
                "环境卫生差",
                "与感染鸟接触"
            ],
            suggestions: [
                "使用驱虫药治疗（遵医嘱）",
                "彻底清洁消毒环境",
                "更换所有垫料",
                "定期驱虫"
            ],
            whenToSeeVet: [
                "粪便中可见虫体",
                "体重下降、消瘦",
                "腹泻",
                "精神萎靡",
                "羽毛质量下降"
            ],
            prevention: [
                "定期驱虫（每3-6个月）",
                "保持环境清洁",
                "避免喂食野外捕捉的昆虫",
                "定期粪便检查"
            ]
        ),
        
        // ========== 营养代谢病 ==========
        BirdSymptom(
            name: "维生素A缺乏症",
            description: "维生素A缺乏是鹦鹉最常见的营养问题之一，主要因长期只吃种子饲料导致。影响皮肤、黏膜和免疫系统，增加感染风险。",
            icon: "carrot",
            severity: .medium,
            category: "营养代谢病",
            possibleCauses: [
                "长期只吃种子饲料",
                "饮食单一，缺乏蔬果",
                "吸收障碍"
            ],
            suggestions: [
                "补充维生素A（遵医嘱）",
                "增加富含维生素A的食物：胡萝卜、红薯、深绿色蔬菜",
                "改善饮食结构，增加蔬果比例",
                "可添加鱼肝油",
                "严重者需注射补充"
            ],
            whenToSeeVet: [
                "口腔、鼻腔黏膜增厚",
                "口腔出现白色斑点或脓肿",
                "眼睛问题",
                "呼吸道反复感染",
                "皮肤干燥、羽毛质量差",
                "肾脏问题"
            ],
            prevention: [
                "提供均衡多样的饮食",
                "每天提供新鲜蔬果",
                "不要只喂种子饲料",
                "可使用营养丸补充"
            ]
        ),
        BirdSymptom(
            name: "钙缺乏症/低钙血症",
            description: "钙缺乏会导致骨骼问题、软壳蛋、抽搐等。产蛋期母鸟尤其需要充足的钙。严重时可导致抽搐甚至死亡。",
            icon: "bone",
            severity: .high,
            category: "营养代谢病",
            possibleCauses: [
                "饮食中钙含量不足",
                "维生素D3缺乏（影响钙吸收）",
                "缺乏阳光照射",
                "产蛋期消耗过多"
            ],
            suggestions: [
                "补充钙质：墨鱼骨、钙粉、蛋壳粉",
                "补充维生素D3",
                "适当晒太阳（每天10-15分钟）",
                "严重抽搐需紧急就医",
                "产蛋期加强钙补充"
            ],
            whenToSeeVet: [
                "抽搐、痉挛",
                "站立不稳、无力",
                "软壳蛋或无壳蛋",
                "蛋阻留（难产）",
                "骨折",
                "幼鸟腿部畸形"
            ],
            prevention: [
                "常备墨鱼骨或矿物块",
                "定期补充钙粉",
                "适当晒太阳",
                "产蛋期加强营养"
            ]
        ),
        BirdSymptom(
            name: "脂肪肝病",
            description: "因高脂肪饮食和缺乏运动导致肝脏脂肪堆积。常见于笼养鸟，尤其是只吃种子的鸟。可导致肝功能衰竭。",
            icon: "liver.fill",
            severity: .high,
            category: "营养代谢病",
            possibleCauses: [
                "高脂肪饮食（过多种子、坚果）",
                "缺乏运动",
                "肥胖",
                "遗传因素"
            ],
            suggestions: [
                "调整饮食，减少高脂肪食物",
                "增加蔬果和低脂食物",
                "增加运动量，扩大活动空间",
                "可使用护肝药物（遵医嘱）",
                "定期监测体重"
            ],
            whenToSeeVet: [
                "肥胖",
                "绿色或黄色粪便",
                "腹部肿胀",
                "精神萎靡",
                "喙部或指甲过度生长",
                "羽毛质量下降"
            ],
            prevention: [
                "提供均衡低脂饮食",
                "限制种子和坚果摄入",
                "提供足够的运动空间",
                "定期称重监测"
            ]
        ),
        BirdSymptom(
            name: "肥胖症",
            description: "因过度喂食和缺乏运动导致体内脂肪过多。肥胖会增加心脏病、脂肪肝、关节问题等风险，缩短寿命。",
            icon: "scalemass",
            severity: .medium,
            category: "营养代谢病",
            possibleCauses: [
                "过度喂食",
                "高脂肪饮食",
                "缺乏运动",
                "笼子太小"
            ],
            suggestions: [
                "减少高脂肪食物（种子、坚果）",
                "增加蔬果比例",
                "控制每日食量",
                "增加运动：更大的笼子、放飞时间",
                "逐渐减重，不要突然节食"
            ],
            whenToSeeVet: [
                "明显肥胖，腹部膨大",
                "皮下可见黄色脂肪",
                "活动减少，不爱飞",
                "呼吸急促",
                "胸骨摸不到"
            ],
            prevention: [
                "提供均衡饮食",
                "控制食量",
                "提供足够运动空间",
                "定期称重监测"
            ]
        ),
        BirdSymptom(
            name: "痛风",
            description: "尿酸代谢障碍导致尿酸盐在关节或内脏沉积。分为关节型和内脏型。常见于老年鸟或肾功能不全的鸟。",
            icon: "figure.walk.diamond",
            severity: .high,
            category: "营养代谢病",
            possibleCauses: [
                "高蛋白饮食",
                "肾功能不全",
                "脱水",
                "维生素A缺乏",
                "某些药物影响"
            ],
            suggestions: [
                "降低饮食中蛋白质含量",
                "保证充足饮水",
                "使用降尿酸药物（遵医嘱）",
                "治疗原发病（如肾病）",
                "止痛治疗"
            ],
            whenToSeeVet: [
                "关节肿胀、变形",
                "脚趾出现白色结节",
                "行走困难、跛行",
                "精神萎靡",
                "食欲下降"
            ],
            prevention: [
                "提供均衡饮食，避免过高蛋白",
                "保证充足饮水",
                "定期健康检查",
                "及时治疗肾脏问题"
            ]
        ),
        BirdSymptom(
            name: "甲状腺肿",
            description: "因碘缺乏导致甲状腺肿大，压迫气管和食道。常见于只吃种子的鸟，尤其是虎皮鹦鹉。",
            icon: "circle.hexagongrid",
            severity: .medium,
            category: "营养代谢病",
            possibleCauses: [
                "碘缺乏",
                "长期只吃种子饲料",
                "饮食单一"
            ],
            suggestions: [
                "补充碘：碘化钾溶液加入饮水",
                "改善饮食，增加蔬果",
                "使用含碘的矿物块",
                "严重者需就医"
            ],
            whenToSeeVet: [
                "呼吸困难",
                "吞咽困难",
                "呕吐或反流",
                "颈部可见肿胀",
                "声音改变"
            ],
            prevention: [
                "提供均衡饮食",
                "使用含碘的矿物补充剂",
                "不要只喂种子"
            ]
        ),
        
        // ========== 繁殖相关疾病 ==========
        BirdSymptom(
            name: "蛋阻留(难产)",
            description: "蛋无法正常排出，卡在输卵管或泄殖腔中。这是紧急情况，如不及时处理可在24-48小时内致死。常见于初产母鸟、钙缺乏或蛋过大的情况。",
            icon: "exclamationmark.octagon",
            severity: .high,
            category: "繁殖相关",
            possibleCauses: [
                "钙缺乏导致子宫收缩无力",
                "蛋过大或畸形",
                "输卵管炎症或肿瘤",
                "初产母鸟",
                "过度产蛋导致疲劳",
                "环境温度过低"
            ],
            suggestions: [
                "这是紧急情况！",
                "保持环境温暖（28-30°C）",
                "增加湿度",
                "在泄殖腔滴入少量植物油或凡士林润滑",
                "轻轻按摩腹部（从前向后）",
                "补充钙质",
                "如1-2小时内无法排出必须就医"
            ],
            whenToSeeVet: [
                "有产蛋姿势但产不出",
                "腹部膨大，可触摸到蛋",
                "肛门膨出",
                "精神萎靡、羽毛蓬松",
                "呼吸急促",
                "站立困难或瘫痪"
            ],
            prevention: [
                "产蛋期充足补钙",
                "适当晒太阳补充维生素D",
                "避免过度繁殖",
                "控制产蛋（减少光照时间）",
                "保持适宜温度"
            ]
        ),
        BirdSymptom(
            name: "慢性产蛋/过度产蛋",
            description: "母鸟持续产蛋不停止，消耗大量钙质和营养，可导致钙缺乏、蛋阻留、输卵管脱垂等严重问题。",
            icon: "repeat.circle",
            severity: .medium,
            category: "繁殖相关",
            possibleCauses: [
                "光照时间过长",
                "环境过于舒适",
                "有巢箱或类似巢穴的环境",
                "与伴侣或主人过度亲密",
                "激素失调"
            ],
            suggestions: [
                "减少光照时间（每天不超过10-12小时）",
                "移除巢箱和类似巢穴的物品",
                "改变环境布置",
                "减少抚摸背部和腹部",
                "补充钙质",
                "严重时可能需要激素治疗"
            ],
            whenToSeeVet: [
                "持续产蛋不停",
                "软壳蛋或无壳蛋",
                "体重下降",
                "精神萎靡",
                "出现蛋阻留症状"
            ],
            prevention: [
                "控制光照时间",
                "不提供巢箱（非繁殖期）",
                "避免过度亲密的互动",
                "提供均衡营养"
            ]
        ),
        BirdSymptom(
            name: "输卵管脱垂",
            description: "输卵管从泄殖腔脱出体外，通常发生在产蛋困难或过度产蛋后。这是紧急情况，需要立即处理。",
            icon: "arrow.down.circle.dotted",
            severity: .high,
            category: "繁殖相关",
            possibleCauses: [
                "蛋阻留后用力过度",
                "过度产蛋",
                "钙缺乏",
                "输卵管感染",
                "肌肉无力"
            ],
            suggestions: [
                "这是紧急情况，需立即就医！",
                "保持脱出组织湿润（用生理盐水）",
                "防止鸟啄伤脱出组织",
                "不要自行尝试复位",
                "保持环境安静"
            ],
            whenToSeeVet: [
                "泄殖腔有组织脱出",
                "脱出组织红肿或出血",
                "精神萎靡",
                "拒食"
            ],
            prevention: [
                "预防蛋阻留",
                "控制产蛋",
                "充足补钙",
                "及时治疗产蛋问题"
            ]
        ),
        
        // ========== 其他疾病 ==========
        BirdSymptom(
            name: "胃部酵母菌病(巨细菌病)",
            description: "由巨型酵母菌(Macrorhabdus ornithogaster)引起的消化道疾病，主要影响腺胃。常见于虎皮鹦鹉、玄凤和金丝雀。可导致慢性消瘦。",
            icon: "circle.hexagonpath",
            severity: .high,
            category: "真菌感染",
            possibleCauses: [
                "巨型酵母菌感染",
                "与感染鸟接触",
                "通过粪便传播",
                "应激或免疫力下降时发病"
            ],
            suggestions: [
                "使用抗真菌药物治疗（两性霉素B等，遵医嘱）",
                "治疗周期较长",
                "饮水中加入少量苹果醋酸化（轻症）",
                "隔离病鸟",
                "提供易消化的食物"
            ],
            whenToSeeVet: [
                "频繁呕吐，食物未消化",
                "粪便中有未消化的种子",
                "慢性消瘦",
                "精神时好时坏",
                "羽毛质量下降"
            ],
            prevention: [
                "新鸟隔离检疫",
                "定期健康检查",
                "保持环境清洁",
                "避免应激"
            ]
        ),
        BirdSymptom(
            name: "便秘",
            description: "粪便干燥、排便困难或无法排便。可能由饮食、饮水不足或疾病引起。严重时可导致肠梗阻。",
            icon: "exclamationmark.arrow.circlepath",
            severity: .medium,
            category: "消化系统疾病",
            possibleCauses: [
                "饮水不足",
                "饮食中缺乏纤维",
                "缺乏油脂性食物",
                "运动不足",
                "肠道疾病或梗阻",
                "异物吞入"
            ],
            suggestions: [
                "增加饮水",
                "喂食少量植物油（1-5ml）",
                "增加蔬果和纤维",
                "可用蓖麻油滴入泄殖腔润滑",
                "轻轻按摩腹部",
                "增加运动"
            ],
            whenToSeeVet: [
                "长时间无粪便排出",
                "有排便姿势但排不出",
                "腹部膨大",
                "精神萎靡",
                "呕吐",
                "怀疑吞入异物"
            ],
            prevention: [
                "保证充足饮水",
                "提供含纤维的食物",
                "适量喂食油脂性食物",
                "提供足够运动空间"
            ]
        ),
        BirdSymptom(
            name: "窦炎",
            description: "鼻窦感染发炎，导致眼睛下方或周围肿胀。常继发于上呼吸道感染或维生素A缺乏。",
            icon: "eye.trianglebadge.exclamationmark",
            severity: .medium,
            category: "呼吸系统疾病",
            possibleCauses: [
                "细菌感染",
                "上呼吸道感染蔓延",
                "维生素A缺乏",
                "真菌感染",
                "外伤"
            ],
            suggestions: [
                "需要兽医治疗",
                "可能需要冲洗窦腔",
                "使用抗生素治疗（遵医嘱）",
                "补充维生素A",
                "保持环境清洁"
            ],
            whenToSeeVet: [
                "眼睛下方或周围肿胀",
                "单眼或双眼肿胀",
                "眼睛或鼻孔有分泌物",
                "打喷嚏、甩头",
                "食欲下降"
            ],
            prevention: [
                "及时治疗呼吸道感染",
                "补充维生素A",
                "保持环境清洁",
                "避免刺激性气体"
            ]
        ),
        BirdSymptom(
            name: "鼻石症",
            description: "鼻腔内分泌物、灰尘等积累形成硬块，堵塞鼻孔。常与维生素A缺乏有关。",
            icon: "nose.fill",
            severity: .medium,
            category: "呼吸系统疾病",
            possibleCauses: [
                "维生素A缺乏",
                "慢性鼻炎",
                "环境灰尘过多",
                "鼻腔分泌物积累"
            ],
            suggestions: [
                "需要兽医手术取出鼻石",
                "补充维生素A",
                "保持环境清洁，减少灰尘",
                "术后可能需要抗生素"
            ],
            whenToSeeVet: [
                "鼻孔堵塞",
                "呼吸困难",
                "鼻孔周围可见硬块",
                "张嘴呼吸"
            ],
            prevention: [
                "补充维生素A",
                "保持环境清洁",
                "避免灰尘和烟雾",
                "及时治疗鼻炎"
            ]
        ),
        BirdSymptom(
            name: "癫痫/抽搐",
            description: "大脑异常放电导致的发作性症状，表现为抽搐、失去平衡、意识障碍等。可由多种原因引起，需要查明病因。",
            icon: "bolt.heart",
            severity: .high,
            category: "神经系统疾病",
            possibleCauses: [
                "中毒（重金属、杀虫剂等）",
                "感染（病毒、细菌）",
                "代谢问题（低钙、低血糖）",
                "肿瘤",
                "外伤",
                "遗传因素"
            ],
            suggestions: [
                "发作时保持环境安静黑暗",
                "移除笼内可能造成伤害的物品",
                "不要强行抓握发作中的鸟",
                "记录发作时间和表现",
                "尽快就医查明原因"
            ],
            whenToSeeVet: [
                "抽搐发作",
                "失去平衡、倒地",
                "头部后仰或转圈",
                "意识丧失",
                "发作后精神萎靡"
            ],
            prevention: [
                "避免接触有毒物质",
                "保持均衡营养",
                "定期健康检查",
                "减少应激"
            ]
        ),
        BirdSymptom(
            name: "歪头症/斜颈",
            description: "头部持续倾斜或转圈，可能由内耳感染、神经系统问题或中毒引起。需要查明病因进行治疗。",
            icon: "arrow.triangle.turn.up.right.circle",
            severity: .high,
            category: "神经系统疾病",
            possibleCauses: [
                "内耳感染",
                "中耳炎",
                "脑部感染或损伤",
                "中毒",
                "前胃扩张症",
                "维生素缺乏"
            ],
            suggestions: [
                "需要兽医诊断病因",
                "根据病因进行针对性治疗",
                "保持环境安全，防止摔伤",
                "可能需要辅助喂食"
            ],
            whenToSeeVet: [
                "头部持续倾斜",
                "转圈行走",
                "失去平衡",
                "眼球震颤",
                "无法正常进食"
            ],
            prevention: [
                "及时治疗耳部感染",
                "避免接触有毒物质",
                "保持均衡营养"
            ]
        ),
        BirdSymptom(
            name: "骨折",
            description: "骨骼断裂，常见于翅膀和腿部。多因撞击、摔落或被夹伤引起。需要及时固定和治疗。",
            icon: "bandage.fill",
            severity: .high,
            category: "外伤",
            possibleCauses: [
                "撞击门窗或墙壁",
                "从高处摔落",
                "被门夹伤",
                "被其他动物攻击",
                "钙缺乏导致骨骼脆弱"
            ],
            suggestions: [
                "限制活动，将鸟放在小笼或箱中",
                "移除栖木，铺软垫",
                "尽快就医",
                "不要自行尝试复位",
                "保持环境安静"
            ],
            whenToSeeVet: [
                "翅膀下垂、无法飞行",
                "腿部无法站立或悬吊",
                "患处肿胀",
                "明显疼痛",
                "骨骼变形"
            ],
            prevention: [
                "放飞前关好门窗",
                "窗户贴防撞贴纸",
                "补充钙质",
                "避免危险环境"
            ]
        ),
        BirdSymptom(
            name: "出血/外伤",
            description: "皮肤或血管破损导致出血。鸟类血量少，大量出血可危及生命。需要及时止血处理。",
            icon: "drop.fill",
            severity: .high,
            category: "外伤",
            possibleCauses: [
                "血羽断裂",
                "指甲剪太短",
                "外伤",
                "被其他鸟攻击",
                "撞击"
            ],
            suggestions: [
                "保持冷静",
                "用干净纱布或棉球压迫止血",
                "血羽出血可用止血粉或面粉",
                "严重时需拔除断裂的血羽",
                "大量出血需紧急就医"
            ],
            whenToSeeVet: [
                "出血无法止住",
                "大量出血",
                "伤口较深",
                "精神萎靡",
                "血羽反复出血"
            ],
            prevention: [
                "剪指甲时注意不要剪太短",
                "避免危险环境",
                "分开有攻击性的鸟"
            ]
        ),
        BirdSymptom(
            name: "中毒",
            description: "摄入或吸入有毒物质导致的急性或慢性中毒。常见毒物包括重金属、特氟龙烟雾、有毒植物、杀虫剂等。可能危及生命。",
            icon: "exclamationmark.triangle",
            severity: .high,
            category: "中毒",
            possibleCauses: [
                "重金属中毒（铅、锌）：啃咬含铅/锌物品",
                "特氟龙中毒：不粘锅过热产生的烟雾",
                "有毒植物：牛油果、巧克力、洋葱等",
                "杀虫剂、清洁剂",
                "香水、空气清新剂",
                "烟草烟雾"
            ],
            suggestions: [
                "立即移除毒物来源",
                "保持通风（吸入性中毒）",
                "紧急就医",
                "带上可疑毒物样本",
                "不要自行催吐"
            ],
            whenToSeeVet: [
                "突然精神萎靡",
                "呕吐、腹泻",
                "抽搐",
                "呼吸困难",
                "共济失调",
                "突然死亡"
            ],
            prevention: [
                "绝对不用不粘锅（特氟龙）",
                "移除含铅锌的物品",
                "不喂有毒食物",
                "避免使用杀虫剂、香水",
                "保持通风"
            ]
        ),
        BirdSymptom(
            name: "脂肪瘤",
            description: "皮下脂肪组织形成的良性肿瘤，表现为皮下可移动的软性肿块。常见于肥胖的鸟，尤其是虎皮鹦鹉和玄凤。",
            icon: "circle.fill",
            severity: .medium,
            category: "肿瘤",
            possibleCauses: [
                "肥胖",
                "高脂肪饮食",
                "遗传因素",
                "缺乏运动"
            ],
            suggestions: [
                "调整饮食，减少脂肪摄入",
                "增加运动",
                "定期监测肿块大小",
                "较大的肿瘤可能需要手术切除"
            ],
            whenToSeeVet: [
                "发现皮下肿块",
                "肿块快速增大",
                "影响活动或飞行",
                "肿块表面破溃"
            ],
            prevention: [
                "保持健康体重",
                "低脂饮食",
                "充足运动"
            ]
        )
    ]
}

// MARK: - 使用帮助视图
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    private let helpSections: [(title: String, icon: String, items: [(question: String, answer: String)])] = [
        (
            title: "首页功能",
            icon: "house.fill",
            items: [
                ("如何添加我的鸟儿？", "点击首页右上角的「+」按钮，填写鸟儿的基本信息（昵称、品种、性别、出生日期等），即可创建鸟儿档案。"),
                ("如何记录鸟儿的日志？", "在首页点击鸟儿卡片进入详情页，点击「写日志」按钮，可以记录鸟儿的体重、饮食、健康状况等信息。"),
                ("如何设置喂食提醒？", "在首页点击「提醒」标签，点击「+」添加新提醒，设置提醒时间和重复周期即可。"),
                ("如何共享鸟儿给家人？", "在鸟儿详情页点击「共享」按钮，输入家人的手机号，选择权限（可编辑/仅查看）发送邀请。"),
                ("误删的鸟儿如何恢复？", "VIP用户可以在「我的」页面点击「回收站」，找到已删除的鸟儿进行恢复。")
            ]
        ),
        (
            title: "百科功能",
            icon: "book.fill",
            items: [
                ("如何查询鸟类品种信息？", "进入「百科」页面，选择「鸟类百科」，可以按分类浏览各种宠物鸟的详细信息，包括习性、饲养要点等。"),
                ("如何查询食物是否安全？", "在「百科」页面选择「食物查询」，搜索或浏览食物列表，查看该食物对鸟儿是否安全。"),
                ("如何根据症状判断疾病？", "在「百科」页面选择「症状查询」，根据鸟儿的症状进行搜索，获取可能的原因和建议。"),
                ("配色预测怎么用？", "在「百科」页面选择「配色预测」，选择父母双方的羽色，系统会预测后代可能的羽色组合。")
            ]
        ),
        (
            title: "广场功能",
            icon: "globe.asia.australia.fill",
            items: [
                ("如何发布帖子？", "在「广场」页面点击右下角的「+」按钮，输入内容、添加图片，点击发布即可。"),
                ("如何发布寻鸟启事？", "在「广场」页面点击右下角的「+」按钮，选择「寻鸟启事」类型，填写走失鸟儿的信息和联系方式。"),
                ("如何关注其他鸟友？", "点击帖子作者头像进入主页，点击「关注」按钮即可。关注后可以在「关注」标签页看到他们的动态。"),
                ("如何收藏喜欢的帖子？", "在帖子详情页点击「收藏」按钮，收藏的帖子可以在「我的」页面的「我的收藏」中查看。")
            ]
        ),
        (
            title: "账号与会员",
            icon: "person.fill",
            items: [
                ("如何修改个人资料？", "在「我的」页面点击头像或昵称区域，进入编辑页面修改昵称、简介等信息。"),
                ("VIP会员有什么特权？", "VIP会员享有：无限鸟儿档案、回收站恢复功能、专属标识、优先客服等特权。"),
                ("如何开通VIP会员？", "在「我的」页面点击VIP卡片，选择会员套餐进行购买。支持月度、年度和永久会员。"),
                ("如何查看共享邀请？", "在「我的」页面点击「共享邀请」，可以查看并处理收到的鸟儿共享邀请。")
            ]
        ),
        (
            title: "常见问题",
            icon: "questionmark.circle.fill",
            items: [
                ("数据会丢失吗？", "您的数据会自动同步到云端，更换设备后登录同一账号即可恢复所有数据。"),
                ("可以离线使用吗？", "部分功能支持离线使用，但发帖、同步等功能需要网络连接。"),
                ("如何反馈问题？", "您可以通过「关于鸟鸟王国」页面底部的联系方式向我们反馈问题和建议。"),
                ("如何注销账号？", "如需注销账号，请联系客服处理。注销后所有数据将被永久删除。")
            ]
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部图标
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(forestGreen)
                        
                        Text("使用帮助")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("快速了解鸟鸟王国的各项功能")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // 帮助分类
                    ForEach(helpSections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            // 分类标题
                            HStack(spacing: 10) {
                                Image(systemName: section.icon)
                                    .font(.headline)
                                    .foregroundColor(forestGreen)
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundColor(forestGreen)
                            }
                            .padding(.horizontal, 16)
                            
                            // 问答列表
                            VStack(spacing: 0) {
                                ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(item.question)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Text(item.answer)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineSpacing(4)
                                    }
                                    .padding(16)
                                    
                                    if index < section.items.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                    }
                    
                    // 底部提示
                    VStack(spacing: 8) {
                        Text("还有其他问题？")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("请通过「关于鸟鸟王国」页面联系我们")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(forestGreen)
                }
            }
        }
    }
}

// MARK: - 关于鸟鸟王国视图
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    private let leafGreen = Color(red: 0.35, green: 0.55, blue: 0.40)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App 图标和名称
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [forestGreen, leafGreen],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "bird.fill")
                                .font(.system(size: 45))
                                .foregroundColor(.white)
                        }
                        .shadow(color: forestGreen.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        VStack(spacing: 4) {
                            Text("鸟鸟王国")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Bird Kingdom")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("版本 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 30)
                    
                    // 应用介绍
                    VStack(alignment: .leading, spacing: 12) {
                        Text("关于我们")
                            .font(.headline)
                            .foregroundColor(forestGreen)
                        
                        Text("鸟鸟王国是一款专为爱鸟人士打造的宠物鸟管理应用。我们致力于帮助每一位鸟友更好地照顾自己的羽毛小伙伴，记录它们成长的每一个瞬间。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
                    
                    // 核心功能
                    VStack(alignment: .leading, spacing: 16) {
                        Text("核心功能")
                            .font(.headline)
                            .foregroundColor(forestGreen)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            featureRow(icon: "bird.fill", title: "鸟儿档案", description: "为每只鸟儿建立专属档案，记录基本信息、健康数据")
                            featureRow(icon: "doc.text.fill", title: "成长日志", description: "记录体重变化、饮食情况、健康状态等日常信息")
                            featureRow(icon: "bell.fill", title: "智能提醒", description: "喂食、换羽、体检等重要事项定时提醒")
                            featureRow(icon: "book.fill", title: "鸟类百科", description: "丰富的鸟类知识库，食物安全查询，症状速查")
                            featureRow(icon: "globe.asia.australia.fill", title: "鸟友广场", description: "分享养鸟心得，寻找走失鸟儿，结识鸟友")
                            featureRow(icon: "person.2.fill", title: "家庭共享", description: "与家人共同管理鸟儿，数据实时同步")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
                    
                    // 开发团队
                    VStack(alignment: .leading, spacing: 12) {
                        Text("开发团队")
                            .font(.headline)
                            .foregroundColor(forestGreen)
                        
                        Text("鸟鸟王国由一群热爱鸟类的开发者倾心打造。我们相信，每一只鸟儿都值得被用心呵护。如果您有任何建议或反馈，欢迎随时联系我们！")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
                    
                    // 联系方式
                    VStack(alignment: .leading, spacing: 16) {
                        Text("联系我们")
                            .font(.headline)
                            .foregroundColor(forestGreen)
                        
                        VStack(spacing: 0) {
                            contactRow(icon: "envelope.fill", title: "邮箱", value: "support@birdkingdom.com")
                            Divider().padding(.leading, 50)
                            contactRow(icon: "globe", title: "官网", value: "www.birdkingdom.com")
                            Divider().padding(.leading, 50)
                            contactRow(icon: "bubble.left.fill", title: "微信公众号", value: "鸟鸟王国")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: forestGreen.opacity(0.06), radius: 6, x: 0, y: 2)
                    
                    // 法律信息
                    VStack(spacing: 12) {
                        Button {
                            // 打开用户协议
                        } label: {
                            Text("用户协议")
                                .font(.subheadline)
                                .foregroundColor(forestGreen)
                        }
                        
                        Button {
                            // 打开隐私政策
                        } label: {
                            Text("隐私政策")
                                .font(.subheadline)
                                .foregroundColor(forestGreen)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    // 版权信息
                    VStack(spacing: 4) {
                        Text("© 2024 鸟鸟王国")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("All Rights Reserved")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(uiColor: .systemGray6).opacity(0.5))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(forestGreen)
                }
            }
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(forestGreen)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func contactRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(forestGreen)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}
