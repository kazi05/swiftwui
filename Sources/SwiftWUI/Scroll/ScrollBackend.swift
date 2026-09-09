/// Backend SPI: resolved scrollport. An unavailable element is never represented as a window.
public enum _ScrollTarget<Host> {
    case window
    case element(Host)
}

/// Backend SPI: the chosen index in the supplied candidates and its visible-top offset.
public struct _ScrollAnchorGeometry {
    public let index: Int
    public let offsetFromVisibleTop: Double

    public init(index: Int, offsetFromVisibleTop: Double) {
        self.index = index; self.offsetFromVisibleTop = offsetFromVisibleTop
    }
}
