// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TodoMVC",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(name: "TodoMVC", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        ], path: "Sources", swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
