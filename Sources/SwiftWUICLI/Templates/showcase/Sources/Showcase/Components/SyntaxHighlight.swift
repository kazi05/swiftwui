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
            .style("display", "none")
            .task { SyntaxHighlight.apply() }
            .attribute("data-swui-highlight-anchor", "true")
    }
}
