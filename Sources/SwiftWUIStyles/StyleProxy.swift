// StyleProxy.swift - Phantom tag for collecting modifier styles

import SwiftWUICore

/// A phantom tag used internally by `.media()` to collect styles from the modifier chain.
///
/// `StyleProxy` is an empty tag that produces a placeholder element. When style
/// modifiers are applied to it, they accumulate in a `ModifiedContent` wrapper.
/// The `.media()` modifier converts the result to `TagNode`s and extracts the
/// collected styles from the placeholder element.
///
/// You don't use `StyleProxy` directly — it is passed as `$0` in the `.media()` closure:
/// ```swift
/// Text("Hello")
///     .media(.compact) { $0.fontSize(.px(16)) }
///     //                  ^^ this is a StyleProxy
/// ```
public struct StyleProxy: Tag, TagNodeConvertible {
    public typealias Body = Never

    public init() {}

    public func toTagNodes() -> [TagNode] {
        [.element(.init(tagName: "__proxy__"))]
    }
}
