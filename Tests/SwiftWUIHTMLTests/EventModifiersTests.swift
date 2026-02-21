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
}
