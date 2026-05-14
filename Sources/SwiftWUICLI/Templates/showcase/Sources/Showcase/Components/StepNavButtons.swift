// StepNavButtons.swift — prev/next + N/M chip embedded in the code panel.

import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public struct StepNavButtons: Tag {
    public let total: Int
    public let current: Int

    public init(total: Int, current: Int) {
        self.total = total
        self.current = current
    }

    public var body: some Tag {
        Div {
            Button(onclick: { StepNavButtons.go(delta: -1) }) {
                Text("← Prev step")
            }
            .padding(.px(6), .px(12))
            .backgroundColor(.token("swui-surface"))
            .border(.px(1), .solid, .token("swui-border"))
            .borderRadius(.px(6))
            .fontSize(.px(12))
            .foregroundColor(.token(current > 1 ? "swui-fg" : "swui-fg-3"))
            .cursor(.pointer)

            Div { EmptyTag() }.style("flex", "1")

            Span { Text("Step \(current) / \(total)") }
                .fontSize(.px(12))
                .foregroundColor(.token("swui-fg-3"))

            Div { EmptyTag() }.style("flex", "1")

            Button(onclick: { StepNavButtons.go(delta: 1) }) {
                Text("Next step →")
            }
            .padding(.px(6), .px(12))
            .backgroundColor(.token("swui-accent"))
            .borderRadius(.px(6))
            .fontSize(.px(12))
            .fontWeight(.w600)
            .foregroundColor(.token("swui-bg"))
            .cursor(.pointer)
        }
        .display(.flex)
        .alignItems(.center)
        .gap(.px(8))
        .padding(.px(8), .px(12))
        .backgroundColor(.token("swui-surface"))
        .borderBottom(.px(1), .solid, .token("swui-border"))
        .attribute("data-step-nav", "\(current)/\(total)")
    }

    // Deviates from plan's getElementById("swui-step-N"): ScrollyTeller stamps
    // each step card with data-scrolly-step="N" (see CodeAndPreview), so we
    // use querySelector against that attribute to find the target element.
    static func go(delta: Int) {
        #if canImport(JavaScriptKit)
        let next = ScrollyStepRegistry.currentStep + delta
        guard let document = JSObject.global.document.object,
              let el = document.querySelector?("[data-scrolly-step=\"\(next)\"]").object else {
            return
        }
        _ = el.scrollIntoView?(JSValue.boolean(true))
        #endif
    }
}
