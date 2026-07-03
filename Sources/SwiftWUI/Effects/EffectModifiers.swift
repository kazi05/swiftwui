struct _OnChangeEffect<V: Equatable, Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let value: V
    let initial: Bool
    let action: (V, V) -> Void
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)   // canonical snapshot keys need the name (spec D7)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        let act = action
        ctx.effects.append(.onChange(
            id: id, newValue: value,
            isEqual: { ($0 as? V) == ($1 as? V) },
            initial: initial,
            action: { old, new in act(old as! V, new as! V) }))
        return resolve(content, path: id, ctx: &ctx)
    }
}

struct _TaskEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let taskID: AnyHashable?
    let action: () async -> Void
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)   // canonical snapshot keys need the name (spec D7)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.effects.append(.task(id: id, taskID: taskID, action: action))
        return resolve(content, path: id, ctx: &ctx)
    }
}

struct _AppearEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let onAppear: (() -> Void)?
    let onDisappear: (() -> Void)?
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)   // canonical snapshot keys need the name (spec D7)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        if let onAppear { ctx.effects.append(.appear(id: id, action: onAppear)) }
        if let onDisappear { ctx.effects.append(.disappear(id: id, action: onDisappear)) }
        return resolve(content, path: id, ctx: &ctx)
    }
}

extension Tag {
    public func onChange<V: Equatable>(of value: V, initial: Bool = false,
                                       _ action: @escaping (V, V) -> Void) -> some Tag {
        _OnChangeEffect(value: value, initial: initial, action: action, content: self)
    }
    /// The action runs on the main actor's executor; writes to @Observable
    /// models from detached/background tasks trap in Observation's onChange
    /// (all state writes must be main-actor).
    public func task(_ action: @escaping () async -> Void) -> some Tag {
        _TaskEffect(taskID: nil, action: action, content: self)
    }
    public func task<ID: Hashable>(id: ID, _ action: @escaping () async -> Void) -> some Tag {
        _TaskEffect(taskID: AnyHashable(id), action: action, content: self)
    }
    public func onAppear(_ action: @escaping () -> Void) -> some Tag {
        _AppearEffect(onAppear: action, onDisappear: nil, content: self)
    }
    public func onDisappear(_ action: @escaping () -> Void) -> some Tag {
        _AppearEffect(onAppear: nil, onDisappear: action, content: self)
    }
}
