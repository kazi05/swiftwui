// ContainerQuery.swift - CSS @container query for parent-aware styling.
//
// Container Queries shipped in all major browsers in 2023; they're the
// modern alternative to viewport-based media queries when a component
// needs to react to its containing element's size rather than the
// viewport's. SwiftWUI surfaces them through the same responsiveStyles
// pipeline that powers `.media(_:)` — the only difference is the
// at-rule prefix on the emitted CSS.

import SwiftWUICore

/// CSS `@container` query. Names a containment context to query against
/// (or queries the nearest container if `name` is nil). Supports the
/// same combinators (`and`, `or`, `not`) as `MediaQuery`.
///
/// Construct with the static factories — they accept either a name or
/// no name, where "no name" targets the nearest containment context
/// with `container-type: inline-size` (or any non-default value) set.
public indirect enum ContainerQuery: Hashable, Sendable {
    case _minWidth(String?, CSSUnit)
    case _maxWidth(String?, CSSUnit)
    case _minHeight(String?, CSSUnit)
    case _maxHeight(String?, CSSUnit)
    case and(ContainerQuery, ContainerQuery)
    case or(ContainerQuery, ContainerQuery)
    case not(ContainerQuery)

    // Public factories — Swift enum cases cannot carry default
    // arguments, so the name-optional / name-required forms are
    // exposed as overloaded statics that funnel into the underscore-
    // prefixed cases.

    public static func minWidth(_ unit: CSSUnit) -> Self { ._minWidth(nil, unit) }
    public static func minWidth(_ name: String, _ unit: CSSUnit) -> Self {
        ._minWidth(name, unit)
    }
    public static func maxWidth(_ unit: CSSUnit) -> Self { ._maxWidth(nil, unit) }
    public static func maxWidth(_ name: String, _ unit: CSSUnit) -> Self {
        ._maxWidth(name, unit)
    }
    public static func minHeight(_ unit: CSSUnit) -> Self { ._minHeight(nil, unit) }
    public static func minHeight(_ name: String, _ unit: CSSUnit) -> Self {
        ._minHeight(name, unit)
    }
    public static func maxHeight(_ unit: CSSUnit) -> Self { ._maxHeight(nil, unit) }
    public static func maxHeight(_ name: String, _ unit: CSSUnit) -> Self {
        ._maxHeight(name, unit)
    }

    /// Container name for the at-rule prefix, when applicable. Nil means
    /// "the nearest containing context with `container-type` set".
    public var name: String? {
        switch self {
        case ._minWidth(let name, _),
             ._maxWidth(let name, _),
             ._minHeight(let name, _),
             ._maxHeight(let name, _):
            return name
        case .and(let lhs, _), .or(let lhs, _), .not(let lhs):
            return lhs.name
        }
    }

    /// The full CSS at-rule string used as the responsive-style key.
    public var cssString: String {
        if let n = name {
            return "@container \(n) \(condition)"
        }
        return "@container \(condition)"
    }

    var condition: String {
        switch self {
        case ._minWidth(_, let u):  return "(min-width: \(u.cssValue))"
        case ._maxWidth(_, let u):  return "(max-width: \(u.cssValue))"
        case ._minHeight(_, let u): return "(min-height: \(u.cssValue))"
        case ._maxHeight(_, let u): return "(max-height: \(u.cssValue))"
        case .and(let l, let r):    return "\(l.condition) and \(r.condition)"
        case .or(let l, let r):     return "\(l.condition), \(r.condition)"
        case .not(let q):           return "not \(q.condition)"
        }
    }
}

extension Tag {
    /// Apply styles conditionally based on a `@container` query.
    /// Mirrors `.media(_:apply:)` but resolves against the nearest
    /// containing element with `container-type` rather than the viewport.
    public func container<T: Tag>(
        _ query: ContainerQuery,
        apply: (StyleProxy) -> T
    ) -> ModifiedContent<Self> {
        ModifiedContent(
            content: self,
            responsiveStyles: [(query.cssString, _extractProxyStyles(apply))]
        )
    }
}

extension ModifiedContent {
    /// Chainable variant of `Tag.container(_:apply:)`.
    public func container<T: Tag>(
        _ query: ContainerQuery,
        apply: (StyleProxy) -> T
    ) -> ModifiedContent<Content> {
        var copy = self
        copy.responsiveStyles.append((query.cssString, _extractProxyStyles(apply)))
        return copy
    }
}

/// Same proxy-style extraction as `ResponsiveModifier`, copied here to
/// avoid making the helper public. Inlining once in this file is
/// cheaper than threading a public utility through the styles module.
private func _extractProxyStyles<T: Tag>(
    _ apply: (StyleProxy) -> T
) -> [(String, String)] {
    let result = apply(StyleProxy())
    let nodes = resolveTagBody(result)
    guard case .element(let el) = nodes.first else { return [] }
    return el.styles
        .sorted(by: { $0.key < $1.key })
        .map { ($0.key, $0.value) }
}
