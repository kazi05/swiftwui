#if arch(wasm32)
import JavaScriptKit
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
    // PWA service-worker wiring (spec 2026-07-12) — retained for backend lifetime.
    private var swUpdateFoundClosure: JSClosure?
    private var swStateChangeClosures: [JSClosure] = []
    private var swRegistration: JSObject?
    private var lastAppliedLinks: [LinkTag]? = nil   // churn guard (setLinks) — nil means "never applied"

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
    public func setProperty(_ node: JSObject, name: String, value: PropertyValue) {
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

    static func decodePayload(event: String, jsEvent e: JSObject) -> Any {
        let target = e.target.object
        switch event {
        case "input":
            return InputEvent(value: target?.value.string ?? "")
        case "change":
            if let t = target, t.type.string == "file", let files = t.files.object {
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
                return FilesEvent(files: out)
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
        registerServiceWorkerIfConfigured(writer)
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
        if let onOnline = onlineClosure { _ = window?.removeEventListener?("online", onOnline) }
        if let onOffline = offlineClosure { _ = window?.removeEventListener?("offline", onOffline) }
        if let onStorage = storageClosure { _ = window?.removeEventListener?("storage", onStorage) }
        if let onScroll = windowScrollClosure { _ = window?.removeEventListener?("scroll", onScroll) }
        if let onResize = windowResizeClosure { _ = window?.removeEventListener?("resize", onResize) }
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
