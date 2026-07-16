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
    let policy: TaskPolicy
    let action: () async -> Void
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)   // canonical snapshot keys need the name (spec D7)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.effects.append(.task(id: id, taskID: taskID, policy: policy, action: action))
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
    public func task(policy: TaskPolicy = .client, _ action: @escaping () async -> Void) -> some Tag {
        _TaskEffect(taskID: nil, policy: policy, action: action, content: self)
    }
    public func task<ID: Hashable>(id: ID, policy: TaskPolicy = .client,
                                   _ action: @escaping () async -> Void) -> some Tag {
        _TaskEffect(taskID: AnyHashable(id), policy: policy, action: action, content: self)
    }
    /// Build-time loader (spec §6, D5): runs during SSG and is awaited before the
    /// HTML is taken; its @State writes ship in the snapshot. On a hydrated client
    /// it is skipped (the snapshot's "tasks" list covers it); on a cold client it
    /// runs like a normal task.
    public func staticTask(_ action: @escaping () async -> Void) -> some Tag {
        _TaskEffect(taskID: nil, policy: .build, action: action, content: self)
    }
    public func onAppear(_ action: @escaping () -> Void) -> some Tag {
        _AppearEffect(onAppear: action, onDisappear: nil, content: self)
    }
    public func onDisappear(_ action: @escaping () -> Void) -> some Tag {
        _AppearEffect(onAppear: nil, onDisappear: action, content: self)
    }
}

struct _DropGuardEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.effects.append(.dropGuard(id: id))
        return resolve(content, path: id, ctx: &ctx)
    }
}

extension Tag {
    /// While mounted anywhere in the tree: a file dropped OUTSIDE any drop
    /// zone no longer navigates the tab away (the classic DnD-app footgun).
    /// Drops inside `data-swui-drop-accepts` zones are untouched.
    public func preventsAccidentalDropNavigation() -> some Tag {
        _DropGuardEffect(content: self)
    }
}
