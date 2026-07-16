import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import SwiftWUI

private final class StubReader: _FileReading {
    func data() async throws -> _FoundationData { _FoundationData() }
    func text() async throws -> String { "" }
}
private func stubFile(name: String, mime: String) -> WebFile {
    WebFile(name: name, size: 1, mimeType: mime,
            lastModified: Date(timeIntervalSince1970: 0), reader: StubReader())
}

@Suite @MainActor struct FileTypeTests {
    @Test func mimeMatching() {
        #expect(FileType.image.matches(stubFile(name: "a.png", mime: "image/png")))
        #expect(!FileType.image.matches(stubFile(name: "a.mp4", mime: "video/mp4")))
        #expect(FileType.pdf.matches(stubFile(name: "doc", mime: "application/pdf")))
        #expect(FileType.any.matches(stubFile(name: "x", mime: "whatever/x")))
    }
    @Test func extensionFallbackWhenMimeEmpty() {
        #expect(FileType.jpeg.matches(stubFile(name: "photo.JPG", mime: "")))
        #expect(!FileType.jpeg.matches(stubFile(name: "photo", mime: "")))     // no dot
        #expect(!FileType.png.matches(stubFile(name: "photo.jpg", mime: "")))
        #expect(FileType(mime: "image/png", extensions: ["PNG"]).matches(stubFile(name: "a.png", mime: "")))
    }
    @Test func acceptStringJoins() {
        #expect(FileType.acceptString([]) == nil)
        #expect(FileType.acceptString([.png, .pdf]) == "image/png,.png,application/pdf,.pdf")
    }
    @Test func typedInputAcceptSerializes() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Input(type: .file, accept: [.image], multiple: true),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        let html = backend.serializeHTML()
        #expect(html.contains("accept=\"image/*\""))
        #expect(html.contains(" multiple"))
    }
}
