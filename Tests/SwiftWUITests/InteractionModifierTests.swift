import Testing
@testable import SwiftWUI

private final class Recorder {
    var taps = 0
    var clickEvents: [ClickEvent] = []
    var doubleTaps = 0
    var hoverStates: [Bool] = []
    var keyDownEvents: [KeyEvent] = []
    var keyUpEvents: [KeyEvent] = []
    var filteredFires = 0
    var focusFires = 0
    var blurFires = 0
    var submitFires = 0
    var order: [Int] = []
    var longPressFires = 0
    var scrollEvents: [ScrollEvent] = []
}

private struct TapFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onTap { cap.taps += 1 } }
}
private struct TapPayloadFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onTap { (e: ClickEvent) in cap.clickEvents.append(e) } }
}
private struct DoubleTapFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onDoubleTap { cap.doubleTaps += 1 } }
}
private struct HoverFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onHover { cap.hoverStates.append($0) } }
}
private struct KeyFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Div()
            .onKeyDown { (e: KeyEvent) in cap.keyDownEvents.append(e) }
            .onKeyUp { (e: KeyEvent) in cap.keyUpEvents.append(e) }
    }
}
private struct FilteredKeyDownFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Div().onKeyDown(.enter, modifiers: [.meta]) { cap.filteredFires += 1 }
    }
}
private struct FocusBlurFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Div().onFocus { cap.focusFires += 1 }.onBlur { cap.blurFires += 1 }
    }
}
private struct SubmitFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onSubmit { cap.submitFires += 1 } }
}
private struct CompositionFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Button("x", onClick: { cap.order.append(1) }).onTap { cap.order.append(2) }
    }
}
private struct LongPressFixture: Tag {
    let cap: Recorder
    var onFire: (() -> Void)? = nil
    var body: some Tag {
        Div().onLongPress(minimumDuration: .milliseconds(50)) {
            cap.longPressFires += 1
            onFire?()
        }
    }
}
private struct ScrollFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onScrollChange { cap.scrollEvents.append($0) } }
}

@Suite @MainActor struct InteractionModifierTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func onTapVoidFiresOnClick() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(TapFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["click"]!); sched.pump()
        #expect(cap.taps == 1)
    }

    @Test func onTapPayloadReceivesClickEventOrDefault() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(TapPayloadFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["click"]!, payload: ClickEvent(button: 1)); sched.pump()
        rt.dispatch(div.events["click"]!); sched.pump()   // no payload → default ClickEvent()
        #expect(cap.clickEvents.count == 2)
        #expect(cap.clickEvents[0].button == 1)
        #expect(cap.clickEvents[1].button == 0)
        #expect(cap.clickEvents[1].metaKey == false)
    }

    @Test func onDoubleTapRegistersDblclick() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(DoubleTapFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["dblclick"]!); sched.pump()
        #expect(cap.doubleTaps == 1)
    }

    @Test func onHoverReceivesEnterAndLeave() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(HoverFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["mouseenter"]!); sched.pump()
        rt.dispatch(div.events["mouseleave"]!); sched.pump()
        #expect(cap.hoverStates == [true, false])
    }

    @Test func onKeyDownAndUpReceiveFullKeyEvent() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(KeyFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        let down = KeyEvent(key: "a", repeated: true, metaKey: true, ctrlKey: true,
                            shiftKey: true, altKey: true, isComposing: true)
        rt.dispatch(div.events["keydown"]!, payload: down); sched.pump()
        #expect(cap.keyDownEvents.count == 1)
        #expect(cap.keyDownEvents[0].key == "a")
        #expect(cap.keyDownEvents[0].repeated == true)
        #expect(cap.keyDownEvents[0].metaKey == true)
        #expect(cap.keyDownEvents[0].ctrlKey == true)
        #expect(cap.keyDownEvents[0].shiftKey == true)
        #expect(cap.keyDownEvents[0].altKey == true)
        #expect(cap.keyDownEvents[0].isComposing == true)

        let up = KeyEvent(key: "b", repeated: false)
        rt.dispatch(div.events["keyup"]!, payload: up); sched.pump()
        #expect(cap.keyUpEvents.count == 1)
        #expect(cap.keyUpEvents[0].key == "b")
    }

    /// Exact-match semantics: fires only when key AND the full modifier set match.
    @Test func filteredOnKeyDownExactMatchSemantics() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(FilteredKeyDownFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!

        rt.dispatch(div.events["keydown"]!,
                    payload: KeyEvent(key: "Enter", repeated: false, metaKey: true)); sched.pump()
        #expect(cap.filteredFires == 1)   // matches key + modifiers exactly

        rt.dispatch(div.events["keydown"]!,
                    payload: KeyEvent(key: "Enter", repeated: false)); sched.pump()
        #expect(cap.filteredFires == 1)   // plain Enter, no modifiers → no fire

        rt.dispatch(div.events["keydown"]!,
                    payload: KeyEvent(key: "Enter", repeated: false, metaKey: true, shiftKey: true)); sched.pump()
        #expect(cap.filteredFires == 1)   // Enter+meta+shift, superset → no fire

        rt.dispatch(div.events["keydown"]!,
                    payload: KeyEvent(key: "Escape", repeated: false, metaKey: true)); sched.pump()
        #expect(cap.filteredFires == 1)   // wrong key → no fire
    }

    @Test func onFocusOnBlurOnSubmitFireOnTheirEvents() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(FocusBlurFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["focus"]!); sched.pump()
        rt.dispatch(div.events["blur"]!); sched.pump()
        #expect(cap.focusFires == 1)
        #expect(cap.blurFires == 1)

        let submitCap = Recorder()
        let (rt2, backend2, sched2) = makeRuntime(SubmitFixture(cap: submitCap))
        let submitDiv = findFirst(backend2.container, tag: "div")!
        rt2.dispatch(submitDiv.events["submit"]!); sched2.pump()
        #expect(submitCap.submitFires == 1)
    }

    /// `.onTap {}` chained onto `Button(onClick:)` — both handlers fire in
    /// registration order (chaining precedent in resolveElement).
    @Test func compositionWithButtonOnClickFiresBothInOrder() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(CompositionFixture(cap: cap))
        let button = findFirst(backend.container, tag: "button")!
        rt.dispatch(button.events["click"]!); sched.pump()
        #expect(cap.order == [1, 2])
    }

    @Test func onScrollChangeReceivesScrollEvent() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(ScrollFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["scroll"]!, payload: ScrollEvent(x: 0, y: 42)); sched.pump()
        #expect(cap.scrollEvents == [ScrollEvent(x: 0, y: 42)])
    }

    @Test(.timeLimit(.minutes(1))) func onLongPressFiresAfterMinimumDuration() async {
        let cap = Recorder()
        var fired: CheckedContinuation<Void, Never>?
        let (rt, backend, sched) = makeRuntime(LongPressFixture(cap: cap, onFire: {
            fired?.resume()
            fired = nil
        }))
        let div = findFirst(backend.container, tag: "div")!
        let started = ContinuousClock.now
        // Wait for the callback itself: under parallel load, a fixed sleep can
        // resume this test before the press task gets its turn on MainActor.
        await withCheckedContinuation { continuation in
            fired = continuation
            rt.dispatch(div.events["pointerdown"]!); sched.pump()
        }
        #expect(started.duration(to: .now) >= .milliseconds(50))
        #expect(cap.longPressFires == 1)
        withExtendedLifetime(rt) {}
    }

    /// pointerdown then pointerup dispatched back-to-back with no `await` between
    /// them: the LongPressState task is created and cancelled before it ever gets
    /// a chance to run, so this can never race the 50ms timer (unlike sleeping
    /// partway through the threshold and hoping the cancel wins).
    @Test func onLongPressCancelledByPointerUp() async throws {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(LongPressFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["pointerdown"]!); sched.pump()
        rt.dispatch(div.events["pointerup"]!); sched.pump()
        try await Task.sleep(for: .milliseconds(150))
        #expect(cap.longPressFires == 0)
    }

    @Test func onLongPressCancelledByPointerCancel() async throws {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(LongPressFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["pointerdown"]!); sched.pump()
        rt.dispatch(div.events["pointercancel"]!); sched.pump()
        try await Task.sleep(for: .milliseconds(150))
        #expect(cap.longPressFires == 0)
    }
}
