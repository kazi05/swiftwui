// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Localized",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        // `Locales` is excluded: the catalogs are codegen input, not a bundled
        // resource. `Generated/L10n.swift` next to them IS compiled.
        .executableTarget(name: "Localized", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        ], exclude: ["Locales"], swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
