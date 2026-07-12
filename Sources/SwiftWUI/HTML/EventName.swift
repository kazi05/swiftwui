public struct EventName: RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public static let click: EventName = "click"
    public static let input: EventName = "input"
    public static let change: EventName = "change"
    public static let keydown: EventName = "keydown"
    public static let keyup: EventName = "keyup"
    public static let submit: EventName = "submit"
    public static let focus: EventName = "focus"
    public static let blur: EventName = "blur"
    public static let dblclick: EventName = "dblclick"
    public static let mouseenter: EventName = "mouseenter"
    public static let mouseleave: EventName = "mouseleave"
    public static let pointerdown: EventName = "pointerdown"
    public static let pointerup: EventName = "pointerup"
    public static let pointercancel: EventName = "pointercancel"
    public static let pointerleave: EventName = "pointerleave"
    public static let scroll: EventName = "scroll"
}
