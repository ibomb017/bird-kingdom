import Vapor
import Fluent

/// 帖子分享页面控制器
/// 用于生成可分享的帖子详情页面，支持 Open Graph 标签（微信/QQ 预览卡片）
struct SharePageController: RouteCollection {
    private let baseURL = "https://birdkingdom.xyz"
    
    func boot(routes: RoutesBuilder) throws {
        // 分享页面（不需要 /api 前缀）
        routes.get("share", "post", ":postId", use: sharePost)
    }
    
    // MARK: - 帖子分享页面
    @Sendable
    func sharePost(req: Request) async throws -> Response {
        guard let postIdStr = req.parameters.get("postId"),
              let postId = Int64(postIdStr) else {
            throw Abort(.notFound)
        }
        
        guard let post = try await ForumPost.find(postId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // 获取作者信息
        var authorName = "鸟鸟王国用户"
        var authorAvatar = "\(baseURL)/images/default-avatar.png"
        if let author = try await User.find(post.authorId, on: req.db) {
            authorName = author.nickname
            if let avatar = author.avatarUrl {
                authorAvatar = avatar
            }
        }
        
        // 获取帖子图片
        let images = try await PostImage.query(on: req.db)
            .filter(\.$postId == postId)
            .all()
        let imageUrls = images.map { $0.imageUrl }
        
        let html = generatePostHtml(
            post: post,
            authorName: authorName,
            authorAvatar: authorAvatar,
            imageUrls: imageUrls
        )
        
        let response = Response(status: .ok)
        response.headers.contentType = .html
        response.body = .init(string: html)
        return response
    }
    
    // MARK: - 生成帖子 HTML 页面
    private func generatePostHtml(post: ForumPost, authorName: String, authorAvatar: String, imageUrls: [String]) -> String {
        let title = generateTitle(post: post)
        let description = truncate(text: post.content, maxLength: 100)
        let imageUrl = getFirstImageUrl(post: post, imageUrls: imageUrls)
        let shareUrl = "\(baseURL)/share/post/\(post.id ?? 0)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        let createdTime = post.createdAt != nil ? dateFormatter.string(from: post.createdAt!) : ""
        
        var html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            
            <!-- Open Graph 标签 -->
            <meta property="og:type" content="article">
            <meta property="og:title" content="\(escapeHtml(title))">
            <meta property="og:description" content="\(escapeHtml(description))">
            <meta property="og:url" content="\(shareUrl)">
            <meta property="og:site_name" content="鸟鸟王国">
        """
        
        if let imgUrl = imageUrl {
            html += """
                <meta property="og:image" content="\(imgUrl)">
                <meta property="og:image:width" content="800">
                <meta property="og:image:height" content="800">
            """
        }
        
        html += """
            
            <!-- Twitter Card -->
            <meta name="twitter:card" content="summary_large_image">
            <meta name="twitter:title" content="\(escapeHtml(title))">
            <meta name="twitter:description" content="\(escapeHtml(description))">
            
            <title>\(escapeHtml(title)) - 鸟鸟王国</title>
            
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #f5f7fa 0%, #e4e8ed 100%);
                    min-height: 100vh;
                    color: #333;
                }
                .header {
                    background: linear-gradient(135deg, #42B883 0%, #35495E 100%);
                    padding: 16px 20px;
                    position: sticky;
                    top: 0;
                    z-index: 100;
                }
                .header-content {
                    display: flex;
                    align-items: center;
                    max-width: 600px;
                    margin: 0 auto;
                }
                .app-name { color: white; font-size: 18px; font-weight: 600; }
                .container { max-width: 600px; margin: 0 auto; padding: 16px; }
                .post-card {
                    background: white;
                    border-radius: 16px;
                    padding: 20px;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.08);
                    margin-bottom: 16px;
                }
                .author-info {
                    display: flex;
                    align-items: center;
                    margin-bottom: 16px;
                }
                .avatar {
                    width: 44px;
                    height: 44px;
                    border-radius: 50%;
                    object-fit: cover;
                    margin-right: 12px;
                    border: 2px solid #42B883;
                }
                .author-name { font-weight: 600; font-size: 15px; }
                .post-time { font-size: 12px; color: #999; }
                .post-content { margin-bottom: 16px; line-height: 1.7; font-size: 15px; }
                .image-grid { display: grid; gap: 4px; margin-bottom: 16px; }
                .image-grid-1 { grid-template-columns: 1fr; }
                .image-grid-2 { grid-template-columns: repeat(2, 1fr); }
                .image-grid-3 { grid-template-columns: repeat(3, 1fr); }
                .post-image { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 8px; }
                .download-banner {
                    background: linear-gradient(135deg, #42B883 0%, #35495E 100%);
                    border-radius: 16px;
                    padding: 24px;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    color: white;
                }
                .banner-text h3 { font-size: 18px; margin-bottom: 4px; }
                .banner-text p { font-size: 13px; opacity: 0.9; }
                .download-btn {
                    background: white;
                    color: #42B883;
                    padding: 12px 24px;
                    border-radius: 25px;
                    font-weight: 600;
                    text-decoration: none;
                }
            </style>
        </head>
        <body>
            <header class="header">
                <div class="header-content">
                    <span class="app-name">🦜 鸟鸟王国</span>
                </div>
            </header>
            
            <main class="container">
                <article class="post-card">
                    <div class="author-info">
                        <img src="\(authorAvatar)" alt="" class="avatar">
                        <div>
                            <span class="author-name">\(escapeHtml(authorName))</span>
                            <div class="post-time">\(createdTime)</div>
                        </div>
                    </div>
                    
                    <div class="post-content">
                        <p>\(escapeHtml(post.content).replacingOccurrences(of: "\n", with: "<br>"))</p>
                    </div>
        """
        
        // 添加图片
        if !imageUrls.isEmpty {
            let gridClass = "image-grid-\(min(imageUrls.count, 3))"
            html += "<div class=\"image-grid \(gridClass)\">\n"
            for (index, url) in imageUrls.prefix(9).enumerated() {
                html += "    <img src=\"\(url)\" alt=\"\" class=\"post-image\">\n"
            }
            html += "</div>\n"
        }
        
        html += """
                </article>
                
                <div class="download-banner">
                    <div class="banner-text">
                        <h3>在鸟鸟王国查看更多精彩内容</h3>
                        <p>记录鸟儿成长，分享养鸟心得</p>
                    </div>
                    <a href="https://apps.apple.com/app/id6740255889" class="download-btn">下载 App</a>
                </div>
            </main>
        </body>
        </html>
        """
        
        return html
    }
    
    // MARK: - 辅助方法
    private func generateTitle(post: ForumPost) -> String {
        if post.postType == "LOST" {
            return "🔍 寻鸟启事" + (post.birdName != nil ? " - \(post.birdName!)" : "")
        }
        let content = post.content
        if content.count > 20 {
            return String(content.prefix(20)) + "..."
        }
        return content
    }
    
    private func getFirstImageUrl(post: ForumPost, imageUrls: [String]) -> String? {
        if post.mediaType == "VIDEO", let cover = post.videoCover {
            return cover
        }
        if !imageUrls.isEmpty {
            return imageUrls[0]
        }
        return post.birdAvatar
    }
    
    private func truncate(text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }
    
    private func escapeHtml(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
