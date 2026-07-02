public struct ListenerID: Hashable {
    public let owner: NodeIdentity
    public let event: String
    public init(owner: NodeIdentity, event: String) { self.owner = owner; self.event = event }
}

public struct ElementNode: Equatable {
    public var identity: NodeIdentity
    public var tag: String
    public var attributes: [String: String]
    public var listeners: [String: ListenerID]
    public var children: [Node]
    public var key: NodeKey?
}

public struct ComponentNode: Equatable {
    public let identity: NodeIdentity
    public let typeName: String
    public var key: NodeKey?
    public var children: [Node]
}

public enum Node: Equatable {
    case text(String)
    case element(ElementNode)
    case component(ComponentNode)

    var key: NodeKey? {
        get {
            switch self {
            case .text: return nil
            case .element(let e): return e.key
            case .component(let c): return c.key
            }
        }
        set {
            switch self {
            case .text(let t):
                // Wrap text in synthetic element to support keying (ForEach requires keys on all nodes)
                self = .element(ElementNode(identity: .root, tag: "__text", attributes: [:], listeners: [:], children: [.text(t)], key: newValue))
            case .element(var e): e.key = newValue; self = .element(e)
            case .component(var c): c.key = newValue; self = .component(c)
            }
        }
    }
}
