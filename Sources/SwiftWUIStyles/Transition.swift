// Transition.swift - Enter/exit transitions for tag appearance

/// Defines enter and exit styles for tag transitions.
///
/// Transitions are applied when tags appear or disappear from the DOM.
///
/// ```swift
/// if isVisible {
///     Div { Text("Hello") }
///         .transition(.opacity)
/// }
/// ```
public struct TagTransition: Sendable, Equatable {
    /// CSS styles to apply when the element enters (initial state before animation).
    public let enterFrom: [String: String]
    /// CSS styles to apply when the element exits (target state of exit animation).
    public let exitTo: [String: String]
    /// The animation to use for the transition.
    public let animation: Animation

    public init(
        enterFrom: [String: String],
        exitTo: [String: String],
        animation: Animation = .default
    ) {
        self.enterFrom = enterFrom
        self.exitTo = exitTo
        self.animation = animation
    }

    // MARK: - Presets

    /// Fade in/out transition.
    public static let opacity = TagTransition(
        enterFrom: ["opacity": "0"],
        exitTo: ["opacity": "0"],
        animation: .default
    )

    /// Scale up/down transition.
    public static let scale = TagTransition(
        enterFrom: ["transform": "scale(0.8)", "opacity": "0"],
        exitTo: ["transform": "scale(0.8)", "opacity": "0"],
        animation: .default
    )

    /// Slide in from left, out to right.
    public static let slide = TagTransition(
        enterFrom: ["transform": "translateX(-100%)", "opacity": "0"],
        exitTo: ["transform": "translateX(100%)", "opacity": "0"],
        animation: .default
    )

    /// Slide up from bottom.
    public static let moveUp = TagTransition(
        enterFrom: ["transform": "translateY(20px)", "opacity": "0"],
        exitTo: ["transform": "translateY(-20px)", "opacity": "0"],
        animation: .default
    )

    /// Slide down from top.
    public static let moveDown = TagTransition(
        enterFrom: ["transform": "translateY(-20px)", "opacity": "0"],
        exitTo: ["transform": "translateY(20px)", "opacity": "0"],
        animation: .default
    )

    // MARK: - Modifiers

    /// Returns a copy with a different animation.
    public func animation(_ animation: Animation) -> TagTransition {
        TagTransition(enterFrom: enterFrom, exitTo: exitTo, animation: animation)
    }

    /// Combine two transitions.
    public func combined(with other: TagTransition) -> TagTransition {
        var mergedEnter = enterFrom
        for (key, value) in other.enterFrom {
            mergedEnter[key] = value
        }
        var mergedExit = exitTo
        for (key, value) in other.exitTo {
            mergedExit[key] = value
        }
        return TagTransition(
            enterFrom: mergedEnter,
            exitTo: mergedExit,
            animation: animation
        )
    }
}
