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
}
#endif
