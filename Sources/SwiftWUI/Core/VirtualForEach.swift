public enum VirtualCollectionMode: Equatable, Sendable {
    /// Render the visible fixed-height window plus overscan. The initial server
    /// and client render includes `initialItemCount` leading rows for useful
    /// no-JavaScript content and one-to-one adoption.
    case windowed
    /// Render every row. Prefer this for small collections where full browser
    /// find-in-page and assistive-technology traversal matter more than DOM size.
    case complete
}

private struct _VirtualEntry<Element, ID: Hashable>: Identifiable {
    let id: ID
    let element: Element
}

/// A fixed-height, vertically scrolling collection with stable keyed rows.
/// Variable-height content is intentionally unsupported because spacer math
/// cannot preserve scroll position without browser measurement and correction.
public struct VirtualForEach<Data: RandomAccessCollection, ID: Hashable, Content: Tag>: Tag {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let rowHeight: Double
    private let viewportHeight: Double
    private let overscan: Int
    private let initialItemCount: Int
    private let mode: VirtualCollectionMode
    private let accessibilityLabel: String?
    private let content: @MainActor (Data.Element) -> Content

    @State private var scrollY = 0.0
    @State private var hasScrolled = false

    public init(_ data: Data, id: KeyPath<Data.Element, ID>,
                rowHeight: Double, viewportHeight: Double,
                overscan: Int = 3, initialItemCount: Int = 20,
                mode: VirtualCollectionMode = .windowed,
                accessibilityLabel: String? = nil,
                @TagBuilder content: @escaping @MainActor (Data.Element) -> Content) {
        precondition(rowHeight > 0 && rowHeight.isFinite,
                     "VirtualForEach rowHeight must be finite and greater than zero")
        precondition(viewportHeight > 0 && viewportHeight.isFinite,
                     "VirtualForEach viewportHeight must be finite and greater than zero")
        self.data = data
        self.id = id
        self.rowHeight = rowHeight
        self.viewportHeight = viewportHeight
        self.overscan = max(0, overscan)
        self.initialItemCount = max(0, initialItemCount)
        self.mode = mode
        self.accessibilityLabel = accessibilityLabel
        self.content = content
    }

    public var body: some Tag {
        let count = data.count
        let boundedY = scrollY.isFinite
            ? min(max(0, scrollY), Double(count) * rowHeight)
            : 0
        let firstVisible = min(count, Int(boundedY / rowHeight))
        let start: Int
        let end: Int
        switch mode {
        case .complete:
            start = 0
            end = count
        case .windowed:
            start = max(0, firstVisible - overscan)
            let visibleBoundary = min(Double(count),
                                      ((boundedY + viewportHeight) / rowHeight).rounded(.up))
            let visibleEnd = min(count, Int(visibleBoundary) + overscan)
            end = hasScrolled ? visibleEnd : min(count, max(visibleEnd, initialItemCount))
        }

        var entries: [_VirtualEntry<Data.Element, ID>] = []
        entries.reserveCapacity(max(0, end - start))
        if start < end {
            var index = data.index(data.startIndex, offsetBy: start)
            for _ in start..<end {
                let element = data[index]
                entries.append(_VirtualEntry(id: element[keyPath: id], element: element))
                data.formIndex(after: &index)
            }
        }

        return Div {
            Div().height(.px(Double(start) * rowHeight)).attribute("aria-hidden", "true")
            ForEach(entries) { entry in
                Div { content(entry.element) }.height(.px(rowHeight))
            }
            Div().height(.px(Double(count - end) * rowHeight)).attribute("aria-hidden", "true")
        }
        .height(.px(viewportHeight))
        .overflowY(.auto)
        .attribute("tabindex", "0")
        .attribute("aria-label", accessibilityLabel)
        .onScrollChange { event in
            scrollY = event.y
            hasScrolled = true
        }
    }
}

extension VirtualForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data,
                rowHeight: Double, viewportHeight: Double,
                overscan: Int = 3, initialItemCount: Int = 20,
                mode: VirtualCollectionMode = .windowed,
                accessibilityLabel: String? = nil,
                @TagBuilder content: @escaping @MainActor (Data.Element) -> Content) {
        self.init(data, id: \.id, rowHeight: rowHeight,
                  viewportHeight: viewportHeight, overscan: overscan,
                  initialItemCount: initialItemCount, mode: mode,
                  accessibilityLabel: accessibilityLabel, content: content)
    }
}
