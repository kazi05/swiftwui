/// Typed event payloads (spec §6). Decoded ONLY in the backend at fire time
/// (trap T4: never process-global payload slots).
public struct InputEvent  { public let value: String
                            public init(value: String) { self.value = value } }
public struct ChangeEvent { public let value: String; public let checked: Bool
                            public init(value: String, checked: Bool) { self.value = value; self.checked = checked } }
public struct KeyEvent {
    public let key: String
    public let repeated: Bool
    public let metaKey: Bool
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    public init(key: String, repeated: Bool,
                metaKey: Bool = false, ctrlKey: Bool = false,
                shiftKey: Bool = false, altKey: Bool = false) {
        self.key = key; self.repeated = repeated
        self.metaKey = metaKey; self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey; self.altKey = altKey
    }
    public var modifiers: EventModifiers {
        var m: EventModifiers = []
        if metaKey { m.insert(.meta) }
        if ctrlKey { m.insert(.ctrl) }
        if shiftKey { m.insert(.shift) }
        if altKey { m.insert(.alt) }
        return m
    }
}

/// DOM KeyboardEvent.key values, SwiftUI-KeyEquivalent style.
public struct KeyEquivalent: Equatable, ExpressibleByStringLiteral {
    public let key: String
    public init(key: String) { self.key = key }
    public init(stringLiteral value: String) { key = value }
    public static let enter = KeyEquivalent(key: "Enter")
    public static let escape = KeyEquivalent(key: "Escape")
    public static let space = KeyEquivalent(key: " ")
    public static let tab = KeyEquivalent(key: "Tab")
    public static let delete = KeyEquivalent(key: "Backspace")
    public static let upArrow = KeyEquivalent(key: "ArrowUp")
    public static let downArrow = KeyEquivalent(key: "ArrowDown")
    public static let leftArrow = KeyEquivalent(key: "ArrowLeft")
    public static let rightArrow = KeyEquivalent(key: "ArrowRight")
}

public struct EventModifiers: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let meta  = EventModifiers(rawValue: 1 << 0)
    public static let ctrl  = EventModifiers(rawValue: 1 << 1)
    public static let shift = EventModifiers(rawValue: 1 << 2)
    public static let alt   = EventModifiers(rawValue: 1 << 3)
}

public struct SubmitEvent { public init() {} }   // backend always preventDefault()s submit (spec D10)
public struct FocusEvent  { public init() {} }

/// Escape-hatch payload for `.on(_:perform:)` — common fields of any event.
public struct GenericEvent {
    public let type: String
    public let targetValue: String?
    public let key: String?
    public let checked: Bool?
    public init(type: String, targetValue: String?, key: String?, checked: Bool?) {
        self.type = type; self.targetValue = targetValue; self.key = key; self.checked = checked
    }
    /// Adapts whatever typed payload arrived for `type` into the generic shape.
    init(type: String, payload: Any?) {
        switch payload {
        case let e as InputEvent:   self.init(type: type, targetValue: e.value, key: nil, checked: nil)
        case let e as ChangeEvent:  self.init(type: type, targetValue: e.value, key: nil, checked: e.checked)
        case let e as KeyEvent:     self.init(type: type, targetValue: nil, key: e.key, checked: nil)
        case let e as ClickEvent:   self.init(type: type, targetValue: e.targetValue, key: nil, checked: e.checked)
        case let e as GenericEvent: self.init(type: type, targetValue: e.targetValue, key: e.key, checked: e.checked)
        default:                    self.init(type: type, targetValue: nil, key: nil, checked: nil)
        }
    }
}

/// Click payload (phase 4, spec §8). Carries what Link needs to decide
/// whether the browser should keep default anchor behavior.
public struct ClickEvent {
    public let button: Int
    public let metaKey: Bool
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    /// target.value / target.checked at fire time (nil for non-form targets).
    /// Filled by DOMBackend's decoder so `.on(.click)` GenericEvent adapters
    /// stop dropping them (phase-4 carry).
    public let targetValue: String?
    public let checked: Bool?
    public init(button: Int = 0, metaKey: Bool = false, ctrlKey: Bool = false,
                shiftKey: Bool = false, altKey: Bool = false,
                targetValue: String? = nil, checked: Bool? = nil) {
        self.button = button; self.metaKey = metaKey; self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey; self.altKey = altKey
        self.targetValue = targetValue; self.checked = checked
    }
    /// True → new-tab/context intent; SPA must not intercept.
    public var isModified: Bool { button != 0 || metaKey || ctrlKey || shiftKey || altKey }
}
