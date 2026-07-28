import SwiftWUI

/// One tutorial section: header + [steps | panel], the panel sticky at lg.
/// activeStep drives the rail fill, the step highlight and the panel swap.
/// Initial-state contract (spec §6): activeStep = 0 on BOTH backends; ssg
/// renders step 0 active; scrollspy mutates state only post-mount.
public struct SectionView: Tag {
    let section: Section
    let index: Int
    @State private var activeStep = 0
    // ponytail: ScrollSpy isn't Encodable — the SSG state snapshot silently drops
    // this component's whole row (StateStore._encodeSnapshotRows skips the identity).
    // Harmless while activeStep's initial value (0) matches SSG output; any future
    // @State here that must round-trip through hydration will also be dropped.
    @State private var spy = ScrollSpy()

    public init(section: Section, index: Int) {
        self.section = section
        self.index = index
    }

    public var body: some Tag {
        // NOTE: body is a @TagBuilder — no `return` statements. The whole
        // section is ONE chained expression so the effect modifiers apply once.
        SwiftWUI.Section(
            id: section.anchor,
            class: index == 0 ? "tut-section" : "tut-section tut-section-divided"
        ) {
            Div(class: "tut-content") {
                Div(class: "tut-section-header") {
                    Div(class: "tut-kicker-row") {
                        Span(class: "tut-kicker") {
                            Span(class: "tut-kicker-slash") { Text("//") }
                            Text(" \(section.kicker)")
                        }
                        Div(class: "tut-kicker-rule")
                    }
                    H2(section.title, class: "tut-section-title")
                    if let intro = section.intro {
                        P(class: "tut-section-intro") { Text(intro) }
                    }
                }
                // DOM order is steps → panel (the reading order a screen reader
                // and a no-CSS client get); below lg `.tut-panel` takes order −1
                // so the code lands first on phones.
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
                // One spring carries the badge scale, the row tint and the rail fill.
                withAnimation(.spring(duration: 0.28, bounce: 0)) { activeStep = idx }
            }
        }
        .onDisappear { [spy] in spy.detach() }
    }
}
