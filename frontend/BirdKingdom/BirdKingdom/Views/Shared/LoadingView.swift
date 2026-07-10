//
//  LoadingView.swift
//  BirdKingdom
//
//  统一的加载中视图组件
//

import SwiftUI

// MARK: - 简洁加载视图
struct LoadingView: View {
    var message: String = L10n.loading
    var showMessage: Bool = true
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.gray)
            
            if showMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveCard)
    }
}

// MARK: - 内联加载指示器（用于列表等场景）
struct InlineLoadingView: View {
    var message: String = L10n.loading
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.gray)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - 全屏加载遮罩
struct LoadingOverlay: View {
    var message: String = NSLocalizedString("处理中...", comment: "")
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
}

// MARK: - 预览
#Preview {
    VStack {
        LoadingView()
        
        Divider()
        
        InlineLoadingView()
        
        Divider()
        
        LoadingOverlay()
    }
}
