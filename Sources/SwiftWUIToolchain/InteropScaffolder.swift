import Foundation

/// Installs an app-owned BridgeJS boundary. The generated ABI glue is never
/// authored here: it is produced by the JavaScriptKit 0.56.1 command plugin.
public enum InteropScaffolder {
    public static let markerBegin = "// swiftwui-interop:begin"
    public static let markerEnd = "// swiftwui-interop:end"
    public static let targetName = "AppInterop"

    @discardableResult
    public static func install(projectDir: String, target: String) throws -> [String] {
        let fm = FileManager.default
        let packagePath = projectDir + "/Package.swift", indexPath = projectDir + "/index.html"
        guard fm.fileExists(atPath: packagePath), fm.fileExists(atPath: indexPath) else { throw ToolchainError.notAProject(projectDir) }
        guard target.range(of: "^[A-Za-z][A-Za-z0-9_]*$", options: .regularExpression) != nil else { throw ToolchainError.invalidName(target) }
        let originalManifest = try String(contentsOfFile: packagePath, encoding: .utf8)
        // A product and a target can share a name. Only a declared target can
        // receive the AppInterop dependency, so reject the former before
        // writing any scaffold files or an apparently successful marker.
        guard declaresTarget(named: target, in: originalManifest) else {
            throw ToolchainError.io("Package.swift has no target named '\(target)' — pass --target with an existing target name")
        }
        var changed: [String] = []
        for rel in ["Package.swift", "tsconfig.json", "Sources/AppInterop/Interop.swift", "Sources/AppInterop/bridge-js.config.json", "Sources/AppInterop/bridge-js.d.ts", "Sources/AppInterop/bridge-js.global.d.ts", "public/interop/index.js", "public/interop/format.js"] {
            // The Swift target lives in Interop/, while the runtime wrapper is a
            // normal project public asset and therefore survives DistLayout.copyPublic.
            let destination = rel.hasPrefix("public/") ? projectDir + "/" + rel : projectDir + "/Interop/" + rel
            if fm.fileExists(atPath: destination) { continue }
            let source = ToolchainResources.url("interop/" + rel)
            try fm.createDirectory(atPath: (destination as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try fm.copyItem(atPath: source.path, toPath: destination)
            changed.append(rel.hasPrefix("public/") ? rel : "Interop/" + rel)
        }
        var manifest = originalManifest
        if !manifest.contains(markerBegin) {
            guard manifest.contains("let package = Package(") || manifest.contains("var package = Package(") else { throw ToolchainError.io("Package.swift must declare `package = Package(...)` for automatic interop wiring") }
            manifest += "\n\(markerBegin)\npackage.dependencies.append(.package(name: \"Interop\", path: \"Interop\"))\nif let target = package.targets.first(where: { $0.name == \"\(target)\" }) {\n    target.dependencies.append(.product(name: \"AppInterop\", package: \"Interop\"))\n}\n\(markerEnd)\n"
            try manifest.write(toFile: packagePath, atomically: true, encoding: .utf8)
            changed.append("Package.swift")
        } else if !manifest.contains("package.targets.first(where: { $0.name == \"\(target)\" })") {
            throw ToolchainError.io("Package.swift has a SwiftWUI interop block for a different target; remove it or initialize the matching target")
        }
        var html = try String(contentsOfFile: indexPath, encoding: .utf8)
        if !html.contains("data-swiftwui-interop") {
            let insertion = try interopLoaderInsertionPoint(in: html)
            // A classic inline script runs while parsing and starts the import
            // after every import map, but before a following module/boot script
            // can observe the promise. The
            // promise itself owns the deadline because the unstamped legacy boot
            // path only awaits it; it has no boot shim timeout of its own.
            let loader = "\n  <script data-swiftwui-interop>let __swuiInteropTimer;window.__swiftwui_interop_ready=Promise.race([import('/interop/index.js'),new Promise((_,reject)=>{__swuiInteropTimer=setTimeout(()=>reject(new Error('JavaScript interop initialization timed out')),30000)})]).finally(()=>clearTimeout(__swuiInteropTimer));window.__swiftwui_interop_ready.catch((error)=>console.error('SwiftWUI interop failed:',error));</script>"
            html.insert(contentsOf: loader, at: insertion)
            try html.write(toFile: indexPath, atomically: true, encoding: .utf8)
            changed.append("index.html")
        }
        return changed
    }

    private static func declaresTarget(named name: String, in manifest: String) -> Bool {
        let uncommented = manifest.replacingOccurrences(of: #"(?s)/\*.*?\*/|//[^\r\n]*"#, with: "", options: .regularExpression)
        let pattern = "\\.(?:target|executableTarget|testTarget|macro|plugin|binaryTarget)\\s*\\(\\s*name\\s*:\\s*\\\"" + NSRegularExpression.escapedPattern(for: name) + "\\\""
        return uncommented.range(of: pattern, options: .regularExpression) != nil
    }

    private static func interopLoaderInsertionPoint(in html: String) throws -> String.Index {
        // Dynamic import begins resolution immediately. An import map that
        // follows it is therefore too late for the generated WASI dependency.
        let pattern = #"(?is)<script\b(?=[^>]*\btype\s*=\s*["']importmap["'])[^>]*>.*?</script\s*>"#
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        if let last = matches.last, let range = Range(last.range, in: html) {
            return range.upperBound
        }
        guard let head = html.range(of: "<head", options: .caseInsensitive),
              let end = html[head.lowerBound...].firstIndex(of: ">") else {
            throw ToolchainError.io("index.html has no <head> for the interop loader")
        }
        return html.index(after: end)
    }

    /// Rebuilds the declared bindings from the resolved, pinned JavaScriptKit
    /// checkout. The package has no lockfile in TS2Swift, so `npm install` is the
    /// reproducible available command for its exact package.json dependency.
    public static func generate(projectDir: String, runner: ProcessRunner) throws {
        let fm = FileManager.default
        let interopDir = projectDir + "/Interop"
        guard fm.fileExists(atPath: interopDir + "/Package.swift") else { throw ToolchainError.io("Interop is not installed; run `swiftwui interop init --target <AppTarget>` first") }
        let ts2swift = interopDir + "/.build/checkouts/JavaScriptKit/Plugins/BridgeJS/Sources/TS2Swift/JavaScript"
        if !fm.fileExists(atPath: ts2swift + "/package.json") {
            let resolve = try runner.run("swift", ["package", "resolve"], cwd: interopDir, streamOutput: true)
            guard resolve.exitCode == 0 else { throw ToolchainError.buildFailed(output: resolve.stdout + resolve.stderr) }
        }
        guard fm.fileExists(atPath: ts2swift + "/package.json") else { throw ToolchainError.io("JavaScriptKit checkout was not resolved under .build/checkouts; run `swift package resolve` and retry") }
        let npm = try runner.run("npm", ["install", "--ignore-scripts", "--no-audit", "--no-fund"], cwd: ts2swift, streamOutput: true)
        guard npm.exitCode == 0 else { throw ToolchainError.buildFailed(output: npm.stdout + npm.stderr) }
        let generated = try runner.run("swift", ["package", "plugin", "--allow-writing-to-package-directory", "bridge-js", "--target", targetName], cwd: interopDir, streamOutput: true)
        guard generated.exitCode == 0 else { throw ToolchainError.buildFailed(output: generated.stdout + generated.stderr) }
        guard fm.fileExists(atPath: interopDir + "/Sources/" + targetName + "/Generated/BridgeJS.swift") else {
            throw ToolchainError.io("BridgeJS completed without Generated/BridgeJS.swift; inspect the plugin output and declarations")
        }
    }
}
