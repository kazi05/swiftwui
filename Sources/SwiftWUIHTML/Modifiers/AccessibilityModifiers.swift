// AccessibilityModifiers.swift - First-class ARIA / a11y modifiers.
//
// Typed wrappers over `.attribute()` so call sites stay readable, the
// allowed values are constrained at compile time, and the modifier
// namespace mirrors SwiftUI's `.accessibilityLabel` family for muscle
// memory.

import SwiftWUICore

/// ARIA roles, restricted to the most common values application code
/// reaches for. The full ARIA 1.2 vocabulary is large; this enum covers
/// the production-relevant subset and falls back to `.attribute("role", …)`
/// for anything exotic.
public enum ARIARole: String, Sendable {
    case alert
    case alertdialog
    case button
    case checkbox
    case dialog
    case heading
    case img
    case link
    case list
    case listbox
    case listitem
    case main
    case menu
    case menuitem
    case nav = "navigation"
    case option
    case progressbar
    case radio
    case region
    case search
    case slider
    case status
    case switchRole = "switch"
    case tab
    case tablist
    case tabpanel
    case textbox
    case timer
    case toolbar
    case tooltip
}

/// Politeness level for live region announcements.
public enum ARIALive: String, Sendable {
    case off
    case polite
    case assertive
}

extension HTMLTag {
    /// Set the accessible name read by screen readers. Equivalent to
    /// `aria-label`. Use when the visible text isn't sufficient.
    public func accessibilityLabel(_ label: String) -> Self {
        attribute("aria-label", label)
    }

    /// Provide an accessibility hint — supplementary description of what
    /// activating the element will do. Maps to `aria-description` (newer)
    /// with a `aria-describedby` fallback strategy left to the renderer.
    public func accessibilityHint(_ hint: String) -> Self {
        attribute("aria-description", hint)
    }

    /// Hide the element from assistive technology entirely.
    public func accessibilityHidden(_ hidden: Bool = true) -> Self {
        attribute("aria-hidden", hidden ? "true" : "false")
    }

    /// Identify the kind of widget this element represents to AT.
    public func accessibilityRole(_ role: ARIARole) -> Self {
        attribute("role", role.rawValue)
    }

    /// Mark the element as a live region whose updates AT should announce.
    /// `.polite` waits for the user to finish the current task; `.assertive`
    /// interrupts. Use `.assertive` sparingly — it is intrusive.
    public func accessibilityLive(_ politeness: ARIALive) -> Self {
        attribute("aria-live", politeness.rawValue)
    }

    // MARK: - Lower-level `.aria(...)` namespace

    /// Generic ARIA helpers for less-common attributes. These are the
    /// type-safe escape hatch when an app needs `aria-*` attributes the
    /// curated `.accessibility…` modifiers above do not cover.
    public func aria(label: String) -> Self { attribute("aria-label", label) }
    public func aria(hint: String) -> Self { attribute("aria-description", hint) }
    public func aria(hidden: Bool) -> Self { attribute("aria-hidden", hidden ? "true" : "false") }
    public func aria(role: ARIARole) -> Self { attribute("role", role.rawValue) }
    public func aria(live: ARIALive) -> Self { attribute("aria-live", live.rawValue) }
    public func aria(invalid: Bool) -> Self { attribute("aria-invalid", invalid ? "true" : "false") }
    public func aria(busy: Bool) -> Self { attribute("aria-busy", busy ? "true" : "false") }
    public func aria(expanded: Bool) -> Self { attribute("aria-expanded", expanded ? "true" : "false") }
    public func aria(selected: Bool) -> Self { attribute("aria-selected", selected ? "true" : "false") }
    public func aria(pressed: Bool) -> Self { attribute("aria-pressed", pressed ? "true" : "false") }
    public func aria(controls id: String) -> Self { attribute("aria-controls", id) }
    public func aria(describedby id: String) -> Self { attribute("aria-describedby", id) }
    public func aria(labelledby id: String) -> Self { attribute("aria-labelledby", id) }
    public func aria(current: String) -> Self { attribute("aria-current", current) }
}

// Internal `attribute(_:_:)` helper, mirrors what `ModifiedContent` exposes.
extension HTMLTag {
    fileprivate func attribute(_ name: String, _ value: String) -> Self {
        var copy = self
        copy.attributes[name] = value
        return copy
    }
}
