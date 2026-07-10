import SwiftUI

/// 合规提示组件
/// 用于显示免责声明、法律提示等合规性信息
struct ComplianceAlert: View {
    let message: String
    var icon: String = "exclamationmark.triangle.fill"
    var iconColor: Color = .orange
    var backgroundColor: Color = Color.orange.opacity(0.1)
    
    init(_ message: String) {
        self.message = message
    }
    
    init(_ message: String, icon: String, iconColor: Color = .orange, backgroundColor: Color? = nil) {
        self.message = message
        self.icon = icon
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor ?? iconColor.opacity(0.1)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
                .padding(.top, 2)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ComplianceAlert(NSLocalizedString("本功能仅供参考，不能替代专业兽医诊断。", comment: ""))
        
        ComplianceAlert(
            NSLocalizedString("请确保您已阅读并同意用户协议。", comment: ""),
            icon: "info.circle.fill",
            iconColor: .blue
        )
        
        ComplianceAlert(
            NSLocalizedString("此操作不可撤销，请谨慎操作。", comment: ""),
            icon: "exclamationmark.circle.fill",
            iconColor: .red
        )
    }
    .padding()
}
