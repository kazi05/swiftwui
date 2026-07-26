/// Options handed to a backend for one view transition (view-transitions spec §3.1).
/// `presetName` becomes `<html data-swui-vt="…">` and `direction`
/// `<html data-swui-nav="push"|"pop">`; `nil` direction omits the attribute.
public struct ViewTransitionOptions: Equatable {
    public var presetName: String?
    public var direction: NavDirection?
    /// Numeric duration for the FLIP fallback, which drives WAAPI rather than CSS.
    public var durationMS: Double
    public init(presetName: String?, direction: NavDirection?, durationMS: Double) {
        self.presetName = presetName; self.direction = direction; self.durationMS = durationMS
    }
}

/// Navigation direction. There is deliberately no `none` case — `nil` is "no
/// direction", which avoids shadowing `Optional.none` at every use site.
public enum NavDirection: String, Equatable { case push, pop }

/// How a page or in-page transition animates (view-transitions spec §2).
/// A value; the CSS it needs is registered when it is used (Task 2).
public struct PageTransition: Equatable {
    enum Kind {
        case fade
        case slide(Edge)
        case zoom(sourceID: String)
        case custom(old: Keyframes, new: Keyframes)
    }
    var kind: Kind
    var durationValue: CSSDuration = .ms(220)
    var timingValue: TimingFunction = .ease
    var reducedMotionRespected = true

    public static let fade = PageTransition(kind: .fade)
    public static func slide(edge: Edge = .trailing) -> PageTransition {
        PageTransition(kind: .slide(edge))
    }
    public static func zoom(sourceID: String, in namespace: TransitionNamespace? = nil) -> PageTransition {
        PageTransition(kind: .zoom(sourceID: namespace?.qualify(sourceID) ?? sourceID))
    }
    public static func custom(old: Keyframes, new: Keyframes) -> PageTransition {
        PageTransition(kind: .custom(old: old, new: new))
    }

    public func duration(_ d: CSSDuration) -> PageTransition {
        var copy = self; copy.durationValue = d; return copy
    }
    public func timingFunction(_ f: TimingFunction) -> PageTransition {
        var copy = self; copy.timingValue = f; return copy
    }
    /// When true (the default) the transition is skipped entirely under
    /// `prefers-reduced-motion: reduce` — same policy as `Keyframes`.
    public func respectsReducedMotion(_ flag: Bool) -> PageTransition {
        var copy = self; copy.reducedMotionRespected = flag; return copy
    }

    var respectsReducedMotion: Bool { reducedMotionRespected }
}

// `Keyframes` carries no Equatable conformance; compare custom transitions by
// the CSS names their stops hash to, which is exactly their identity in the
// stylesheet.
extension PageTransition.Kind: Equatable {
    static func == (a: PageTransition.Kind, b: PageTransition.Kind) -> Bool {
        switch (a, b) {
        case (.fade, .fade): return true
        case (.slide(let x), .slide(let y)): return x == y
        case (.zoom(let x), .zoom(let y)): return x == y
        case (.custom(let ao, let an), .custom(let bo, let bn)):
            return ao.cssName == bo.cssName && an.cssName == bn.cssName
        default: return false
        }
    }
}

/// A flat name prefix for `matchedTransition(id:in:)`. NOT a SwiftUI
/// `@Namespace`: `view-transition-name` is document-global, and two
/// `@Namespace` instances in two route bodies could never match. The prefix is
/// validated once here so a bad prefix fails in one place instead of poisoning
/// every id built from it.
public struct TransitionNamespace: Equatable {
    let prefix: String?
    public init(_ prefix: String) {
        self.prefix = CSSSanitize.isValidIdent(prefix) ? prefix : nil
    }
    func qualify(_ id: String) -> String {
        guard let prefix else { return id }
        return prefix + "-" + id
    }
}

/// Maps to `object-fit` on a group's old/new snapshots. The UA sizes them
/// `inline-size: 100%; block-size: auto`, preserving each snapshot's aspect
/// ratio, so a group interpolating between two very different aspect ratios
/// shows underfilled or doubled content. There is no universally right default,
/// hence the explicit choice: `.none` keeps content at natural size and clips,
/// `.cover` crops, `.fill` stretches.
public enum TransitionContentFit: String, Equatable {
    case cover, contain, fill, none
}

/// Ambient `PageTransition` for the dynamic extent of a `withViewTransition`
/// body. The second sanctioned @MainActor static in this codebase, for the same
/// reason as `Transaction._active`: the free function has no `Runtime` handle in
/// scope, and there is exactly one app / one `Runtime` per process.
@MainActor
enum ViewTransitionScope {
    static var _active: PageTransition?
}

/// Runs `body` with `transition` active for every state write it makes, so the
/// resulting flush commits inside a browser view transition (spec §2, §3.2).
/// Nested calls save/restore; a body that writes nothing arms nothing.
///
/// Calling this during body evaluation is illegal, same as any state write —
/// `Runtime.markDirty`'s existing assert traps it.
@MainActor
public func withViewTransition<T>(_ transition: PageTransition = .fade,
                                  _ body: () throws -> T) rethrows -> T {
    let saved = ViewTransitionScope._active
    ViewTransitionScope._active = transition
    defer { ViewTransitionScope._active = saved }
    return try body()
}

extension PageTransition {
    func options(direction: NavDirection?) -> ViewTransitionOptions {
        ViewTransitionOptions(presetName: cssAttributeValue, direction: direction,
                              durationMS: durationValue.milliseconds)
    }
}
