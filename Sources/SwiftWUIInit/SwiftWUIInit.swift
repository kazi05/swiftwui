import Foundation

/// Entry point for the SwiftWUI project scaffolding CLI tool.
///
/// Usage: `swift run swiftwui-init <ProjectName>`
///
/// Generates a complete SwiftWUI project directory with all required
/// configuration files, a starter application, and development tooling.
@main
struct SwiftWUIInit {
    static func main() throws {
        let args = CommandLine.arguments

        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        let projectName = args[1]

        guard isValidProjectName(projectName) else {
            print("Error: Project name must contain only letters, numbers, hyphens, and underscores.")
            exit(1)
        }

        let generator = FileGenerator(projectName: projectName)
        try generator.generate()

        printSuccess(projectName: projectName)
    }

    /// Validates that a project name contains only allowed characters.
    private static func isValidProjectName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    /// Prints usage information when no arguments are provided.
    private static func printUsage() {
        print("""
        SwiftWUI Project Generator

        Usage: swift run swiftwui-init <ProjectName>

        Creates a new SwiftWUI project with:
          - Package.swift (Swift 6.0, WASM-ready)
          - Sources/main.swift (Application + ContentView template)
          - index.html (HTML template with <div id="app">)
          - package.json (Vite dev server)
          - .gitignore
        """)
    }

    /// Prints success message with next steps after project generation.
    private static func printSuccess(projectName: String) {
        print("""

        Project '\(projectName)' created successfully!

        Next steps:
          cd \(projectName)
          npm install
          swift package --swift-sdk swift-6.2.3-RELEASE_wasm js -c debug
          npm run dev

        Then open http://localhost:8080 in your browser.
        """)
    }
}
