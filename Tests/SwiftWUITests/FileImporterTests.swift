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

private final class Recorder { var completions: [[WebFile]] = [] }
private struct ImporterFixture: Tag {
    let cap: Recorder
    @State var showPicker = false
    var body: some Tag {
        Button("pick", onClick: { showPicker = true })
            .fileImporter(isPresented: $showPicker,
                          allowedContentTypes: [.image],
                          allowsMultipleSelection: true) { cap.completions.append($0) }
        P { showPicker ? "open" : "closed" }
    }
}

@Suite @MainActor struct FileImporterTests {
    private func mount() -> (Runtime<MockBackend>, MockBackend, TestScheduler, Recorder) {
        let cap = Recorder()
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ImporterFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched, cap)
    }
    @Test func presentBumpsClickCommand() {
        let (rt, backend, sched, _) = mount()
        let input = findFirst(backend.container, tag: "input")!
        #expect(input.props["swui:cmd:click"] == .string("0"))
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(input.props["swui:cmd:click"] == .string("1"))
    }
    @Test func selectionCompletesAndResetsBinding() {
        let (rt, backend, sched, cap) = mount()
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        let input = findFirst(backend.container, tag: "input")!
        let file = WebFile(name: "a.png", size: 3, mimeType: "image/png",
                           lastModified: Date(timeIntervalSince1970: 0), reader: StubReader())
        rt.dispatch(input.events["change"]!, payload: FilesEvent(files: [file]))
        sched.pump()
        #expect(cap.completions.count == 1 && cap.completions[0][0].name == "a.png")
        #expect(findFirst(backend.container, tag: "p")!.children[0].text == "closed")
    }
    @Test func cancelResetsBinding() {
        let (rt, backend, sched, cap) = mount()
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        let input = findFirst(backend.container, tag: "input")!
        rt.dispatch(input.events["cancel"]!)
        sched.pump()
        #expect(cap.completions.isEmpty)
        #expect(findFirst(backend.container, tag: "p")!.children[0].text == "closed")
    }
    @Test func hiddenInputSerialization() {
        let (_, backend, _, _) = mount()
        let html = backend.serializeHTML()
        #expect(html.contains("accept=\"image/*\"") && html.contains(" multiple"))
        #expect(html.contains("style=\"display: none\""))
        #expect(!html.contains("swui:cmd"))
    }
}
