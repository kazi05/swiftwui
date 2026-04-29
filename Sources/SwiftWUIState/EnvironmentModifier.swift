// EnvironmentModifier.swift - Tree-scoped environment override for tags.

import SwiftWUICore

/// A tag wrapper that pushes a single environment value onto the
/// environment stack while its content's `toTagNodes()` runs.
///
/// `.environment(\.theme, .dark)` is the user-facing API; this struct is
/// the concrete tag the modifier produces. The override is scoped via
/// `TaskLocal.withValue`, so siblings outside the wrapper continue to
/// see whatever value the surrounding scope had.
public struct EnvironmentModifier<Content: Tag, Value>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: Content
    public let keyPath: WritableKeyPath<EnvironmentValues, Value>
    public let value: Value

    public init(
        content: Content,
        keyPath: WritableKeyPath<EnvironmentValues, Value>,
        value: Value
    ) {
        self.content = content
        self.keyPath = keyPath
        self.value = value
    }

    public func toTagNodes() -> [TagNode] {
        // Build the next environment by copying the current one and writing
        // through the supplied keyPath. Then run the subtree under that
        // task-local override. Sibling subtrees outside this call see the
        // unchanged outer environment.
        var next = EnvironmentValues.current
        next[keyPath: keyPath] = value
        return EnvironmentValues.$current.withValue(next) {
            if let convertible = content as? TagNodeConvertible {
                return convertible.toTagNodes()
            }
            return resolveTagBody(content)
        }
    }
}

extension Tag {
    /// Override an environment value for this tag and all of its descendants.
    ///
    /// ```swift
    /// MyApp()
    ///     .environment(\.theme, .dark)
    /// ```
    public func environment<Value>(
        _ keyPath: WritableKeyPath<EnvironmentValues, Value>,
        _ value: Value
    ) -> EnvironmentModifier<Self, Value> {
        EnvironmentModifier(content: self, keyPath: keyPath, value: value)
    }
}
