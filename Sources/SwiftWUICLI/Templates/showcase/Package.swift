// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "{{PROJECT_NAME}}",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "SwiftWUI", path: "../../"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(
            name: "{{PROJECT_NAME}}",
            dependencies: [
                .product(name: "SwiftWUI", package: "SwiftWUI"),
            ]
        ),
    ]
)
