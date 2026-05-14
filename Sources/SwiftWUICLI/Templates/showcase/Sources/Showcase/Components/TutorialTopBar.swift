// TutorialTopBar.swift — dual-dropdown top bar matching Apple Tutorials.

import SwiftWUI

public struct TutorialTopBar: Tag {
    public let currentChapter: String
    public let stepTitles: [String]
    public let currentStep: Int

    public init(currentChapter: String, stepTitles: [String], currentStep: Int) {
        self.currentChapter = currentChapter
        self.stepTitles = stepTitles
        self.currentStep = currentStep
    }

    public var body: some Tag {
        let chapterTitle = ChapterRegistry.chapter(forID: currentChapter)?.title ?? "Welcome"
        let active = max(1, min(currentStep, stepTitles.count))
        let activeTitle = stepTitles.indices.contains(active - 1) ? stepTitles[active - 1] : ""

        return Div {
            // Wordmark
            Div {
                Span { Text("Develop in Swift") }
                    .fontFamily("var(--font-display)")
                    .fontSize(.px(14))
                    .fontWeight(.w600)
                    .foregroundColor(.token("swui-fg"))
                Span { Text(" Tutorials") }
                    .fontFamily("var(--font-display)")
                    .fontSize(.px(14))
                    .fontWeight(.w600)
                    .foregroundColor(.token("swui-accent"))
            }
            .display(.flex)
            .alignItems(.center)

            // Chapter dropdown
            Details {
                Summary {
                    Span { Text(chapterTitle) }
                        .fontSize(.px(13))
                        .foregroundColor(.token("swui-fg"))
                    Span { Text(" ▾") }
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-3"))
                }
                .cursor(.pointer)
                .style("list-style", "none")
                .padding(.px(6), .px(10))
                .borderRadius(.px(6))
                .backgroundColor(.token("swui-surface"))
                .border(.px(1), .solid, .token("swui-border"))

                ChapterPickerPopover(active: currentChapter)
                    .position(.absolute)
                    .style("top", "calc(100% + 4px)")
                    .left(.zero)
                    .zIndex(100)
            }
            .position(.relative)

            // Section dropdown + N of M chip
            Details {
                Summary {
                    Span { Text(activeTitle) }
                        .fontSize(.px(13))
                        .foregroundColor(.token("swui-fg"))
                    Span { Text("  \(active) of \(stepTitles.count)") }
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-3"))
                    Span { Text(" ▾") }
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-3"))
                }
                .cursor(.pointer)
                .style("list-style", "none")
                .padding(.px(6), .px(10))
                .borderRadius(.px(6))
                .backgroundColor(.token("swui-surface"))
                .border(.px(1), .solid, .token("swui-border"))

                SectionPickerPopover(chapter: currentChapter,
                                     stepTitles: stepTitles,
                                     active: currentStep)
                    .position(.absolute)
                    .style("top", "calc(100% + 4px)")
                    .left(.zero)
                    .zIndex(100)
            }
            .position(.relative)

            // Spacer + theme toggle on the right
            Div { EmptyTag() }.style("flex", "1")
            ThemeToggle()
        }
        .display(.flex)
        .alignItems(.center)
        .gap(.px(16))
        .padding(.px(8), .px(16))
        .backgroundColor(.token("swui-bg"))
        .borderBottom(.px(1), .solid, .token("swui-border"))
        .position(.sticky)
        .top(.zero)
        .zIndex(50)
        .attribute("data-swui-topbar", "true")
    }
}
