/// Why a coalesced render was scheduled. Multiple reasons may be present when
/// several writes land before the same microtask flush.
public enum RuntimeRenderReason: Equatable {
    case mount
    case dependency(NodeIdentity)
    case navigation(path: String, isHistory: Bool)
}

public struct RuntimeTreeStatistics: Equatable {
    public let components: Int
    public let elements: Int
    public let textNodes: Int

    public init(components: Int, elements: Int, textNodes: Int) {
        self.components = components
        self.elements = elements
        self.textNodes = textNodes
    }
}

/// One component in a pre-order snapshot of the committed component tree.
/// Text and element payloads are intentionally excluded, so diagnostics expose
/// structure without copying rendered content or attribute values.
public struct RuntimeComponentTreeEntry: Equatable {
    public let identity: NodeIdentity
    public let typeName: String
    public let parentIdentity: NodeIdentity?

    public init(identity: NodeIdentity, typeName: String,
                parentIdentity: NodeIdentity?) {
        self.identity = identity
        self.typeName = typeName
        self.parentIdentity = parentIdentity
    }
}

public struct RuntimeLifetimeCounts: Equatable {
    public let stateRows: Int
    public let retainedComponents: Int
    public let listeners: Int
    public let effects: Int
    public let animationValues: Int
    public let transitions: Int
    public let mountedComponents: Int

    public init(stateRows: Int, retainedComponents: Int, listeners: Int,
                effects: Int, animationValues: Int, transitions: Int,
                mountedComponents: Int) {
        self.stateRows = stateRows
        self.retainedComponents = retainedComponents
        self.listeners = listeners
        self.effects = effects
        self.animationValues = animationValues
        self.transitions = transitions
        self.mountedComponents = mountedComponents
    }
}

public struct RuntimeRenderDiagnostic: Equatable {
    public enum Kind: Equatable { case mount, update }

    public let kind: Kind
    public let reasons: [RuntimeRenderReason]
    public let dirtyIdentityCount: Int
    public let coveredRootCount: Int
    public let passCount: Int
    public let duration: Duration
    public let lifetimes: RuntimeLifetimeCounts
    public let tree: RuntimeTreeStatistics?
    public let componentTree: [RuntimeComponentTreeEntry]?
}

public struct RuntimeAdoptionDiagnostic: Equatable {
    public enum Outcome: Equatable { case succeeded, toleratedTrailingNodes(Int), failed }
    public let outcome: Outcome
    public let consumedNodes: Int
    public let availableNodes: Int
    public let message: String?

    public init(outcome: Outcome, consumedNodes: Int, availableNodes: Int,
                message: String? = nil) {
        self.outcome = outcome
        self.consumedNodes = consumedNodes
        self.availableNodes = availableNodes
        self.message = message
    }
}

public enum RuntimeDiagnosticEvent: Equatable {
    case render(RuntimeRenderDiagnostic)
    case adoption(RuntimeAdoptionDiagnostic)
}

/// A Swift-only, opt-in event sink. When absent, the render loop performs no
/// timing, tree traversal, event allocation, or JavaScript bridge call.
public struct RuntimeDiagnostics {
    public let includeTreeStatistics: Bool
    public let includeComponentTree: Bool
    private let receive: @MainActor (RuntimeDiagnosticEvent) -> Void

    public init(includeTreeStatistics: Bool = false,
                includeComponentTree: Bool = false,
                receive: @escaping @MainActor (RuntimeDiagnosticEvent) -> Void) {
        self.includeTreeStatistics = includeTreeStatistics
        self.includeComponentTree = includeComponentTree
        self.receive = receive
    }

    @MainActor func emit(_ event: RuntimeDiagnosticEvent) { receive(event) }
}

func runtimeComponentTree(_ node: Node) -> [RuntimeComponentTreeEntry] {
    var entries: [RuntimeComponentTreeEntry] = []
    func visit(_ node: Node, parent: NodeIdentity?) {
        switch node {
        case .text:
            break
        case .element(let element):
            for child in element.children { visit(child, parent: parent) }
        case .component(let component):
            entries.append(RuntimeComponentTreeEntry(
                identity: component.identity,
                typeName: component.typeName,
                parentIdentity: parent
            ))
            for child in component.children { visit(child, parent: component.identity) }
        }
    }
    visit(node, parent: nil)
    return entries
}

func runtimeTreeStatistics(_ node: Node) -> RuntimeTreeStatistics {
    switch node {
    case .text:
        return RuntimeTreeStatistics(components: 0, elements: 0, textNodes: 1)
    case .element(let element):
        return element.children.reduce(into: RuntimeTreeStatistics(components: 0, elements: 1, textNodes: 0)) {
            let child = runtimeTreeStatistics($1)
            $0 = RuntimeTreeStatistics(components: $0.components + child.components,
                                       elements: $0.elements + child.elements,
                                       textNodes: $0.textNodes + child.textNodes)
        }
    case .component(let component):
        return component.children.reduce(into: RuntimeTreeStatistics(components: 1, elements: 0, textNodes: 0)) {
            let child = runtimeTreeStatistics($1)
            $0 = RuntimeTreeStatistics(components: $0.components + child.components,
                                       elements: $0.elements + child.elements,
                                       textNodes: $0.textNodes + child.textNodes)
        }
    }
}
