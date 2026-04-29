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
        /// Web API observers (resize, intersection, mutation, lifecycle) attached to this element.
        public var observers: [WebObserver]
        /// Reconciliation key. When set, the reconciler matches old/new
        /// children by `key` rather than by index, preserving DOM nodes
        /// (and their state-bearing JSObject identity / @State storage)
        /// across reorders, insertions, and removals. `ForEach` propagates
        /// `Identifiable.id` here. `nil` means "use positional diff".
        ///
        /// Distinct from the `data-swiftwui-id` attribute (set by `.id(_:)`),
        /// which forces a *replacement* on change. `key` is the opposite:
        /// matching keys preserve, missing keys remove, new keys insert.
        public var key: String?

        public init(
            tagName: String,
            attributes: [String: String] = [:],
            styles: [String: String] = [:],
            classes: [String] = [],
            eventListeners: [String: EventListenerID] = [:],
            children: [TagNode] = [],
            responsiveStyles: [String: [String: String]] = [:],
            observers: [WebObserver] = [],
            key: String? = nil
        ) {
            self.tagName = tagName
            self.attributes = attributes
            self.styles = styles
            self.classes = classes
            self.eventListeners = eventListeners
            self.children = children
            self.responsiveStyles = responsiveStyles
            self.observers = observers
            self.key = key
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
