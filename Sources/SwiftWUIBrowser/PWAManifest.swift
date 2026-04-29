// PWAManifest.swift - Web App Manifest builder for installable apps.
//
// Browsers fetch `manifest.webmanifest` (linked from `<link rel="manifest">`)
// to decide whether to offer the user "Install this app" UX, what icons
// to use on the home screen, what colour to paint the title bar, and
// how the launcher should display the app (browser tab vs standalone
// vs fullscreen). SwiftWUI surfaces this through a typed builder that
// emits the canonical JSON — apps wire its output into the production
// HTML template or serve it from a Vapor route.

#if !arch(wasm32)
import Foundation
#endif

/// Web App Manifest builder.
///
/// ```swift
/// let manifest = WebAppManifest(
///     name: "SwiftWUI Counter",
///     shortName: "Counter",
///     startURL: "/",
///     display: .standalone,
///     themeColor: "#0a84ff",
///     backgroundColor: "#ffffff",
///     icons: [
///         .init(src: "/icon-192.png", sizes: "192x192", type: "image/png"),
///         .init(src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: .maskable),
///     ]
/// )
/// let json = manifest.json()
/// // serve at /manifest.webmanifest
/// ```
public struct WebAppManifest: Sendable {
    public var name: String
    public var shortName: String?
    public var description: String?
    public var startURL: String
    public var scope: String?
    public var display: DisplayMode
    public var orientation: Orientation?
    public var themeColor: String?
    public var backgroundColor: String?
    public var icons: [Icon]
    public var lang: String?
    public var dir: TextDirection?
    public var categories: [String]

    public enum DisplayMode: String, Sendable {
        case browser
        case minimalUI = "minimal-ui"
        case standalone
        case fullscreen
    }

    public enum Orientation: String, Sendable {
        case any
        case natural
        case landscape
        case portrait
        case portraitPrimary = "portrait-primary"
        case landscapePrimary = "landscape-primary"
    }

    public enum TextDirection: String, Sendable {
        case ltr, rtl, auto
    }

    /// Application icon descriptor. The browser picks the closest size
    /// to whatever surface it is rendering into (home screen, splash,
    /// task switcher, etc).
    public struct Icon: Sendable {
        public var src: String
        public var sizes: String
        public var type: String?
        public var purpose: Purpose?

        public enum Purpose: String, Sendable {
            case any
            /// Icon designed to fit the OS-defined "safe zone" so a
            /// circular or rounded-rectangle mask doesn't clip
            /// important content. Required on Android and iOS PWA
            /// install paths.
            case maskable
            case monochrome
        }

        public init(src: String, sizes: String, type: String? = nil, purpose: Purpose? = nil) {
            self.src = src
            self.sizes = sizes
            self.type = type
            self.purpose = purpose
        }
    }

    public init(
        name: String,
        shortName: String? = nil,
        description: String? = nil,
        startURL: String = "/",
        scope: String? = nil,
        display: DisplayMode = .standalone,
        orientation: Orientation? = nil,
        themeColor: String? = nil,
        backgroundColor: String? = nil,
        icons: [Icon] = [],
        lang: String? = nil,
        dir: TextDirection? = nil,
        categories: [String] = []
    ) {
        self.name = name
        self.shortName = shortName
        self.description = description
        self.startURL = startURL
        self.scope = scope
        self.display = display
        self.orientation = orientation
        self.themeColor = themeColor
        self.backgroundColor = backgroundColor
        self.icons = icons
        self.lang = lang
        self.dir = dir
        self.categories = categories
    }

    /// Render the manifest as a JSON string. Hand-rolled rather than
    /// going through `JSONEncoder` so the implementation stays usable
    /// from Foundation-free builds (Embedded Swift on the long-term
    /// roadmap). Keys are ordered for deterministic output.
    public func json() -> String {
        var pairs: [(String, String)] = []
        pairs.append(("name", quote(name)))
        if let shortName { pairs.append(("short_name", quote(shortName))) }
        if let description { pairs.append(("description", quote(description))) }
        pairs.append(("start_url", quote(startURL)))
        if let scope { pairs.append(("scope", quote(scope))) }
        pairs.append(("display", quote(display.rawValue)))
        if let orientation { pairs.append(("orientation", quote(orientation.rawValue))) }
        if let themeColor { pairs.append(("theme_color", quote(themeColor))) }
        if let backgroundColor { pairs.append(("background_color", quote(backgroundColor))) }
        if !icons.isEmpty {
            pairs.append(("icons", iconsJSON()))
        }
        if let lang { pairs.append(("lang", quote(lang))) }
        if let dir { pairs.append(("dir", quote(dir.rawValue))) }
        if !categories.isEmpty {
            let arr = categories.map(quote).joined(separator: ", ")
            pairs.append(("categories", "[\(arr)]"))
        }

        let body = pairs.map { "\"\($0)\": \($1)" }.joined(separator: ", ")
        return "{\(body)}"
    }

    private func iconsJSON() -> String {
        let arr = icons.map { icon -> String in
            var parts: [(String, String)] = [
                ("src", quote(icon.src)),
                ("sizes", quote(icon.sizes)),
            ]
            if let type = icon.type { parts.append(("type", quote(type))) }
            if let purpose = icon.purpose {
                parts.append(("purpose", quote(purpose.rawValue)))
            }
            let body = parts.map { "\"\($0)\": \($1)" }.joined(separator: ", ")
            return "{\(body)}"
        }.joined(separator: ", ")
        return "[\(arr)]"
    }

    private func quote(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
        return out
    }
}
