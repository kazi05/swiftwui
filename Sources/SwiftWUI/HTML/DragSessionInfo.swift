/// Window-level drag state: is anything being dragged over the page right
/// now (including OS files, which never fire dragstart in-page). Feeds
/// `@Environment(\.dragSession)`; `.none` outside a live runtime.
public struct DragSessionInfo: Equatable, Sendable {
    public let isActive: Bool
    public let hasFiles: Bool
    public let types: [String]
    public init(isActive: Bool, hasFiles: Bool, types: [String]) {
        self.isActive = isActive; self.hasFiles = hasFiles; self.types = types
    }
    public static let none = DragSessionInfo(isActive: false, hasFiles: false, types: [])
}
