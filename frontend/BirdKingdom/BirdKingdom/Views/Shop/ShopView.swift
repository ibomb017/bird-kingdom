//
//  ShopView.swift
//  BirdKingdom
//
//  商城页面 - 预留接口
//  TODO: 未来实现商城功能
//
//  使用方法：在 MainTabView 中添加以下代码启用商城标签页
//  ShopView()
//      .tabItem {
//          Label("商城", systemImage: "cart.fill")
//      }
//      .tag(4)
//

import SwiftUI

// MARK: - 商城页面
struct ShopView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        // TODO: 实现商城功能
        EmptyView()
    }
}

// MARK: - 商品模型（预留）
// struct Product: Identifiable {
//     let id: Int64
//     let name: String
//     let price: Double
//     let imageUrl: String?
//     let description: String
// }

// MARK: - 商城服务（预留）
// class ShopService: ObservableObject {
//     static let shared = ShopService()
//     @Published var products: [Product] = []
// }
