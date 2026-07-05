import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainWatcherTests {
    func tempProject() throws -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-watch-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir + "/Sources", withIntermediateDirectories: true)
        try "// v1".write(toFile: dir + "/Sources/main.swift", atomically: true, encoding: .utf8)
        try "// pkg".write(toFile: dir + "/Package.swift", atomically: true, encoding: .utf8)
        return dir
    }

    @Test func detectsEditAddRemoveOnce() throws {
        let dir = try tempProject()
        let w = FileWatcher(root: dir)
        #expect(!w.changed())                                     // quiescent
        try "// v2".write(toFile: dir + "/Sources/main.swift", atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(2)],
                                              ofItemAtPath: dir + "/Sources/main.swift")
        #expect(w.changed())                                      // edit seen
        #expect(!w.changed())                                     // consumed
        try "// new".write(toFile: dir + "/Sources/extra.swift", atomically: true, encoding: .utf8)
        #expect(w.changed())                                      // add seen
        try FileManager.default.removeItem(atPath: dir + "/Sources/extra.swift")
        #expect(w.changed())                                      // remove seen
    }

    @Test func ignoresNonSwiftNoise() throws {
        let dir = try tempProject()
        let w = FileWatcher(root: dir)
        try "x".write(toFile: dir + "/Sources/notes.txt", atomically: true, encoding: .utf8)
        #expect(!w.changed())
    }
}
