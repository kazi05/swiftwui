import Testing
@testable import SwiftWUICore
@testable import SwiftWUIState

@Suite("onChange Modifier", .serialized)
struct OnChangeTests {
    @Test("onChange wraps content transparently")
    func onChangeWrapsContent() {
        let text = Text("Hello")
        let modified = text.onChange(of: 0) { _, _ in }
        let nodes = resolveTagBody(modified)
        #expect(nodes.count == 1)
        if case .text(let content) = nodes.first {
            #expect(content == "Hello")
        } else {
            Issue.record("Expected text node passed through")
        }
    }

    @Test("onChange is available on any Tag")
    func onChangeAvailableOnAnyTag() {
        let text = Text("Test")
        let _ = text.onChange(of: "value") { _, _ in }
        // Compiles = passes
    }

    @Test("onChange fires when value changes across re-renders at same call site")
    func onChangeFiresAcrossRenders() {
        OnChangeStorage.clear()
        final class FireLog: @unchecked Sendable {
            var entries: [(Int, Int)] = []
        }
        final class Box: @unchecked Sendable { var value: Int = 1 }

        let log = FireLog()
        let box = Box()
        let observer: @Sendable (Int, Int) -> Void = { old, new in
            log.entries.append((old, new))
        }

        // Simulate re-renders by reconstructing the tag at the same call site.
        // The previous-value storage must persist across these reconstructions.
        func renderOnce() {
            let tag = Text("x").onChange(of: box.value, perform: observer)
            _ = tag.toTagNodes()
        }

        // First render: no prior value, action must not fire.
        renderOnce()
        #expect(log.entries.isEmpty)

        // Second render with same value: action must not fire.
        renderOnce()
        #expect(log.entries.isEmpty)

        // Mutate value, third render: action must fire with (1, 2).
        box.value = 2
        renderOnce()
        #expect(log.entries.count == 1)
        if let last = log.entries.last {
            #expect(last == (1, 2))
        }

        // Mutate again, fourth render: action must fire with (2, 3).
        box.value = 3
        renderOnce()
        #expect(log.entries.count == 2)
        if let last = log.entries.last {
            #expect(last == (2, 3))
        }

        // No mutation, fifth render: must not fire again.
        renderOnce()
        #expect(log.entries.count == 2)
    }

    @Test("onChange isolates storage between distinct call sites")
    func onChangeIsolatesCallSites() {
        OnChangeStorage.clear()
        final class Counter: @unchecked Sendable { var n = 0 }
        final class IntBox: @unchecked Sendable {
            var value: Int
            init(_ v: Int) { self.value = v }
        }
        let a = Counter()
        let b = Counter()
        let v1 = IntBox(1)
        let v2 = IntBox(100)

        func renderA() {
            let tag = Text("a").onChange(of: v1.value) { _, _ in a.n += 1 }
            _ = tag.toTagNodes()
        }
        func renderB() {
            let tag = Text("b").onChange(of: v2.value) { _, _ in b.n += 1 }
            _ = tag.toTagNodes()
        }

        renderA(); renderB()  // prime
        renderA(); renderB()  // no change
        v1.value = 2; renderA(); renderB()  // a fires
        #expect(a.n == 1)
        #expect(b.n == 0)
        v2.value = 200; renderA(); renderB()  // b fires
        #expect(a.n == 1)
        #expect(b.n == 1)
    }
}
