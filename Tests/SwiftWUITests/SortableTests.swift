import Testing
@testable import SwiftWUI

private final class Recorder {
    var moves: [(Int, Int)] = []
}
private struct ListFixture: Tag {
    let cap: Recorder
    let items: [String]
    var body: some Tag {
        Div(class: "list") {
            ForEach(items, id: \.self) { item in
                Div(class: "row") { P { item } }
            }
            .onMove { from, to in cap.moves.append((from, to)) }
        }
    }
}

@Suite @MainActor struct SortableTests {
    private func mount(_ items: [String] = ["a", "b", "c"])
        -> (Runtime<MockBackend>, MockBackend, TestScheduler, Recorder) {
        let cap = Recorder()
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ListFixture(cap: cap, items: items),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched, cap)
    }
    private func rows(_ backend: MockBackend) -> [MockNode] {
        findFirst(backend.container, tag: "div")!.children.filter { $0.attrs["class"] == "row" }
    }

    @Test func rowsAreDecorated() {
        let (_, backend, _, _) = mount()
        let r = rows(backend)
        #expect(r.count == 3)
        #expect(r[1].attrs["draggable"] == "true")
        #expect(r[1].attrs["data-swui-drag-type"] == "application/x-swiftwui.move")
        #expect(r[1].attrs["data-swui-drag"] == "1")
        #expect(r[1].attrs["data-swui-drop-accepts"] == "application/x-swiftwui.move")
        for e in ["dragstart", "dragover", "drop", "dragend"] {
            #expect(r[0].events[e] != nil)
        }
    }
    @Test func dragDownMovesRow() {
        let (rt, backend, sched, cap) = mount()
        let r = rows(backend)
        rt.dispatch(r[0].events["dragstart"]!, payload: DragEvent(targetHeight: 40))
        sched.pump()
        // hover lower half of row 2 → insertion index 3
        rt.dispatch(rows(backend)[2].events["dragover"]!,
                    payload: DragEvent(targetHeight: 40, offsetY: 30))
        sched.pump()
        rt.dispatch(rows(backend)[2].events["drop"]!, payload: DropEvent())
        sched.pump()
        #expect(cap.moves.count == 1)
        #expect(cap.moves[0].0 == 0 && cap.moves[0].1 == 3)
    }
    @Test func dragUpUpperHalfInsertsBefore() {
        let (rt, backend, sched, cap) = mount()
        let r = rows(backend)
        rt.dispatch(r[2].events["dragstart"]!, payload: DragEvent(targetHeight: 40))
        sched.pump()
        rt.dispatch(rows(backend)[0].events["dragover"]!,
                    payload: DragEvent(targetHeight: 40, offsetY: 10))
        sched.pump()
        rt.dispatch(rows(backend)[0].events["drop"]!, payload: DropEvent())
        sched.pump()
        #expect(cap.moves[0].0 == 2 && cap.moves[0].1 == 0)
    }
    @Test func dragendClearsWithoutMove() {
        let (rt, backend, sched, cap) = mount()
        let r = rows(backend)
        rt.dispatch(r[0].events["dragstart"]!, payload: DragEvent(targetHeight: 40))
        rt.dispatch(r[0].events["dragend"]!, payload: DragEvent())
        sched.pump()
        #expect(cap.moves.isEmpty)
    }
    @Test func foreignDropIsNoop() {
        let (rt, backend, sched, cap) = mount()
        // no dragstart in this list → sourceIndex nil → drop ignored
        rt.dispatch(rows(backend)[1].events["drop"]!, payload: DropEvent())
        sched.pump()
        #expect(cap.moves.isEmpty)
    }
}
