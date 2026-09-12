import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainStaticContainmentTests {
    @Test(arguments: ["file", "directory", "index"])
    func symbolicLinksCannotServeFilesOutsideRoot(kind: String) throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwui-containment-\(UUID().uuidString)")
        let root = base.appendingPathComponent("public")
        let outside = base.appendingPathComponent("private")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let secret = outside.appendingPathComponent("secret.html")
        try "outside-root".write(to: secret, atomically: true, encoding: .utf8)

        let path: String
        switch kind {
        case "file":
            try fm.createSymbolicLink(at: root.appendingPathComponent("linked.html"),
                                      withDestinationURL: secret)
            path = "/linked.html"
        case "directory":
            try fm.createSymbolicLink(at: root.appendingPathComponent("linked"),
                                      withDestinationURL: outside)
            path = "/linked/secret.html"
        default:
            try fm.createSymbolicLink(at: root.appendingPathComponent("index.html"),
                                      withDestinationURL: secret)
            path = "/"
        }

        let handler = StaticFiles.handler(urlPrefix: "/", root: root.path, spaFallback: true)
        let response = handler(HTTPRequest(method: "GET", path: path, headers: [:]))
        #expect(response == nil)
    }

    @Test func symbolicLinksWithinRootAndRootAliasesStillServeFiles() throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftwui-containment-\(UUID().uuidString)")
        let root = base.appendingPathComponent("public")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let page = root.appendingPathComponent("page.html")
        try "inside-root".write(to: page, atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: root.appendingPathComponent("linked.html"),
                                  withDestinationURL: page)
        let alias = base.appendingPathComponent("alias")
        try fm.createSymbolicLink(at: alias, withDestinationURL: root)

        let handler = StaticFiles.handler(urlPrefix: "/", root: alias.path)
        let response = try #require(handler(HTTPRequest(method: "GET", path: "/linked.html", headers: [:])))
        #expect(response.status == 200)
        #expect(String(decoding: response.body, as: UTF8.self) == "inside-root")
    }
}
