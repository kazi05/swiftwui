// ErrorBoundary.swift - Catches render-time errors and shows a fallback.

/// A tag wrapper that catches errors thrown while evaluating its content
/// closure and renders a fallback subtree instead.
///
/// SwiftWUI's `body: some Tag` requirement is non-throwing — the protocol
/// matches SwiftUI's `View.body` shape, and Swift cannot synthesise a
/// throwing accessor through it. `ErrorBoundary` therefore takes a
/// `() throws -> any Tag` content closure that the user writes explicitly:
///
/// ```swift
/// ErrorBoundary(fallback: { error in
///     P { Text("Failed to load: \(error.localizedDescription)") }
/// }) {
///     try buildDashboard(for: userID)   // can throw at render time
/// }
/// ```
///
/// **Catches:** synchronous errors thrown by `content()` while the tag tree
/// is being resolved into `TagNode`s.
///
/// **Does NOT catch:** `fatalError`, `precondition`, force-unwrap traps,
/// nor errors thrown asynchronously from `.task` modifiers (those land in
/// `AsyncResource.phase`, addressed by `AsyncBoundary` in a later phase).
public struct ErrorBoundary<Fallback: Tag>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: () throws -> any Tag
    public let fallback: (Error) -> Fallback
    public let onError: ((Error) -> Void)?

    public init(
        fallback: @escaping (Error) -> Fallback,
        onError: ((Error) -> Void)? = nil,
        content: @escaping () throws -> any Tag
    ) {
        self.content = content
        self.fallback = fallback
        self.onError = onError
    }

    public func toTagNodes() -> [TagNode] {
        do {
            let inner = try content()
            if let convertible = inner as? TagNodeConvertible {
                return convertible.toTagNodes()
            }
            return resolveTagBody(inner)
        } catch {
            onError?(error)
            let fallbackTag = fallback(error)
            if let convertible = fallbackTag as? TagNodeConvertible {
                return convertible.toTagNodes()
            }
            return resolveTagBody(fallbackTag)
        }
    }
}
