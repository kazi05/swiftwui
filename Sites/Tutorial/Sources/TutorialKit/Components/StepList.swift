import SwiftWUI

/// Left column of a section, and the identity's signature: THE RAIL — a 2px
/// spine down the 44px gutter, each step's two-digit number docked to it in a
/// 24px badge, and a fill running from the top down to the active step.
/// Two-digit step number without Foundation (no String(format:) on wasm —
/// TodoMVC convention: no Foundation in wasm targets).
func stepNumber(_ i: Int) -> String { (i < 9 ? "0" : "") + String(i + 1) }

public struct StepList: Tag {
    let section: Section
    let activeStep: Int

    public init(section: Section, activeStep: Int) {
        self.section = section
        self.activeStep = activeStep
    }

    /// The fill height is a Swift expression over the data, not a CSS trick —
    /// so it is set inline. `max(…, 1)` only guards a stepless section.
    private var fillPercent: Double {
        Double(activeStep + 1) / Double(max(section.steps.count, 1)) * 100
    }

    public var body: some Tag {
        Div(class: "tut-steps") {
            Div(class: "tut-rail") {
                Div(class: "tut-rail-fill").height(.percent(fillPercent))
            }
            ForEach(Array(section.steps.enumerated()), id: \.offset) { item in
                let active = item.offset == activeStep
                Div(id: "\(section.anchor)-step-\(item.offset)",
                    class: active ? "tut-step tut-step-active" : "tut-step") {
                    // Docked to the rail: absolute at left −44, so it sits on
                    // the spine regardless of the row's height.
                    Span(class: active ? "tut-step-badge tut-step-badge-active"
                                       : "tut-step-badge tut-step-badge-rest") {
                        Text(stepNumber(item.offset))
                    }
                    .scaleEffect(active ? 1.08 : 1)
                    Div {
                        P(class: active ? "tut-step-title tut-step-title-active"
                                        : "tut-step-title tut-step-title-rest") {
                            Text(item.element.title)
                        }
                        if let detail = item.element.detail {
                            P(class: "tut-step-detail") { Text(detail) }
                        }
                    }
                }
            }
        }
    }
}
