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

private final class Recorder {
    var targeted: [Bool] = []
    var dropped: [[WebFile]] = []
    var location: DropLocation?
}
private struct ZoneFixture: Tag {
    let cap: Recorder
    let allowed: [FileType]
    var body: some Tag {
        Div()
            .dropDestination(for: WebFile.self, allowedTypes: allowed) { files, loc in
                cap.dropped.append(files); cap.location = loc; return true
            } isTargeted: { cap.targeted.append($0) }
    }
}

@Suite @MainActor struct FileDropDestinationTests {
    private func mount(_ allowed: [FileType] = []) -> (Runtime<MockBackend>, MockBackend, TestScheduler, Recorder) {
        let cap = Recorder()
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ZoneFixture(cap: cap, allowed: allowed),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched, cap)
    }

    @Test func acceptsAttributeSerialized() {
        let (_, backend, _, _) = mount([.image, .pdf])
        #expect(backend.serializeHTML().contains(
            "data-swui-drop-accepts=\"Files:image/*,application/pdf\""))
        let (_, b2, _, _) = mount()
        #expect(b2.serializeHTML().contains("data-swui-drop-accepts=\"Files\""))
    }
    @Test func targetedLifecycleIgnoresInternalTransitions() {
        let (rt, backend, sched, cap) = mount()
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["dragenter"]!, payload: DragEvent(types: ["Files"], hasFiles: true))
        rt.dispatch(div.events["dragleave"]!, payload: DragEvent(isInternalTransition: true))
        rt.dispatch(div.events["dragenter"]!, payload: DragEvent(types: ["Files"], hasFiles: true,
                                                                 isInternalTransition: true))
        rt.dispatch(div.events["dragleave"]!, payload: DragEvent())
        sched.pump()
        #expect(cap.targeted == [true, false])   // internal enter/leave ignored
    }
    @Test func nonFileDragNeverTargets() {
        let (rt, backend, sched, cap) = mount()
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["dragenter"]!, payload: DragEvent(types: ["text/plain"]))
        sched.pump()
        #expect(cap.targeted.isEmpty)
    }
    @Test func dropDeliversFilesAndLocation() {
        let (rt, backend, sched, cap) = mount()
        let div = findFirst(backend.container, tag: "div")!
        let f = stubFile(name: "a.png", mime: "image/png")
        rt.dispatch(div.events["drop"]!, payload: DropEvent(files: [f], x: 10, y: 20))
        sched.pump()
        #expect(cap.dropped.count == 1 && cap.dropped[0].count == 1)
        #expect(cap.location == DropLocation(x: 10, y: 20))
        #expect(cap.targeted.last == false)
    }
    @Test func allowedTypesFilterAtDrop() {
        let (rt, backend, sched, cap) = mount([.image])
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["drop"]!, payload: DropEvent(files: [
            stubFile(name: "a.png", mime: "image/png"),
            stubFile(name: "b.mp4", mime: "video/mp4"),
        ]))
        sched.pump()
        #expect(cap.dropped.count == 1 && cap.dropped[0].map(\.name) == ["a.png"])
        // all filtered out → action not called
        rt.dispatch(div.events["drop"]!, payload: DropEvent(files: [
            stubFile(name: "c.mp4", mime: "video/mp4"),
        ]))
        sched.pump()
        #expect(cap.dropped.count == 1)
    }
    @Test func dragoverListenerRegistered() {
        let (_, backend, _, _) = mount()
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.events["dragover"] != nil)   // decode acceptance depends on it
    }
}
