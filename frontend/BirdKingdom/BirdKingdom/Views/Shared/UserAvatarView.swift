import SwiftUI

/// 统一的用户头像视图
/// 用于所有显示用户头像的地方，保证占位符风格统一
struct UserAvatarView: View {
    let avatarUrl: String?
    let size: CGFloat
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    init(avatarUrl: String?, size: CGFloat = 40) {
        self.avatarUrl = avatarUrl
        self.size = size
    }
    
    var body: some View {
        if let avatarUrl = avatarUrl, !avatarUrl.isEmpty, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
            // 显示网络图片
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderView
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
            .frame(width: size, height: size)
        } else {
            // 默认占位图 - 使用APP自制的小鸟图标
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(primaryColor.opacity(0.1))
            
            // 使用APP自制的小鸟图标作为占位符
            Image("bird")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.55, height: size * 0.55)
                .foregroundColor(primaryColor.opacity(0.5))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        UserAvatarView(avatarUrl: nil, size: 60)
        UserAvatarView(avatarUrl: "", size: 40)
        UserAvatarView(avatarUrl: "https://example.com/avatar.jpg", size: 50)
    }
    .padding()
}
