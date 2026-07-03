import Testing
import Observation
@testable import SwiftWUI

@Observable private final class Model {
    var count = 0
    var unrelated = 0
}

private final class Counters { var byLabel: [String: Int] = [:]
                               func bump(_ l: String) { byLabel[l, default: 0] += 1 } }

private struct Reader: Tag {
    let model: Model
    let counters: Counters
    var body: some Tag {
        counters.bump("reader")
        return P { "count: \(model.count)" }
    }
}
private struct NonReader: Tag {
    let counters: Counters
    var body: some Tag {
        counters.bump("nonreader")
        return P { "static" }
    }
}
private struct ObsHost: Tag {
    @State var model = Model()
    let counters: Counters
    var body: some Tag {
        counters.bump("host")
        return Div {
            Reader(model: model, counters: counters)
            NonReader(counters: counters)
            Button("+") { model.count += 1 }
        }
    }
}

@Observable private final class RowModel {
    var label = "one"
}
private struct DirectForEachRead: Tag {
    let model: RowModel
    var body: some Tag {
        Ul {
            ForEach([1], id: \.self) { _ in
                Li { model.label }        // read INSIDE ForEach closure, no row component
            }
        }
    }
}

@MainActor @Suite struct ObservationTests {
    @Test func forEachClosureReadTracksModel() {
        let backend = MockBackend(); let sched = TestScheduler()
        let model = RowModel()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: DirectForEachRead(model: model),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.serializeHTML().contains("one"))
        model.label = "two"                // must invalidate DirectForEachRead
        sched.pump()
        #expect(backend.serializeHTML().contains("two"))
        #expect(!backend.serializeHTML().contains("one"))
    }

    @Test func modelWriteDirtiesOnlyReaders() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ObsHost(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(counters.byLabel == ["host": 1, "reader": 1, "nonreader": 1])

        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        // host's body reads nothing on the model; only Reader read .count
        #expect(counters.byLabel == ["host": 1, "reader": 2, "nonreader": 1])
        #expect(findAll(backend.container, tag: "p")[0].children[0].text == "count: 1")
    }

    @Test func trackingRearmsAcrossRenders() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ObsHost(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        let button = findFirst(backend.container, tag: "button")!
        for expected in 1...3 {
            rt.dispatch(button.events["click"]!)
            sched.pump()
            #expect(counters.byLabel["reader"] == expected + 1)   // fires every time, not once
        }
    }

    @Test func unrelatedPropertyWriteIsIgnored() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let model = Model()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Reader(model: model, counters: counters),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        model.unrelated += 1                          // never read by any body
        sched.pump()
        #expect(counters.byLabel["reader"] == 1)      // no re-render
    }

    @Test func bindableProducesWritableBinding() {
        let model = Model()
        @Bindable var m = model
        let binding = $m.count
        binding.wrappedValue = 7
        #expect(model.count == 7)
        #expect(binding.wrappedValue == 7)
    }
}
