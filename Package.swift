// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftWUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SwiftWUI", targets: ["SwiftWUI"]),
        .library(name: "SwiftWUICore", targets: ["SwiftWUICore"]),
        .library(name: "SwiftWUIHTML", targets: ["SwiftWUIHTML"]),
        .library(name: "SwiftWUIStyles", targets: ["SwiftWUIStyles"]),
        .library(name: "SwiftWUIState", targets: ["SwiftWUIState"]),
        .library(name: "SwiftWUIPage", targets: ["SwiftWUIPage"]),
        .library(name: "SwiftWUIRouter", targets: ["SwiftWUIRouter"]),
        .library(name: "SwiftWUIRuntime", targets: ["SwiftWUIRuntime"]),
        .library(name: "SwiftWUIBrowser", targets: ["SwiftWUIBrowser"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        // Umbrella module
        .target(
            name: "SwiftWUI",
            dependencies: [
                "SwiftWUICore",
                "SwiftWUIHTML",
                "SwiftWUIStyles",
                "SwiftWUIState",
                "SwiftWUIPage",
                "SwiftWUIRouter",
                "SwiftWUIRuntime",
                "SwiftWUIBrowser",
            ]
        ),

        // Core - Tag protocol, TagBuilder, base types
        .target(name: "SwiftWUICore"),

        // HTML - All HTML tags
        .target(
            name: "SwiftWUIHTML",
            dependencies: ["SwiftWUICore"]
        ),

        // Styles - CSS modifiers and values
        .target(
            name: "SwiftWUIStyles",
            dependencies: ["SwiftWUICore"]
        ),

        // State - Reactivity (@State, @Binding, observe)
        .target(
            name: "SwiftWUIState",
            dependencies: ["SwiftWUICore"]
        ),

        // Page - Page protocol and rendering
        .target(
            name: "SwiftWUIPage",
            dependencies: ["SwiftWUICore", "SwiftWUIHTML", "SwiftWUIStyles"]
        ),

        // Router - URL routing and navigation
        .target(
            name: "SwiftWUIRouter",
            dependencies: ["SwiftWUICore", "SwiftWUIPage"]
        ),

        // Runtime - WASM runtime, Virtual DOM, Reconciler
        .target(
            name: "SwiftWUIRuntime",
            dependencies: [
                "SwiftWUICore",
                "SwiftWUIHTML",
                "SwiftWUIStyles",
                "SwiftWUIState",
                "SwiftWUIPage",
                "SwiftWUIRouter",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ]
        ),

        // Browser - Browser API utilities (LocalStorage, Geolocation, etc.)
        .target(
            name: "SwiftWUIBrowser",
            dependencies: [
                "SwiftWUICore",
                "SwiftWUIState",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ]
        ),

        // CLI - Project scaffolding tool
        .executableTarget(
            name: "swiftwui-init",
            dependencies: [],
            path: "Sources/SwiftWUIInit"
        ),

        // Tests
        .testTarget(
            name: "SwiftWUICoreTests",
            dependencies: ["SwiftWUICore"]
        ),
        .testTarget(
            name: "SwiftWUIHTMLTests",
            dependencies: ["SwiftWUIHTML"]
        ),
        .testTarget(
            name: "SwiftWUIStylesTests",
            dependencies: ["SwiftWUIStyles", "SwiftWUIHTML"]
        ),
        .testTarget(
            name: "SwiftWUIStateTests",
            dependencies: ["SwiftWUIState", "SwiftWUICore"]
        ),
        .testTarget(
            name: "SwiftWUIBrowserTests",
            dependencies: ["SwiftWUIBrowser", "SwiftWUIState"]
        ),
        .testTarget(
            name: "SwiftWUIRuntimeTests",
            dependencies: ["SwiftWUIRuntime", "SwiftWUICore"]
        ),
    ]
)
