// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftWUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SwiftWUI", targets: ["SwiftWUI"]),
        .library(name: "SwiftWUIDOM", targets: ["SwiftWUIDOM"]),
        .library(name: "SwiftWUIStatic", targets: ["SwiftWUIStatic"]),
        .executable(name: "swiftwui", targets: ["SwiftWUICLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(name: "SwiftWUI", swiftSettings: [.defaultIsolation(MainActor.self)]),
        .target(name: "SwiftWUIStatic", dependencies: ["SwiftWUI"],
                swiftSettings: [.defaultIsolation(MainActor.self)]),
        .target(name: "SwiftWUIDOM", dependencies: [
            "SwiftWUI",
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
            .product(name: "JavaScriptFoundationCompat", package: "JavaScriptKit"),
        ], exclude: [
            "bridge-js.config.json",
            "bridge-js.d.ts",
            "bridge-js.global.d.ts",
            "Generated/JavaScript",
        ], swiftSettings: [
            .enableExperimentalFeature("Extern")   // required by BridgeJS Generated/ code
        ]),
        .target(name: "SwiftWUIToolchain", dependencies: ["SwiftWUI"],
                resources: [.copy("Resources")]),
        // ponytail: target named "SwiftWUICLI", not "swiftwui" — a same-named
        // target collides with "SwiftWUI" in per-target .build dirs on
        // case-insensitive APFS. Product name (what `swift run` resolves) stays "swiftwui".
        .executableTarget(name: "SwiftWUICLI", dependencies: [
            "SwiftWUIToolchain",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "SwiftWUITests", dependencies: ["SwiftWUI", "SwiftWUIStatic", "SwiftWUIToolchain"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
