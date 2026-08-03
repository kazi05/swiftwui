#if arch(wasm32)
import JavaScriptKit
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Retains the WAAPI `Animation` object plus the bookkeeping `animate` needs to
/// settle exactly once, whichever of finished/timeout/cancel/finish/visibility
/// fires first (anim spec §8). Keyed in `DOMBackend.liveAnimationTokens` by
/// `ObjectIdentifier(self)` — this is a Swift class, not a JSObject, so that
/// key is stable (unlike ObjectIdentifier(JSObject), see file header note).
@MainActor
final class DOMAnimationToken: AnimationToken {
    let animation: JSObject
    let isInfinite: Bool
    var settled = false
    var settle: ((AnimationSettle) -> Void)?
    var timeoutID: JSValue?
    // finished.then(onFinished, onRejected) + the timeout oneshot. A
    // JSOneshotClosure self-releases only when INVOKED, so the unfired ones
    // (the losing .then branch, and the timeout on a happy-path finish) would
    // leak their host-func box. Retained here; released in settleOnce.
    var closures: [JSOneshotClosure] = []
    init(animation: JSObject, isInfinite: Bool) {
        self.animation = animation
        self.isInfinite = isInfinite
    }
}

/// JSObject glue. All bookkeeping keys use the __swuid int stamped at creation —
/// NEVER ObjectIdentifier(JSObject) (spec §8.5 invariant 4, trap T5).
@MainActor
public final class DOMBackend: RendererBackend {
    public typealias HostNode = JSObject

    private let jsDocument = JSObject.global.document
    // The bridged `document` global is a computed getter — two bridge crossings
    // and a fresh handle per call. Cache the SWDocument once; every
    // createElement/createTextNode reuses it.
    private lazy var swDocument: SWDocument = try! document
    private let dispatch: (ListenerID, Any?) -> Void
    private var closures: [String: JSClosure] = [:]   // "\(uid)#\(event)" → retained
    private var listenerIDs: [String: ListenerID] = [:]
    private var nextUID = 0
    // Element observers (IntersectionObserver/ResizeObserver) — same retention
    // discipline as `closures`/`listenerIDs`, keyed "\(uid)#\(kind.key)".
    private var domObservers: [String: JSObject] = [:]
    private var observerClosures: [String: JSClosure] = [:]
    private var observerIDs: [String: ListenerID] = [:]
    // Environment observation closures — named (not positional) so teardown pairs
    // each with its exact target; retained for backend lifetime (v1 leak lesson).
    private var schemeClosure: JSClosure?
    private var onlineClosure: JSClosure?
    private var offlineClosure: JSClosure?
    private var windowScrollClosure: JSClosure?
    private var windowResizeClosure: JSClosure?
    private var storageClosure: JSClosure?          // window "storage" event — same teardown as above
    private var colorSchemeQuery: JSObject?        // keep the MediaQueryList alive with its listener
    private var reduceMotionClosure: JSClosure?
    private var reduceMotionQuery: JSObject?       // keep the MediaQueryList alive with its listener
    // dragSession (DnD spec §3.4): window-level dragenter/dragleave depth counter
    // plus drop/dragend resets, all retained for backend lifetime.
    private var dragDepth = 0
    private var dragEnterClosure: JSClosure?
    private var dragLeaveClosure: JSClosure?
    private var dragResetDropClosure: JSClosure?
    private var dragResetEndClosure: JSClosure?
    // preventsAccidentalDropNavigation (DnD task 7) — window dragover/drop
    // listeners installed only while ≥1 guard is mounted; both nil ⇔ disabled.
    private var dropGuardOverClosure: JSClosure?
    private var dropGuardDropClosure: JSClosure?
    // observeMediaQuery (responsive styling) — one closure per call, retained for backend lifetime.
    private var retainedMediaClosures: [JSClosure] = []
    // ... and the MediaQueryList itself (v1 leak lesson, same as colorSchemeQuery/reduceMotionQuery
    // above) — otherwise JS can GC the MQL and silently drop the change listener.
    private var retainedMediaQueries: [JSObject] = []
    // PWA service-worker wiring (spec 2026-07-12) — retained for backend lifetime.
    private var swUpdateFoundClosure: JSClosure?
    private var swStateChangeClosures: [JSClosure] = []
    private var swRegistration: JSObject?
    private var lastAppliedLinks: [LinkTag]? = nil   // churn guard (setLinks) — nil means "never applied"
    // Animations (task 14) — table of unsettled tokens (force-finished on
    // visibilitychange) and the lazily-installed page-lifetime listener.
    private var liveAnimationTokens: [ObjectIdentifier: DOMAnimationToken] = [:]
    private var visibilityChangeClosure: JSClosure?
    private var linearEasingSupported: Bool?    // cached CSS.supports() probe, first animate() call
    // View transitions (spec 2026-07-26 §3.1, §5.3, §7): the FLIP fallback
    // (Task 6) needs the named elements, and every name write already passes
    // through setStyleProperty/removeStyleProperty — exact, and cheaper than
    // any DOM query. `[style*="view-transition-name"]` was the first draft and
    // matches `none`, matches custom properties containing the text, and
    // misses names set from a stylesheet rule.
    private var namedHosts: [String: JSObject] = [:]
    // Generation token: a second navigation aborts the first mid-animation,
    // and an untokened cleanup would wipe the attributes the newer transition
    // just wrote. Bumped once per performViewTransition call.
    private var vtGeneration = 0
    private var activeTransition: JSObject?
    // A JSOneshotClosure self-releases only when INVOKED — the update
    // callback, the losing ready/finished branch, and the watchdog when the
    // transition already settled are all one-shots that may never fire.
    // Retained here, released deterministically in releaseTransitionClosures.
    // Keyed by generation (NOT one shared array): transition A's promises can
    // settle after transition B has already started (a second navigation
    // aborts the first mid-animation, but A's `finished` still resolves
    // asynchronously afterward) — a shared array would let A's settle release
    // B's still-pending closures out from under it.
    private var vtClosuresByGeneration: [Int: [JSOneshotClosure]] = [:]
    // The watchdog's setTimeout id, same per-generation keying, so a normal
    // settle can cancel it before releasing its closure — an already-fired
    // timer invoking a released host function is a hard crash, not a no-op.
    private var vtTimeoutIDByGeneration: [Int: JSValue] = [:]
    private var pageHideClosure: JSClosure?      // retained for the backend's lifetime, like the others
    /// `?swui-vt=flip` forces the FLIP path in a supporting browser — without it
    /// nobody would ever exercise that code by hand.
    private lazy var forceFlipFallback: Bool = {
        guard let search = JSObject.global.location.object?.search.string,
              let params = JSObject.global.URLSearchParams.function?.new(search) else { return false }
        return params.get?("swui-vt").string == "flip"
    }()

    public init(dispatch: @escaping (ListenerID, Any?) -> Void) { self.dispatch = dispatch }

    public func createElement(_ tag: String) -> JSObject {
        let el = try! swDocument.createElement(tag).jsObject
        el.__swuid = .number(Double(nextUID)); nextUID += 1
        return el
    }
    public func createTextNode(_ text: String) -> JSObject {
        let n = try! swDocument.createTextNode(text).jsObject
        n.__swuid = .number(Double(nextUID)); nextUID += 1
        return n
    }
    public func setText(_ node: JSObject, _ text: String) {
        try! SWNode(unsafelyWrapping: node).setData(text)
    }
    public func setAttribute(_ node: JSObject, name: String, value: String) {
        try! SWNode(unsafelyWrapping: node).setAttribute(name, value)
    }
    public func removeAttribute(_ node: JSObject, name: String) {
        try! SWNode(unsafelyWrapping: node).removeAttribute(name)
    }
    // No bridged CSSStyleDeclaration binding — dynamic JSObject call, same
    // idiom as the other ad hoc DOM calls in this file (e.g. setStylesheet's
    // `el.setAttribute`, setMetaTags' `removeChild`).
    public func setStyleProperty(_ node: JSObject, name: String, value: String) {
        _ = node.style.object?.setProperty?(name, value)
        if name == "view-transition-name" {
            purgeNamedHost(node)   // drop whatever name this node had before (rename or → "none")
            if value != "none" { namedHosts[value] = node }
        }
    }
    public func removeStyleProperty(_ node: JSObject, name: String) {
        _ = node.style.object?.removeProperty?(name)
        if name == "view-transition-name" { purgeNamedHost(node) }
    }
    /// Removes every entry pointing at `node`, regardless of key. `JSObject`'s
    /// `==` compares the underlying JS object id, so this is exact.
    private func purgeNamedHost(_ node: JSObject) {
        for (key, host) in namedHosts where host == node { namedHosts[key] = nil }
    }
    public func setProperty(_ node: JSObject, name: String, value: PropertyValue) {
        if name.hasPrefix("swui:cmd:") {
            // One-shot imperative command, delivered via the property diff
            // channel (applies only on change). "0" is the initial no-op nonce;
            // "" is also a no-op — the reconciler's property-removal path emits
            // .string("") for a cleared property. A grafted nonce re-applied on
            // a hot-reload remount triggers a click() without transient
            // activation — browsers ignore it (documented-harmless).
            guard case .string(let nonce) = value, nonce != "0", !nonce.isEmpty else { return }
            if name == "swui:cmd:click" { _ = node.click?() }
            return
        }
        switch value {
        case .string(let s):
            if node[name].string != s { node[name] = .string(s) }
        case .bool(let b):
            if node[name].boolean != b { node[name] = .boolean(b) }
        }
    }

    public func setEventListener(_ node: JSObject, event: String, id: ListenerID) {
        let key = closureKey(node, event)
        listenerIDs[key] = id
        guard closures[key] == nil else { return }    // fire-time lookup: closure reusable as-is
        let closure = JSClosure { [weak self] args in
            guard let self, let current = self.listenerIDs[key] else { return .undefined }
            let payload = args.first?.object.map { Self.decodePayload(event: current.event, jsEvent: $0) }
            self.dispatch(current, payload)
            return .undefined
        }
        closures[key] = closure                        // Swift retention = lifetime (invariant 1)
        if event == "scroll" {
            // Never preventDefault()s — passive avoids blocking the scroll thread.
            let opts = JSObject.global.Object.function!.new()
            opts.passive = .boolean(true)
            _ = node.addEventListener?(event, closure, opts)
        } else {
            _ = node.addEventListener?(event, closure)
        }
    }

    /// FileList → [WebFile] — same duck-typed shape for `input.files` and
    /// `dataTransfer.files`.
    static func webFiles(from files: JSObject) -> [WebFile] {
        let n = Int(files.length.number ?? 0)
        var out: [WebFile] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            guard let f = files.item?(i).object else { continue }
            out.append(WebFile(
                name: f.name.string ?? "",
                size: Int(f.size.number ?? 0),
                mimeType: f.type.string ?? "",
                lastModified: Date(timeIntervalSince1970: (f.lastModified.number ?? 0) / 1000),
                reader: DOMFileReader(file: f)))
        }
        return out
    }

    /// `dataTransfer.types`/`.items` are JS array-likes, not real Arrays —
    /// no `.map`/`.compactMap` on the JSValue side, hence the manual index loop.
    static func jsStringArray(_ value: JSValue) -> [String] {
        guard let arr = value.object else { return [] }
        let n = Int(arr.length.number ?? 0)
        return (0..<n).compactMap { arr[$0].string }
    }

    /// Mimes of file items during hover (kind=="file"); empty when the
    /// browser hides items mid-drag → matcher goes optimistic.
    static func dragItemMimes(_ e: JSObject) -> [String] {
        guard let items = e.dataTransfer.object?.items.object else { return [] }
        let n = Int(items.length.number ?? 0)
        var out: [String] = []
        for i in 0..<n {
            guard let item = items[i].object, item.kind.string == "file" else { continue }
            out.append(item.type.string ?? "")
        }
        return out
    }

    static func decodeDragEvent(_ e: JSObject) -> DragEvent {
        let types = jsStringArray(e.dataTransfer.object?.types ?? .undefined)
        var isInternal = false
        if let ct = e.currentTarget.object, let rt = e.relatedTarget.object {
            isInternal = ct.contains?(rt).boolean ?? false
        }
        let cx = e.clientX.number ?? 0, cy = e.clientY.number ?? 0
        var tw = 0.0, th = 0.0, ox = 0.0, oy = 0.0
        if let rect = e.currentTarget.object?.getBoundingClientRect?().object {
            tw = rect.width.number ?? 0; th = rect.height.number ?? 0
            ox = cx - (rect.left.number ?? 0); oy = cy - (rect.top.number ?? 0)
        }
        return DragEvent(types: types, hasFiles: types.contains("Files"),
                         x: cx, y: cy, isInternalTransition: isInternal,
                         targetWidth: tw, targetHeight: th, offsetX: ox, offsetY: oy)
    }

    static func decodePayload(event: String, jsEvent e: JSObject) -> Any {
        let target = e.target.object
        switch event {
        case "input":
            return InputEvent(value: target?.value.string ?? "")
        case "change":
            if let t = target, t.type.string == "file", let files = t.files.object {
                return FilesEvent(files: Self.webFiles(from: files))
            }
            return ChangeEvent(value: target?.value.string ?? "",
                               checked: target?.checked.boolean ?? false)
        case "keydown", "keyup":
            return KeyEvent(key: e.key.string ?? "", repeated: e["repeat"].boolean ?? false,
                            metaKey: e.metaKey.boolean ?? false,
                            ctrlKey: e.ctrlKey.boolean ?? false,
                            shiftKey: e.shiftKey.boolean ?? false,
                            altKey: e.altKey.boolean ?? false)
        case "submit":
            _ = e.preventDefault?()
            return SubmitEvent()
        case "focus", "blur":
            return FocusEvent()
        case "scroll":
            return ScrollEvent(x: target?.scrollLeft.number ?? 0,
                               y: target?.scrollTop.number ?? 0)
        case "click":
            let click = ClickEvent(button: Int(e.button.number ?? 0),
                                   metaKey: e.metaKey.boolean ?? false,
                                   ctrlKey: e.ctrlKey.boolean ?? false,
                                   shiftKey: e.shiftKey.boolean ?? false,
                                   altKey: e.altKey.boolean ?? false,
                                   targetValue: target?.value.string,
                                   checked: target?.checked.boolean)
            // SPA interception (spec §8): unmodified click on a managed link →
            // suppress full-page navigation; Link's Swift handler navigates.
            if !click.isModified,
               e.currentTarget.object?.hasAttribute?("data-swui-link").boolean == true {
                _ = e.preventDefault?()
            }
            return click
        case "dragstart":
            // Attribute-driven source (DnD spec §2.3/§2.4): payload was encoded
            // at render time; setData MUST happen synchronously here.
            if let ct = e.currentTarget.object, let dt = e.dataTransfer.object,
               let type = ct.getAttribute?("data-swui-drag-type").string,
               let body = ct.getAttribute?("data-swui-drag").string {
                _ = dt.setData?(type, body)
                dt.effectAllowed = .string("copyMove")
            }
            return Self.decodeDragEvent(e)
        case "dragenter", "dragover":
            let ev = Self.decodeDragEvent(e)
            // preventDefault ⇔ this zone accepts the current drag — the browser
            // cursor then honestly shows allowed/not-allowed (rejected state).
            if let ct = e.currentTarget.object,
               let accepts = ct.getAttribute?("data-swui-drop-accepts").string,
               _DragAcceptance.matches(accepts: accepts, types: ev.types,
                                       fileMimes: Self.dragItemMimes(e)) {
                _ = e.preventDefault?()
                e.dataTransfer.object?.dropEffect = .string("copy")
            }
            return ev
        case "dragleave", "dragend":
            return Self.decodeDragEvent(e)
        case "drop":
            _ = e.preventDefault?()          // never let the browser open the file
            var files: [WebFile] = []
            var strings: [String: String] = [:]
            if let dt = e.dataTransfer.object {
                if let list = dt.files.object { files = Self.webFiles(from: list) }
                for t in Self.jsStringArray(dt.types) where t != "Files" {
                    if let s = dt.getData?(t).string, !s.isEmpty { strings[t] = s }
                }
            }
            return DropEvent(files: files, strings: strings,
                             x: e.clientX.number ?? 0, y: e.clientY.number ?? 0)
        default:
            return GenericEvent(type: event,
                                targetValue: target?.value.string,
                                key: e.key.string,
                                checked: target?.checked.boolean)
        }
    }
    public func removeEventListener(_ node: JSObject, event: String) {
        let key = closureKey(node, event)
        listenerIDs[key] = nil
        guard let closure = closures.removeValue(forKey: key) else { return }
        _ = node.removeEventListener?(event, closure)  // same function object (invariant 2)
    }

    private func observerKey(_ node: JSObject, _ kind: ObserverKind) -> String {
        "\(Int(node.__swuid.number ?? -1))#\(kind.key)"
    }

    public func observe(_ node: JSObject, kind: ObserverKind, id: ListenerID) {
        let key = observerKey(node, kind)
        observerIDs[key] = id
        guard domObservers[key] == nil else { return }   // fire-time lookup, reusable
        let closure: JSClosure
        let observer: JSObject?
        switch kind {
        case .visibility(let threshold):
            closure = JSClosure { [weak self] args in
                guard let self, let current = self.observerIDs[key] else { return .undefined }
                let visible = args.first?.object?[0].object?.isIntersecting.boolean ?? false
                self.dispatch(current, visible)
                return .undefined
            }
            let opts = JSObject.global.Object.function!.new()
            opts.threshold = .number(threshold)
            observer = JSObject.global.IntersectionObserver.function?.new(closure, opts)
        case .size:
            closure = JSClosure { [weak self] args in
                guard let self, let current = self.observerIDs[key] else { return .undefined }
                let rect = args.first?.object?[0].object?.contentRect.object
                self.dispatch(current, SizeEvent(width: rect?.width.number ?? 0,
                                                 height: rect?.height.number ?? 0))
                return .undefined
            }
            observer = JSObject.global.ResizeObserver.function?.new(closure)
        }
        guard let observer else { return }               // API absent (old browser) → no-op
        _ = observer.observe?(node)
        domObservers[key] = observer
        observerClosures[key] = closure                  // Swift retention = lifetime
    }

    public func unobserve(_ node: JSObject, kind: ObserverKind) {
        let key = observerKey(node, kind)
        observerIDs[key] = nil
        guard let observer = domObservers.removeValue(forKey: key) else { return }
        _ = observer.disconnect?()
        observerClosures[key] = nil
    }

    public func insert(_ child: JSObject, into parent: JSObject, before anchor: JSObject?) {
        let p = SWNode(unsafelyWrapping: parent)
        if let anchor { try! p.insertBefore(SWNode(unsafelyWrapping: child),
                                            SWNode(unsafelyWrapping: anchor)) }
        else { try! p.appendChild(SWNode(unsafelyWrapping: child)) }
    }
    public func remove(_ child: JSObject, from parent: JSObject) {
        try! SWNode(unsafelyWrapping: parent).removeChild(SWNode(unsafelyWrapping: child))
        // Liveness-based, not node-based: removeStyleProperty never fires for a
        // host torn out with its inline style intact, and a named element
        // nested inside `child`'s subtree detaches here too (removeChild
        // cascades natively) without ever getting its own `remove` call.
        // isConnected is exact for both cases. Guarded so the hot path (no
        // view transition ever used) costs nothing.
        if !namedHosts.isEmpty {
            for (key, host) in namedHosts where host.isConnected.boolean != true { namedHosts[key] = nil }
        }
    }

    private func closureKey(_ node: JSObject, _ event: String) -> String {
        "\(Int(node.__swuid.number ?? -1))#\(event)"
    }

    private var styleElement: JSObject?
    public func setStylesheet(_ text: String) {
        if styleElement == nil {
            let document = JSObject.global.document
            // The SSG-inlined stylesheet (spec §5) becomes the managed one —
            // reuse it instead of appending a duplicate <style>.
            if let existing = document.querySelector("style[data-swiftwui]").object {
                styleElement = existing
            } else {
                let el = document.createElement("style")
                _ = el.setAttribute("id", "swiftwui-styles")
                _ = document.head.appendChild(el)
                styleElement = el.object
            }
        }
        styleElement!.textContent = .string(text)
    }

    // History/head idioms below are the v1-audited patterns (master
    // DOMBridge.swift:387-416) — do not "modernize" them.
    public func pushState(path: String) {
        _ = JSObject.global.history.object!.pushState!(JSValue.null, "", path)
    }
    public func replaceState(path: String) {
        _ = JSObject.global.history.object!.replaceState!(JSValue.null, "", path)
    }
    public func historyBack() {
        _ = JSObject.global.history.object!.back!()
    }
    /// The prerender's own `[data-swiftwui-ssg]` head tags: the synthesized
    /// canonical and hreflang links, AND the fall-through page's
    /// `<meta name="robots" content="noindex">`. `setLinks`/`setMetaTags`
    /// deliberately do not sweep them — they belong to the URL that was served
    /// and the client cannot rebuild them — so this is the one place they go,
    /// called by Runtime on every client-side URL move.
    /// Nothing to do after the first move: the selector then matches nothing.
    ///
    /// The meta half matters as much as the links: a visitor landing on a
    /// prerendered 404 and following an in-page `Link` to a real page would
    /// otherwise carry that `noindex` for the rest of the session.
    public func dropPrerenderedHeadLinks() {
        let old = jsDocument.querySelectorAll("link[data-swiftwui-ssg], meta[data-swiftwui-ssg]").object
        let n = Int(old?.length.number ?? 0)
        for i in (0..<n).reversed() {
            if let el = old?[i].object { _ = el.parentNode.object?.removeChild?(el) }
        }
    }
    public func setTitle(_ title: String) {
        jsDocument.title = .string(title)
    }
    public func setMetaTags(_ tags: [MetaTag]) {
        // Replace ONLY the managed set (spec §9): marked data-swiftwui.
        let old = jsDocument.querySelectorAll("meta[data-swiftwui]").object
        let n = Int(old?.length.number ?? 0)
        for i in (0..<n).reversed() {
            if let el = old?[i].object {
                _ = el.parentNode.object?.removeChild?(el)
            }
        }
        guard let head = jsDocument.head.object else { return }
        for tag in tags {
            let el = jsDocument.createElement("meta").object!
            for name in tag.attributes.keys.sorted() {
                _ = el.setAttribute?(name, tag.attributes[name]!)
            }
            _ = el.setAttribute?("data-swiftwui", "")
            _ = head.appendChild?(el)
        }
    }
    public func setStructuredData(_ blocks: [String]) {
        // Replace ONLY the managed set (spec §5.3): marked data-swiftwui.
        let old = jsDocument.querySelectorAll("script[type='application/ld+json'][data-swiftwui]").object
        let n = Int(old?.length.number ?? 0)
        for i in (0..<n).reversed() {
            if let el = old?[i].object {
                _ = el.parentNode.object?.removeChild?(el)
            }
        }
        guard let head = jsDocument.head.object else { return }
        for block in blocks {
            let el = jsDocument.createElement("script").object!
            _ = el.setAttribute?("type", "application/ld+json")
            _ = el.setAttribute?("data-swiftwui", "")
            el.textContent = .string(block)      // textContent is not an HTML sink
            _ = head.appendChild?(el)
        }
    }
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {
        let window = JSObject.global.window.object
        // prefers-color-scheme: initial read BEFORE the first render pass, then change listener.
        if let mql = window?.matchMedia?("(prefers-color-scheme: dark)").object {
            writer.setColorScheme(mql.matches.boolean == true ? .dark : .light)
            let onSchemeChange = JSClosure { args in
                let matches = args.first?.object?.matches.boolean == true
                writer.setColorScheme(matches ? .dark : .light)
                return .undefined
            }
            _ = mql.addEventListener?("change", onSchemeChange)
            schemeClosure = onSchemeChange
            colorSchemeQuery = mql
        }
        // prefers-reduced-motion: initial read BEFORE the first render pass, then change listener.
        if let mql = window?.matchMedia?("(prefers-reduced-motion: reduce)").object {
            writer.setReduceMotion(mql.matches.boolean == true)
            let onMotionChange = JSClosure { args in
                writer.setReduceMotion(args.first?.object?.matches.boolean == true)
                return .undefined
            }
            _ = mql.addEventListener?("change", onMotionChange)
            reduceMotionClosure = onMotionChange
            reduceMotionQuery = mql
        }
        // navigator.onLine + online/offline events.
        if let nav = JSObject.global.navigator.object {
            writer.setOnline(nav.onLine.boolean ?? true)
        }
        let onOnline = JSClosure { _ in writer.setOnline(true); return .undefined }
        let onOffline = JSClosure { _ in writer.setOnline(false); return .undefined }
        _ = window?.addEventListener?("online", onOnline)
        _ = window?.addEventListener?("offline", onOffline)
        onlineClosure = onOnline
        offlineClosure = onOffline
        // dragSession (DnD spec §3.4): dragenter/dragleave depth-counted so
        // bubbling child enters/leaves don't flip the session off early; drop
        // and dragend force-reset the depth (the pairing dragleave never fires
        // on a successful drop).
        let enter = JSClosure { [weak self] args in
            guard let self else { return .undefined }
            self.dragDepth += 1
            if let e = args.first?.object {
                let ev = Self.decodeDragEvent(e)
                writer.setDragSession(DragSessionInfo(isActive: true,
                                                      hasFiles: ev.hasFiles,
                                                      types: ev.types))
            }
            return .undefined
        }
        _ = window?.addEventListener?("dragenter", enter)
        dragEnterClosure = enter
        let leave = JSClosure { [weak self] _ in
            guard let self else { return .undefined }
            self.dragDepth = max(0, self.dragDepth - 1)
            if self.dragDepth == 0 { writer.setDragSession(.none) }
            return .undefined
        }
        _ = window?.addEventListener?("dragleave", leave)
        dragLeaveClosure = leave
        let reset = { [weak self] (_: [JSValue]) -> JSValue in
            self?.dragDepth = 0
            writer.setDragSession(.none)
            return .undefined
        }
        let dropReset = JSClosure(reset); let endReset = JSClosure(reset)
        _ = window?.addEventListener?("drop", dropReset)
        _ = window?.addEventListener?("dragend", endReset)
        dragResetDropClosure = dropReset
        dragResetEndClosure = endReset
        registerServiceWorkerIfConfigured(writer)
    }
    /// Responsive styling (matches() reactivity, Task 9): synchronous initial
    /// read + a `change` listener, same matchMedia idiom as
    /// beginEnvironmentObservation. Each call gets its own MediaQueryList AND
    /// closure, both retained for the backend's lifetime (v1 leak lesson) —
    /// otherwise the MediaQueryList can be GC'd and silently drops its listener.
    public func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool {
        guard let mql = JSObject.global.window.object?.matchMedia?(condition).object else { return false }
        let onMatchChange = JSClosure { args in
            onChange(args.first?.object?.matches.boolean == true)
            return .undefined
        }
        _ = mql.addEventListener?("change", onMatchChange)
        retainedMediaClosures.append(onMatchChange)
        retainedMediaQueries.append(mql)
        return mql.matches.boolean == true
    }
    /// PWA (spec 2026-07-12): register the service worker when the scaffold
    /// marker is present. Skipped in dev — a caching SW poisons hot reload.
    /// Safe to run again after endEnvironmentObservation(): register() with
    /// the same script URL returns the existing registration.
    private func registerServiceWorkerIfConfigured(_ writer: EnvironmentSignals.Writer) {
        guard JSObject.global.__swiftwui_dev.boolean != true else { return }
        let document = JSObject.global.document
        guard let meta = document.querySelector("meta[name=\"swiftwui:serviceworker\"]").object,
              let path = meta.getAttribute?("content").string, !path.isEmpty else { return }
        guard let sw = JSObject.global.navigator.object?.serviceWorker.object else { return }

        let options = JSObject.global.Object.function!.new()
        options.updateViaCache = "none"   // the SW script itself must never stick in HTTP cache
        let promise = sw.register!(path, options)

        let onRegistered = JSOneshotClosure { [weak self] args in
            guard let self, let reg = args.first?.object else { return .undefined }
            self.swRegistration = reg
            // Update found while the tab was away: waiting worker already there.
            // controller != nil distinguishes an update from the first install.
            if reg.waiting.object != nil, sw.controller.object != nil {
                writer.setAppUpdateAvailable(true)
            }
            // Install already in flight when register() resolves (common path: the
            // browser's on-navigation update check started installing the new SW
            // before the wasm booted — updatefound fired before we attached).
            if let installing = reg.installing.object {
                self.watchInstalling(installing, sw: sw, writer: writer)
            }
            let onUpdateFound = JSClosure { [weak self] _ in
                guard let self, let installing = self.swRegistration?.installing.object else {
                    return .undefined
                }
                self.watchInstalling(installing, sw: sw, writer: writer)
                return .undefined
            }
            _ = reg.addEventListener?("updatefound", onUpdateFound)
            self.swUpdateFoundClosure = onUpdateFound   // JSClosure must outlive the page (v1 lesson)
            return .undefined
        }
        let onError = JSOneshotClosure { args in
            _ = JSObject.global.console.object?.warn?(
                "SwiftWUI: service worker registration failed", args.first ?? .undefined)
            return .undefined
        }
        _ = promise.object?.then?(onRegistered, onError)
    }
    /// Attaches the statechange listener that flips appUpdateAvailable once an
    /// `installing` worker finishes installing (and a controller already
    /// exists, so this is an update, not the first install). Shared by both
    /// call sites: an install already in flight when register() resolves, and
    /// a later updatefound event.
    private func watchInstalling(_ installing: JSObject, sw: JSObject, writer: EnvironmentSignals.Writer) {
        let onState = JSClosure { _ in
            if installing.state.string == "installed", sw.controller.object != nil {
                writer.setAppUpdateAvailable(true)
            }
            return .undefined
        }
        _ = installing.addEventListener?("statechange", onState)
        swStateChangeClosures.append(onState)   // JSClosure must outlive the page (v1 lesson)
    }
    public func reloadForUpdate() {
        let sw = JSObject.global.navigator.object?.serviceWorker.object
        if let reg = swRegistration, let waiting = reg.waiting.object {
            // Reload only after the waiting worker takes control — reloading
            // first would race the activation and boot the OLD version.
            let onControllerChange = JSOneshotClosure { _ in
                _ = JSObject.global.location.object?.reload?()
                return .undefined
            }
            _ = sw?.addEventListener?("controllerchange", onControllerChange)
            let msg = JSObject.global.Object.function!.new()
            msg.type = "SKIP_WAITING"
            _ = waiting.postMessage?(msg)
        } else {
            _ = JSObject.global.location.object?.reload?()
        }
    }
    public func beginWindowEventObservation(_ sink: @escaping (WindowEventKind, Any) -> Void) {
        guard windowScrollClosure == nil, let window = JSObject.global.window.object else { return }
        let scroll = JSClosure { _ in
            sink(.scroll, ScrollEvent(x: JSObject.global.window.scrollX.number ?? 0,
                                      y: JSObject.global.window.scrollY.number ?? 0))
            return .undefined
        }
        let opts = JSObject.global.Object.function!.new()
        opts.passive = .boolean(true)
        _ = window.addEventListener?("scroll", scroll, opts)
        let resize = JSClosure { _ in
            sink(.resize, SizeEvent(width: JSObject.global.window.innerWidth.number ?? 0,
                                    height: JSObject.global.window.innerHeight.number ?? 0))
            return .undefined
        }
        _ = window.addEventListener?("resize", resize)
        windowScrollClosure = scroll
        windowResizeClosure = resize
    }
    /// preventsAccidentalDropNavigation (DnD task 7): a file dropped anywhere
    /// outside a `data-swui-drop-accepts` zone would otherwise navigate the
    /// tab to that file — the classic DnD-app footgun. Idempotent both ways.
    public func setDropNavigationGuard(_ enabled: Bool) {
        guard let window = JSObject.global.window.object else { return }
        if enabled {
            guard dropGuardOverClosure == nil else { return }
            let make = { JSClosure { args in
                if let e = args.first?.object,
                   e.target.object?.closest?("[data-swui-drop-accepts]").object == nil {
                    _ = e.preventDefault?()
                }
                return .undefined
            } }
            let over = make(); let drop = make()
            _ = window.addEventListener?("dragover", over)
            _ = window.addEventListener?("drop", drop)
            dropGuardOverClosure = over
            dropGuardDropClosure = drop
        } else {
            if let c = dropGuardOverClosure { _ = window.removeEventListener?("dragover", c) }
            if let c = dropGuardDropClosure { _ = window.removeEventListener?("drop", c) }
            dropGuardOverClosure = nil
            dropGuardDropClosure = nil
        }
    }
    /// Detaches every environment-observation listener and releases its
    /// closure. Called by DOMRuntime when a mount attempt is discarded
    /// (hydration mismatch) — symmetric with beginEnvironmentObservation.
    /// Also tears down the storage-event listener (beginStorageObservation)
    /// so a discarded mount leaves no dangling window listener.
    public func endEnvironmentObservation() {
        let window = JSObject.global.window.object
        if let mql = colorSchemeQuery, let onChange = schemeClosure {
            _ = mql.removeEventListener?("change", onChange)
        }
        if let mql = reduceMotionQuery, let onChange = reduceMotionClosure {
            _ = mql.removeEventListener?("change", onChange)
        }
        if let onOnline = onlineClosure { _ = window?.removeEventListener?("online", onOnline) }
        if let onOffline = offlineClosure { _ = window?.removeEventListener?("offline", onOffline) }
        if let onStorage = storageClosure { _ = window?.removeEventListener?("storage", onStorage) }
        if let onScroll = windowScrollClosure { _ = window?.removeEventListener?("scroll", onScroll) }
        if let onResize = windowResizeClosure { _ = window?.removeEventListener?("resize", onResize) }
        if let onEnter = dragEnterClosure { _ = window?.removeEventListener?("dragenter", onEnter) }
        if let onLeave = dragLeaveClosure { _ = window?.removeEventListener?("dragleave", onLeave) }
        if let onDrop = dragResetDropClosure { _ = window?.removeEventListener?("drop", onDrop) }
        if let onDragEnd = dragResetEndClosure { _ = window?.removeEventListener?("dragend", onDragEnd) }
        // swStateChangeClosures is cleared below without individually removing each
        // listener: this teardown only runs while the backend itself is being
        // discarded (a hydration-mismatch remount), and that discard path
        // completes before the register() promise ever resolves — so no
        // statechange listener has been attached yet, and the array cannot
        // outlive the backend regardless.
        if let reg = swRegistration, let onUpdateFound = swUpdateFoundClosure {
            _ = reg.removeEventListener?("updatefound", onUpdateFound)
        }
        swUpdateFoundClosure = nil
        swStateChangeClosures = []
        swRegistration = nil
        schemeClosure = nil
        onlineClosure = nil
        offlineClosure = nil
        storageClosure = nil
        windowScrollClosure = nil
        windowResizeClosure = nil
        colorSchemeQuery = nil
        reduceMotionClosure = nil
        reduceMotionQuery = nil
        dragEnterClosure = nil
        dragLeaveClosure = nil
        dragResetDropClosure = nil
        dragResetEndClosure = nil
        dragDepth = 0
        for observer in domObservers.values { _ = observer.disconnect?() }
        domObservers = [:]
        observerClosures = [:]
        observerIDs = [:]
    }
    public func setLinks(_ links: [LinkTag]) {
        // Churn guard: skip remove-all/re-add-all when the set is unchanged (e.g.
        // title-only navigations), avoiding <link rel="stylesheet"> FOUC. The
        // first call after hydration still re-applies the SSG-emitted set once —
        // this backend has no cheap way to verify DOM state matches lastAppliedLinks
        // (nil) before that — a known, ledgered one-time churn.
        guard lastAppliedLinks != links else { return }
        // A client-declared canonical beside the prerender's surviving one is two
        // `rel=canonical` with different hrefs, which Google discards outright —
        // worse than the missing canonical this whole split avoids. Same policy
        // as a URL move: drop the prerender's set, never reconcile it.
        if links.contains(where: { $0.attributes["rel"] == "canonical" }) { dropPrerenderedHeadLinks() }
        // Replace ONLY the managed set (spec §9): marked data-swiftwui.
        let old = jsDocument.querySelectorAll("link[data-swiftwui]").object
        let n = Int(old?.length.number ?? 0)
        for i in (0..<n).reversed() {
            if let el = old?[i].object {
                _ = el.parentNode.object?.removeChild?(el)
            }
        }
        guard let head = jsDocument.head.object else { return }
        for link in links {
            let el = jsDocument.createElement("link").object!
            for name in link.attributes.keys.sorted() {
                _ = el.setAttribute?(name, link.attributes[name]!)
            }
            _ = el.setAttribute?("data-swiftwui", "")
            _ = head.appendChild?(el)
        }
        lastAppliedLinks = links
    }

    // MARK: Animations (task 14, anim spec §8) — real WAAPI via dynamic JSObject calls.
    @discardableResult
    public func animate(_ node: JSObject, request: AnimationRequest,
                         onSettle: @escaping (AnimationSettle) -> Void) -> AnimationToken? {
        var keyframes: [[String: JSValue]] = []
        if let from = request.from {
            keyframes.append([request.property: .string(from), "offset": .number(0)])
        }
        if let to = request.to {
            keyframes.append([request.property: .string(to)])
        }
        let timing = request.timing
        let options = JSObject.global.Object.function!.new()
        options.duration = .number(timing.durationMs)
        options.delay = .number(timing.delayMs)
        options.easing = .string(resolvedEasing(timing.easing))
        options.iterations = .number(timing.iterations)   // already .infinity when isInfinite
        options.direction = .string(timing.autoreverses ? "alternate" : "normal")
        options.composite = .string(request.mode == .additive ? "add" : "replace")
        options.fill = "none"

        guard let anim = node.animate?(keyframes.jsValue, options.jsValue).object else { return nil }

        let token = DOMAnimationToken(animation: anim, isInfinite: timing.isInfinite)
        token.settle = onSettle
        liveAnimationTokens[ObjectIdentifier(token)] = token
        installVisibilityListenerIfNeeded()

        let onFinished = JSOneshotClosure { [weak self, weak token] _ in
            guard let self, let token else { return .undefined }
            self.settleOnce(token, reason: .finished)
            return .undefined
        }
        let onRejected = JSOneshotClosure { [weak self, weak token] _ in
            guard let self, let token else { return .undefined }
            self.settleOnce(token, reason: .cancelled)
            return .undefined
        }
        _ = anim.finished.object?.then?(onFinished, onRejected)
        token.closures = [onFinished, onRejected]

        // Timeout race (anim spec §7.3.3): the `finished` promise can hang
        // (e.g. a display:none ancestor pauses the animation) — force it after
        // the animation's TOTAL wall-clock runtime + a 200ms margin. WAAPI
        // counts each `alternate` leg as one iteration, so total is simply
        // duration × iterations regardless of autoreverses. Infinite animations
        // never finish by design, so they get no timeout.
        if !timing.isInfinite {
            let timeoutClosure = JSOneshotClosure { [weak self, weak token] _ in
                guard let self, let token else { return .undefined }
                _ = token.animation.cancel?()
                self.settleOnce(token, reason: .forced)
                return .undefined
            }
            let total = timing.durationMs * max(timing.iterations, 1) + timing.delayMs + 200
            token.timeoutID = JSObject.global.setTimeout!(timeoutClosure, total)
            token.closures.append(timeoutClosure)
        }
        return token
    }

    public func cancelAnimation(_ token: AnimationToken) {
        guard let t = token as? DOMAnimationToken else { return }
        _ = t.animation.cancel?()
        settleOnce(t, reason: .cancelled)
    }

    public func finishAnimation(_ token: AnimationToken) {
        guard let t = token as? DOMAnimationToken else { return }
        forceFinish(t)
    }

    /// WAAPI throws InvalidStateError on `finish()` of an infinite animation —
    /// `cancel()` instead for those. Shared by `finishAnimation` and the
    /// visibilitychange handler (both are "force-finish every live token").
    private func forceFinish(_ token: DOMAnimationToken) {
        if token.isInfinite {
            _ = token.animation.cancel?()
        } else {
            _ = token.animation.finish?()
        }
        settleOnce(token, reason: .forced)
    }

    /// Guards `settled`, clears the timeout, drops the table entry, and fires
    /// `onSettle` exactly once — every settle path (finished/timeout/cancel/
    /// finish/visibility) funnels through here.
    private func settleOnce(_ token: DOMAnimationToken, reason: AnimationSettle.Reason) {
        guard !token.settled else { return }
        token.settled = true
        liveAnimationTokens[ObjectIdentifier(token)] = nil
        if let t = token.timeoutID { _ = JSObject.global.clearTimeout?(t) }
        token.timeoutID = nil
        // Deterministically free every host-func box, whichever fired or not.
        // JSOneshotClosure.release() is an idempotent dict removal — releasing
        // the already-fired one again is harmless (the `settled` guard above
        // makes this whole block run once regardless).
        for c in token.closures { c.release() }
        token.closures = []
        let settle = token.settle
        token.settle = nil
        settle?(AnimationSettle(reason: reason))
    }

    /// One document-level listener, page lifetime (anim spec §7.3.3): the tab
    /// going to the background force-finishes every in-flight animation so it
    /// doesn't hang forever behind a throttled rAF/timer.
    private func installVisibilityListenerIfNeeded() {
        guard visibilityChangeClosure == nil else { return }
        let closure = JSClosure { [weak self] _ in
            guard let self, self.jsDocument.hidden.boolean == true else { return .undefined }
            for token in Array(self.liveAnimationTokens.values) {   // snapshot: forceFinish mutates the table
                self.forceFinish(token)
            }
            return .undefined
        }
        _ = jsDocument.addEventListener("visibilitychange", closure)
        visibilityChangeClosure = closure
    }

    /// CSS `linear(...)` easing (emitted by SpringSolver) isn't supported by
    /// every engine yet — probe once and fall back to "ease-out" (anim spec §13).
    /// The plain "linear" keyword is universally supported and never rewritten.
    private func resolvedEasing(_ easing: String) -> String {
        guard easing.hasPrefix("linear(") else { return easing }
        if linearEasingSupported == nil {
            linearEasingSupported = JSObject.global.CSS.object?
                .supports?("animation-timing-function", "linear(0, 1)").boolean ?? false
        }
        return linearEasingSupported == true ? easing : "ease-out"
    }

    // MARK: View transitions (spec 2026-07-26 §3.1, §5.3)
    public func performViewTransition(_ options: ViewTransitionOptions,
                                      update: @escaping () -> Void) {
        guard !forceFlipFallback,
              jsDocument.startViewTransition.function != nil else {
            performFlipTransition(options, update: update)
            return
        }
        installPageHideSkipIfNeeded()

        vtGeneration += 1
        let generation = vtGeneration
        let root = jsDocument.documentElement.object
        // Set BEFORE the call: the old frame is captured at the rendering
        // opportunity AFTER it, so these attributes are live during that capture.
        // User CSS must therefore not key real (non-pseudo) styles off them.
        if let preset = options.presetName { _ = root?.setAttribute?("data-swui-vt", preset) }
        if let direction = options.direction {
            _ = root?.setAttribute?("data-swui-nav", direction.rawValue)
        } else {
            // A directionless transition (e.g. `withViewTransition`, no
            // navigation) must not inherit a PREVIOUS transition's attribute —
            // otherwise it plays that transition's reversed `pop` variant.
            _ = root?.removeAttribute?("data-swui-nav")
        }

        let callback = JSOneshotClosure { _ in
            update()
            return .undefined
        }
        vtClosuresByGeneration[generation, default: []].append(callback)
        guard let transition = jsDocument.startViewTransition(callback).object else {
            // Threw or returned nothing: run the commit inline rather than
            // stranding it. The Runtime's `ran` guard makes a late platform
            // call harmless. `callback` never reached the JS engine here, so
            // it must be released explicitly or it leaks its host-func box.
            update()
            clearTransitionAttributes(generation: generation)
            releaseTransitionClosures(generation: generation)
            return
        }
        activeTransition = transition

        // `ready` rejects on EVERY skip — duplicate names, hidden tab
        // (InvalidStateError), superseded by a newer transition (AbortError).
        // Without this, ordinary double-clicks log unhandled rejections.
        let onReadyRejected = JSOneshotClosure { _ in .undefined }
        _ = transition.ready.object?.catch?(onReadyRejected)
        vtClosuresByGeneration[generation, default: []].append(onReadyRejected)

        // `finished` RESOLVES on a skip but REJECTS when the update callback
        // rejects, so both branches must clean up.
        let cleanup = JSOneshotClosure { [weak self] _ in
            self?.finishTransition(generation: generation)
            return .undefined
        }
        let cleanupRejected = JSOneshotClosure { [weak self] _ in
            self?.finishTransition(generation: generation)
            return .undefined
        }
        _ = transition.finished.object?.then?(cleanup, cleanupRejected)
        vtClosuresByGeneration[generation, default: []].append(cleanup)
        vtClosuresByGeneration[generation, default: []].append(cleanupRejected)

        // Watchdog for the one case the platform does not guarantee: the update
        // callback is scheduled, never synchronous, so a document torn down
        // inside the capture window never delivers it. Idempotent thanks to the
        // Runtime's `ran` guard. The timer id is kept so a normal settle can
        // cancel it first (see finishTransition) — an already-fired setTimeout
        // invoking a released host function is a hard crash, not a no-op.
        let watchdog = JSOneshotClosure { _ in
            update()
            return .undefined
        }
        if let timeoutID = JSObject.global.setTimeout?(watchdog, options.durationMS + 1000) {
            vtTimeoutIDByGeneration[generation] = timeoutID
        }
        vtClosuresByGeneration[generation, default: []].append(watchdog)
    }

    private func finishTransition(generation: Int) {
        clearTransitionAttributes(generation: generation)
        if generation == vtGeneration { activeTransition = nil }
        // Cancel the watchdog BEFORE releasing its closure: clearTimeout makes
        // the pending timer inert, so releasing right after can never race an
        // in-flight firing that would call into a released host function.
        if let timeoutID = vtTimeoutIDByGeneration.removeValue(forKey: generation) {
            _ = JSObject.global.clearTimeout?(timeoutID)
        }
        releaseTransitionClosures(generation: generation)
    }

    /// Deterministically frees every host-func box retained for ONE
    /// generation — same discipline as DOMAnimationToken.settleOnce
    /// (`animate` above), but scoped per-transition: a superseded transition's
    /// promises can settle after a newer one has already started, and a
    /// shared retention pool would let that stale settle release the newer
    /// transition's still-pending closures out from under it. `release()` is
    /// an idempotent dict removal, so releasing an already-self-released
    /// (invoked) closure again is harmless. Without this call, the losing
    /// ready/finished branch on every single transition would leak its
    /// host-func box permanently: dropping the Swift-side array reference
    /// does not free it, since JSOneshotClosure's own static registry
    /// independently retains it until `release()` runs.
    private func releaseTransitionClosures(generation: Int) {
        guard let closures = vtClosuresByGeneration.removeValue(forKey: generation) else { return }
        for c in closures { c.release() }
    }

    /// Generation-tokened: a newer transition may already have written its own
    /// attributes (a second navigation aborts the first mid-animation), and an
    /// untokened cleanup would wipe them.
    private func clearTransitionAttributes(generation: Int) {
        guard generation == vtGeneration, let root = jsDocument.documentElement.object else { return }
        _ = root.removeAttribute?("data-swui-vt")
        _ = root.removeAttribute?("data-swui-nav")
    }

    private func installPageHideSkipIfNeeded() {
        guard pageHideClosure == nil else { return }
        let closure = JSClosure { [weak self] _ in
            _ = self?.activeTransition?.skipTransition?()
            return .undefined
        }
        _ = JSObject.global.window.object?.addEventListener?("pagehide", closure)
        pageHideClosure = closure      // retained for the backend's lifetime, like the others
    }

    private struct FlipRect {
        let left: Double, top: Double, width: Double, height: Double
    }

    /// Fallback for browsers without the View Transitions API (and for
    /// `?swui-vt=flip`). Deliberately partial — §7 of the spec lists every
    /// degradation, and they are documented in the DocC article too. Notably: a
    /// named element nested inside another named element rides its ancestor's
    /// morph instead of animating independently (see the ancestor-skip below).
    private func performFlipTransition(_ options: ViewTransitionOptions,
                                       update: @escaping () -> Void) {
        let before = measureNamedHosts()
        update()
        let after = measureNamedHosts()

        // Outermost-first, SKIPPING any name whose nearest named ancestor is
        // already animating: CSS transforms compound down the subtree, so an
        // ancestor's `scale` already applies to its descendants' rendering —
        // giving the descendant its own scale on top would double-transform it
        // (the hero + form case in the spec's own example, where the hero
        // itself scales). Compensating only translate (not scale) was tried and
        // is wrong; riding the ancestor's morph is the correct visual result
        // when the ancestor moves-only too, since the two deltas are then equal
        // and this same guard already no-ops the descendant.
        var applied: [JSObject] = []
        for (name, newRect) in after.sorted(by: { depth(of: $0.value.host) < depth(of: $1.value.host) }) {
            guard let old = before[name],
                  !applied.contains(where: { isAncestor($0, of: newRect.host) }) else { continue }
            let dx = old.rect.left - newRect.rect.left
            let dy = old.rect.top - newRect.rect.top
            let sx = newRect.rect.width > 0 ? old.rect.width / newRect.rect.width : 1
            let sy = newRect.rect.height > 0 ? old.rect.height / newRect.rect.height : 1
            guard dx != 0 || dy != 0 || sx != 1 || sy != 1 else { continue }
            animateFlip(newRect.host, dx: dx, dy: dy, sx: sx, sy: sy, durationMS: options.durationMS)
            applied.append(newRect.host)
        }
    }

    /// Document coordinates, not viewport: the two measurements straddle a full
    /// subtree replacement that can change document height, clamp `scrollTop`,
    /// or trip scroll anchoring, and an uncompensated delta would carry the
    /// scroll difference into every element.
    private func measureNamedHosts() -> [String: (rect: FlipRect, host: JSObject)] {
        let scrollX = JSObject.global.window.scrollX.number ?? 0
        let scrollY = JSObject.global.window.scrollY.number ?? 0
        var out: [String: (FlipRect, JSObject)] = [:]
        for (name, host) in namedHosts {
            guard host.isConnected.boolean == true,
                  let r = host.getBoundingClientRect?().object else { continue }
            let rect = FlipRect(left: (r.left.number ?? 0) + scrollX,
                                top: (r.top.number ?? 0) + scrollY,
                                width: r.width.number ?? 0,
                                height: r.height.number ?? 0)
            out[name] = (rect, host)
        }
        return out
    }

    /// Local copy of `SwiftWUI.cssNumber` — that one is internal to the
    /// `SwiftWUI` module and not visible here (task scope is `SwiftWUIDOM`
    /// only). Integer-valued doubles render without a trailing ".0".
    private func cssNumber(_ d: Double) -> String {
        if d == d.rounded(), abs(d) < 1e15 { return String(Int(d)) }
        return String(d)
    }

    private func animateFlip(_ host: JSObject, dx: Double, dy: Double,
                             sx: Double, sy: Double, durationMS: Double) {
        // `transform-origin` defaults to `50% 50%`, so `scale` happens about
        // the center while `dx`/`dy` were computed from top-left corners —
        // without pinning it to `0 0` on both keyframes, the first frame is
        // off by half the size delta on each axis whenever the element
        // resizes (the exact case this fallback exists for).
        let from: [String: JSValue] = [
            "translate": .string("\(cssNumber(dx))px \(cssNumber(dy))px"),
            "scale": .string("\(cssNumber(sx)) \(cssNumber(sy))"),
            "transform-origin": .string("0 0"),
        ]
        let to: [String: JSValue] = ["translate": .string("none"), "scale": .string("none"),
                                     "transform-origin": .string("0 0")]
        let options = JSObject.global.Object.function!.new()
        options.duration = .number(durationMS)
        options.easing = .string("ease")
        // `backwards`, not `none`: an effect with no delay applies from its
        // start time on the NEXT frame, so `none` lets the element paint one
        // frame at its final position.
        options.fill = .string("backwards")
        _ = host.animate?([from, to].jsValue, options.jsValue)
    }

    private func depth(of node: JSObject) -> Int {
        var n = 0
        var current = node.parentElement.object
        while let c = current { n += 1; current = c.parentElement.object }
        return n
    }

    private func isAncestor(_ candidate: JSObject, of node: JSObject) -> Bool {
        candidate.contains?(node).boolean == true && candidate != node
    }

    // MARK: Web storage (phase 8a)
    private func storageObject(_ kind: StorageKind) -> JSObject? {
        let window = JSObject.global.window.object
        return kind == .local ? window?.localStorage.object : window?.sessionStorage.object
    }
    public func storageRead(kind: StorageKind, key: String) -> String? {
        storageObject(kind)?.getItem?(key).string
    }
    public func storageWrite(kind: StorageKind, key: String, value: String?) {
        guard let s = storageObject(kind) else { return }
        if let value {
            // setItem can throw (QuotaExceededError, disabled storage). Use the
            // throwing call so a full/blocked store degrades to a warning, not a trap.
            do {
                _ = try s.throwing.setItem?(key, value)
            } catch {
                print("SwiftWUI storage: write for '\(key)' failed — \(error)")
            }
        } else {
            _ = s.removeItem?(key)
        }
    }
    public func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void) {
        let closure = JSClosure { args in
            guard let e = args.first?.object else { return .undefined }
            // The storage event fires cross-document for localStorage. key == null
            // means clear() — no per-key delivery; ignored (ledgered residual).
            guard let key = e.key.string else { return .undefined }
            onExternalChange(.local, key, e.newValue.string)
            return .undefined
        }
        _ = JSObject.global.window.object?.addEventListener?("storage", closure)
        storageClosure = closure
    }

    // MARK: Localization (spec 2026-07-28)
    public func setDocumentLanguage(_ lang: String, dir: String?) {
        guard let root = jsDocument.documentElement.object else { return }
        _ = root.setAttribute?("lang", lang)
        if let dir { _ = root.setAttribute?("dir", dir) }
        else { _ = root.removeAttribute?("dir") }
    }

    public func preferredLanguages() -> [String] {
        guard let nav = JSObject.global.navigator.object else { return [] }
        if let list = nav.languages.object {
            let count = Int(list.length.number ?? 0)
            return (0..<count).compactMap { list[$0].string }
        }
        return [nav.language.string].compactMap { $0 }
    }

    public func readCookie(_ name: String) -> String? {
        guard let jar = jsDocument.cookie.string else { return nil }
        for pair in jar.split(separator: ";") {
            let trimmed = pair.drop(while: { $0 == " " })
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            if trimmed[trimmed.startIndex..<eq] == name {
                return String(trimmed[trimmed.index(after: eq)...])
            }
        }
        return nil
    }

    public func writeCookie(_ name: String, value: String, maxAgeDays: Int, secure: Bool) {
        // Values are validated locale tags; refuse anything else rather than
        // letting a stray ';' forge cookie attributes. Empty is refused too: a
        // bare `swiftwui_locale=` reads back as "" — a jar entry that says a
        // locale was chosen while carrying no tag.
        guard !value.isEmpty,
              value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { return }
        var cookie = "\(name)=\(value); path=/; max-age=\(maxAgeDays * 86_400); SameSite=Lax"
        if secure { cookie += "; Secure" }
        jsDocument.cookie = .string(cookie)
    }

    // MARK: Hydration read API (phase 5, spec §10)
    public func childCount(of node: JSObject) -> Int {
        Int(node.childNodes.length.number ?? 0)
    }
    public func child(of node: JSObject, at index: Int) -> JSObject {
        let c = node.childNodes.item(index).object!
        // Adopted nodes (hydration) never went through createElement/createTextNode,
        // so they lack the __swuid stamp — without it every adopted node's
        // closureKey collapses to "-1#event" (C1: listener registry collisions).
        if c.__swuid.isUndefined || c.__swuid.isNull {
            c.__swuid = .number(Double(nextUID)); nextUID += 1
        }
        return c
    }
    public func tagName(of node: JSObject) -> String? {
        // nodeType 1 = element; DOM tagName is uppercase — normalize.
        guard node.nodeType.number == 1 else { return nil }
        return node.tagName.string?.lowercased()
    }
}
#endif
