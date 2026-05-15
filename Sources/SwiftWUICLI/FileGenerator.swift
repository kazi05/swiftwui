import ArgumentParser
import Foundation

/// Generates the file system structure for a new SwiftWUI project.
///
/// Creates the project directory and populates it with all template files
/// required to build and run a SwiftWUI web application. Two modes are
/// available: `.showcase` (default) copies the full 12-chapter Apple-style
/// showcase from the bundled resource, and `.minimal` writes a minimal
/// Counter-style scaffold from inline templates.
struct FileGenerator {

    // MARK: - Nested types

    /// Controls which scaffold template `generate()` produces.
    enum Mode: String {
        /// The default mode: a full 12-chapter showcase application copied
        /// from `Templates/showcase/` in the SwiftWUICLI resource bundle.
        case showcase
        /// The legacy minimal Counter-style scaffold generated from inline
        /// string templates in `Templates.swift`.
        case minimal
    }

    // MARK: - Stored properties

    /// The name of the project to generate.
    let projectName: String

    /// Which scaffold template to produce.
    let mode: Mode

    // MARK: - Init

    /// Creates a new generator.
    ///
    /// - Parameters:
    ///   - projectName: The name of the project directory and Swift module.
    ///   - mode: Template mode. Defaults to `.showcase`.
    init(projectName: String, mode: Mode = .showcase) {
        self.projectName = projectName
        self.mode = mode
    }

    // MARK: - Public API

    /// Generates the complete project structure in the current working directory.
    ///
    /// Creates a new directory named after the project and populates it with
    /// all necessary configuration and source files.
    ///
    /// - Throws: An error if directory creation or file writing fails, or if
    ///   the showcase template resource cannot be located in the bundle.
    func generate() throws {
        let dest = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(projectName)

        if FileManager.default.fileExists(atPath: dest.path) {
            // Throw a ValidationError so swift-argument-parser surfaces a
            // single clean error message and a non-zero exit, without
            // killing the process from inside a library helper. This also
            // keeps `generate()` callable from unit tests.
            throw ValidationError("Directory '\(projectName)' already exists.")
        }

        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: false)
        var success = false
        defer {
            if !success {
                try? FileManager.default.removeItem(at: dest)
            }
        }
        switch mode {
        case .showcase: try scaffoldShowcase(at: dest)
        case .minimal:  try scaffoldMinimal(at: dest)
        }
        success = true
    }

    // MARK: - Private helpers

    /// Copies the bundled showcase template into `destination` and substitutes
    /// the `{{PROJECT_NAME}}` and `{{project_name}}` placeholder tokens.
    ///
    /// - Parameter destination: The newly-created project root directory.
    /// - Throws: An `NSError` with domain `SwiftWUICLI` / code 100 if the
    ///   template resource is missing from the bundle; any `FileManager` or
    ///   string-encoding error encountered during the copy or token walk.
    private func scaffoldShowcase(at destination: URL) throws {
        let templateRoot: URL

        // Try Bundle.module first (works for executable targets built with SPM
        // resource support on Swift 5.9+). The `forResource:withExtension:subdirectory:`
        // form is required — forResource: does NOT treat slashes as path separators,
        // so "Templates/showcase" would always return nil.
        if let bundledURL = Bundle.module.url(
            forResource: "showcase",
            withExtension: nil,
            subdirectory: "Templates"
        ) {
            templateRoot = bundledURL
        } else if let fallbackURL = executableRelativeTemplateURL() {
            templateRoot = fallbackURL
        } else {
            throw NSError(
                domain: "SwiftWUICLI", code: 100,
                userInfo: [NSLocalizedDescriptionKey:
                    "Templates/showcase resource missing — try `make sync-templates`"]
            )
        }

        // Copy the whole tree into the destination.
        // destination already exists (created in generate()), so we must copy
        // the *contents* rather than the directory itself.
        let fm = FileManager.default
        let items = try fm.contentsOfDirectory(
            at: templateRoot,
            includingPropertiesForKeys: nil
        )
        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            do {
                try fm.copyItem(at: item, to: target)
            } catch {
                // Surface which item failed — a generic NSCocoaErrorDomain
                // message gives no hint about the partial copy state, and
                // `defer { rm dest }` will already clean up.
                throw NSError(
                    domain: "SwiftWUICLI", code: 101,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Failed copying '\(item.lastPathComponent)' into '\(projectName)/': \(error.localizedDescription)"]
                )
            }
            print("  Created \(projectName)/\(item.lastPathComponent)")
        }

        // Substitute placeholder tokens throughout all text files.
        try renameTokens(in: destination, replacing: [
            "{{PROJECT_NAME}}": projectName,
            "{{project_name}}": projectName.lowercased(),
        ])

        // Sync target rsyncs literal directory names; tokens are substituted
        // inside file content only. The Swift module / target / test-target
        // names produced after `renameTokens` need the source directories
        // renamed to match (SwiftPM convention: `Sources/<targetName>/`).
        try renameDirectories(in: destination, replacing: [
            "Showcase": projectName,
        ])
    }

    /// Locates the `Templates/showcase` directory relative to the CLI binary,
    /// used as a fallback when `Bundle.module` is not synthesised.
    ///
    /// Walks up from the executable path to find a `Templates/showcase` sibling.
    ///
    /// - Returns: The URL if found, `nil` otherwise.
    private func executableRelativeTemplateURL() -> URL? {
        guard CommandLine.arguments.count > 0 else { return nil }
        var candidate = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        // Walk up at most five levels (covers .build/debug/swiftwui → project root).
        for _ in 0..<5 {
            let probe = candidate
                .appendingPathComponent("Templates")
                .appendingPathComponent("showcase")
            if FileManager.default.fileExists(atPath: probe.path) {
                return probe
            }
            candidate = candidate.deletingLastPathComponent()
        }
        return nil
    }

    /// Renames subdirectories inside `dir` whose names contain any of the
    /// provided token strings.
    ///
    /// The walk is top-down (outer directories renamed before inner ones) so
    /// that a parent rename does not invalidate a child URL already on the
    /// pending stack.
    ///
    /// The showcase template stores source directories under their literal
    /// names (`Sources/Showcase/`, `Tests/ShowcaseTests/`) because the
    /// `make sync-templates` rsync step only substitutes tokens inside file
    /// content, not in path components. This helper fixes up those names at
    /// scaffold time so the generated project satisfies SwiftPM's
    /// `Sources/<targetName>/` convention and builds without modification.
    ///
    /// - Parameters:
    ///   - dir: Root directory to walk.
    ///   - tokens: Dictionary mapping literal strings to their replacements.
    /// - Throws: Any `FileManager.moveItem` error.
    private func renameDirectories(in dir: URL, replacing tokens: [String: String]) throws {
        let fm = FileManager.default
        // Top-down breadth-first walk so we rename outer dirs before inner ones.
        // Walk the tree manually so we don't fight a paused enumerator.
        var pending: [URL] = [dir]
        while let cur = pending.popLast() {
            guard let entries = try? fm.contentsOfDirectory(
                at: cur,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) else { continue }
            for entry in entries {
                let isDir = (try? entry.resourceValues(
                    forKeys: [.isDirectoryKey]
                ).isDirectory) ?? false
                guard isDir else { continue }
                let name = entry.lastPathComponent
                var newName = name
                for (token, value) in tokens {
                    newName = newName.replacingOccurrences(of: token, with: value)
                }
                if newName != name {
                    let renamed = entry.deletingLastPathComponent()
                        .appendingPathComponent(newName)
                    try fm.moveItem(at: entry, to: renamed)
                    pending.append(renamed)
                } else {
                    pending.append(entry)
                }
            }
        }
    }

    /// Recursively walks `dir` and performs in-place token replacement on all
    /// recognised text files.
    ///
    /// - Parameters:
    ///   - dir: Root directory to walk.
    ///   - tokens: Dictionary mapping placeholder strings to their replacements.
    /// - Throws: Any `String(contentsOf:)` or `String.write(to:)` error.
    private func renameTokens(in dir: URL, replacing tokens: [String: String]) throws {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return }

        let textExtensions: Set<String> = [
            "swift", "html", "md", "json", "css", "js",
            "yml", "yaml", "txt",
        ]

        for case let url as URL in walker {
            let isFile = (try? url.resourceValues(
                forKeys: [.isRegularFileKey]
            ).isRegularFile) ?? false
            guard isFile else { continue }

            let ext = url.pathExtension.lowercased()
            guard textExtensions.contains(ext) else { continue }

            var contents = try String(contentsOf: url, encoding: .utf8)
            for (token, value) in tokens {
                contents = contents.replacingOccurrences(of: token, with: value)
            }
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Writes the legacy minimal Counter-style scaffold using inline templates.
    ///
    /// - Parameter destination: The newly-created project root directory.
    /// - Throws: Any file-system error encountered while writing template files.
    private func scaffoldMinimal(at destination: URL) throws {
        let root = destination.path

        // Create Sources subdirectory.
        try FileManager.default.createDirectory(
            atPath: root + "/Sources",
            withIntermediateDirectories: true
        )

        let files: [(relativePath: String, content: String)] = [
            ("/Package.swift",      Templates.minimalPackageSwift(name: projectName)),
            ("/Sources/main.swift", Templates.minimalMainSwift(name: projectName)),
            ("/index.html",         Templates.minimalIndexHTML(name: projectName)),
            ("/README.md",          Templates.minimalReadmeMD(name: projectName)),
            ("/.gitignore",         Templates.minimalGitignore()),
        ]

        for (relativePath, content) in files {
            let fullPath = root + relativePath
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
            print("  Created \(projectName)\(relativePath)")
        }
    }
}
