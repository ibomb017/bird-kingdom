import Vapor

/// .well-known 目录控制器
/// 用于提供 Universal Links 所需的 apple-app-site-association 文件
struct WellKnownController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Apple App Site Association 文件
        routes.get(".well-known", "apple-app-site-association", use: getAppleAppSiteAssociation)
        
        // 备用路径
        routes.get("apple-app-site-association", use: getAppleAppSiteAssociation)
    }
    
    // MARK: - Apple App Site Association
    @Sendable
    func getAppleAppSiteAssociation(req: Request) async throws -> Response {
        // AASA 配置
        // 使用实际的 Team ID 和 Bundle ID
        let aasa = """
        {
            "applinks": {
                "apps": [],
                "details": [
                    {
                        "appID": "2876L6B56T.com.ibomb.BirdKingdom",
                        "paths": [
                            "/share/*",
                            "/post/*",
                            "/user/*"
                        ]
                    }
                ]
            },
            "webcredentials": {
                "apps": [
                    "2876L6B56T.com.ibomb.BirdKingdom"
                ]
            }
        }
        """
        
        let response = Response(status: .ok)
        response.headers.contentType = .json
        response.body = .init(string: aasa)
        return response
    }
}
