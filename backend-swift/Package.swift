// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BirdKingdomServer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Vapor - Swift 后端框架
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // Fluent - ORM 框架
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        // Fluent MySQL 驱动
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.4.0"),
        // JWT 认证
        .package(url: "https://github.com/vapor/jwt.git", from: "4.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "BirdKingdomServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver"),
                .product(name: "JWT", package: "jwt"),
            ],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "BirdKingdomServer"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            path: "Tests/AppTests"
        ),
    ]
)
