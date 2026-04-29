import Testing
@testable import SwiftWUICore
@testable import SwiftWUIHTML
@testable import SwiftWUIState

private final class Box<Value>: @unchecked Sendable {
    var value: Value
    init(_ v: Value) { self.value = v }
}

private func bindBox<V>(_ box: Box<V>) -> Binding<V> {
    Binding(get: { box.value }, set: { box.value = $0 })
}

@Suite("Typed input components", .serialized)
struct TypedInputTests {
    // MARK: - TextField

    @Test("TextField renders <input type=text> with current value")
    func textFieldRenders() {
        let box = Box("hello")
        let field = TextField("Name", text: bindBox(box))
        let nodes = resolveTagBody(field)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.tagName == "input")
        #expect(el.attributes["type"] == "text")
        #expect(el.attributes["value"] == "hello")
    }

    @Test("TextField updates binding when oninput fires with currentValue")
    func textFieldBinding() {
        let box = Box("")
        let field = TextField("Name", text: bindBox(box))
        let nodes = resolveTagBody(field)
        guard case .element(let el) = nodes.first,
              let listenerID = el.eventListeners["input"] else {
            Issue.record("expected input listener"); return
        }
        InputEventContext.currentValue = "typed"
        EventHandlerRegistry.handler(for: listenerID)?()
        InputEventContext.currentValue = nil
        #expect(box.value == "typed")
    }

    // MARK: - SecureField

    @Test("SecureField renders <input type=password>")
    func secureFieldType() {
        let box = Box("")
        let field = SecureField("Password", text: bindBox(box))
        let nodes = resolveTagBody(field)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["type"] == "password")
    }

    // MARK: - Toggle

    @Test("Toggle renders <input type=checkbox> and reflects bound state")
    func toggleReflectsState() {
        let box = Box(true)
        let field = Toggle("Notifications", isOn: bindBox(box))
        let nodes = resolveTagBody(field)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["type"] == "checkbox")
        #expect(el.attributes["checked"] == "true")
    }

    @Test("Toggle flips its binding when oninput fires")
    func toggleFlipsBinding() {
        let box = Box(false)
        let field = Toggle("X", isOn: bindBox(box))
        let nodes = resolveTagBody(field)
        guard case .element(let el) = nodes.first,
              let listenerID = el.eventListeners["input"] else {
            Issue.record("expected input listener"); return
        }
        EventHandlerRegistry.handler(for: listenerID)?()
        #expect(box.value == true)
    }

    // MARK: - Slider

    @Test("Slider emits min/max/step attributes plus type=range")
    func sliderAttributes() {
        let box = Box(0.5)
        let slider = Slider("Vol", value: bindBox(box), in: 0...1, step: 0.1)
        let nodes = resolveTagBody(slider)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["type"] == "range")
        #expect(el.attributes["min"] == "0.0")
        #expect(el.attributes["max"] == "1.0")
        #expect(el.attributes["step"] == "0.1")
    }

    @Test("Slider updates Double binding from oninput string parsing")
    func sliderBinding() {
        let box = Box(0.0)
        let slider = Slider("V", value: bindBox(box), in: 0...10)
        let nodes = resolveTagBody(slider)
        guard case .element(let el) = nodes.first,
              let listenerID = el.eventListeners["input"] else {
            Issue.record("expected input listener"); return
        }
        InputEventContext.currentValue = "7.5"
        EventHandlerRegistry.handler(for: listenerID)?()
        InputEventContext.currentValue = nil
        #expect(box.value == 7.5)
    }

    // MARK: - Stepper

    @Test("Stepper emits step + min/max + Int parsing")
    func stepperAttributes() {
        let box = Box(5)
        let stepper = Stepper("Qty", value: bindBox(box), in: 1...99, step: 2)
        let nodes = resolveTagBody(stepper)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["type"] == "number")
        #expect(el.attributes["step"] == "2")
        #expect(el.attributes["min"] == "1")
        #expect(el.attributes["max"] == "99")
    }

    // MARK: - NumberField

    @Test("NumberField updates Double binding from typed input")
    func numberFieldBinding() {
        let box = Box(0.0)
        let nf = NumberField("X", value: bindBox(box))
        let nodes = resolveTagBody(nf)
        guard case .element(let el) = nodes.first,
              let listenerID = el.eventListeners["input"] else {
            Issue.record("expected input listener"); return
        }
        InputEventContext.currentValue = "42.7"
        EventHandlerRegistry.handler(for: listenerID)?()
        InputEventContext.currentValue = nil
        #expect(box.value == 42.7)
    }

    // MARK: - ColorPicker

    @Test("ColorPicker uses type=color and round-trips hex via binding")
    func colorPickerRoundTrip() {
        let box = Box("#ffffff")
        let picker = ColorPicker("Accent", hex: bindBox(box))
        let nodes = resolveTagBody(picker)
        guard case .element(let el) = nodes.first,
              let listenerID = el.eventListeners["input"] else {
            Issue.record("expected element + listener"); return
        }
        #expect(el.attributes["type"] == "color")
        #expect(el.attributes["value"] == "#ffffff")
        InputEventContext.currentValue = "#0088ff"
        EventHandlerRegistry.handler(for: listenerID)?()
        InputEventContext.currentValue = nil
        #expect(box.value == "#0088ff")
    }

    // MARK: - DatePicker

    @Test("DatePicker uses type=date and binds the ISO string")
    func datePickerString() {
        let box = Box("2026-04-29")
        let picker = DatePicker("Birthday", dateString: bindBox(box))
        let nodes = resolveTagBody(picker)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.attributes["type"] == "date")
        #expect(el.attributes["value"] == "2026-04-29")
    }

    // MARK: - Picker

    @Test("Picker renders <select> wrapping its options")
    func pickerRendersSelect() {
        enum Choice: String, LosslessStringConvertible {
            case a, b, c
            var description: String { rawValue }
            init?(_ s: String) { self.init(rawValue: s) }
        }
        let box = Box(Choice.a)
        let picker = Picker("Choose", selection: bindBox(box)) {
            Option(value: "a") { Text("A") }
            Option(value: "b") { Text("B") }
        }
        let nodes = resolveTagBody(picker)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.tagName == "select")
        // Two <option> children.
        let optionCount = el.children.filter {
            if case .element(let e) = $0, e.tagName == "option" { return true }
            return false
        }.count
        #expect(optionCount == 2)
    }
}
