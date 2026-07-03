import SwiftWUI

#if arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop

/// Startup canary (spec §6, decision 13): if reflection metadata was stripped,
/// Mirror finds nothing and every @State would silently reset each render.
@MainActor private struct _ReflectionProbe { @State var probe = 0 }
@MainActor private func assertReflectionAlive() {
    let found = Mirror(reflecting: _ReflectionProbe()).children
        .contains { $0.value is _StateProperty }
    precondition(found, """
        SwiftWUI: reflection metadata is unavailable — @State cannot persist. \
        Remove -disable-reflection-metadata from the build.
        """)
}

@MainActor private final class DispatchBox {
    var fn: (ListenerID, Any?) -> Void = { _, _ in }
}

@MainActor private func jsMicrotask(_ f: @escaping () -> Void) {
    _ = JSObject.global.queueMicrotask!(JSOneshotClosure { _ in
        f()
        return .undefined
    })
}

@MainActor
public enum DOMRuntime {
    private static var retained: [AnyObject] = []      // runtime lives for the page lifetime

    public static func mount(_ root: some Tag, selector: String = "body",
                             globalStyles: [Rule] = [], themes: [ThemeDefinition] = []) {
        JavaScriptEventLoop.installGlobalExecutor()
        assertReflectionAlive()
        let document = JSObject.global.document
        let container: JSObject = selector == "body"
            ? document.body.object!
            : document.querySelector(selector).object!
        let box = DispatchBox()
        let backend = DOMBackend(dispatch: { box.fn($0, $1) })
        let location = JSObject.global.location
        let initialPath = (location.pathname.string ?? "/") + (location.search.string ?? "")
        let runtime = Runtime(backend: backend, container: container,
                              root: root, initialPath: initialPath,
                              scheduleMicrotask: jsMicrotask,
                              globalStyles: globalStyles, themes: themes)
        box.fn = { [weak runtime] in runtime?.dispatch($0, payload: $1) }
        retained.append(runtime)
        retained.append(backend)
        runtime.mount()
        let popstate = JSClosure { [weak runtime] _ in
            let loc = JSObject.global.location
            runtime?.handlePopState(url: (loc.pathname.string ?? "/") + (loc.search.string ?? ""))
            return .undefined
        }
        _ = JSObject.global.window.object?.addEventListener?("popstate", popstate)
        retained.append(popstate)                 // JSClosure must outlive the page (v1 lesson)
        _ = container.setAttribute?("data-swui-mounted", "true")   // test-sync hook (v1 lesson)
    }
}

extension App {
    @MainActor public static func main() {
        DOMRuntime.mount(Self().body, globalStyles: Self.globalStyles, themes: Self.themes)
    }
}
#else
extension App {
    public static func main() {
        fatalError("SwiftWUIDOM requires wasm32. Use HTMLRenderer for native rendering.")
    }
}
#endif
