import SwiftWUI

/// One tutorial section (Figma 4:5): header + [steps | sticky panel].
/// activeStep drives both the step highlight and the panel swap (spec D2).
/// Initial-state contract (spec §6): activeStep = 0 on BOTH backends; ssg
/// renders step 0 active; scrollspy mutates state only post-mount.
public struct SectionView: Tag {
    let section: Section
    let index: Int
    @State private var activeStep = 0
    @State private var spy = ScrollSpy()

    public init(section: Section, index: Int) {
        self.section = section
        self.index = index
    }

    public var body: some Tag {
        // NOTE: body is a @TagBuilder — no `return` statements. The whole
        // section is ONE chained expression so the effect modifiers apply once.
        SwiftWUI.Section(id: section.anchor, class: "tut-section") {
            Div(class: "tut-content") {
                Div(class: "tut-section-header") {
                    Span(class: "tut-kicker") { Text(section.kicker) }
                    H2(section.title, class: "tut-section-title")
                    if let intro = section.intro {
                        P(class: "tut-section-intro") { Text(intro) }
                    }
                }
                Div(class: "tut-section-body") {
                    StepList(section: section, activeStep: activeStep)
                    Div(class: "tut-panel") {
                        PanelView(panel: section.activePanel(step: activeStep))
                    }
                }
            }
        }
        .onAppear { [section, spy] in
            spy.attach(anchor: section.anchor, stepCount: section.steps.count) { idx in
                activeStep = idx
            }
        }
        .onDisappear { [spy] in spy.detach() }
    }
}
