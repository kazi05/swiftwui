import SwiftWUI

/// Left column of a section (Figma 4:11). The ACTIVE step gets emphasized
/// number/title colors inline (Rule has no descendant selectors).
/// Two-digit step number without Foundation (no String(format:) on wasm —
/// TodoMVC convention: no Foundation in wasm targets).
func stepNumber(_ i: Int) -> String { (i < 9 ? "0" : "") + String(i + 1) }

public struct StepList: Tag {
    let section: Section
    let activeStep: Int

    public var body: some Tag {
        Div(class: "tut-steps") {
            ForEach(Array(section.steps.enumerated()), id: \.offset) { item in
                Div(id: "\(section.anchor)-step-\(item.offset)",
                    class: item.offset == activeStep ? "tut-step tut-step-active" : "tut-step") {
                    if item.offset == activeStep {
                        Span(class: "tut-step-num") { Text(stepNumber(item.offset)) }
                            .color(.token(.accent))
                        Div {
                            P(class: "tut-step-title") { Text(item.element.title) }
                                .color(.token(.ink)).fontWeight(.custom(600))
                            if let detail = item.element.detail {
                                P(class: "tut-step-detail") { Text(detail) }
                            }
                        }
                    } else {
                        Span(class: "tut-step-num") { Text(stepNumber(item.offset)) }
                        Div {
                            P(class: "tut-step-title") { Text(item.element.title) }
                            if let detail = item.element.detail {
                                P(class: "tut-step-detail") { Text(detail) }
                            }
                        }
                    }
                }
            }
        }
    }
}
