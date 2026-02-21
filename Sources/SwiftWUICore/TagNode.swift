// TagNode.swift - Virtual DOM node representation

/// Represents a virtual DOM node used for diffing and rendering.
/// This is the intermediate representation between the Tag tree and the real DOM.
public enum TagNode: Equatable, Sendable {
    case element(Element)
    case text(String)
    case fragment([TagNode])

    /// A virtual DOM element node.
    public struct Element: Equatable, Sendable {
        public var tagName: String
        public var attributes: [String: String]
        public var styles: [String: String]
        public var classes: [String]
        public var eventListeners: [String: EventListenerID]
        public var children: [TagNode]
        /// Responsive CSS styles. Key = CSS media query string, Value = style declarations.
        public var responsiveStyles: [String: [String: String]]

        public init(
            tagName: String,
            attributes: [String: String] = [:],
            styles: [String: String] = [:],
            classes: [String] = [],
            eventListeners: [String: EventListenerID] = [:],
            children: [TagNode] = [],
            responsiveStyles: [String: [String: String]] = [:]
        ) {
            self.tagName = tagName
            self.attributes = attributes
            self.styles = styles
            self.classes = classes
            self.eventListeners = eventListeners
            self.children = children
            self.responsiveStyles = responsiveStyles
        }
    }
}

/// Unique identifier for event listeners.
/// Used to track and compare event listeners across renders.
public struct EventListenerID: Equatable, Hashable, Sendable {
    public let id: String

    public init(_ id: String) {
        self.id = id
    }
}
