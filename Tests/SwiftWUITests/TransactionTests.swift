import Foundation
import Testing
@testable import SwiftWUI

private struct SpringBlock: Tag {
    @State var on = false
    var body: some Tag {
        Div(class: "spring") {
            Text(on ? "1" : "0")
            Button("t") { withAnimation(.spring(duration: 1)) { on.toggle() } }
        }
    }
}
private struct LinearBlock: Tag {
    @State var on = false
    var body: some Tag {
        Div(class: "linear") {
            Text(on ? "1" : "0")
            Button("t") { withAnimation(.linear(duration: 0.2)) { on.toggle() } }
        }
    }
}
private struct TwoAnimatedBlocks: Tag {
    var body: some Tag {
        SpringBlock()
        LinearBlock()
    }
}

private struct PlainBlock: Tag {
    @State var on = false
    let cls: String
    var body: some Tag {
        Div(class: cls) {
            Text(on ? "1" : "0")
            Button("t") { on.toggle() }
        }
    }
}
private struct XYBlocks: Tag {
    var body: some Tag {
        PlainBlock(cls: "x")
        PlainBlock(cls: "y")
    }
}

private struct SoloBlock: Tag {
    @State var on = false
    var body: some Tag {
        Div(class: "solo") {
            Text(on ? "1" : "0")
            Button("t") { on.toggle() }
        }
    }
}

/// Finds the first element node (in the internal `Node` tree, not the DOM)
/// matching `predicate` — used to recover an element's `NodeIdentity` for
/// asserting against `Runtime._lastEffectiveTransactions`.
@MainActor
func findElement(_ node: Node, where predicate: (ElementNode) -> Bool) -> ElementNode? {
    switch node {
    case .element(let e):
        if predicate(e) { return e }
        for c in e.children { if let f = findElement(c, where: predicate) { return f } }
        return nil
    case .component(let c):
        for ch in c.children { if let f = findElement(ch, where: predicate) { return f } }
        return nil
    case .text:
        return nil
    }
}

@Suite @MainActor struct TransactionTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func perWriteCapture_twoBlocksTwoTransactions() {
        let (runtime, backend, sched) = makeRuntime(TwoAnimatedBlocks())
        let buttons = findAll(backend.container, tag: "button")
        withAnimation(.spring(duration: 1)) { runtime.dispatch(buttons[0].events["click"]!) }
        withAnimation(.linear(duration: 0.2)) { runtime.dispatch(buttons[1].events["click"]!) }
        sched.pump()   // both writes coalesced into one flush
        let divSpring = findElement(runtime._current!, where: { $0.attributes["class"] == "spring" })!
        let divLinear = findElement(runtime._current!, where: { $0.attributes["class"] == "linear" })!
        #expect(runtime._lastEffectiveTransactions[divSpring.identity]?.animation == .spring(duration: 1))
        #expect(runtime._lastEffectiveTransactions[divLinear.identity]?.animation == .linear(duration: 0.2))
    }

    @Test func nestedInnerWins() {
        let (runtime, backend, sched) = makeRuntime(XYBlocks())
        let buttons = findAll(backend.container, tag: "button")
        withAnimation(.linear(duration: 1)) {
            withAnimation(.easeIn(duration: 1)) {
                runtime.dispatch(buttons[0].events["click"]!)   // x: inner easeIn
            }
            runtime.dispatch(buttons[1].events["click"]!)       // y: outer linear still active
        }
        sched.pump()
        let divX = findElement(runtime._current!, where: { $0.attributes["class"] == "x" })!
        let divY = findElement(runtime._current!, where: { $0.attributes["class"] == "y" })!
        #expect(runtime._lastEffectiveTransactions[divX.identity]?.animation == .easeIn(duration: 1))
        #expect(runtime._lastEffectiveTransactions[divY.identity]?.animation == .linear(duration: 1))
    }

    @Test func nilAnimationCaptured() {
        let (runtime, backend, sched) = makeRuntime(SoloBlock())
        let button = findFirst(backend.container, tag: "button")!
        withAnimation(nil) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        let div = findElement(runtime._current!, where: { $0.attributes["class"] == "solo" })!
        let entry = runtime._lastEffectiveTransactions[div.identity]
        #expect(entry != nil)
        #expect(entry?.animation == nil)
    }

    @Test func noTransactionNoEntries() {
        let (runtime, backend, sched) = makeRuntime(SoloBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)   // plain write, no withAnimation
        sched.pump()
        #expect(runtime._lastEffectiveTransactions.isEmpty)
    }

    @Test func emptyGroupFiresNextMicrotask() {
        let (runtime, backend, sched) = makeRuntime(SoloBlock())
        let button = findFirst(backend.container, tag: "button")!
        var completed = false
        withAnimation(completion: { completed = true }) {
            runtime.dispatch(button.events["click"]!)
        }
        #expect(!completed)   // deferred — not synchronous with the write
        sched.pump()
        sched.pump()          // tolerate either same-flush or next-microtask arming
        #expect(completed)
    }
}
