import SwiftUI

/// 流式布局组件
/// 自动将子视图排列成多行，当一行放不下时自动换行
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var result = CGSize.zero
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if rowWidth + size.width > containerWidth {
                // 换行
                result.width = max(result.width, rowWidth - spacing)
                result.height += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        
        // 最后一行
        result.width = max(result.width, rowWidth - spacing)
        result.height += rowHeight
        
        return result
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rowX: CGFloat = bounds.minX
        var rowY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        var rowItems: [(Subviews.Element, CGSize)] = []
        
        func placeRow() {
            guard !rowItems.isEmpty else { return }
            
            let rowWidth = rowItems.reduce(0) { $0 + $1.1.width } + CGFloat(rowItems.count - 1) * spacing
            
            var x: CGFloat
            switch alignment {
            case .center:
                x = bounds.minX + (bounds.width - rowWidth) / 2
            case .trailing:
                x = bounds.maxX - rowWidth
            default:
                x = bounds.minX
            }
            
            for (subview, size) in rowItems {
                subview.place(at: CGPoint(x: x, y: rowY), proposal: .unspecified)
                x += size.width + spacing
            }
            
            rowY += rowHeight + spacing
            rowHeight = 0
            rowItems = []
        }
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if rowX + size.width > bounds.maxX && !rowItems.isEmpty {
                placeRow()
                rowX = bounds.minX
            }
            
            rowItems.append((subview, size))
            rowX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        placeRow()
    }
}

#Preview {
    FlowLayout(spacing: 8) {
        ForEach(0..<10) { i in
            Text("Item \(i)")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
    }
    .frame(width: 300)
    .padding()
}
