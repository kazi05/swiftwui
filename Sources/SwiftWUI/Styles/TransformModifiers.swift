/// A point in the 0…1 unit square, used to anchor `transform-origin` for
/// `.scaleEffect`/`.rotationEffect` (anim spec §3.5). `(0, 0)` is the
/// top-leading corner, `(1, 1)` the bottom-trailing corner — SwiftUI's
/// convention. LTR-only, matching `Edge` (AnyTransition.swift).
public struct UnitPoint: Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }

    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let topLeading = UnitPoint(x: 0, y: 0)
    public static let top = UnitPoint(x: 0.5, y: 0)
    public static let topTrailing = UnitPoint(x: 1, y: 0)
    public static let leading = UnitPoint(x: 0, y: 0.5)
    public static let trailing = UnitPoint(x: 1, y: 0.5)
    public static let bottomLeading = UnitPoint(x: 0, y: 1)
    public static let bottom = UnitPoint(x: 0.5, y: 1)
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)

    /// `"transform-origin"` value, e.g. `"50% 50%"`.
    var cssTransformOrigin: String { "\(cssNumber(x * 100))% \(cssNumber(y * 100))%" }
}

extension StyleDeclaration {
    // Individual transform-channel properties (anim spec §3.5/§6.7): each of
    // `translate`/`rotate`/`scale` is its own CSS property and animates on its
    // own channel, independent of the others. Bare `transform` has no typed
    // factory here — reserved for a future FLIP implementation.
    public static func translate(x: CSSLength, y: CSSLength) -> Self {
        .init(property: "translate", value: x.css + " " + y.css)
    }
    public static func scale(_ v: Double) -> Self {
        .init(property: "scale", value: cssNumber(v))
    }
    public static func rotate(degrees: Double) -> Self {
        .init(property: "rotate", value: cssNumber(degrees) + "deg")
    }
    public static func transformOrigin(_ v: UnitPoint) -> Self {
        .init(property: "transform-origin", value: v.cssTransformOrigin)
    }
}

extension Tag {
    /// Translates the element by `x`/`y` pixels via the individual `translate`
    /// CSS property (own animation channel, independent of `.scaleEffect`/
    /// `.rotationEffect` on the same element).
    public func offset(x: Double = 0, y: Double = 0) -> _StyledTag<Self> {
        _styled(.translate(x: .px(x), y: .px(y)))
    }
    /// Scales the element via the individual `scale` CSS property. `anchor`
    /// only emits `transform-origin` when it differs from `.center` (the CSS
    /// default) — an element supports exactly one `transform-origin`, so
    /// combining `.scaleEffect` and `.rotationEffect` with two *different*
    /// non-center anchors on the same element is unsupported; wrap in an
    /// extra element if you need that. Composition order for the separate
    /// translate/rotate/scale properties is fixed by CSS: translate, then
    /// rotate, then scale.
    public func scaleEffect(_ s: Double, anchor: UnitPoint = .center) -> _StyledTag<Self> {
        let styled = _styled(.scale(s))
        guard anchor != .center else { return styled }
        return styled._styled(.transformOrigin(anchor))
    }
    /// Rotates the element (degrees) via the individual `rotate` CSS
    /// property. See `.scaleEffect` for the `transform-origin`/anchor caveat.
    public func rotationEffect(_ degrees: Double, anchor: UnitPoint = .center) -> _StyledTag<Self> {
        let styled = _styled(.rotate(degrees: degrees))
        guard anchor != .center else { return styled }
        return styled._styled(.transformOrigin(anchor))
    }
}

extension _StyledTag {
    // Collapse variants — same semantics as the `Tag` versions above.
    public func offset(x: Double = 0, y: Double = 0) -> Self {
        _styled(.translate(x: .px(x), y: .px(y)))
    }
    public func scaleEffect(_ s: Double, anchor: UnitPoint = .center) -> Self {
        let styled = _styled(.scale(s))
        guard anchor != .center else { return styled }
        return styled._styled(.transformOrigin(anchor))
    }
    public func rotationEffect(_ degrees: Double, anchor: UnitPoint = .center) -> Self {
        let styled = _styled(.rotate(degrees: degrees))
        guard anchor != .center else { return styled }
        return styled._styled(.transformOrigin(anchor))
    }
}

extension HTMLTag {
    // Self-returning variants — same semantics as the `Tag` versions above.
    public func offset(x: Double = 0, y: Double = 0) -> Self {
        _style(.translate(x: .px(x), y: .px(y)))
    }
    public func scaleEffect(_ s: Double, anchor: UnitPoint = .center) -> Self {
        let styled = _style(.scale(s))
        guard anchor != .center else { return styled }
        return styled._style(.transformOrigin(anchor))
    }
    public func rotationEffect(_ degrees: Double, anchor: UnitPoint = .center) -> Self {
        let styled = _style(.rotate(degrees: degrees))
        guard anchor != .center else { return styled }
        return styled._style(.transformOrigin(anchor))
    }
}
