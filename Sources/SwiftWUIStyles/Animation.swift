// Animation.swift - CSS animation and transition types

/// Represents a CSS animation/transition configuration.
///
/// ```swift
/// withAnimation(.easeInOut(duration: 0.3)) {
///     isVisible = true
/// }
///
/// Div { content }
///     .animation(.spring, value: isExpanded)
/// ```
public struct Animation: Sendable, Equatable {
    public let duration: Double  // seconds
    public let timingFunction: TimingFunction
    public let delay: Double  // seconds

    public init(duration: Double, timingFunction: TimingFunction, delay: Double = 0) {
        self.duration = duration
        self.timingFunction = timingFunction
        self.delay = delay
    }

    // MARK: - Presets

    /// Default animation: 0.3s ease-in-out.
    public static let `default` = Animation(duration: 0.3, timingFunction: .easeInOut)

    /// Linear animation.
    public static func linear(duration: Double) -> Animation {
        Animation(duration: duration, timingFunction: .linear)
    }

    /// Ease-in animation.
    public static func easeIn(duration: Double) -> Animation {
        Animation(duration: duration, timingFunction: .easeIn)
    }

    /// Ease-out animation.
    public static func easeOut(duration: Double) -> Animation {
        Animation(duration: duration, timingFunction: .easeOut)
    }

    /// Ease-in-out animation.
    public static func easeInOut(duration: Double) -> Animation {
        Animation(duration: duration, timingFunction: .easeInOut)
    }

    /// Spring animation (CSS approximation using cubic-bezier).
    public static let spring = Animation(
        duration: 0.5,
        timingFunction: .cubicBezier(0.175, 0.885, 0.32, 1.275)
    )

    /// Bouncy spring with more overshoot.
    public static let bouncy = Animation(
        duration: 0.6,
        timingFunction: .cubicBezier(0.34, 1.56, 0.64, 1)
    )

    /// Custom animation with specified parameters.
    public static func custom(
        duration: Double,
        timingFunction: TimingFunction,
        delay: Double = 0
    ) -> Animation {
        Animation(duration: duration, timingFunction: timingFunction, delay: delay)
    }

    // MARK: - Modifiers

    /// Returns a copy with added delay.
    public func delay(_ delay: Double) -> Animation {
        Animation(duration: duration, timingFunction: timingFunction, delay: delay)
    }

    /// Returns a copy with different speed (multiplies duration).
    public func speed(_ multiplier: Double) -> Animation {
        Animation(duration: duration / multiplier, timingFunction: timingFunction, delay: delay)
    }

    // MARK: - CSS Generation

    /// CSS transition value for "all" properties.
    public var cssTransitionAll: String {
        if delay > 0 {
            return "all \(formatDuration(duration)) \(timingFunction.cssValue) \(formatDuration(delay))"
        }
        return "all \(formatDuration(duration)) \(timingFunction.cssValue)"
    }

    /// CSS transition value for specific properties.
    public func cssTransitionValue(for properties: [String]) -> String {
        properties.map { property in
            if delay > 0 {
                return "\(property) \(formatDuration(duration)) \(timingFunction.cssValue) \(formatDuration(delay))"
            }
            return "\(property) \(formatDuration(duration)) \(timingFunction.cssValue)"
        }.joined(separator: ", ")
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds == 0 { return "0s" }
        // Always use seconds format for consistency and predictability
        return "\(seconds)s"
    }
}

// MARK: - TimingFunction

/// CSS timing function for animations and transitions.
public enum TimingFunction: Sendable, Equatable {
    case linear
    case ease
    case easeIn
    case easeOut
    case easeInOut
    case cubicBezier(Double, Double, Double, Double)
    /// Step function for discrete animations.
    case steps(Int, StepPosition)

    public var cssValue: String {
        switch self {
        case .linear: return "linear"
        case .ease: return "ease"
        case .easeIn: return "ease-in"
        case .easeOut: return "ease-out"
        case .easeInOut: return "ease-in-out"
        case .cubicBezier(let x1, let y1, let x2, let y2):
            return "cubic-bezier(\(x1), \(y1), \(x2), \(y2))"
        case .steps(let count, let position):
            return "steps(\(count), \(position.cssValue))"
        }
    }
}

/// Step position for step timing functions.
public enum StepPosition: Sendable, Equatable {
    case start
    case end

    public var cssValue: String {
        switch self {
        case .start: return "start"
        case .end: return "end"
        }
    }
}

// MARK: - AnimationContext

/// Global animation context for `withAnimation`.
///
/// When `withAnimation` is called, it sets the current animation context
/// before executing the state mutation. The render cycle then picks up
/// this context and applies CSS transitions to changed elements.
///
/// Thread-safe because WASM is single-threaded.
public enum AnimationContext {
    /// The currently active animation, if any.
    nonisolated(unsafe) public static var current: Animation? = nil
}

// MARK: - withAnimation

/// Execute a state mutation with animation.
///
/// ```swift
/// withAnimation(.easeInOut(duration: 0.3)) {
///     isVisible.toggle()
/// }
/// ```
///
/// This sets `AnimationContext.current` before executing the body.
/// The render cycle will detect this and apply CSS transitions to
/// all style changes that occur during the re-render.
public func withAnimation(_ animation: Animation = .default, _ body: () -> Void) {
    AnimationContext.current = animation
    body()
    // Don't clear here — the render cycle will capture and clear it
}
