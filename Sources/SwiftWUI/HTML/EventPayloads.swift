/// Typed event payloads (spec §6). Decoded ONLY in the backend at fire time
/// (trap T4: never process-global payload slots).
public struct InputEvent  { public let value: String
                            public init(value: String) { self.value = value } }
public struct ChangeEvent { public let value: String; public let checked: Bool
                            public init(value: String, checked: Bool) { self.value = value; self.checked = checked } }

/// Dispatch-local cancellation state shared by copies of a `KeyEvent`.
///
/// The DOM backend owns the token's short lifetime. It deliberately contains no
/// JavaScript event reference, so retaining a copied payload cannot retain a DOM
/// event after the listener returns.
@_spi(DOM)
public final class _KeyEventDispatchToken {
    nonisolated deinit { }

    @_spi(DOM) public private(set) var isCancellationRequested = false
    private var isOpen = true

    @_spi(DOM) public init() {}

    func requestCancellation() {
        guard isOpen else { return }
        isCancellationRequested = true
    }

    @_spi(DOM) public func close() { isOpen = false }
}

public struct KeyEvent {
    public let key: String
    public let repeated: Bool
    public let metaKey: Bool
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    /// Whether the key belongs to an IME composition. The DOM backend also
    /// recognizes the legacy key-code 229 signal when the browser reports it.
    public let isComposing: Bool
    private let dispatchToken: _KeyEventDispatchToken?

    public init(key: String, repeated: Bool,
                metaKey: Bool = false, ctrlKey: Bool = false,
                shiftKey: Bool = false, altKey: Bool = false,
                isComposing: Bool = false) {
        self.init(key: key, repeated: repeated, metaKey: metaKey, ctrlKey: ctrlKey,
                  shiftKey: shiftKey, altKey: altKey, isComposing: isComposing,
                  _dispatchToken: nil)
    }

    @_spi(DOM)
    public init(key: String, repeated: Bool,
                metaKey: Bool = false, ctrlKey: Bool = false,
                shiftKey: Bool = false, altKey: Bool = false,
                isComposing: Bool = false,
                _dispatchToken: _KeyEventDispatchToken?) {
        self.key = key; self.repeated = repeated
        self.metaKey = metaKey; self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey; self.altKey = altKey
        self.isComposing = isComposing
        self.dispatchToken = _dispatchToken
    }

    /// Prevents the browser's default keyboard action when called directly from
    /// the current key-event callback. Calls made after that callback returns,
    /// or on a manually constructed payload, have no effect.
    public func preventDefault() { dispatchToken?.requestCancellation() }

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

/// Element scroll offset (spec §2.2).
public struct ScrollEvent: Equatable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// Element content size, delivered by `onSizeChange` (ResizeObserver).
public struct SizeEvent: Equatable {
    public let width: Double
    public let height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}

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

/// Payload for dragstart/dragend/dragenter/dragover/dragleave (DnD spec §2.2).
public struct DragEvent: Equatable {
    /// `dataTransfer.types` snapshot ("Files" marks an OS-file drag).
    public let types: [String]
    public let hasFiles: Bool
    public let x: Double, y: Double                    // clientX/Y
    /// True when this enter/leave is a crossing between children of the
    /// listening element (`currentTarget.contains(relatedTarget)`); a null
    /// relatedTarget (left the window / Safari) reads as false = a real leave.
    public let isInternalTransition: Bool
    /// currentTarget geometry — lets sortable compute insertion halves
    /// without a backend measure API.
    public let targetWidth: Double, targetHeight: Double
    public let offsetX: Double, offsetY: Double
    public init(types: [String] = [], hasFiles: Bool = false,
                x: Double = 0, y: Double = 0,
                isInternalTransition: Bool = false,
                targetWidth: Double = 0, targetHeight: Double = 0,
                offsetX: Double = 0, offsetY: Double = 0) {
        self.types = types; self.hasFiles = hasFiles; self.x = x; self.y = y
        self.isInternalTransition = isInternalTransition
        self.targetWidth = targetWidth; self.targetHeight = targetHeight
        self.offsetX = offsetX; self.offsetY = offsetY
    }
}

/// Payload for `drop`. `files` from `dataTransfer.files`; `strings` maps each
/// non-file content type to its `getData` body. Inbound bodies are UNTRUSTED.
public struct DropEvent {
    public let files: [WebFile]
    public let strings: [String: String]
    public let x: Double, y: Double
    public init(files: [WebFile] = [], strings: [String: String] = [:],
                x: Double = 0, y: Double = 0) {
        self.files = files; self.strings = strings; self.x = x; self.y = y
    }
}

/// Drop point in client coordinates (SwiftUI's CGPoint analog).
public struct DropLocation: Equatable {
    public let x: Double, y: Double
    public init(x: Double = 0, y: Double = 0) { self.x = x; self.y = y }
}
