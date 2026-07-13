/// Edge of a container, used by `AnyTransition.move(edge:)` (Task 12 also
/// needs this for `UnitPoint`-based anchors, so it's defined here rather than
/// duplicated). LTR-only in v1 — `.leading`/`.trailing` map to the physical
/// left/right edge, no RTL flip.
public enum Edge {
    case leading, trailing, top, bottom
}

/// A transition describes the "off-stage" (active) style declarations for a
/// tag's insertion and removal (anim spec §3.4, adapted): enter animates from
/// `insertionActive` to the tag's current presentation, exit animates from
/// the current presentation to `removalActive`. Playback lands in Tasks 9-10
/// — this type is pure value-semantics storage plus the composition surface.
public struct AnyTransition: Equatable {
    var insertionActive: [StyleDeclaration]
    var removalActive: [StyleDeclaration]
    var animation: Animation?

    /// No off-stage styling — insertion/removal are not animated.
    public static let identity = AnyTransition(insertionActive: [], removalActive: [], animation: nil)

    /// The same active declarations for both insertion and removal.
    public static func active(_ declarations: [StyleDeclaration]) -> AnyTransition {
        AnyTransition(insertionActive: declarations, removalActive: declarations, animation: nil)
    }

    public static let opacity = AnyTransition.active([.opacity(0)])

    public static func scale(_ s: Double = 0.0) -> AnyTransition {
        .active([StyleDeclaration(property: "scale", value: cssNumber(s))])
    }

    public static func offset(x: Double = 0, y: Double = 0) -> AnyTransition {
        .active([StyleDeclaration(property: "translate", value: "\(cssNumber(x))px \(cssNumber(y))px")])
    }

    public static func move(edge: Edge) -> AnyTransition {
        let value: String
        switch edge {
        case .leading: value = "-100% 0"
        case .trailing: value = "100% 0"
        case .top: value = "0 -100%"
        case .bottom: value = "0 100%"
        }
        return .active([StyleDeclaration(property: "translate", value: value)])
    }

    public static let slide = AnyTransition.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))

    /// Union of both phase lists (self's declarations first, then `other`'s).
    /// `animation` prefers self's override, falling back to `other`'s.
    public func combined(with other: AnyTransition) -> AnyTransition {
        AnyTransition(insertionActive: insertionActive + other.insertionActive,
                     removalActive: removalActive + other.removalActive,
                     animation: animation ?? other.animation)
    }

    /// `insertion`'s active declarations drive mount, `removal`'s drive
    /// unmount; the two halves don't otherwise interact.
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition {
        AnyTransition(insertionActive: insertion.insertionActive, removalActive: removal.removalActive, animation: nil)
    }

    /// Overrides the animation used to play this transition (last call wins).
    public func animation(_ a: Animation?) -> AnyTransition {
        var copy = self
        copy.animation = a
        return copy
    }
}
