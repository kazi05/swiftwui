// SyntaxHighlight.swift — bridge to highlight.js loaded via CDN in index.html.

import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit

public enum SyntaxHighlight {
    /// Trigger highlight.js to scan the document and apply colours to all
    /// `<pre><code class="language-*">…</code></pre>` blocks. Safe to call
    /// after every route change.
    public static func apply() {
        guard let hljs = JSObject.global.hljs.object else { return }
        _ = hljs.highlightAll?()
    }
}
#else
public enum SyntaxHighlight {
    public static func apply() {}
}
#endif

/// A zero-size Tag whose only purpose is to call `SyntaxHighlight.apply()`
/// when it mounts. Drop one at the bottom of every page that renders code
/// blocks; the `.task { … }` modifier ensures `apply()` runs once per
/// route change without leaking observers.
public struct HighlightOnMount: Tag {
    public init() {}
    public var body: some Tag {
        Div { EmptyTag() }
            .display(.none)
            .task { SyntaxHighlight.apply() }
            .attribute("data-swui-highlight-anchor", "true")
    }
}

/// Renders a multi-line code string as a vertical stack of line rows,
/// each carrying `data-line="N"` (1-indexed). Lines whose number is in
/// `highlightLines` additionally carry `data-line-hl="N"` — CSS selects
/// these via `[data-line-hl]` to apply the `--swui-code-line-hl` background.
public struct LineNumberedCode: Tag {
    public let code: String
    public let highlightLines: [Int]

    public init(code: String, highlightLines: [Int] = []) {
        self.code = code
        self.highlightLines = highlightLines
    }

    public var body: some Tag {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hlSet = Set(highlightLines)

        let rows = lines.enumerated().map { idx, src in
            LineRow(id: idx + 1, source: src, highlighted: hlSet.contains(idx + 1))
        }

        return Div {
            ForEach(rows) { row in
                Div {
                    Span { Text("\(row.id)") }
                        .foregroundColor(.token("swui-fg-3"))
                        .textAlign(.right)
                        .style("padding-right", "12px")
                        .style("user-select", "none")
                    Code { Text(row.source) }
                        .whiteSpace(.pre)
                        .fontFamily("var(--font-mono)")
                }
                .display(.grid)
                .gridTemplateColumns("36px 1fr")
                .fontSize(.px(12))
                .attribute("data-line", "\(row.id)")
                .attribute("class", row.highlighted ? "swui-code-line swui-code-line-hl" : "swui-code-line")
                .attribute("data-line-hl", row.highlighted ? "\(row.id)" : "")
            }
        }
        .display(.block)
        .attribute("data-swui-code-panel", "true")
    }

    private struct LineRow: Identifiable {
        let id: Int
        let source: String
        let highlighted: Bool
    }
}
