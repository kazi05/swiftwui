// BrowserEnvironment.swift - EnvironmentValues extensions for browser APIs

import SwiftWUIState

/// Environment key for the user's preferred colour scheme.
struct ColorSchemeKey: EnvironmentKey {
    public static var defaultValue: ColorScheme { .light }
}

/// Environment key for the current screen size category.
struct ScreenSizeKey: EnvironmentKey {
    public static var defaultValue: ScreenSize { .regular }
}

/// Environment key for the reduced motion preference.
struct PrefersReducedMotionKey: EnvironmentKey {
    public static var defaultValue: Bool { false }
}

extension EnvironmentValues {
    /// The user's preferred colour scheme.
    public var colorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }

    /// The current screen size category.
    public var screenSize: ScreenSize {
        get { self[ScreenSizeKey.self] }
        set { self[ScreenSizeKey.self] = newValue }
    }

    /// Whether the user prefers reduced motion.
    public var prefersReducedMotion: Bool {
        get { self[PrefersReducedMotionKey.self] }
        set { self[PrefersReducedMotionKey.self] = newValue }
    }
}
