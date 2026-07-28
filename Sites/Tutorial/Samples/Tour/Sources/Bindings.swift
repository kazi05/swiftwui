import Observation
import SwiftWUI

/// Chapter: "Two-way data and events". One compose form wired three ways —
/// `@State`'s own `$`-projection, a `Binding` into an `@Observable` model, and
/// the event vocabulary `HTMLTag` exposes.

// tutorial:begin tour-bindings-model
@Observable final class MessageDraft {
    var subject = ""
    var text = ""
}
// tutorial:end tour-bindings-model

// tutorial:begin tour-bindings-modifier
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
// tutorial:end tour-bindings-modifier

struct BindingsDemo: Tag, Page {
    var title: String { "Bindings and events — SwiftWUI Tour" }

    @State private var draft = MessageDraft()
    @State private var to = ""
    @State private var priority = "normal"
    @State private var copySelf = false
    @State private var status = "Nothing sent yet."
    @State private var hint = ""
    @State private var footerSeen = false

    var body: some Tag {
        // The dynamic member lives on the PROJECTED value: `$d.subject`,
        // never `d.$subject`.
        @Bindable var d = draft
        Main(class: "tour") {
            H1("Compose")
// tutorial:begin tour-bindings-form
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
// tutorial:end tour-bindings-form

            // Reading `draft.subject` in the body is what re-renders on every
            // keystroke — the Binding only writes; Observation does the telling.
            P { Text("\(draft.subject.isEmpty ? "(no subject)" : draft.subject) · \(draft.text.count) characters") }

// tutorial:begin tour-bindings-events
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
// tutorial:end tour-bindings-events
        }
    }

    func send() {
        guard !to.isEmpty, !draft.subject.isEmpty else {
            status = "A recipient and a subject, please."
            return
        }
        status = "Sent \"\(draft.subject)\" to \(to) as \(priority)\(copySelf ? ", copy to you" : "")."
        draft.subject = ""
        draft.text = ""
    }
}
