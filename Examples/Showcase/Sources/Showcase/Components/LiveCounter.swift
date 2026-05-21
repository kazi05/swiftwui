// LiveCounter.swift — interactive Counter preview used by StatePage.
//
// `@State` in a descendant struct is recreated on every parent render
// (see ScrollyTeller for the same gap), so a naive `@State var count`
// inside a preview Tag resets to its default each time the chapter
// re-renders — making the demo button look broken. This component
// keeps a singleton `@Observable` state keyed by the call site so the
// counter survives re-renders.

import Observation
import SwiftWUI

@Observable
final class LiveCounterState: @unchecked Sendable {
    var count: Int = 0
}

nonisolated(unsafe) private var liveCounterStates: [String: LiveCounterState] = [:]

private func liveCounterState(for identity: String) -> LiveCounterState {
    if let existing = liveCounterStates[identity] { return existing }
    let new = LiveCounterState()
    liveCounterStates[identity] = new
    return new
}

public struct LiveCounter: Tag {
    private let identity: String

    public init(
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        self.identity = "live-counter:\(file):\(line):\(column)"
    }

    public var body: some Tag {
        let state = liveCounterState(for: identity)
        let bump: @Sendable () -> Void = { [identity] in
            liveCounterState(for: identity).count += 1
        }
        return Div {
            Span { Text("Count: \(state.count)") }
                .fontSize(.px(20))
                .fontFamily("var(--font-mono)")
                .foregroundColor(.token("swui-fg"))
            Div {
                Button(onclick: bump) {
                    Text("+ Increment")
                }
                .backgroundColor(.token("swui-accent"))
                .foregroundColor(.css("#fff"))
                .padding(.px(6), .px(14))
                .borderRadius(.px(6))
                .fontSize(.px(13))
                .cursor(.pointer)
                .style("border", "none")
            }
            .style("margin-top", "10px")
        }
    }
}
