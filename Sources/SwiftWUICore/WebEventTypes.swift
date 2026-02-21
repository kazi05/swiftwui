/// Scroll position of an element.
public struct ScrollOffset: Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Size of a DOM element (from ResizeObserver).
public struct ElementSize: Sendable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Bounding rectangle of a DOM element (from getBoundingClientRect).
public struct ElementRect: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Keyboard event information.
public struct KeyInfo: Sendable, Equatable {
    public let key: String
    public let code: String
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    public let metaKey: Bool

    public init(key: String, code: String, ctrlKey: Bool, shiftKey: Bool, altKey: Bool, metaKey: Bool) {
        self.key = key
        self.code = code
        self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey
        self.altKey = altKey
        self.metaKey = metaKey
    }
}
