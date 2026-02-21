/// File content templates for generated SwiftWUI projects.
///
/// Each static method returns the full text content of a project file,
/// parameterized by the project name where applicable. Templates are based
/// on the working Counter example in the SwiftWUI repository.
enum Templates {

    /// Generates a `Package.swift` manifest for the new project.
    ///
    /// - Parameter name: The project/target name.
    /// - Returns: The full content of `Package.swift`.
    static func packageSwift(name: String) -> String {
        """
        // swift-tools-version: 6.0

        import PackageDescription

        let package = Package(
            name: "\(name)",
            platforms: [.macOS(.v14)],
            dependencies: [
                // Local development dependency (adjust path as needed):
                .package(name: "SwiftWUI", path: "../../"),
                // For published releases, replace the line above with:
                // .package(url: "https://github.com/AkhtarGadique/SwiftWUI.git", from: "0.1.0"),
                .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
            ],
            targets: [
                .executableTarget(
                    name: "\(name)",
                    dependencies: [
                        .product(name: "SwiftWUI", package: "SwiftWUI"),
                    ]
                ),
            ]
        )

        """
    }

    /// Generates the main application source file with a starter ContentView.
    ///
    /// - Parameter name: The project name, used as the page title.
    /// - Returns: The full content of `Sources/main.swift`.
    static func mainSwift(name: String) -> String {
        """
        import SwiftWUI

        struct ContentView: Tag {
            @State var count = 0

            var body: some Tag {
                Div {
                    H1 { "\(name)" }
                    P {
                        Text("Count: \\(count)")
                    }
                    .fontSize(.px(24))
                    Div {
                        Button(onclick: { count -= 1 }) {
                            Text("-")
                        }
                        .padding(.px(8), .px(16))
                        .fontSize(.px(20))
                        .cursor(.pointer)

                        Button(onclick: { count += 1 }) {
                            Text("+")
                        }
                        .padding(.px(8), .px(16))
                        .fontSize(.px(20))
                        .cursor(.pointer)
                    }
                    .display(.flex)
                    .style("gap", "12px")
                    .style("align-items", "center")
                }
                .padding(.px(32))
                .style("font-family", "system-ui, sans-serif")
            }
        }

        let app = Application {
            Route("/") { ContentView() }
        }
        app.mount()

        """
    }

    /// Generates the HTML entry point for the application.
    ///
    /// - Parameter name: The project name, used as the page `<title>`.
    /// - Returns: The full content of `index.html`.
    static func indexHTML(name: String) -> String {
        let lowercasedName = name.lowercased()
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(name)</title>
        </head>
        <body>
            <div id="app"></div>
            <script type="module">
                import { init } from "\(lowercasedName)";
                await init();
            </script>
        </body>
        </html>

        """
    }

    /// Generates the npm `package.json` for the Vite dev server.
    ///
    /// - Parameter name: The project name, used as the npm package name.
    /// - Returns: The full content of `package.json`.
    static func packageJSON(name: String) -> String {
        let lowercasedName = name.lowercased()
        return """
        {
          "name": "\(lowercasedName)-app",
          "private": true,
          "type": "module",
          "scripts": {
            "dev": "vite",
            "build": "vite build"
          },
          "devDependencies": {
            "\(lowercasedName)": "file:.build/plugins/PackageToJS/outputs/Package",
            "vite": "^7.3.1"
          }
        }

        """
    }

    /// Generates a `.gitignore` tailored for SwiftWUI WASM projects.
    ///
    /// - Returns: The full content of `.gitignore`.
    static func gitignore() -> String {
        """
        .build/
        node_modules/
        .swiftpm/
        *.js
        !vite.config.js

        """
    }
}
