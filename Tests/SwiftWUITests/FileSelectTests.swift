import Foundation
import Testing
@testable import SwiftWUI

private final class InMemoryReader: _FileReading {
    let bytes: Foundation.Data
    init(_ s: String) { bytes = Data(s.utf8) }
    func data() async throws -> Foundation.Data { bytes }
    func text() async throws -> String { String(decoding: bytes, as: UTF8.self) }
}

@Suite @MainActor struct FileSelectTests {

    private func makeFile(_ name: String, _ content: String) -> WebFile {
        WebFile(name: name, size: content.utf8.count, mimeType: "text/plain",
                lastModified: Date(timeIntervalSince1970: 0),
                reader: InMemoryReader(content))
    }

    @Test func onFileSelectionReceivesFiles() {
        @MainActor final class Box { var names: [String] = [] }
        let box = Box()
        struct Picker: Tag {
            let box: Box
            var body: some Tag {
                Input(type: .file, multiple: true)
                    .onFileSelection { files in box.names = files.map(\.name) }
            }
        }
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Picker(box: box), scheduleMicrotask: { $0() })
        runtime.mount()
        func firstChange(_ n: MockNode) -> ListenerID? {
            if let id = n.events["change"] { return id }
            for c in n.children { if let id = firstChange(c) { return id } }
            return nil
        }
        let lid = firstChange(backend.container)!
        runtime.dispatch(lid, payload: FilesEvent(files: [makeFile("a.txt", "hi"),
                                                          makeFile("b.txt", "yo")]))
        #expect(box.names == ["a.txt", "b.txt"])
        _ = runtime
    }

    @Test func webFileReadsThroughReader() async throws {
        let file = makeFile("a.txt", "hello")
        #expect(try await file.text() == "hello")
        #expect(try await file.data() == Data("hello".utf8))
        #expect(file.size == 5)
    }

    @Test func acceptAndMultipleSerialize() {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Input(type: .file, accept: ".png,image/*", multiple: true),
                              scheduleMicrotask: { $0() })
        runtime.mount()
        let html = backend.serializeHTML()
        #expect(html.contains(#"accept=".png,image/*""#))
        #expect(html.contains("multiple"))
        _ = runtime
    }
}
