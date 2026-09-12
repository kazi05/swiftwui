import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct InteropScaffolderTests {
    @Test func installIsIdempotentAndWiresOnlyTheNamedTarget() throws {
        let root = NSTemporaryDirectory() + "swiftwui-interop-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        try """
        import PackageDescription
        let package = Package(name: "Example", targets: [.executableTarget(name: "App")])
        """.write(toFile: root + "/Package.swift", atomically: true, encoding: .utf8)
        try "<html><head><script type=\"module\" src=\"/app/index.js\"></script></head><body></body></html>".write(toFile: root + "/index.html", atomically: true, encoding: .utf8)
        let first = try InteropScaffolder.install(projectDir: root, target: "App")
        #expect(first.contains("Package.swift"))
        #expect(first.contains("index.html"))
        let package = try String(contentsOfFile: root + "/Package.swift", encoding: .utf8)
        #expect(package.contains("let package = Package"))
        #expect(package.components(separatedBy: InteropScaffolder.markerBegin).count == 2)
        #expect(package.contains("AppInterop"))
        let html = try String(contentsOfFile: root + "/index.html", encoding: .utf8)
        #expect(html.contains("data-swiftwui-interop"))
        #expect(html.range(of: "data-swiftwui-interop")!.lowerBound < html.range(of: "type=\"module\"")!.lowerBound)
        #expect(html.contains("__swiftwui_interop_ready=Promise.race"))
        #expect(html.contains("JavaScript interop initialization timed out"))
        #expect(html.contains("console.error('SwiftWUI interop failed:',error)"))
        #expect(FileManager.default.fileExists(atPath: root + "/public/interop/index.js"))
        #expect(!FileManager.default.fileExists(atPath: root + "/Interop/public/interop/index.js"))
        let facade = try String(contentsOfFile: root + "/Interop/Sources/AppInterop/Interop.swift", encoding: .utf8)
        #expect(facade.contains("public enum AppInterop"))
        #expect(facade.contains("public func dispose"))
        _ = try InteropScaffolder.install(projectDir: root, target: "App")
        let second = try String(contentsOfFile: root + "/Package.swift", encoding: .utf8)
        #expect(second == package)
    }

    @Test func installRejectsUnknownTargetBeforeChangingManifest() throws {
        let root = NSTemporaryDirectory() + "swiftwui-interop-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        let original = "import PackageDescription\nlet package = Package(name: \"Example\")\n"
        try original.write(toFile: root + "/Package.swift", atomically: true, encoding: .utf8)
        try "<head></head>".write(toFile: root + "/index.html", atomically: true, encoding: .utf8)
        #expect(throws: ToolchainError.self) { try InteropScaffolder.install(projectDir: root, target: "Missing") }
        #expect(try String(contentsOfFile: root + "/Package.swift", encoding: .utf8) == original)
    }

    @Test func installRejectsAProductWhoseNameIsNotATarget() throws {
        let root = NSTemporaryDirectory() + "swiftwui-interop-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        let original = """
        import PackageDescription
        let package = Package(name: "Example", products: [.executable(name: "App", targets: ["ActualApp"])], targets: [.executableTarget(name: "ActualApp")])
        """
        try original.write(toFile: root + "/Package.swift", atomically: true, encoding: .utf8)
        try "<head></head>".write(toFile: root + "/index.html", atomically: true, encoding: .utf8)
        #expect(throws: ToolchainError.self) { try InteropScaffolder.install(projectDir: root, target: "App") }
        #expect(try String(contentsOfFile: root + "/Package.swift", encoding: .utf8) == original)
        #expect(!FileManager.default.fileExists(atPath: root + "/Interop"))
    }

    @Test func loaderFollowsImportMapAndPrecedesBootModule() throws {
        let root = NSTemporaryDirectory() + "swiftwui-interop-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        try "import PackageDescription\nlet package = Package(name: \"Example\", targets: [.executableTarget(name: \"App\")])\n".write(toFile: root + "/Package.swift", atomically: true, encoding: .utf8)
        try """
        <html><head>
        <script type="importmap">{"imports":{"@bjorn3/browser_wasi_shim":"/vendor/wasi.js"}}</script>
        <script type="module" src="/app/index.js"></script>
        </head><body></body></html>
        """.write(toFile: root + "/index.html", atomically: true, encoding: .utf8)
        _ = try InteropScaffolder.install(projectDir: root, target: "App")
        let html = try String(contentsOfFile: root + "/index.html", encoding: .utf8)
        let map = try #require(html.range(of: "type=\"importmap\""))
        let loader = try #require(html.range(of: "data-swiftwui-interop"))
        let boot = try #require(html.range(of: "type=\"module\""))
        #expect(map.lowerBound < loader.lowerBound)
        #expect(loader.lowerBound < boot.lowerBound)
    }

    @Test func commentedTargetDoesNotCountAsATarget() throws {
        let root = NSTemporaryDirectory() + "swiftwui-interop-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        let original = """
        import PackageDescription
        // .executableTarget(name: "App")
        let package = Package(name: "Example", targets: [.executableTarget(name: "ActualApp")])
        """
        try original.write(toFile: root + "/Package.swift", atomically: true, encoding: .utf8)
        try "<head></head>".write(toFile: root + "/index.html", atomically: true, encoding: .utf8)
        #expect(throws: ToolchainError.self) { try InteropScaffolder.install(projectDir: root, target: "App") }
        #expect(try String(contentsOfFile: root + "/Package.swift", encoding: .utf8) == original)
    }
}
