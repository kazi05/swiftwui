/// An ordered description of the property-wrapper storage a component wants
/// the runtime to link. This is the reflection-free compatibility path; types
/// that do not conform continue to use Mirror exactly as before.
public struct ComponentProperties {
    var stateProperties: [any _StateProperty] = []
    var stateStableIDs: [String?] = []
    var environmentProperties: [any _EnvironmentProperty] = []

    public init() {}

    public mutating func state<Value>(_ property: State<Value>) {
        stateProperties.append(property)
        stateStableIDs.append(nil)
    }

    /// Registers a state slot by a source-stable identifier. When every state
    /// property uses this form, snapshots survive declaration reordering and
    /// can adopt added or removed slots independently.
    public mutating func state<Value>(_ property: State<Value>, stableID: String) {
        precondition(!stableID.isEmpty,
                     "Explicit state stableID must not be empty")
        stateProperties.append(property)
        stateStableIDs.append(stableID)
    }

    public mutating func environment(_ property: any _EnvironmentProperty) {
        environmentProperties.append(property)
    }

    var completeStateStableIDs: [String]? {
        guard stateStableIDs.contains(where: { $0 != nil }) else { return nil }
        precondition(stateStableIDs.allSatisfy { $0 != nil },
                     "Use stableID for every state property in an explicit registration")
        let ids = stateStableIDs.map { $0! }
        precondition(Set(ids).count == ids.count,
                     "Explicit state stableIDs must be unique within a component")
        return ids
    }
}

/// Opt-in component registration for clients that need stable cross-binary
/// hydration identities or want to remove Mirror from the hot linking path.
/// State properties must be registered in declaration order to preserve the
/// existing snapshot slot format.
public protocol ExplicitComponentRegistration {
    static var componentIdentifier: String { get }
    @MainActor func registerProperties(_ properties: inout ComponentProperties)
}
