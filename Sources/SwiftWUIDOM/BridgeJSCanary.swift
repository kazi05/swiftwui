#if arch(wasm32)
/// Startup canary (spike for spec §1.4): proves the vendored BridgeJS glue is
/// alive in this deployment. One bridged createElement + setAttribute round trip.
func assertBridgeJSAlive() {
    do {
        let el = try document.createElement("div")
        try el.setAttribute("data-swui-bridge-canary", "1")
    } catch {
        fatalError("SwiftWUI: BridgeJS bridge is not functional: \(error)")
    }
}
#endif
