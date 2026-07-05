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

    private static func makeBackend() -> (backend: DOMBackend, box: DispatchBox) {
        let box = DispatchBox()
        let backend = DOMBackend(dispatch: { box.fn($0, $1) })
        return (backend, box)
    }

    private static func makeRuntime<B: RendererBackend>(
        root: some Tag, backend: B, container: B.HostNode, initialPath: String,
        globalStyles: [Rule], themes: [ThemeDefinition]
    ) -> Runtime<B> {
        Runtime(backend: backend, container: container, root: root, initialPath: initialPath,
                scheduleMicrotask: jsMicrotask, globalStyles: globalStyles, themes: themes)
    }

    /// Seeds a freshly constructed runtime's store/effects from a parsed
    /// snapshot payload (spec §7). Shared by the adopting attempt AND the
    /// cold-mount fallback (carried review: a structure mismatch doesn't mean
    /// the STATE values are invalid — re-seed rather than discard).
    private static func seed<B: RendererBackend>(_ runtime: Runtime<B>, with payload: SnapshotBoot.Payload) {
        runtime._store._pendingRows = payload.rows.mapValues { $0.map(\.raw) }
        runtime._store._decodeSlot = SnapshotBoot.decodeSlot
        runtime._effects._skipBuildTaskKeys = Set(payload.tasks)
    }

    /// Dispatch rebind, retention, popstate wiring, test-sync attributes —
    /// shared tail of every mount path.
    private static func finishMount<B: RendererBackend>(
        runtime: Runtime<B>, box: DispatchBox, raw: DOMBackend, container: JSObject, hydrated: Bool
    ) {
        box.fn = { [weak runtime] in runtime?.dispatch($0, payload: $1) }
        retained.append(runtime)
        retained.append(raw)
        let popstate = JSClosure { [weak runtime] _ in
            let loc = JSObject.global.location
            runtime?.handlePopState(url: (loc.pathname.string ?? "/") + (loc.search.string ?? ""))
            return .undefined
        }
        _ = JSObject.global.window.object?.addEventListener?("popstate", popstate)
        retained.append(popstate)                 // JSClosure must outlive the page (v1 lesson)
        _ = container.setAttribute?("data-swui-mounted", "true")   // test-sync hook (v1 lesson)
        if hydrated {
            _ = container.setAttribute?("data-swui-hydrated", "true")   // browser-test hook
        }
    }

    public static func mount(_ root: some Tag, selector: String = "body",
                             globalStyles: [Rule] = [], themes: [ThemeDefinition] = []) {
        JavaScriptEventLoop.installGlobalExecutor()
        assertReflectionAlive()
        let document = JSObject.global.document
        let container: JSObject = selector == "body"
            ? document.body.object!
            : document.querySelector(selector).object!
        let location = JSObject.global.location
        let initialPath = (location.pathname.string ?? "/") + (location.search.string ?? "")

        // Snapshot present + path matches (spec §7) → attempt adoption. On
        // success we're done; on mismatch (spec D6) we discard the DOM and
        // fall through to the classic mount below, re-seeding it from the
        // SAME parsed payload (never re-read the script tag).
        var fallbackPayload: SnapshotBoot.Payload?
        if let payload = SnapshotBoot.read(currentPath: location.pathname.string ?? "/") {
            let (raw, box) = makeBackend()
            let adopting = AdoptingBackend(base: raw, container: container)
            let runtime = makeRuntime(root: root, backend: adopting, container: container,
                                      initialPath: initialPath,
                                      globalStyles: globalStyles, themes: themes)
            seed(runtime, with: payload)
            runtime.mount()
            if adopting.finishAdoption() {
                SnapshotBoot.removeScriptTag()
                finishMount(runtime: runtime, box: box, raw: raw, container: container, hydrated: true)
                return
            }
            // Mismatch: discard everything, cold-boot below. The discarded
            // runtime's client .task effects already started real Tasks (I1) —
            // cancel them first or they outlive this runtime and duplicate
            // side effects when the fallback re-runs the same loaders.
            runtime._effects._cancelAll()
            while Int(container.childNodes.length.number ?? 0) > 0 {
                _ = container.removeChild?(container.childNodes.item(0))
            }
            retained.removeAll()
            fallbackPayload = payload
        }
        let (raw, box) = makeBackend()
        let runtime = makeRuntime(root: root, backend: raw, container: container,
                                  initialPath: initialPath,
                                  globalStyles: globalStyles, themes: themes)
        if let payload = fallbackPayload { seed(runtime, with: payload) }
        runtime.mount()
        finishMount(runtime: runtime, box: box, raw: raw, container: container, hydrated: false)
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
