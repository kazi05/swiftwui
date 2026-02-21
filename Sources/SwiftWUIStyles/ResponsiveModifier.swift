// ResponsiveModifier.swift - .media() modifier for responsive CSS styles

import SwiftWUICore

// MARK: - Tag Extension

extension Tag {
    /// Apply styles conditionally under a CSS media query.
    ///
    /// The closure receives a `StyleProxy` — apply any style modifiers to it.
    /// Those styles will only take effect when the media query matches.
    ///
    /// ```swift
    /// Text("Hello")
    ///     .fontSize(.px(24))
    ///     .media(.compact) { $0.fontSize(.px(16)) }
    /// ```
    public func media<T: Tag>(
        _ query: MediaQuery,
        apply: (StyleProxy) -> T
    ) -> ModifiedContent<Self> {
        let styles = extractProxyStyles(apply)
        return ModifiedContent(
            content: self,
            responsiveStyles: [(query.cssString, styles)]
        )
    }
}

// MARK: - ModifiedContent Extension

extension ModifiedContent {
    /// Apply styles conditionally under a CSS media query (chainable).
    public func media<T: Tag>(
        _ query: MediaQuery,
        apply: (StyleProxy) -> T
    ) -> ModifiedContent<Content> {
        var copy = self
        let styles = extractProxyStyles(apply)
        copy.responsiveStyles.append((query.cssString, styles))
        return copy
    }
}

// MARK: - Style Extraction

/// Runs the closure with a StyleProxy, converts the result to TagNodes,
/// and extracts the accumulated inline styles from the proxy element.
private func extractProxyStyles<T: Tag>(
    _ apply: (StyleProxy) -> T
) -> [(String, String)] {
    let result = apply(StyleProxy())
    let nodes = resolveTagBody(result)
    guard case .element(let el) = nodes.first else { return [] }
    return el.styles
        .sorted(by: { $0.key < $1.key })
        .map { ($0.key, $0.value) }
}
