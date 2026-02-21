import Testing
@testable import SwiftWUICore
@testable import SwiftWUIHTML

@Suite("Event Modifiers")
struct EventModifiersTests {
    @Test("onHover registers mouseenter and mouseleave listeners")
    func onHoverRegistersListeners() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onHover { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["mouseenter"] != nil)
        #expect(el.eventListeners["mouseleave"] != nil)
    }

    @Test("onFocus registers focus listener")
    func onFocusRegistersListener() {
        EventHandlerRegistry.clear()
        let input = Input(type: .text)
            .onFocus { }
        let nodes = resolveTagBody(input)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["focus"] != nil)
    }

    @Test("onBlur registers blur listener")
    func onBlurRegistersListener() {
        EventHandlerRegistry.clear()
        let input = Input(type: .text)
            .onBlur { }
        let nodes = resolveTagBody(input)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["blur"] != nil)
    }

    @Test("onInput registers input listener")
    func onInputRegistersListener() {
        EventHandlerRegistry.clear()
        let input = Input(type: .text)
            .onInput { _ in }
        let nodes = resolveTagBody(input)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["input"] != nil)
    }

    @Test("onSubmit registers submit listener")
    func onSubmitRegistersListener() {
        EventHandlerRegistry.clear()
        let form = Form {}
            .onSubmit { }
        let nodes = resolveTagBody(form)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["submit"] != nil)
    }

    @Test("onScroll registers scroll listener")
    func onScrollRegistersListener() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onScroll { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["scroll"] != nil)
    }

    @Test("onKeyDown registers keydown listener")
    func onKeyDownRegistersListener() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onKeyDown { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["keydown"] != nil)
    }

    @Test("onKeyUp registers keyup listener")
    func onKeyUpRegistersListener() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onKeyUp { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["keyup"] != nil)
    }

    @Test("onCopy registers copy listener")
    func onCopyRegistersListener() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onCopy { }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["copy"] != nil)
    }

    @Test("onPaste registers paste listener")
    func onPasteRegistersListener() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onPaste { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["paste"] != nil)
    }

    @Test("onDrag registers dragstart listener")
    func onDragRegistersListener() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onDrag { }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["dragstart"] != nil)
    }

    @Test("onDrop registers drop listener")
    func onDropRegistersListener() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onDrop { }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["drop"] != nil)
    }

    // MARK: - Observer Modifiers

    @Test("onAppear registers intersection observer")
    func onAppearRegistersObserver() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onAppear { }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 1)
        if case .intersection(let threshold, _) = el.observers.first {
            #expect(threshold == 0)
        } else {
            Issue.record("Expected intersection observer")
        }
    }

    @Test("onDisappear registers intersection observer with negative threshold")
    func onDisappearRegistersObserver() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onDisappear { }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 1)
        if case .intersection(let threshold, _) = el.observers.first {
            #expect(threshold == -1)
        } else {
            Issue.record("Expected intersection observer")
        }
    }

    @Test("onResize registers resize observer")
    func onResizeRegistersObserver() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onResize { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 1)
        if case .resize = el.observers.first {
            // OK
        } else {
            Issue.record("Expected resize observer")
        }
    }

    @Test("onFrameChange registers resize observer")
    func onFrameChangeRegistersObserver() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onFrameChange { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 1)
        if case .resize = el.observers.first {
            // OK
        } else {
            Issue.record("Expected resize observer")
        }
    }

    @Test("onIntersection registers intersection observer with custom threshold")
    func onIntersectionRegistersObserver() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onIntersection(threshold: 0.75) { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 1)
        if case .intersection(let threshold, _) = el.observers.first {
            #expect(threshold == 0.75)
        } else {
            Issue.record("Expected intersection observer")
        }
    }

    // MARK: - Lifecycle Modifiers

    @Test("onMount registers lifecycle mount observer")
    func onMountRegistersObserver() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onMount { }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 1)
        if case .lifecycle(let event, _) = el.observers.first {
            #expect(event == .mount)
        } else {
            Issue.record("Expected lifecycle mount observer")
        }
    }

    @Test("onUnmount registers lifecycle unmount observer")
    func onUnmountRegistersObserver() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onUnmount { }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 1)
        if case .lifecycle(let event, _) = el.observers.first {
            #expect(event == .unmount)
        } else {
            Issue.record("Expected lifecycle unmount observer")
        }
    }

    // MARK: - Mutation Observer

    @Test("onMutation adds mutation observer")
    func onMutationAddsObserver() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onMutation(.init(childList: true)) { }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 1)
        if case .mutation(let opts, _) = el.observers.first {
            #expect(opts.childList == true)
        } else {
            Issue.record("Expected mutation observer")
        }
    }

    // MARK: - Identity

    @Test("id sets data-swiftwui-id attribute")
    func idSetsAttribute() {
        let div = Div {}
            .id(42)
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.attributes["data-swiftwui-id"] == "42")
    }

    @Test("Multiple observers can be chained")
    func multipleObserversChained() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onMount { }
            .onUnmount { }
            .onResize { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.observers.count == 3)
    }

    // MARK: - Event Context Tests

    @Test("onInput reads value from InputEventContext")
    func onInputReadsContext() {
        EventHandlerRegistry.clear()
        nonisolated(unsafe) var receivedValue = ""
        let input = Input(type: .text)
            .onInput { value in receivedValue = value }
        let nodes = resolveTagBody(input)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        // Simulate the context being set by DOMRenderer
        InputEventContext.currentValue = "hello"
        if let handler = EventHandlerRegistry.handler(for: el.eventListeners["input"]!) {
            handler()
        }
        InputEventContext.currentValue = nil
        #expect(receivedValue == "hello")
    }

    @Test("onScroll reads offset from ScrollEventContext")
    func onScrollReadsContext() {
        EventHandlerRegistry.clear()
        nonisolated(unsafe) var receivedOffset = ScrollOffset(x: 0, y: 0)
        let div = Div {}
            .onScroll { offset in receivedOffset = offset }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        ScrollEventContext.currentOffset = ScrollOffset(x: 10, y: 20)
        if let handler = EventHandlerRegistry.handler(for: el.eventListeners["scroll"]!) {
            handler()
        }
        ScrollEventContext.currentOffset = nil
        #expect(receivedOffset.x == 10)
        #expect(receivedOffset.y == 20)
    }

    @Test("onKeyDown reads key info from KeyEventContext")
    func onKeyDownReadsContext() {
        EventHandlerRegistry.clear()
        nonisolated(unsafe) var receivedKey = ""
        let div = Div {}
            .onKeyDown { info in receivedKey = info.key }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        KeyEventContext.currentKey = KeyInfo(
            key: "Enter", code: "Enter",
            ctrlKey: false, shiftKey: false, altKey: false, metaKey: false
        )
        if let handler = EventHandlerRegistry.handler(for: el.eventListeners["keydown"]!) {
            handler()
        }
        KeyEventContext.currentKey = nil
        #expect(receivedKey == "Enter")
    }

    @Test("onPaste reads text from PasteEventContext")
    func onPasteReadsContext() {
        EventHandlerRegistry.clear()
        nonisolated(unsafe) var receivedText = ""
        let div = Div {}
            .onPaste { text in receivedText = text }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        PasteEventContext.currentText = "pasted content"
        if let handler = EventHandlerRegistry.handler(for: el.eventListeners["paste"]!) {
            handler()
        }
        PasteEventContext.currentText = nil
        #expect(receivedText == "pasted content")
    }
}
