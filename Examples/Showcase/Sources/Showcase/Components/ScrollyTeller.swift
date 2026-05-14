// ScrollyTeller.swift — 2-column scroll-driven teaching widget.

import Foundation
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
        public let highlightLines: [Int]
        public let preview: AnyTag
        public init(number: Int,
                    title: String,
                    prose: String,
                    code: String,
                    highlightLines: [Int] = [],
                    preview: AnyTag) {
            self.number = number
            self.title = title
            self.prose = prose
            self.code = code
            self.highlightLines = highlightLines
            self.preview = preview
        }
    }

    let steps: [Step]
    @State private var activeStep: Int = 1
    private let containerId: String

    public init(steps: [Step]) {
        self.steps = steps
        self.containerId = "swui-scrolly-\(UUID().uuidString.prefix(8))"
    }

    public var body: some Tag {
        Div {
            leftColumn
            rightColumn
        }
        .display(.grid)
        .gridTemplateColumns("1fr 1fr")
        .gap(.px(48))
        .style("max-width", Layout.maxContentWidth)
        .margin(.zero, .auto)
        .style("padding", "32px \(Layout.pageHorizontalPadding)")
        .attribute("data-swui-scrolly", "true")
        .attribute("data-swui-scrolly-id", containerId)
        .task { @Sendable in
            let id = containerId
            await MainActor.run {
                installScrollyObserver(containerId: id) { newValue in
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
                    highlightLines: step.highlightLines,
                    preview: step.preview,
                    showInlinePreview: false
                )
                .attribute("class", "swui-step-card")
                .attribute("data-active", step.number == activeStep ? "true" : "false")
            }
        }
        .display(.flex)
        .flexDirection(.column)
        .gap(.px(32))
    }

    private var rightColumn: some Tag {
        Div {
            StepNavButtons(total: steps.count, current: activeStep)
            Div {
                if let active = steps.first(where: { $0.number == activeStep }) {
                    active.preview
                } else if let first = steps.first {
                    first.preview
                }
            }
            .padding(.px(32), .px(24))
            .backgroundColor(.token("swui-surface"))
            .border(.px(1), .solid, .token("swui-border"))
            .style("border-radius", "var(--radius-md)")
            .attribute("data-swui-scrolly-sticky", "true")
            .attribute("data-swui-preview-pane", "true")
            .attribute("class", "swui-preview-pane")
            .attribute("data-active-step", "\(activeStep)")
        }
        .position(.sticky)
        .style("top", Layout.stickyTopOffset)
        .style("align-self", "start")
    }
}

extension ScrollyTeller.Step: Identifiable {
    public var id: Int { number }
}

#if canImport(JavaScriptKit)

// Known: observer leaks across route changes; framework needs an unmount hook to release.
nonisolated(unsafe) var scrollyObservers: [String: (closure: JSClosure, observer: JSObject)] = [:]

@MainActor
private func installScrollyObserver(containerId: String, setActive: @escaping @Sendable (Int) -> Void) {
    guard let document = JSObject.global.document.object else { return }

    // Scope the container lookup to this specific ScrollyTeller instance.
    guard let container = document.querySelector?("[data-swui-scrolly-id=\"\(containerId)\"]").object else { return }
    let stepsList = container.querySelectorAll!("[data-scrolly-step]").object
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

    // Retain the closure and observer for the process lifetime.
    // Without this, JavaScriptKit's refcount drops to zero and JS callbacks crash.
    scrollyObservers[containerId] = (closure: callback, observer: observer)
}
#else
@MainActor
private func installScrollyObserver(containerId: String, setActive: @escaping @Sendable (Int) -> Void) {}
#endif
