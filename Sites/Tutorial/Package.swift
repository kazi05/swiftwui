// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TutorialSite",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Explicit identity: a path dependency otherwise takes its package name
        // from the directory, so a git worktree named anything but "SwiftWUI"
        // fails resolution before a single source file is read.
        .package(name: "SwiftWUI", path: "../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .target(name: "TutorialKit", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        ], swiftSettings: [.defaultIsolation(MainActor.self)]),
        .executableTarget(name: "TutorialSite", dependencies: [
            "TutorialKit",
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "SwiftWUIStatic", package: "SwiftWUI",
                     condition: .when(platforms: [.macOS, .linux])),
        ], swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "TutorialKitTests", dependencies: [
            "TutorialKit",
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIStatic", package: "SwiftWUI"),
        ], swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
