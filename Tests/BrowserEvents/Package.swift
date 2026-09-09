// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BrowserEvents",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "SwiftWUI", path: "../.."),
        // Match the repository's resolved version for repeatable browser tests.
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.56.1"),
    ],
    targets: [
        .executableTarget(name: "BrowserEvents", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        ], path: "Sources", swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
