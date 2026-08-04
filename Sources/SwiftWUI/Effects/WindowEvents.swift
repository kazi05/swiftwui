public enum WindowEventKind: Hashable {
    case scroll, resize
}

/// Runtime-owned fan-out for window-level events. The backend attaches real
/// window listeners lazily, on the first subscription ever (page lifetime,
/// like environment observation — never detached).
@MainActor
final class WindowEventHub {
    nonisolated deinit { }
    private var subscribers: [NodeIdentity: (kind: WindowEventKind, action: (Any) -> Void)] = [:]
    var onFirstSubscriber: (() -> Void)?
    private var began = false

    func subscribe(id: NodeIdentity, kind: WindowEventKind, action: @escaping (Any) -> Void) {
        subscribers[id] = (kind, action)
        if !began { began = true; onFirstSubscriber?() }
    }
    func unsubscribe(id: NodeIdentity) { subscribers[id] = nil }
    func dispatch(_ kind: WindowEventKind, payload: Any) {
        for (_, sub) in subscribers where sub.kind == kind { sub.action(payload) }
    }
}

struct _WindowEventEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let kind: WindowEventKind
    let action: (Any) -> Void
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.effects.append(.windowEvent(id: id, kind: kind, action: action))
        return resolve(content, path: id, ctx: &ctx)
    }
}

extension Tag {
    /// Window (page) scroll. Element-independent, so available on any Tag —
    /// unlike element-bound event modifiers (HTMLTag-only).
    public func onWindowScroll(_ action: @escaping (ScrollEvent) -> Void) -> some Tag {
        _WindowEventEffect(kind: .scroll,
                           action: { any in if let e = any as? ScrollEvent { action(e) } },
                           content: self)
    }
    public func onWindowResize(_ action: @escaping (SizeEvent) -> Void) -> some Tag {
        _WindowEventEffect(kind: .resize,
                           action: { any in if let e = any as? SizeEvent { action(e) } },
                           content: self)
    }
}
