// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ShipCounter",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(name: "ShipCounter", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            .product(name: "SwiftWUIStatic", package: "SwiftWUI",
                     condition: .when(platforms: [.macOS, .linux])),
        ], path: "Sources", swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
