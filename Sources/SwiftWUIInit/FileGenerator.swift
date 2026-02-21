import Foundation

/// Generates the file system structure for a new SwiftWUI project.
///
/// Creates the project directory, subdirectories, and all template files
/// required to build and run a SwiftWUI web application.
struct FileGenerator {
    /// The name of the project to generate.
    let projectName: String

    /// Generates the complete project structure in the current working directory.
    ///
    /// Creates a new directory named after the project and populates it with
    /// all necessary configuration and source files.
    ///
    /// - Throws: An error if directory creation or file writing fails.
    func generate() throws {
        let fm = FileManager.default
        let currentDir = fm.currentDirectoryPath
        let root = currentDir + "/" + projectName

        // Check if directory already exists
        if fm.fileExists(atPath: root) {
            print("Error: Directory '\(projectName)' already exists.")
            exit(1)
        }

        // Create directory structure
        try fm.createDirectory(
            atPath: root + "/Sources",
            withIntermediateDirectories: true
        )

        // Define all files to generate
        let files: [(relativePath: String, content: String)] = [
            ("/Package.swift", Templates.packageSwift(name: projectName)),
            ("/Sources/main.swift", Templates.mainSwift(name: projectName)),
            ("/index.html", Templates.indexHTML(name: projectName)),
            ("/package.json", Templates.packageJSON(name: projectName)),
            ("/.gitignore", Templates.gitignore()),
        ]

        // Write each file
        for (relativePath, content) in files {
            let fullPath = root + relativePath
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
            print("  Created \(projectName)\(relativePath)")
        }
    }
}
