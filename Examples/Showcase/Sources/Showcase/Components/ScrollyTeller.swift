// ScrollyTeller.swift — 2-column scroll-driven teaching widget.

import Foundation
import Observation
import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

// Persists across re-renders so the IntersectionObserver setter, which
// captures a reference to one specific instance, keeps writing to the
// same observable storage that current `body` evaluations read.
// `@State` storage is recreated on every render of a descendant struct,
// so it cannot back this widget — see also the unresolved framework gap
// noted in main.swift's `app.mount()` comment.
@Observable
final class ScrollyTellerState: @unchecked Sendable {
    var activeStep: Int = 1
}

// WASM is single-threaded, so the storage lookup is safe under
// `nonisolated(unsafe)` — there is no other thread that could race.
nonisolated(unsafe) private var scrollyTellerStates: [String: ScrollyTellerState] = [:]

private func scrollyTellerState(for identity: String) -> ScrollyTellerState {
    if let existing = scrollyTellerStates[identity] { return existing }
    let new = ScrollyTellerState()
    scrollyTellerStates[identity] = new
    return new
}

public struct ScrollyTeller: Tag, @unchecked Sendable {
    public struct Step: @unchecked Sendable {
        public let number: Int
        public let title: String
        public let prose: String
        public let code: String
        public let highlightLines: [Int]
        public let preview: PreviewKind
        public init(number: Int,
                    title: String,
                    prose: String,
                    code: String,
                    highlightLines: [Int] = [],
                    preview: PreviewKind) {
            self.number = number
            self.title = title
            self.prose = prose
            self.code = code
            self.highlightLines = highlightLines
            self.preview = preview
        }
    }

    let steps: [Step]
    private let containerId: String

    public init(
        steps: [Step],
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.steps = steps
        // Stable per call site — same chapter page always resolves to the
        // same observable storage across re-renders.
        self.containerId = "swui-scrolly-\(file):\(line):\(column)"
    }

    private var activeStep: Int {
        scrollyTellerState(for: containerId).activeStep
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
                let state = scrollyTellerState(for: id)
                installScrollyObserver(containerId: id) { newValue in
                    state.activeStep = newValue
                    ScrollyStepRegistry.currentStep = newValue
                }
            }
        }
    }

    private var leftColumn: some Tag {
        Div {
            ForEach(steps) { step in
                let inlinePreview: AnyTag = {
                    switch step.preview {
                    case .live(let tag): return tag
                    case .screenshot(let path):
                        return AnyTag(
                            Img(src: "/snapshots/\(path)", alt: "Preview screenshot")
                                .maxWidth(.percent(100))
                                .display(.block)
                        )
                    }
                }()
                CodeAndPreview(
                    stepNumber: step.number,
                    title: step.title,
                    prose: step.prose,
                    code: step.code,
                    highlightLines: step.highlightLines,
                    preview: inlinePreview,
                    showInlinePreview: false
                )
                .attribute("class", "swui-step-card")
                .attribute("data-active", step.number == activeStep ? "true" : "false")
                .attribute("data-swui-step-card", "true")
                .attribute("id", "swui-step-\(step.number)")
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
                    PreviewFrame(kind: active.preview)
                } else if let first = steps.first {
                    PreviewFrame(kind: first.preview)
                }
            }
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

// Re-installing the observer on every render would attach N copies to
// the same target. Guard so install runs once per containerId for the
// lifetime of the document.
nonisolated(unsafe) var scrollyObservers: [String: (closure: JSClosure, observer: JSObject)] = [:]

// SPA nav reuses the outer scrolly Div across chapters (reconciler keeps
// elements with the same tag name and only patches attributes). The
// `.task` mount handler only fires on element CREATION, so the new
// chapter never installs its observer. This scanner walks the document
// after every render and installs observers for any container that
// does not yet have one.
@MainActor
public func scanAndInstallScrollyObservers() {
    guard let document = JSObject.global.document.object,
          let containers = document.querySelectorAll?("[data-swui-scrolly-id]").object else { return }
    let count = Int(containers["length"].number ?? 0)
    for i in 0..<count {
        guard let el = containers[i].object,
              let id = el.getAttribute?("data-swui-scrolly-id").string,
              scrollyObservers[id] == nil else { continue }
        let state = scrollyTellerState(for: id)
        installScrollyObserver(containerId: id) { newValue in
            state.activeStep = newValue
            ScrollyStepRegistry.currentStep = newValue
        }
    }
}

@MainActor
private func installScrollyObserver(containerId: String, setActive: @escaping @Sendable (Int) -> Void) {
    if scrollyObservers[containerId] != nil { return }
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
