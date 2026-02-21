import Testing
@testable import SwiftWUICore

@Suite("WebEventTypes")
struct WebEventTypesTests {
    @Test("ScrollOffset stores x and y")
    func scrollOffset() {
        let offset = ScrollOffset(x: 100, y: 200)
        #expect(offset.x == 100)
        #expect(offset.y == 200)
    }

    @Test("Size stores width and height")
    func sizeValues() {
        let size = ElementSize(width: 320, height: 480)
        #expect(size.width == 320)
        #expect(size.height == 480)
    }

    @Test("Rect stores all fields")
    func rectValues() {
        let rect = ElementRect(x: 10, y: 20, width: 100, height: 50)
        #expect(rect.x == 10)
        #expect(rect.y == 20)
        #expect(rect.width == 100)
        #expect(rect.height == 50)
    }

    @Test("KeyInfo stores all fields")
    func keyInfoValues() {
        let key = KeyInfo(key: "Enter", code: "Enter", ctrlKey: false, shiftKey: true, altKey: false, metaKey: false)
        #expect(key.key == "Enter")
        #expect(key.code == "Enter")
        #expect(key.shiftKey == true)
        #expect(key.ctrlKey == false)
    }

    @Test("EventHandlerRegistry registers typed callback via wrapper")
    func typedCallbackWrapper() {
        EventHandlerRegistry.clear()
        nonisolated(unsafe) var received: String? = nil
        // Register a () -> Void that wraps typed logic
        let id = EventHandlerRegistry.register {
            received = "called"
        }
        let handler = EventHandlerRegistry.handler(for: id)
        #expect(handler != nil)
        handler?()
        #expect(received == "called")
    }
}
