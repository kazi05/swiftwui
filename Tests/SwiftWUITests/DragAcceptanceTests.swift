import Testing
@testable import SwiftWUI

@Suite struct DragAcceptanceTests {
    @Test func mimeWildcards() {
        #expect(_DragAcceptance.mimeMatches(pattern: "*/*", mime: "application/pdf"))
        #expect(_DragAcceptance.mimeMatches(pattern: "image/*", mime: "image/png"))
        #expect(!_DragAcceptance.mimeMatches(pattern: "image/*", mime: "video/mp4"))
        #expect(_DragAcceptance.mimeMatches(pattern: "Image/PNG", mime: "image/png"))
        #expect(!_DragAcceptance.mimeMatches(pattern: "image/png", mime: "image/jpeg"))
    }
    @Test func filesToken() {
        #expect(_DragAcceptance.matches(accepts: "Files", types: ["Files"], fileMimes: []))
        #expect(!_DragAcceptance.matches(accepts: "Files", types: ["text/plain"], fileMimes: []))
    }
    @Test func filesWithPatterns() {
        #expect(_DragAcceptance.matches(accepts: "Files:image/*,application/pdf",
                                        types: ["Files"], fileMimes: ["image/png"]))
        #expect(!_DragAcceptance.matches(accepts: "Files:image/*",
                                         types: ["Files"], fileMimes: ["video/mp4"]))
        // items unavailable mid-drag → optimistic accept
        #expect(_DragAcceptance.matches(accepts: "Files:image/*",
                                        types: ["Files"], fileMimes: []))
    }
    @Test func customTypeToken() {
        #expect(_DragAcceptance.matches(accepts: "application/x-swiftwui.taskcard",
                                        types: ["application/x-swiftwui.taskcard"], fileMimes: []))
        #expect(!_DragAcceptance.matches(accepts: "application/x-swiftwui.taskcard",
                                         types: ["text/plain"], fileMimes: []))
    }
    @Test func multiTokenAnyMatch() {
        #expect(_DragAcceptance.matches(accepts: "Files application/x-swiftwui.taskcard",
                                        types: ["application/x-swiftwui.taskcard"], fileMimes: []))
    }
    @Test func dragEventDefaults() {
        let e = DragEvent()
        #expect(e.types.isEmpty && !e.hasFiles && !e.isInternalTransition)
        let d = DropEvent()
        #expect(d.files.isEmpty && d.strings.isEmpty)
    }
}
