// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Interop",
    platforms: [.macOS(.v14)],
    products: [.library(name: "AppInterop", targets: ["AppInterop"])],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.59.0"),
    ],
    targets: [
        .target(name: "AppInterop", dependencies: ["JavaScriptKit"], exclude: [
            "bridge-js.config.json", "bridge-js.d.ts", "bridge-js.global.d.ts", "Generated/JavaScript",
        ], swiftSettings: [.enableExperimentalFeature("Extern")]),
    ]
)
