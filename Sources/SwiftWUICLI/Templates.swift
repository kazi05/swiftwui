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

    /// Generates a `.gitignore` tailored for SwiftWUI WASM projects.
    ///
    /// No `package.json` / `node_modules` rules — the canonical tooling is the
    /// Vapor-based `swiftwui` CLI which builds and serves WASM directly. Vite
    /// stays available as an optional alternative pipeline if a project opts
    /// into a custom JS toolchain, but is no longer scaffolded by default.
    ///
    /// - Returns: The full content of `.gitignore`.
    static func gitignore() -> String {
        """
        .build/
        .swiftpm/
        dist/
        *.wasm
        *.wasm.br
        *.wasm.gz
        *.wasm.sri
        # Vite/npm artefacts (only relevant if you opt into a custom JS pipeline)
        node_modules/
        package-lock.json

        """
    }

    /// Returns a short README explaining how to develop and ship a project
    /// scaffolded by `swiftwui init`.
    static func readmeMD(name: String) -> String {
        """
        # \(name)

        SwiftWUI web application.

        ## Develop

        ```sh
        swiftwui dev --target \(name)
        ```

        Opens a Vapor-backed dev server with hot reload at <http://localhost:8080>.

        ## Build for production

        ```sh
        swiftwui build --target \(name) --optimize size
        ```

        Outputs an optimised, brotli-compressed `dist/` directory ready for
        upload to any static host (Cloudflare Pages, Netlify, Fastly, S3).
        Each artefact has a sidecar `<file>.sri` with its SHA-384 hash for
        Subresource Integrity.

        ## Toolchain

        Run `swiftwui doctor` to verify all required tools (`swift`, `wasm-opt`,
        `brotli`, `gzip`, `openssl`, `fswatch`, swiftwasm SDK) are installed.

        """
    }
}
