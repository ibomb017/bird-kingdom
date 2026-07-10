//
//  FoodModels.swift
//  BirdKingdom
//
//  食物相关数据模型
//

import SwiftUI

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

// MARK: - 鸟类类型（用于食物偏好）
enum BirdType: String, CaseIterable {
    case lovebird = "牡丹鹦鹉"
    case budgie = "虎皮鹦鹉"
    case cockatiel = "玄凤鹦鹉"
    case parrotlet = "太平洋鹦鹉"
    case conure = "锥尾鹦鹉"
    case cockatoo = "凤头鹦鹉"
    case macaw = "金刚鹦鹉"
    case africanGrey = "非洲灰鹦鹉"
    case canary = "金丝雀"
    case finch = "文鸟/雀类"
    
    var icon: String {
        switch self {
        case .lovebird: return "heart.fill"
        case .budgie: return "leaf.fill"
        case .cockatiel: return "crown.fill"
        case .parrotlet: return "star.fill"
        case .conure: return "sun.max.fill"
        case .cockatoo: return "cloud.fill"
        case .macaw: return "flame.fill"
        case .africanGrey: return "brain.head.profile"
        case .canary: return "music.note"
        case .finch: return "music.note.list"
        }
    }
}

// MARK: - 食物偏好等级
enum FoodPreference: String {
    case loves = "特别爱吃"      // 该鸟种特别喜欢
    case likes = "喜欢"         // 大多数个体喜欢
    case neutral = "一般"       // 可以吃但不特别喜欢
    case dislikes = "不太爱吃"   // 大多数个体不喜欢
    case unsuitable = "不适合"   // 该鸟种不适合吃
    
    var color: Color {
        switch self {
        case .loves: return Color(red: 0.2, green: 0.7, blue: 0.3)
        case .likes: return Color(red: 0.4, green: 0.6, blue: 0.8)
        case .neutral: return Color.gray
        case .dislikes: return Color.orange
        case .unsuitable: return Color.red
        }
    }
    
    var icon: String {
        switch self {
        case .loves: return "heart.fill"
        case .likes: return "hand.thumbsup.fill"
        case .neutral: return "minus.circle"
        case .dislikes: return "hand.thumbsdown"
        case .unsuitable: return "xmark.circle.fill"
        }
    }
}

// MARK: - 食物数据模型
struct BirdFood: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: FoodCategory
    let safetyLevel: FoodSafetyLevel
    let description: String
    let notes: String
    let nutrients: [String]
    
    // 新增：鸟类偏好（不同鸟种对该食物的喜好程度）
    let birdPreferences: [BirdType: FoodPreference]
    
    // 新增：权威来源（确保食物安全性有据可查）
    let sources: [String]
    
    // Hashable conformance
    static func == (lhs: BirdFood, rhs: BirdFood) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // 兼容旧的初始化方法
    init(name: String, category: FoodCategory, safetyLevel: FoodSafetyLevel, description: String, notes: String, nutrients: [String], birdPreferences: [BirdType: FoodPreference] = [:], sources: [String] = []) {
        self.name = name
        self.category = category
        self.safetyLevel = safetyLevel
        self.description = description
        self.notes = notes
        self.nutrients = nutrients
        self.birdPreferences = birdPreferences
        self.sources = sources
    }
    
    // 获取特定鸟类的偏好
    func preference(for birdType: BirdType) -> FoodPreference {
        return birdPreferences[birdType] ?? .neutral
    }
    
    // 获取特别喜欢这个食物的鸟类
    var lovedByBirds: [BirdType] {
        birdPreferences.filter { $0.value == .loves }.map { $0.key }
    }
    
    // 获取不适合吃这个食物的鸟类
    var unsuitableForBirds: [BirdType] {
        birdPreferences.filter { $0.value == .unsuitable }.map { $0.key }
    }
}
