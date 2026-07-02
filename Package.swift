// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftWUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SwiftWUI", targets: ["SwiftWUI"]),
        .library(name: "SwiftWUIDOM", targets: ["SwiftWUIDOM"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .target(name: "SwiftWUI", swiftSettings: [.defaultIsolation(MainActor.self)]),
        .target(name: "SwiftWUIDOM", dependencies: [
            "SwiftWUI",
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
        ]),
        .testTarget(name: "SwiftWUITests", dependencies: ["SwiftWUI"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
