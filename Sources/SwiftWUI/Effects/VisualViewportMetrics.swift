public struct VisualViewportMetrics: Equatable, Sendable, Codable {
    public let width: Double
    public let height: Double
    public let offsetTop: Double
    public let offsetLeft: Double
    public let scale: Double
    public let layoutViewportHeight: Double

    public init(width: Double, height: Double, offsetTop: Double,
                offsetLeft: Double, scale: Double, layoutViewportHeight: Double) {
        self.width = width
        self.height = height
        self.offsetTop = offsetTop
        self.offsetLeft = offsetLeft
        self.scale = scale
        self.layoutViewportHeight = layoutViewportHeight
    }
}
