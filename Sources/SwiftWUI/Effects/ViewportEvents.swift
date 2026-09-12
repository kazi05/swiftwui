struct _DocumentVisibilityEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let initial: Bool
    let action: (Bool) -> Void
    let content: Content

    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.effects.append(.documentVisibility(id: id, initial: initial, action: action))
        return resolve(content, path: id, ctx: &ctx)
    }
}

struct _VisualViewportEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let initial: Bool
    let action: (VisualViewportMetrics) -> Void
    let content: Content

    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.effects.append(.visualViewport(id: id, initial: initial, action: action))
        return resolve(content, path: id, ctx: &ctx)
    }
}

extension Tag {
    public func onDocumentVisibilityChange(initial: Bool = true,
                                           _ action: @escaping (Bool) -> Void) -> some Tag {
        _DocumentVisibilityEffect(initial: initial, action: action, content: self)
    }

    public func onVisualViewportChange(initial: Bool = true,
                                       _ action: @escaping (VisualViewportMetrics) -> Void) -> some Tag {
        _VisualViewportEffect(initial: initial, action: action, content: self)
    }
}
