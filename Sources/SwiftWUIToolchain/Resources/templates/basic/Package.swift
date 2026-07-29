// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "{{NAME}}",
    platforms: [.macOS(.v14)],
    dependencies: [
        {{SWIFTWUI_DEPENDENCY}},
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(name: "{{NAME}}", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            .product(name: "SwiftWUIStatic", package: "SwiftWUI",
                     condition: .when(platforms: [.macOS, .linux])),
        ], path: "Sources",
        // Catalogs are codegen input, not a bundled resource.
        exclude: ["Locales"],
        swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
