// ServiceWorker.swift - Service worker registration helper.
//
// Service workers run in the background, intercepting network requests,
// caching responses for offline use, and handling push notifications.
// SwiftWUI does not (yet) ship a Swift-authored worker — the worker
// must still be a JavaScript file the browser can boot before the WASM
// bundle is even loaded — but we provide the registration plumbing so
// app code can install the worker with a single call from `Application.mount`.

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

/// Service worker registration helper.
///
/// ```swift
/// // In your app's main:
/// let app = Application { Route("/") { HomePage() } }
/// app.mount()
/// ServiceWorker.register(at: "/sw.js")
/// ```
///
/// The worker file itself is plain JavaScript that the user authors
/// once and ships as a static asset. SwiftWUI's
/// `Application.renderHTMLDocument(_:)` does not auto-inject the
/// worker reference — apps decide when to register, since service
/// workers cache aggressively and are easy to misconfigure.
public enum ServiceWorker {
    /// Register a service worker file by URL. No-op on browsers that
    /// don't support service workers, on insecure contexts, and on
    /// non-WASM builds (server / test).
    public static func register(at scriptURL: String, scope: String? = nil) {
        #if canImport(JavaScriptKit)
        let nav = JSObject.global.navigator.object
        guard let nav, nav.serviceWorker.object != nil else { return }
        if let scope {
            let opts = JSObject.global.Object.function!.new()
            opts["scope"] = .string(scope)
            _ = nav.serviceWorker.object!.register!(scriptURL, opts)
        } else {
            _ = nav.serviceWorker.object!.register!(scriptURL)
        }
        #endif
    }

    /// Unregister all service workers controlling the current page.
    /// Useful in development when a stale cached worker is masking
    /// new code.
    public static func unregisterAll() {
        #if canImport(JavaScriptKit)
        guard let nav = JSObject.global.navigator.object,
              let sw = nav.serviceWorker.object else { return }
        let promise = sw.getRegistrations!()
        // Fire-and-forget — we don't await the promise, the unregister
        // calls happen lazily as the iteration callback fires.
        let then = promise.then.function
        _ = then?(JSOneshotClosure { args in
            guard let regs = args.first?.object else { return .undefined }
            let length = Int(regs.length.number ?? 0)
            for i in 0..<length {
                if let reg = regs[i].object {
                    _ = reg.unregister!()
                }
            }
            return .undefined
        })
        #endif
    }
}
