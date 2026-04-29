// ScrollyTeller.swift — 2-column scroll-driven teaching widget.

import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public struct ScrollyTeller: Tag, @unchecked Sendable {
    public struct Step: @unchecked Sendable {
        public let number: Int
        public let title: String
        public let prose: String
        public let code: String
        public let preview: AnyTag
        public init(number: Int, title: String, prose: String, code: String, preview: AnyTag) {
            self.number = number
            self.title = title
            self.prose = prose
            self.code = code
            self.preview = preview
        }
    }

    let steps: [Step]
    @State private var activeStep: Int = 1

    public init(steps: [Step]) { self.steps = steps }

    public var body: some Tag {
        Div {
            leftColumn
            rightColumn
        }
        .style("display", "grid")
        .style("grid-template-columns", "1fr 1fr")
        .style("gap", "48px")
        .style("max-width", Layout.maxContentWidth)
        .style("margin", "0 auto")
        .style("padding", "32px \(Layout.pageHorizontalPadding)")
        .attribute("data-swui-scrolly", "true")
        .task { @Sendable in
            await MainActor.run {
                installScrollyObserver { newValue in
                    self.activeStep = newValue
                }
            }
        }
    }

    private var leftColumn: some Tag {
        Div {
            ForEach(steps) { step in
                CodeAndPreview(
                    stepNumber: step.number,
                    title: step.title,
                    prose: step.prose,
                    code: step.code,
                    preview: step.preview,
                    showInlinePreview: false
                )
            }
        }
        .style("display", "flex")
        .style("flex-direction", "column")
        .style("gap", "32px")
    }

    private var rightColumn: some Tag {
        Div {
            Div {
                if let active = steps.first(where: { $0.number == activeStep }) {
                    active.preview
                } else if let first = steps.first {
                    first.preview
                }
            }
            .style("padding", "32px 24px")
            .style("background", "var(--swui-surface)")
            .style("border", "1px solid var(--swui-border)")
            .style("border-radius", "var(--radius-md)")
            .attribute("data-swui-scrolly-sticky", "true")
            .attribute("data-active-step", "\(activeStep)")
        }
        .style("position", "sticky")
        .style("top", Layout.stickyTopOffset)
        .style("align-self", "start")
    }
}

extension ScrollyTeller.Step: Identifiable {
    public var id: Int { number }
}

#if canImport(JavaScriptKit)
@MainActor
private func installScrollyObserver(setActive: @escaping @Sendable (Int) -> Void) {
    guard let document = JSObject.global.document.object else { return }
    let stepsList = document.querySelectorAll!("[data-scrolly-step]").object
    let length = Int(stepsList?["length"].number ?? 0)
    guard length > 0 else { return }

    let callback = JSClosure { args -> JSValue in
        guard let entries = args.first?.object else { return .undefined }
        let count = Int(entries["length"].number ?? 0)
        for i in 0..<count {
            guard let entry = entries[i].object else { continue }
            if entry["isIntersecting"].boolean ?? false {
                if let target = entry["target"].object,
                   let attr = target.getAttribute?("data-scrolly-step").string,
                   let n = Int(attr) {
                    setActive(n)
                }
            }
        }
        return .undefined
    }

    let options = JSObject.global.Object.function!.new()
    options["rootMargin"] = .string("-40% 0px -40% 0px")
    options["threshold"] = .number(0)

    guard let observerFn = JSObject.global.IntersectionObserver.function else { return }
    let observer = observerFn.new(callback, options)
    if let list = stepsList {
        for i in 0..<length {
            _ = observer.observe!(list[i])
        }
    }
}
#else
@MainActor
private func installScrollyObserver(setActive: @escaping @Sendable (Int) -> Void) {}
#endif
