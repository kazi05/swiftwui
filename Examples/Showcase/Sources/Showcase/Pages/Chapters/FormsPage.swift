// FormsPage.swift — Chapter 5: Forms & Inputs

import SwiftWUI

public struct FormsPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 5 — Building UI",
                title: "Forms & Inputs",
                lead: "SwiftWUI ships typed form controls — Slider, Stepper, Picker, TextField — that bind directly to @State via a Binding. Write once; the framework wires the DOM event, coerces the string value, and updates your state.",
                meta: [
                    ("Estimated time", "10 min"),
                    ("Difficulty", "Intermediate"),
                    ("Module", "SwiftWUIHTML"),
                ]
            )
            ScrollyTeller(steps: formSteps)
            ChapterFooter(prev: ("Lists & ForEach", "/learn/lists"), next: ("Routing & Guards", "/learn/routing"))
            HighlightOnMount()
        }
    }

    private var formSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Bind a Slider to Double state",
            prose: "`Slider` renders `<input type=range>`. Pass a `Binding<Double>` and a closed range. The `oninput` handler coerces the string value from the DOM event back to `Double` automatically.",
            code: """
            @State var temperature: Double = 22

            Slider("Temperature", value: $temperature, in: 0...100)
            P { Text("\\(Int(temperature)) °C") }
            """,
            highlightLines: [1, 3],
            preview: .live(AnyTag(
                Div {
                    Span { Text("Temperature") }
                        .fontSize(.px(12))
                        .foregroundColor(.token("swui-fg-3"))
                    Div {
                        Span { Text("22 °C") }
                            .fontSize(.px(20))
                            .fontFamily("var(--font-mono)")
                            .foregroundColor(.token("swui-accent"))
                    }
                    .style("margin-top", "6px")
                    Div { EmptyTag() }
                        .style("width", "100%")
                        .style("height", "4px")
                        .style("background", "linear-gradient(to right, var(--swui-accent) 22%, var(--swui-border) 22%)")
                        .borderRadius(.px(2))
                        .style("margin-top", "10px")
                }
            ))
        ),
        .init(
            number: 2,
            title: "Increment integers with Stepper",
            prose: "`Stepper` renders `<input type=number>` with explicit bounds and step. It binds to `Binding<Int>`. Optionally pass `in:` and `step:` parameters to constrain the allowed range.",
            code: """
            @State var quantity: Int = 1

            Stepper("Quantity", value: $quantity, in: 1...99, step: 1)
            P { Text("Items: \\(quantity)") }
            """,
            highlightLines: [1, 3],
            preview: .live(AnyTag(
                Div {
                    Span { Text("Quantity") }
                        .fontSize(.px(12))
                        .foregroundColor(.token("swui-fg-3"))
                    Div {
                        Span { Text("Items: 1") }
                            .fontSize(.px(16))
                            .fontFamily("var(--font-mono)")
                            .foregroundColor(.token("swui-fg"))
                    }
                    .style("margin-top", "6px")
                    Div {
                        Span { Text("[ 1 ]") }
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(18))
                            .foregroundColor(.token("swui-accent"))
                            .border(.px(1), .solid, .token("swui-border"))
                            .padding(.px(4), .px(12))
                            .borderRadius(.px(6))
                    }
                    .style("margin-top", "8px")
                }
            ))
        ),
        .init(
            number: 3,
            title: "Choose from a list with Picker",
            prose: "`Picker` renders a `<select>` element bound to any `LosslessStringConvertible` type. Declare an enum conforming to `LosslessStringConvertible`, then pass `Option` tags as content.",
            code: """
            enum Size: String, LosslessStringConvertible {
              case small, medium, large
              var description: String { rawValue }
              init?(_ s: String) { self.init(rawValue: s) }
            }

            @State var size: Size = .medium

            Picker("Size", selection: $size) {
              Option(value: "small")  { Text("Small") }
              Option(value: "medium") { Text("Medium") }
              Option(value: "large")  { Text("Large") }
            }
            """,
            highlightLines: [1, 9],
            preview: .live(AnyTag(
                Div {
                    Span { Text("Size") }
                        .fontSize(.px(12))
                        .foregroundColor(.token("swui-fg-3"))
                    Div {
                        Span { Text("Medium  ▾") }
                            .fontSize(.px(14))
                            .padding(.px(6), .px(12))
                            .border(.px(1), .solid, .token("swui-border"))
                            .borderRadius(.px(6))
                            .foregroundColor(.token("swui-fg"))
                            .backgroundColor(.token("swui-surface"))
                            .cursor(.pointer)
                    }
                    .style("margin-top", "8px")
                }
            ))
        ),
        .init(
            number: 4,
            title: "Validate before enabling submit",
            prose: "Gate the submit `Button` on a boolean derived from your state. Because `body` is re-evaluated on every state change, the disabled/enabled appearance stays in sync without any imperative toggle.",
            code: """
            @State var email = ""

            let isValid = email.contains("@")

            Button(onclick: { submit() }) {
              Text("Submit")
            }
            .style("opacity", isValid ? "1" : "0.4")
            .attribute("disabled", isValid ? nil : "true")
            """,
            highlightLines: [3, 8, 9],
            preview: .live(AnyTag(
                Div {
                    Div {
                        Span { Text("email = \"\"  — disabled") }
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.token("swui-fg-3"))
                    }
                    Div {
                        Span { Text("Submit") }
                            .backgroundColor(.token("swui-accent"))
                            .foregroundColor(.css("#fff"))
                            .padding(.px(7), .px(18))
                            .borderRadius(.px(6))
                            .fontSize(.px(13))
                            .style("opacity", "0.4")
                            .style("cursor", "not-allowed")
                    }
                    .style("margin-top", "10px")
                }
            ))
        ),
        .init(
            number: 5,
            title: "Compose inputs into a form layout",
            prose: "Wrap inputs in a `Div` with flex layout to build polished form rows. Each control is independently bound; they co-exist inside one `body` without any shared mutable state between them.",
            code: """
            Div {
              TextField("Name", text: $name)
              Slider("Volume", value: $volume, in: 0...1)
              Toggle("Notifications", isOn: $notify)
              Button(onclick: save) { Text("Save") }
            }
            .style("display", "flex")
            .style("flex-direction", "column")
            .style("gap", "12px")
            """,
            highlightLines: [7, 8, 9],
            preview: .live(AnyTag(
                Div {
                    Span { Text("Name field") }
                        .display(.block)
                        .padding(.px(6), .px(10))
                        .border(.px(1), .solid, .token("swui-border"))
                        .borderRadius(.px(6))
                        .fontSize(.px(13))
                        .foregroundColor(.token("swui-fg-3"))
                        .backgroundColor(.token("swui-surface"))
                    Div { EmptyTag() }
                        .style("height", "4px")
                        .style("background", "linear-gradient(to right, var(--swui-accent) 60%, var(--swui-border) 60%)")
                        .borderRadius(.px(2))
                    Span { Text("Save") }
                        .display(.inlineBlock)
                        .backgroundColor(.token("swui-accent"))
                        .foregroundColor(.css("#fff"))
                        .padding(.px(6), .px(14))
                        .borderRadius(.px(6))
                        .fontSize(.px(13))
                        .cursor(.pointer)
                }
                .display(.flex)
                .flexDirection(.column)
                .gap(.px(10))
            ))
        ),
    ] }
}
