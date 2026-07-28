/// Chapter 15 — Bind and listen (authored sections; sample: Samples/Tour/Sources/Bindings.swift).
public enum Ch15 {
    // Byte-identical to the marked regions of Samples/Tour/Sources/Bindings.swift —
    // ExcerptSyncTests fails on any drift, whitespace included.
    static let modelCode = #"""
@Observable final class MessageDraft {
    var subject = ""
    var text = ""
}
"""#
    static let modifierCode = #"""
/// A TagModifier holds `@State` of its own: `ModifiedTag` is a real component
/// boundary, so `hovered` is independent of whatever the modifier wraps.
struct FieldFrame: TagModifier {
    @State private var hovered = false

    func body(content: Content) -> some Tag {
        Div { content }
            .display(.flex)
            .flexDirection(.column)
            .gap(.px(4))
            .padding(.px(10))
            .borderRadius(.px(8))
            .border(.px(1), .solid, .hex(hovered ? "#a8a29e" : "#e7e5e4"))
            .onHover { hovered = $0 }
    }
}
"""#
    static let formCode = #"""
            Form {
                Label {
                    Text("To")
                    // `$to` is @State's own projected Binding<String>.
                    Input(type: .email, value: $to, placeholder: "someone@example.com")
                        .onFocus { hint = "Cmd+Enter in the body sends." }
                        .onBlur { hint = "" }
                }
                .modifier(FieldFrame())     // event modifiers first: ModifiedTag is not an HTMLTag

                Label {
                    Text("Subject")
                    Input(value: $d.subject)    // Binding written into the @Observable model
                }
                .modifier(FieldFrame())

                Textarea(text: $d.text)
                    .minHeight(.px(120))
                    // Exact modifier match: Cmd+Shift+Enter does NOT fire this.
                    .onKeyDown(.enter, modifiers: [.meta]) { send() }

                // A controlled Select stores its choice in the DOM `value`
                // property, which does not serialize — a prerendered page shows
                // the first option until hydration seeds the binding.
                Select(value: $priority) {
                    Option("Normal", value: "normal")
                    Option("Urgent", value: "urgent")
                }

                Label {
                    Input(checked: $copySelf)
                    Text("Send me a copy")
                }
            }
"""#
    static let eventsCode = #"""
            Div {
                Button("Send") { send() }
                // Discarding is destructive, so it asks for a deliberate gesture.
                Button { Text("Hold to discard") }
                    .onLongPress(minimumDuration: .milliseconds(700)) {
                        draft.subject = ""
                        draft.text = ""
                        status = "Discarded."
                    }
            }
            .display(.flex)
            .gap(.px(8))

            P { Text(status) }
            Small { Text(hint) }

            // The threshold is part of the observer's identity key, so two
            // onVisibilityChange calls on one element coexist rather than
            // overwrite each other.
            Footer {
                Link("/") { Span { "Back to the tour" } }
                Small { Text(footerSeen ? " — you read to the end" : "") }
            }
            .onVisibilityChange(threshold: 0.5) { footerSeen = $0 }
"""#

    static let samplePath = "Sites/Tutorial/Samples/Tour/Sources/Bindings.swift"

    public static let chapter = Chapter(
        slug: "bind-and-listen", track: .interact, kicker: "CHAPTER · INTERACT",
        title: "Bind and listen",
        tagline: "Two-way values, a real event vocabulary, and your own reusable modifiers.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "bind-currency", kicker: "01 · BINDINGS",
                    title: "Bindings are the currency",
                    intro: "A Binding<Value> is a get/set pair aimed at storage someone else owns. Every two-way control in SwiftWUI takes one, so this is the type you pass around.",
                    steps: [
                        Step("Build one by hand with Binding(get:set:) when the value is derived or lives behind an accessor.",
                             detail: "Examples/TodoMVC does exactly that over an @Observable store reached through the environment."),
                        Step("$state is @State's projected value — a Binding you get for nothing.",
                             detail: "It captures the state's slot rather than its box, so a binding vended before a re-render keeps writing to the right storage after identity adoption."),
                        Step("Binding.constant(_:) is read-only: reads work, the setter does nothing.",
                             detail: "Reach for it to mirror a value into a second field you do not want edited."),
                        Step("A binding only writes. Something still has to read that value inside a body for the page to change."),
                        Step("Run the tour sample and type in the compose form to watch one round trip end to end."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "cd Sites/Tutorial/Samples/Tour"),
                        TermLine(.command, "swiftwui dev"),
                        TermLine(.output, "  serving http://localhost:8080"),
                        TermLine(.note, "Type in a field: the control writes the binding, the body reads it back, the DOM catches up."),
                    ])),
            Section(anchor: "bind-controls", kicker: "02 · CONTROLS",
                    title: "The controlled-input family",
                    intro: "Four initializers consume a Binding directly and keep the DOM in step with it. Each one wires the same loop: DOM event writes the binding, the binding write re-renders, the render seeds the DOM property.",
                    steps: [
                        Step("Input(type:value:) tracks a Binding<String> in the DOM value property and writes back on every input event."),
                        Step("Input(checked:) is the checkbox form of the same deal, driven by change."),
                        Step("Textarea(text:) is text-only in controlled mode — the initializer is constrained to Content == EmptyTag, so it takes no children."),
                        Step("Select(value:) keeps the choice in the DOM value property, which serializes to nothing.",
                             detail: "A prerendered page therefore shows the first option until hydration runs and seeds the binding — do not read the initial paint as a bug."),
                        Step("Chain .on(.input) on a controlled input to observe as well as bind; the escape hatch composes with the binding write instead of replacing it."),
                    ],
                    panel: .code(CodePanel(file: "Bindings.swift", code: formCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-bindings-form")))),
            Section(anchor: "bind-observable", kicker: "03 · MODELS",
                    title: "Bindable and dollar-model-dot-field",
                    intro: "When the value lives on an @Observable reference type, @Bindable projects a Binding out of any writable property. It is a projection helper and nothing more.",
                    steps: [
                        Step("Mark the model @Observable and keep it in @State, or reach it through the environment."),
                        Step("Declare @Bindable var d = draft inside body, then write $d.subject.",
                             detail: "The dynamic member lives on the projected value. d.subject reads and writes the model directly, and d.$subject does not exist.",
                             panel: .code(CodePanel(file: "Bindings.swift", code: formCode,
                                                    origin: .sample(path: samplePath,
                                                                    marker: "tour-bindings-form")))),
                        Step("The subscript takes a ReferenceWritableKeyPath, so it reaches writable properties of a class only."),
                        Step("@Bindable has no runtime integration. Observation drives the re-render, and only when some body reads the property.",
                             detail: "The demo prints draft.subject below the form; that read is what repaints on every keystroke."),
                    ],
                    panel: .code(CodePanel(file: "Bindings.swift", code: modelCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-bindings-model")))),
            Section(anchor: "bind-events", kicker: "04 · EVENTS",
                    title: "The event vocabulary",
                    intro: "Every event modifier is declared on HTMLTag and returns Self, so they chain on any element and never on a component. The payload types are small structs, not JS objects.",
                    steps: [
                        Step("onTap, onDoubleTap, onHover, onFocus, onBlur and onSubmit cover the everyday cases; onTap also has a ClickEvent variant.",
                             detail: "For anything else there is .on(_:perform:), but its GenericEvent decodes only input, change, key and click payloads — a scroll or drag event arrives with every field nil."),
                        Step("onSubmit always calls preventDefault(), so a form never reloads the page and there is no way to ask for one."),
                        Step("onKeyDown(_:modifiers:_:) matches the modifier set exactly, not by containment.",
                             detail: "Cmd+Shift+Enter does not fire a handler registered for [.meta]. Take the KeyEvent overload and read event.modifiers yourself when you want looser matching."),
                        Step("onLongPress(minimumDuration:) fires once the pointer stays down; pointerup, pointercancel and pointerleave cancel it.",
                             detail: "A re-render mid-press swaps the tracker, so a timer started before that render can no longer be cancelled — keep the pressed element stable while it counts."),
                        Step("onVisibilityChange(threshold:) and onSizeChange wrap IntersectionObserver and ResizeObserver; the threshold is part of the observer key, so two thresholds on one element coexist."),
                    ],
                    panel: .code(CodePanel(file: "Bindings.swift", code: eventsCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-bindings-events")))),
            Section(anchor: "bind-modifiers", kicker: "05 · MODIFIERS",
                    title: "Write your own modifier",
                    intro: "TagModifier is the ViewModifier analog: one body(content:) that wraps whatever it is applied to. It is how a field frame, a card shell or a focus ring stops being copy-paste.",
                    steps: [
                        Step("Implement body(content:) — content is the placeholder for the wrapped tag, resolved at its position in your body."),
                        Step(".modifier(_:) is declared on Tag, so it works on components too; the event modifiers are not.",
                             detail: "The result is a ModifiedTag, which is not an HTMLTag — apply .onTap, .onFocus and friends first, then .modifier(...) last, or the chain stops compiling."),
                        Step("ModifiedTag is a real component boundary: the modifier's own @State and @Environment work and invalidate independently of the content it wraps."),
                        Step("It keeps the caller's Styled scope on purpose, so wrapped content still matches the component's scoped rules."),
                        Step("Using content twice in one body duplicates the subtree into two copies with independent state, quietly — the same limitation SwiftUI has."),
                    ],
                    panel: .code(CodePanel(file: "Bindings.swift", code: modifierCode,
                                           origin: .sample(path: samplePath,
                                                           marker: "tour-bindings-modifier")))),
        ],
        quiz: Quiz(questions: [
            Question(prompt: "A textarea carries .onKeyDown(.enter, modifiers: [.meta]) { send() }. The reader holds Cmd and Shift and presses Enter. What happens?",
                     options: [
                        "send() runs — [.meta] is satisfied because Cmd is held",
                        "Nothing — the filtered overload matches the modifier set exactly, and [.meta, .shift] is a different set",
                        "send() runs twice, once per modifier key",
                        "The handler throws because the modifier set does not match",
                     ],
                     correctIndex: 1,
                     explanation: "onKeyDown(_:modifiers:_:) compares the whole modifier set for equality, not containment. A superset does not fire it. When you want Cmd+Enter to survive an extra Shift, use the KeyEvent overload and inspect event.modifiers yourself."),
            Question(prompt: "You wrap a Label in .modifier(FieldFrame()) and then try to chain .onFocus after it. Why does that not compile?",
                     options: [
                        "onFocus only exists on Input, not on Label",
                        "A TagModifier consumes every event handler on the content it wraps",
                        ".modifier(_:) returns a ModifiedTag, and the event modifiers are declared on HTMLTag — so apply them before .modifier(...)",
                        "Focus events need a Binding, which FieldFrame does not provide",
                     ],
                     correctIndex: 2,
                     explanation: ".modifier(_:) lives on Tag and returns ModifiedTag<Self, M>; onFocus and the rest live on HTMLTag and return Self. Once you have a ModifiedTag the event modifiers are out of reach, so the order is event modifiers first, .modifier(...) last."),
            Question(prompt: "draft is an @Observable model held in @State. Inside body you write @Bindable var d = draft. Which expression gives you a Binding<String> for the subject field?",
                     options: [
                        "d.$subject",
                        "$d.subject",
                        "draft.$subject",
                        "$draft.subject",
                     ],
                     correctIndex: 1,
                     explanation: "The dynamic-member subscript is declared on Bindable itself and is reachable only through the projected value, so $d.subject is the Binding. d.subject reads and writes the model directly, and d.$subject does not exist. Remember that @Bindable only writes — the re-render still comes from a body reading the tracked property."),
        ]))
}
