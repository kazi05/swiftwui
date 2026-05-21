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
        .executable(name: "swiftwui", targets: ["SwiftWUICLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
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

        // HTML - All HTML tags. Depends on SwiftWUIState so overlay
        // modifiers (.sheet / .alert / .popover) can take a `Binding<Bool>`
        // for their isPresented gate without forcing every consumer to
        // unwrap Bindings manually.
        .target(
            name: "SwiftWUIHTML",
            dependencies: ["SwiftWUICore", "SwiftWUIState"]
        ),

        // Styles - CSS modifiers and values
        .target(
            name: "SwiftWUIStyles",
            dependencies: ["SwiftWUICore"]
        ),

        // State - Reactivity (@State, @Binding, observe)
        .target(
            name: "SwiftWUIState",
            dependencies: [
                "SwiftWUICore",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ]
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

        // Unified CLI: scaffolding + dev server + production build under
        // a single `swiftwui` binary using swift-argument-parser. Replaces
        // the legacy `swiftwui-init` and `swiftwui-dev` executables.
        //
        // Target name is CamelCase (`SwiftWUICLI`) so the build directory
        // does not collide with the umbrella library `SwiftWUI` on
        // case-insensitive filesystems. The product name `swiftwui` is what
        // users actually invoke; SwiftPM lets binary name and target name
        // diverge via the products array.
        .executableTarget(
            name: "SwiftWUICLI",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/SwiftWUICLI",
            resources: [
                .copy("Templates"),
            ]
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
        .testTarget(
            name: "SwiftWUICLITests",
            dependencies: ["SwiftWUICLI"],
            path: "Tests/SwiftWUICLITests"
        ),
    ]
)
