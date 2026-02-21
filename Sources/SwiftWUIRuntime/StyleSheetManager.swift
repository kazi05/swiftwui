// StyleSheetManager.swift - Manages responsive CSS rules via <style> injection

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import SwiftWUICore

/// Manages a `<style>` element for responsive CSS rules.
///
/// When the DOMRenderer encounters `responsiveStyles` on a TagNode element,
/// it calls `ensureClass()` to get a CSS class name. The manager generates
/// the class deterministically (via FNV-1a hash) and injects the `@media`
/// rule into the `<style>` tag if it hasn't been registered yet.
public final class StyleSheetManager {

    #if canImport(JavaScriptKit)
    private let bridge: DOMBridge?
    private var styleElement: JSObject?
    #endif

    /// Tracks registered CSS class names to avoid duplicate rule injection.
    private var registeredRules: Set<String> = []

    #if canImport(JavaScriptKit)
    public init(bridge: DOMBridge) {
        self.bridge = bridge
    }
    #endif

    /// No-argument initializer for non-WASM environments and testing.
    public init() {
        #if canImport(JavaScriptKit)
        self.bridge = nil
        #endif
    }

    /// Ensure a CSS class exists for the given responsive style.
    ///
    /// If the class has already been registered, returns the same name without
    /// injecting a duplicate rule. Otherwise, generates the CSS rule and appends
    /// it to the `<style>` element.
    ///
    /// - Parameters:
    ///   - mediaQuery: The CSS `@media` query string.
    ///   - styles: The CSS property-value declarations.
    /// - Returns: The CSS class name to apply to the DOM element.
    public func ensureClass(mediaQuery: String, styles: [String: String]) -> String {
        let className = responsiveClassName(mediaQuery: mediaQuery, styles: styles)

        guard !registeredRules.contains(className) else {
            return className
        }

        registeredRules.insert(className)

        let declarations = styles
            .sorted(by: { $0.key < $1.key })
            .map { "  \($0.key): \($0.value) !important;" }
            .joined(separator: "\n")
        let rule = "\(mediaQuery) {\n  .\(className) {\n\(declarations)\n  }\n}"

        #if canImport(JavaScriptKit)
        if let bridge {
            if styleElement == nil {
                styleElement = bridge.getOrCreateStyleElement(id: "swiftwui-responsive")
            }
            bridge.appendCSSRule(styleElement!, rule: rule)
        }
        #endif

        return className
    }

    /// Generate the CSS rule text for a responsive class (for testing/inspection).
    public func cssRuleText(mediaQuery: String, styles: [String: String]) -> String {
        let className = responsiveClassName(mediaQuery: mediaQuery, styles: styles)
        let declarations = styles
            .sorted(by: { $0.key < $1.key })
            .map { "  \($0.key): \($0.value) !important;" }
            .joined(separator: "\n")
        return "\(mediaQuery) {\n  .\(className) {\n\(declarations)\n  }\n}"
    }
}
