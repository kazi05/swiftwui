// RenderContext.swift — structural component identity for state persistence.
//
// `@State` storage is created in the property wrapper's initializer, which runs
// every time a parent's `body` reconstructs a child struct. Without an identity
// model, that means nested components get fresh storage on every render and lose
// their state — the framework's central bug.
//
// RenderContext threads a structural path through the single `resolveTagBody`
// recursion. Each custom component gets a path key (parent path + type + sibling
// index); a persistent table maps path → storage objects. Just before a
// component's `body` is evaluated, its freshly-constructed `@State` is grafted
// onto the persisted storage for that path, so the value survives re-renders.
// The public API (`@State`, `body`) is unchanged.
//
// Single-threaded WASM / synchronous render, so a process-global `current` and
// plain mutable state are safe — the same pattern the animation/event contexts
// use.

/// A stored property that owns relocatable reactive storage (today: `@State`).
/// RenderContext grafts persisted storage onto freshly-built component structs
/// through this protocol so state survives re-renders. Underscored because it is
/// an implementation detail of the state-identity machinery, not user API.
public protocol _StatefulProperty {
    /// The storage object this property currently points at.
    var _storageObject: AnyObject { get }
    /// Point this property at a previously-persisted storage object.
    func _adoptStorage(_ object: AnyObject)
}

/// A property that reads from the tree-scoped environment (today: `@Environment`).
/// RenderContext asks it to snapshot the environment at render time — while the
/// ancestor's `.environment(_:_:)` scope is still active — so a value read later
/// (in an event handler or async closure, after that scope has popped) still sees
/// the ancestor's override instead of the default. Opaque because the concrete
/// `EnvironmentValues` type lives in the state module, not Core.
public protocol _EnvironmentReader {
    func _captureEnvironment()
}

/// Owns the persistent per-path state table and the transient per-render walk
/// state. One instance lives on each renderer and survives across renders.
///
/// `@unchecked Sendable`: an instance is confined to the render that owns it —
/// each renderer has its own context and a single render runs on one thread
/// (single-threaded in WASM; one task per render elsewhere). It is never touched
/// by two threads at once, so the mutable interior needs no lock.
public final class RenderContext: @unchecked Sendable {

    /// The context active for the current render, if any. When nil,
    /// `resolveTagBody` behaves exactly as before (no identity, fresh storage) —
    /// correct for one-shot SSR/SSG.
    ///
    /// `@TaskLocal` so concurrent renders (e.g. parallel native tests, or a
    /// multi-threaded SSR server) each see their own context instead of racing
    /// on one global pointer. In the single-threaded WASM runtime there is one
    /// task, so this behaves as a simple current-context slot.
    @TaskLocal public static var current: RenderContext?

    /// Persistent across renders: structural path → storage object per `@State`
    /// slot (in declaration order).
    private var stateTable: [String: [AnyObject]] = [:]

    private struct Frame {
        let path: String
        var childCounts: [String: Int] = [:]
    }
    /// Transient stack for the render in progress.
    private var frames: [Frame] = []
    /// Paths reached this render; anything else is swept (unmounted) at pass end.
    private var visited: Set<String> = []

    public init() {}

    /// Structural path of the component currently being resolved (top frame),
    /// or "" when no component is active. Used to scope call-site-keyed effects
    /// like `.onChange` to a specific component instance so two instances of the
    /// same component do not share one previous-value slot.
    public var currentPath: String { frames.last?.path ?? "" }

    /// Resolve a root tag under this context, managing the render-pass lifecycle
    /// (install as current, seed the root frame, sweep unmounted paths, restore).
    public func resolveRoot<T: Tag>(_ tag: T) -> [TagNode] {
        frames = [Frame(path: "")]
        visited = []
        defer {
            // Sweep unmounted paths. Snapshot keys first — mutating the
            // dictionary while iterating its lazy `.keys` view is undefined.
            for key in Array(stateTable.keys) where !visited.contains(key) {
                stateTable.removeValue(forKey: key)
            }
            frames = []
        }
        return RenderContext.$current.withValue(self) {
            resolveTagBody(tag)
        }
    }

    /// Enter a component frame: assign it a sibling index under the current
    /// parent, push its frame, and return its structural path. Called by
    /// `resolveTagBody` for every custom component.
    func enterComponent(typeName: String) -> String {
        guard !frames.isEmpty else {
            // Defensive: only reachable if called outside resolveRoot.
            let path = "/\(typeName)#0"
            frames.append(Frame(path: path))
            visited.insert(path)
            return path
        }
        let parentIndex = frames.count - 1
        let index = frames[parentIndex].childCounts[typeName, default: 0]
        frames[parentIndex].childCounts[typeName] = index + 1
        let path = "\(frames[parentIndex].path)/\(typeName)#\(index)"
        frames.append(Frame(path: path))
        visited.insert(path)
        return path
    }

    func exitComponent() {
        if !frames.isEmpty { frames.removeLast() }
    }

    /// Link a component's identity-dependent properties just before its `body`
    /// runs: graft persisted `@State` storage (keyed by `path`) and snapshot the
    /// current environment onto any `@Environment`. One Mirror pass handles both.
    func linkProperties(of tag: Any, at path: String) {
        var stateProps: [_StatefulProperty] = []
        for child in Mirror(reflecting: tag).children {
            if let state = child.value as? _StatefulProperty {
                stateProps.append(state)
            }
            if let env = child.value as? _EnvironmentReader {
                // Capture now, while the ancestor's environment scope is active.
                env._captureEnvironment()
            }
        }
        guard !stateProps.isEmpty else { return }
        if let persisted = stateTable[path] {
            for (i, prop) in stateProps.enumerated() where i < persisted.count {
                prop._adoptStorage(persisted[i])
            }
        } else {
            stateTable[path] = stateProps.map { $0._storageObject }
        }
    }
}
