//
//  HighlightedText.swift
//  BirdKingdom
//
//  搜索关键词高亮显示组件
//

import SwiftUI

// MARK: - 高亮文本视图
struct HighlightedText: View {
    let text: String
    let highlight: String
    let highlightColor: Color
    let font: Font
    let baseColor: Color
    let lineLimit: Int?
    
    init(
        _ text: String,
        highlight: String,
        highlightColor: Color = .yellow,
        font: Font = .body,
        baseColor: Color = .primary,
        lineLimit: Int? = nil
    ) {
        self.text = text
        self.highlight = highlight
        self.highlightColor = highlightColor
        self.font = font
        self.baseColor = baseColor
        self.lineLimit = lineLimit
    }
    
    var body: some View {
        if highlight.isEmpty {
            // 无关键词时直接显示原文
            Text(text)
                .font(font)
                .foregroundColor(baseColor)
                .lineLimit(lineLimit)
        } else {
            // 有关键词时高亮显示
            highlightedTextView
                .lineLimit(lineLimit)
        }
    }
    
    private var highlightedTextView: some View {
        let attributedText = createHighlightedText()
        return Text(attributedText)
            .font(font)
    }
    
    private func createHighlightedText() -> AttributedString {
        var attributedString = AttributedString(text)
        
        // 设置默认颜色
        attributedString.foregroundColor = baseColor
        
        // 查找所有匹配的关键词位置（不区分大小写）
        let lowercasedText = text.lowercased()
        let lowercasedHighlight = highlight.lowercased()
        
        var searchStartIndex = lowercasedText.startIndex
        
        while let range = lowercasedText.range(of: lowercasedHighlight, range: searchStartIndex..<lowercasedText.endIndex) {
            // 将String.Index转换为AttributedString的范围
            let startOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            let endOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound)
            
            if let attrStart = attributedString.index(attributedString.startIndex, offsetByCharacters: startOffset),
               let attrEnd = attributedString.index(attributedString.startIndex, offsetByCharacters: endOffset) {
                let attrRange = attrStart..<attrEnd
                attributedString[attrRange].backgroundColor = highlightColor
                attributedString[attrRange].foregroundColor = .black
            }
            
            // 移动搜索起始位置
            searchStartIndex = range.upperBound
        }
        
        return attributedString
    }
}

// MARK: - AttributedString扩展
extension AttributedString {
    func index(_ i: AttributedString.Index, offsetByCharacters offset: Int) -> AttributedString.Index? {
        var currentIndex = i
        var remainingOffset = offset
        
        while remainingOffset > 0 {
            guard currentIndex < self.endIndex else { return nil }
            currentIndex = self.index(afterCharacter: currentIndex)
            remainingOffset -= 1
        }
        
        return currentIndex
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        HighlightedText(
            NSLocalizedString("这是一个测试文本，包含关键词搜索功能", comment: ""),
            highlight: NSLocalizedString("关键词", comment: ""),
            highlightColor: .yellow
        )
        
        HighlightedText(
            NSLocalizedString("我家的虎皮鹦鹉今天很活泼", comment: ""),
            highlight: NSLocalizedString("鹦鹉", comment: ""),
            highlightColor: .yellow,
            font: .system(size: 13)
        )
        
        HighlightedText(
            NSLocalizedString("没有匹配的关键词", comment: ""),
            highlight: NSLocalizedString("测试", comment: ""),
            highlightColor: .yellow
        )
        
        HighlightedText(
            NSLocalizedString("多个匹配：鹦鹉是一种鹦鹉科的鸟类", comment: ""),
            highlight: NSLocalizedString("鹦鹉", comment: ""),
            highlightColor: .orange.opacity(0.5)
        )
    }
    .padding()
}
