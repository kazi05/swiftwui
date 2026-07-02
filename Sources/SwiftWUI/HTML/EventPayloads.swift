/// Typed event payloads (spec §6). Decoded ONLY in the backend at fire time
/// (trap T4: never process-global payload slots).
public struct InputEvent  { public let value: String
                            public init(value: String) { self.value = value } }
public struct ChangeEvent { public let value: String; public let checked: Bool
                            public init(value: String, checked: Bool) { self.value = value; self.checked = checked } }
public struct KeyEvent    { public let key: String; public let repeated: Bool
                            public init(key: String, repeated: Bool) { self.key = key; self.repeated = repeated } }
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
        case let e as GenericEvent: self.init(type: type, targetValue: e.targetValue, key: e.key, checked: e.checked)
        default:                    self.init(type: type, targetValue: nil, key: nil, checked: nil)
        }
    }
}
