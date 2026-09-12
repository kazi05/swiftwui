#if arch(wasm32) && DEBUG
import SwiftWUI
import JavaScriptKit

extension DOMRuntime {
    /// Call before mount in a debug build. Inspect
    /// `window.__swiftwui_diagnostics` from browser DevTools. The bounded ring
    /// contains metadata only; text, field values and attributes are excluded.
    public static func enableDevTools(limit: Int = 100) {
        let events = JSObject.global.Array.function!.new()
        JSObject.global.__swiftwui_diagnostics = .object(events)
        diagnostics = RuntimeDiagnostics(includeTreeStatistics: true, includeComponentTree: true) { event in
            let item = JSObject.global.Object.function!.new()
            switch event {
            case .render(let render):
                item.kind = .string("render")
                item.phase = .string(String(describing: render.kind))
                item.reasons = .string(render.reasons.map { String(describing: $0) }.joined(separator: ", "))
                item.durationMS = .number(Double(render.duration.components.seconds) * 1000 + Double(render.duration.components.attoseconds) / 1e15)
                item.dirty = .number(Double(render.dirtyIdentityCount))
                item.passes = .number(Double(render.passCount))
                item.listeners = .number(Double(render.lifetimes.listeners))
                item.effects = .number(Double(render.lifetimes.effects))
                let tree = JSObject.global.Array.function!.new()
                for component in render.componentTree ?? [] {
                    let node = JSObject.global.Object.function!.new()
                    node.identity = .string(String(describing: component.identity))
                    node.type = .string(component.typeName)
                    node.parent = component.parentIdentity.map { .string(String(describing: $0)) } ?? .null
                    _ = tree.push?(node)
                }
                item.components = .object(tree)
            case .adoption(let adoption):
                item.kind = .string("adoption")
                item.outcome = .string(String(describing: adoption.outcome))
                item.message = adoption.message.map(JSValue.string) ?? .null
                item.consumed = .number(Double(adoption.consumedNodes))
                item.available = .number(Double(adoption.availableNodes))
            }
            _ = events.push?(item)
            while Int(events.length.number ?? 0) > max(1, limit) { _ = events.shift?() }
        }
    }
}
#endif
