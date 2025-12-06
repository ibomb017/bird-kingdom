import SwiftUI

struct BirdAvatarView: View {
    let avatarUrl: String?
    let size: CGFloat
    let isDead: Bool
    
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    init(avatarUrl: String?, size: CGFloat = 60, isDead: Bool = false) {
        self.avatarUrl = avatarUrl
        self.size = size
        self.isDead = isDead
    }
    
    var body: some View {
        ZStack {
            if let avatarUrl = avatarUrl, let url = URL(string: avatarUrl) {
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
                .fill(forestGreen.opacity(0.15))
            
            Image(systemName: "bird.fill")
                .font(.system(size: size * 0.5))
                .foregroundColor(forestGreen.opacity(0.6))
        }
        .frame(width: size, height: size)
    }
}
