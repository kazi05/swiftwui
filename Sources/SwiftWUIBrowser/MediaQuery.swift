// MediaQuery.swift - Browser media query and responsive design utilities

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import Observation

/// The user's preferred colour scheme.
public enum ColorScheme: String, Sendable {
    case light
    case dark
}

/// Screen size category for responsive design breakpoints.
public enum ScreenSize: Sendable {
    /// Width < 768px (mobile).
    case compact
    /// Width 768--1024px (tablet).
    case regular
    /// Width > 1024px (desktop).
    case expanded
}

/// Tracks browser media query state for responsive design.
///
/// Call ``startListening()`` once during application setup. The observable
/// properties update automatically when the browser environment changes.
///
/// ```swift
/// struct ResponsiveView: Tag {
///     @State var media = MediaQueryState()
///
///     var body: some Tag {
///         if media.screenSize == .compact {
///             MobileLayout()
///         } else {
///             DesktopLayout()
///         }
///     }
/// }
/// ```
@Observable
public final class MediaQueryState: @unchecked Sendable {
    /// The user's preferred colour scheme.
    public var colorScheme: ColorScheme = .light
    /// The current viewport width in CSS pixels.
    public var screenWidth: Double = 1024
    /// The current viewport height in CSS pixels.
    public var screenHeight: Double = 768

    /// Computed screen size category based on ``screenWidth``.
    public var screenSize: ScreenSize {
        if screenWidth < 768 { return .compact }
        if screenWidth <= 1024 { return .regular }
        return .expanded
    }

    /// Whether the user prefers reduced motion.
    public var prefersReducedMotion: Bool = false

    public init() {}

    /// Start listening for media query changes.
    ///
    /// Call this once during application setup. It reads the initial state
    /// and attaches event listeners for ongoing changes.
    /// On non-WASM platforms this is a no-op.
    public func startListening() {
        #if arch(wasm32)
        // Color scheme
        let darkMql = JSObject.global.matchMedia!("(prefers-color-scheme: dark)")
        colorScheme = darkMql.object!.matches.boolean == true ? .dark : .light

        // Reduced motion
        let motionMql = JSObject.global.matchMedia!("(prefers-reduced-motion: reduce)")
        prefersReducedMotion = motionMql.object!.matches.boolean == true

        // Screen size
        screenWidth = JSObject.global.innerWidth.number ?? 1024
        screenHeight = JSObject.global.innerHeight.number ?? 768

        // Listen for resize events
        let resizeClosure = JSClosure { [weak self] _ in
            self?.screenWidth = JSObject.global.innerWidth.number ?? 1024
            self?.screenHeight = JSObject.global.innerHeight.number ?? 768
            return .undefined
        }
        _ = JSObject.global.addEventListener!("resize", resizeClosure)

        // Listen for color scheme changes
        let schemeClosure = JSClosure { [weak self] args in
            let matches = args[0].object!.matches.boolean == true
            self?.colorScheme = matches ? .dark : .light
            return .undefined
        }
        _ = darkMql.object!.addEventListener!("change", schemeClosure)
        #endif
    }
}
