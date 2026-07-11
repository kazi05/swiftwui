#if arch(wasm32)
import JavaScriptKit
import SwiftWUI

/// JSObject glue. All bookkeeping keys use the __swuid int stamped at creation —
/// NEVER ObjectIdentifier(JSObject) (spec §8.5 invariant 4, trap T5).
@MainActor
public final class DOMBackend: RendererBackend {
    public typealias HostNode = JSObject

    private let document = JSObject.global.document
    private let dispatch: (ListenerID, Any?) -> Void
    private var closures: [String: JSClosure] = [:]   // "\(uid)#\(event)" → retained
    private var listenerIDs: [String: ListenerID] = [:]
    private var nextUID = 0
    // Environment observation closures — named (not positional) so teardown pairs
    // each with its exact target; retained for backend lifetime (v1 leak lesson).
    private var schemeClosure: JSClosure?
    private var onlineClosure: JSClosure?
    private var offlineClosure: JSClosure?
    private var storageClosure: JSClosure?          // window "storage" event — same teardown as above
    private var colorSchemeQuery: JSObject?        // keep the MediaQueryList alive with its listener
    private var lastAppliedLinks: [LinkTag]? = nil   // churn guard (setLinks) — nil means "never applied"

    public init(dispatch: @escaping (ListenerID, Any?) -> Void) { self.dispatch = dispatch }

    public func createElement(_ tag: String) -> JSObject {
        let el = document.createElement(tag).object!
        el.__swuid = .number(Double(nextUID)); nextUID += 1
        return el
    }
    public func createTextNode(_ text: String) -> JSObject {
        let n = document.createTextNode(text).object!
        n.__swuid = .number(Double(nextUID)); nextUID += 1
        return n
    }
    public func setText(_ node: JSObject, _ text: String) { node.data = .string(text) }
    public func setAttribute(_ node: JSObject, name: String, value: String) {
        _ = node.setAttribute?(name, value)
    }
    public func removeAttribute(_ node: JSObject, name: String) {
        _ = node.removeAttribute?(name)
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
        _ = node.addEventListener?(event, closure)
    }

    static func decodePayload(event: String, jsEvent e: JSObject) -> Any {
        let target = e.target.object
        switch event {
        case "input":
            return InputEvent(value: target?.value.string ?? "")
        case "change":
            return ChangeEvent(value: target?.value.string ?? "",
                               checked: target?.checked.boolean ?? false)
        case "keydown", "keyup":
            return KeyEvent(key: e.key.string ?? "", repeated: e["repeat"].boolean ?? false)
        case "submit":
            _ = e.preventDefault?()
            return SubmitEvent()
        case "focus", "blur":
            return FocusEvent()
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

    public func insert(_ child: JSObject, into parent: JSObject, before anchor: JSObject?) {
        if let anchor { _ = parent.insertBefore?(child, anchor) }
        else { _ = parent.appendChild?(child) }
    }
    public func remove(_ child: JSObject, from parent: JSObject) {
        _ = parent.removeChild?(child)
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
        document.title = .string(title)
    }
    public func setMetaTags(_ tags: [MetaTag]) {
        // Replace ONLY the managed set (spec §9): marked data-swiftwui.
        let old = document.querySelectorAll("meta[data-swiftwui]").object
        let n = Int(old?.length.number ?? 0)
        for i in (0..<n).reversed() {
            if let el = old?[i].object {
                _ = el.parentNode.object?.removeChild?(el)
            }
        }
        guard let head = document.head.object else { return }
        for tag in tags {
            let el = document.createElement("meta").object!
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
        schemeClosure = nil
        onlineClosure = nil
        offlineClosure = nil
        storageClosure = nil
        colorSchemeQuery = nil
    }
    public func setLinks(_ links: [LinkTag]) {
        // Churn guard: skip remove-all/re-add-all when the set is unchanged (e.g.
        // title-only navigations), avoiding <link rel="stylesheet"> FOUC. The
        // first call after hydration still re-applies the SSG-emitted set once —
        // this backend has no cheap way to verify DOM state matches lastAppliedLinks
        // (nil) before that — a known, ledgered one-time churn.
        guard lastAppliedLinks != links else { return }
        // Replace ONLY the managed set (spec §9): marked data-swiftwui.
        let old = document.querySelectorAll("link[data-swiftwui]").object
        let n = Int(old?.length.number ?? 0)
        for i in (0..<n).reversed() {
            if let el = old?[i].object {
                _ = el.parentNode.object?.removeChild?(el)
            }
        }
        guard let head = document.head.object else { return }
        for link in links {
            let el = document.createElement("link").object!
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
