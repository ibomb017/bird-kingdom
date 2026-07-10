import SwiftUI

struct BirdAvatarView: View {
    let avatarUrl: String?
    let size: CGFloat
    let isDead: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var primaryColor: Color { themeManager.primaryColor }
    
    init(avatarUrl: String?, size: CGFloat = 60, isDead: Bool = false) {
        self.avatarUrl = avatarUrl
        self.size = size
        self.isDead = isDead
    }
    
    var body: some View {
        ZStack {
            if let avatarUrl = avatarUrl, let url = URL(string: AppConfig.applyCDN(to: avatarUrl)) {
                // 显示网络图片
                AsyncImage(url: url) { phase in
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
            } else {
                // 默认占位图
                placeholderView
            }
            
            // 已故标识
            if isDead {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: size, height: size)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
    }
    
    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(primaryColor.opacity(0.08))
            
            Image("bird")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.6, height: size * 0.6)
                .foregroundColor(primaryColor.opacity(0.4))
        }
        .frame(width: size, height: size)
    }
}
