import Vapor

/// 静态页面控制器
struct StaticPageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // 隐私政策页面
        routes.get("privacy", use: privacy)
        
        // 用户协议页面
        routes.get("terms", use: terms)
    }
    
    // MARK: - 隐私政策
    @Sendable
    func privacy(req: Request) async throws -> Response {
        // 尝试从文件系统读取
        let filePath = req.application.directory.workingDirectory + "docs/privacy.html"
        
        if FileManager.default.fileExists(atPath: filePath) {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let response = Response(status: .ok)
            response.headers.contentType = .html
            response.body = .init(string: content)
            return response
        }
        
        // 如果文件不存在，返回默认页面
        let html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>隐私政策 - 鸟鸟王国</title>
            <style>
                body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
                h1 { color: #42B883; }
            </style>
        </head>
        <body>
            <h1>隐私政策</h1>
            <p>鸟鸟王国非常重视您的隐私保护。</p>
            <p>详细内容请参阅我们的应用内隐私政策说明。</p>
        </body>
        </html>
        """
        
        let response = Response(status: .ok)
        response.headers.contentType = .html
        response.body = .init(string: html)
        return response
    }
    
    // MARK: - 用户协议
    @Sendable
    func terms(req: Request) async throws -> Response {
        let filePath = req.application.directory.workingDirectory + "docs/terms.html"
        
        if FileManager.default.fileExists(atPath: filePath) {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let response = Response(status: .ok)
            response.headers.contentType = .html
            response.body = .init(string: content)
            return response
        }
        
        let html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>用户协议 - 鸟鸟王国</title>
            <style>
                body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
                h1 { color: #42B883; }
            </style>
        </head>
        <body>
            <h1>用户协议</h1>
            <p>欢迎使用鸟鸟王国。</p>
            <p>详细内容请参阅我们的应用内用户协议说明。</p>
        </body>
        </html>
        """
        
        let response = Response(status: .ok)
        response.headers.contentType = .html
        response.body = .init(string: html)
        return response
    }
}
