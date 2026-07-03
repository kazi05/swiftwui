import Testing
@testable import SwiftWUI

private struct EchoFixture: Tag {
    @State var text = "start"
    var body: some Tag {
        Div {
            Input(type: .text, value: $text)
            P { text }
        }
    }
}
private struct CheckFixture: Tag {
    @State var done = false
    var body: some Tag {
        Div {
            Input(checked: $done)
            if done { P { "done" } }
        }
    }
}

@MainActor @Suite struct ControlledInputTests {
    @Test func inputEventWritesBindingAndRerenders() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: EchoFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let input = findFirst(backend.container, tag: "input")!
        #expect(input.props["value"] == .string("start"))
        rt.dispatch(input.events["input"]!, payload: InputEvent(value: "hello"))
        sched.pump()
        #expect(findFirst(backend.container, tag: "p")!.children[0].text == "hello")
        #expect(input.props["value"] == .string("hello"))     // echo write is a no-op value-wise
    }

    @Test func checkboxTogglesBinding() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: CheckFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let input = findFirst(backend.container, tag: "input")!
        #expect(input.attrs["type"] == "checkbox")
        #expect(input.props["checked"] == .bool(false))
        rt.dispatch(input.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()
        #expect(findFirst(backend.container, tag: "p") != nil)
        #expect(input.props["checked"] == .bool(true))
    }

    @Test func textareaControlled() {
        let html = HTMLRenderer.render(Textarea(text: .constant("hi")))
        #expect(html == #"<textarea>hi</textarea>"#)
    }

    @Test func formOnSubmit() {
        var submitted = 0
        let form = Form(onSubmit: { (_: SubmitEvent) in submitted += 1 }) { EmptyTag() }
        form._attributes.handlers[0].action(SubmitEvent())
        #expect(submitted == 1)
    }

    @Test func escapeHatchComposesWithControlledBinding() {
        let backend = MockBackend(); let sched = TestScheduler()
        var hatchValues: [String?] = []
        struct F: Tag {
            @State var text = ""
            let onHatch: (GenericEvent) -> Void
            var body: some Tag {
                Div {
                    Input(type: .text, value: $text).on(.input) { onHatch($0) }
                    P { text }
                }
            }
        }
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(onHatch: { hatchValues.append($0.targetValue) }),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        let input = findFirst(backend.container, tag: "input")!
        rt.dispatch(input.events["input"]!, payload: InputEvent(value: "both"))
        sched.pump()
        #expect(findFirst(backend.container, tag: "p")!.children[0].text == "both")  // binding fired
        #expect(hatchValues == ["both"])                                              // hatch fired too
    }
}
