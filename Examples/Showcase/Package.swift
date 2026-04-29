// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Showcase",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "SwiftWUI", path: "../../"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(
            name: "Showcase",
            dependencies: [
                .product(name: "SwiftWUI", package: "SwiftWUI"),
            ]
        ),
        .testTarget(
            name: "ShowcaseTests",
            dependencies: ["Showcase"]
        ),
    ]
)
