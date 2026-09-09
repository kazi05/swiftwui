/// The scrollport controlled by a `ScrollReader`.
public enum ScrollContainer: Hashable, Sendable {
    case window
    /// An exact HTML ID within the reader's own logical subtree.
    case element(id: String)
}

/// A fresh layout-scrollport snapshot in CSS pixels.
public struct ScrollMetrics: Equatable, Sendable, Codable {
    public let x: Double
    public let y: Double
    public let viewportWidth: Double
    public let viewportHeight: Double
    public let contentWidth: Double
    public let contentHeight: Double

    public init(x: Double, y: Double, viewportWidth: Double, viewportHeight: Double,
                contentWidth: Double, contentHeight: Double) {
        self.x = x; self.y = y
        self.viewportWidth = viewportWidth; self.viewportHeight = viewportHeight
        self.contentWidth = contentWidth; self.contentHeight = contentHeight
    }

    /// Backend SPI: malformed browser geometry must not become a snapshot.
    public var _isValid: Bool {
        x.isFinite && y.isFinite &&
        viewportWidth.isFinite && viewportWidth >= 0 &&
        viewportHeight.isFinite && viewportHeight >= 0 &&
        contentWidth.isFinite && contentWidth >= 0 &&
        contentHeight.isFinite && contentHeight >= 0
    }
}

/// A message/row identity and its signed offset from the visible scrollport top.
public struct ScrollAnchor: Equatable, Sendable, Codable {
    public let elementID: String
    public let offsetFromVisibleTop: Double

    public init(elementID: String, offsetFromVisibleTop: Double) {
        self.elementID = elementID
        self.offsetFromVisibleTop = offsetFromVisibleTop
    }
}
