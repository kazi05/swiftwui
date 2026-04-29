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
            preview: AnyTag(
                Div {
                    Span { Text("Temperature") }
                        .style("font-size", "12px")
                        .style("color", "var(--swui-fg-3)")
                    Div {
                        Span { Text("22 °C") }
                            .style("font-size", "20px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-accent)")
                    }
                    .style("margin-top", "6px")
                    Div { EmptyTag() }
                        .style("width", "100%")
                        .style("height", "4px")
                        .style("background", "linear-gradient(to right, var(--swui-accent) 22%, var(--swui-border) 22%)")
                        .style("border-radius", "2px")
                        .style("margin-top", "10px")
                }
            )
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
            preview: AnyTag(
                Div {
                    Span { Text("Quantity") }
                        .style("font-size", "12px")
                        .style("color", "var(--swui-fg-3)")
                    Div {
                        Span { Text("Items: 1") }
                            .style("font-size", "16px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-fg)")
                    }
                    .style("margin-top", "6px")
                    Div {
                        Span { Text("[ 1 ]") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "18px")
                            .style("color", "var(--swui-accent)")
                            .style("border", "1px solid var(--swui-border)")
                            .style("padding", "4px 12px")
                            .style("border-radius", "6px")
                    }
                    .style("margin-top", "8px")
                }
            )
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
            preview: AnyTag(
                Div {
                    Span { Text("Size") }
                        .style("font-size", "12px")
                        .style("color", "var(--swui-fg-3)")
                    Div {
                        Span { Text("Medium  ▾") }
                            .style("font-size", "14px")
                            .style("padding", "6px 12px")
                            .style("border", "1px solid var(--swui-border)")
                            .style("border-radius", "6px")
                            .style("color", "var(--swui-fg)")
                            .style("background", "var(--swui-surface)")
                            .style("cursor", "pointer")
                    }
                    .style("margin-top", "8px")
                }
            )
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
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("email = \"\"  — disabled") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "12px")
                            .style("color", "var(--swui-fg-3)")
                    }
                    Div {
                        Span { Text("Submit") }
                            .style("background", "var(--swui-accent)")
                            .style("color", "#fff")
                            .style("padding", "7px 18px")
                            .style("border-radius", "6px")
                            .style("font-size", "13px")
                            .style("opacity", "0.4")
                            .style("cursor", "not-allowed")
                    }
                    .style("margin-top", "10px")
                }
            )
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
            preview: AnyTag(
                Div {
                    Span { Text("Name field") }
                        .style("display", "block")
                        .style("padding", "6px 10px")
                        .style("border", "1px solid var(--swui-border)")
                        .style("border-radius", "6px")
                        .style("font-size", "13px")
                        .style("color", "var(--swui-fg-3)")
                        .style("background", "var(--swui-surface)")
                    Div { EmptyTag() }
                        .style("height", "4px")
                        .style("background", "linear-gradient(to right, var(--swui-accent) 60%, var(--swui-border) 60%)")
                        .style("border-radius", "2px")
                    Span { Text("Save") }
                        .style("display", "inline-block")
                        .style("background", "var(--swui-accent)")
                        .style("color", "#fff")
                        .style("padding", "6px 14px")
                        .style("border-radius", "6px")
                        .style("font-size", "13px")
                        .style("cursor", "pointer")
                }
                .style("display", "flex")
                .style("flex-direction", "column")
                .style("gap", "10px")
            )
        ),
    ] }
}
