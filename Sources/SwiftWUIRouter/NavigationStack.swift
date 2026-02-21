// NavigationStack.swift - Navigation container component

import SwiftWUICore

/// A container that displays the current route's content.
/// Analogous to SwiftUI's NavigationStack.
///
/// ```swift
/// struct App: Tag {
///     let router: Router
///
///     var body: some Tag {
///         NavigationStack(router: router)
///     }
/// }
/// ```
public struct NavigationStack: Tag {
    public typealias Body = Never

    let router: Router
    let fallback: AnyTag?

    public init(router: Router) {
        self.router = router
        self.fallback = nil
    }

    public init(router: Router, @TagBuilder fallback: () -> some Tag) {
        self.router = router
        self.fallback = AnyTag(fallback())
    }
}

extension NavigationStack: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        if let matchedTag = router.matchedTag(for: router.currentPath) {
            return resolveTagBody(matchedTag)
        }
        if let fallback {
            return resolveTagBody(fallback)
        }
        // 404 - no matching route
        return [.element(.init(
            tagName: "div",
            attributes: ["class": "swiftwui-404"],
            children: [.text("Page not found: \(router.currentPath)")]
        ))]
    }
}
