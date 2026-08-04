/// Build-time check for the boot-UI authoring constraints (boot spec §5.6).
///
/// Boot UI is rendered ONCE, natively, at build time. `@State` never
/// re-renders, `.task`/`.onAppear` never run, and no Swift closure can fire
/// before the runtime that owns it exists — so an author gets a spinner with a
/// dead button and, without this, no diagnostic at all.
///
/// DELIBERATELY NARROW, AND HONEST ABOUT IT. Exact for three things, all
/// directly observable in the `ResolveContext` a render returns:
///
///   - registered listeners (`ctx.liveListeners`),
///   - grafted `@State` rows (`StateStore.rowIdentities`),
///   - effects (`ctx.effects`).
///
/// It CANNOT see `@Environment` and `@AppStorage`/`@SceneStorage` (injected
/// straight onto the struct, no store row), `@Dependency` (resolved outside the
/// render tree entirely) or the WAAPI `.animation`/`.transition` engine (a
/// client-side commit the build render never reaches). Those are UNENFORCED,
/// not promised: a check that half works is worse than a documented limitation,
/// because it advertises a guarantee it does not provide.
///
/// Findings are RETURNED, never asserted. `swiftwui build` defaults to
/// `-c release`, where assertions are stripped — a probe that only asserted
/// would silently do nothing in the one configuration authors ship. The caller
/// writes them to stderr and decides the exit status (`StaticSite.generate`).
public enum BootProbe {
    public struct Finding {
        public let message: String
        /// Errors fail a build; warnings only print.
        public let isError: Bool
    }

    /// Standalone check — resolves `content` in a throwaway build render, so
    /// every listener/row/effect it finds belongs to `content`.
    ///
    /// `Runtime._renderBootShell` does NOT route through this: it already has a
    /// resolved context and probing that one costs nothing extra. Internal
    /// therefore — the tests reach it with `@testable`, and the two real call
    /// sites use `findings` directly.
    static func check(_ content: AnyTag) -> [Finding] {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        ctx.isBuildRender = true
        let nodes = resolve(content, path: .root, ctx: &ctx)
        return findings(root: .root, nodes: nodes, ctx: ctx, what: "boot UI")
    }

    /// Findings for a boot subtree already resolved into `ctx` at `root`.
    ///
    /// Everything is selected by PATH (`isSelfOrDescendant(of: root)`), never by
    /// a before/after count delta: a `.whileBooting` placeholder shares the
    /// page's store, the SSG re-resolves after the build-task drain, and
    /// `StateStore.link` reuses the row — so a delta is not a signal.
    ///
    /// `nodes` is that subtree's output. It is needed for exactly one thing,
    /// `Link`'s exemption; see `collectLinkOwners`.
    static func findings(root: NodeIdentity, nodes: [Node], ctx: ResolveContext,
                         what: String) -> [Finding] {
        var out: [Finding] = []
        var linkOwners: Set<NodeIdentity> = []
        collectLinkOwners(nodes, into: &linkOwners)

        let listeners = ctx.liveListeners.filter { $0.owner.isSelfOrDescendant(of: root) }
        let dead = listeners.filter { !linkOwners.contains($0.owner) }
        if !dead.isEmpty {
            out.append(.init(message: "\(what) registers \(dead.count) event handler(s); "
                                    + "no Swift closure can run before the runtime is live",
                             isError: true))
        }
        if dead.count < listeners.count {
            out.append(.init(message: "\(what) contains a Link; its click handler is dead until the "
                                    + "runtime is live, but the <a href> navigates without it",
                             isError: false))
        }
        if ctx.store.rowIdentities.contains(where: { $0.isSelfOrDescendant(of: root) }) {
            out.append(.init(message: "\(what) declares @State; it is rendered once at build time "
                                    + "and never re-renders", isError: true))
        }
        // Named from the cases actually present, and named as the MODIFIER an
        // author would go looking for: sending them to unrelated code is the
        // wrong-diagnostic failure this probe exists to prevent.
        var kinds: [String] = []
        for e in ctx.effects where e.id.isSelfOrDescendant(of: root) {
            let name: String
            switch e {
            // `.onChange` has two producers — `_OnChangeEffect` and
            // `_RouteChangeEffect` — and the case carries no discriminator, so
            // name the pair rather than guess which one.
            case .onChange:    name = ".onChange/.onRouteChange"
            case .task:        name = ".task"
            case .appear:      name = ".onAppear"
            case .disappear:   name = ".onDisappear"
            // This one DOES discriminate: the kind is right there.
            case .windowEvent(_, let kind, _):
                name = kind == .scroll ? ".onWindowScroll" : ".onWindowResize"
            // NOT `.dropDestination`, which is a different modifier entirely
            // (it registers attributes, not this effect).
            case .dropGuard:   name = ".preventsAccidentalDropNavigation"
            }
            if !kinds.contains(name) { kinds.append(name) }
        }
        if !kinds.isEmpty {
            out.append(.init(message: "\(what) declares \(kinds.joined(separator: ", ")); "
                                    + "effects never run in a build render", isError: true))
        }
        return out
    }

    /// `Link` registers an internal click handler yet navigates perfectly well
    /// through its own `<a href>` — it works in the failed boot state, which is
    /// exactly when boot UI matters. So it is exempt, as a warning.
    ///
    /// The handler is registered on the same element that carries
    /// `data-swui-link`, the marker the DOM backend already keys navigation off,
    /// which makes this a structural match. Matching the identity path instead
    /// would be a guess: canonical `.type` segments embed FULL generic type
    /// names, so `Link<Span<Text>>` — and any author type merely spelled
    /// "…Link…" — lands in the same string.
    private static func collectLinkOwners(_ nodes: [Node], into out: inout Set<NodeIdentity>) {
        for node in nodes {
            switch node {
            case .element(let e):
                if e.attributes["data-swui-link"] != nil { out.insert(e.identity) }
                collectLinkOwners(e.children, into: &out)
            case .component(let c):
                collectLinkOwners(c.children, into: &out)
            case .text:
                break
            }
        }
    }
}
