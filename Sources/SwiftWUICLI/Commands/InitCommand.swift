import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scaffold a new SwiftWUI project.")

    @Argument(help: "Project name ([A-Za-z][A-Za-z0-9_]*).") var name: String
    @Option(name: .long, help: "Template: basic, mvvm, or tca.") var template: String = "basic"
    @Option(name: .long, help: "Path to a local SwiftWUI checkout (default: fetch from GitHub).")
    var swiftwuiPath: String?

    func run() throws {
        let dir = FileManager.default.currentDirectoryPath + "/" + name
        try Scaffolder.scaffold(template: template, name: name, swiftwuiPath: swiftwuiPath, into: dir)
        print("""
        created \(name)/ (template: \(template))
          cd \(name)
          swiftwui dev
        """)
    }
}
