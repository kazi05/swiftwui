import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit
import JavaScriptEventLoop

// Drives Swift concurrency on the WASM single-threaded JS event loop.
// Without this, `Task { ... }` bodies never run — `.task` modifiers and
// any async work scheduled from event handlers silently no-op.
JavaScriptEventLoop.installGlobalExecutor()

private func installThemeCSS() {
    guard let document = JSObject.global.document.object,
          let head = document.head.object,
          let style = document.createElement?("style").object else { return }
    _ = style.setAttribute?("data-swui-theme", "showcase")
    style.textContent = .string(ShowcaseTheme.css)
    _ = head.appendChild?(style)
}

// PackageToJS-generated index.html points highlight.js at jsDelivr's
// `npm/lib/core.min.js`, which is the CommonJS build and throws
// `module is not defined` in a browser context — so `window.hljs`
// never gets exported. Install the cdnjs browser bundle from Swift
// instead so the page does not depend on the packaged template.
private func installHighlightJS() {
    guard let document = JSObject.global.document.object,
          let head = document.head.object else { return }
    if document.querySelector?("script[data-swui-hljs]").object != nil { return }

    if let css = document.createElement?("link").object {
        _ = css.setAttribute?("rel", "stylesheet")
        _ = css.setAttribute?("href", "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css")
        _ = css.setAttribute?("data-swui-hljs", "style")
        _ = head.appendChild?(css)
    }

    func addScript(_ src: String, _ tag: String) {
        guard let s = document.createElement?("script").object else { return }
        _ = s.setAttribute?("src", src)
        _ = s.setAttribute?("data-swui-hljs", tag)
        _ = head.appendChild?(s)
    }

    addScript("https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js", "core")

    // Load Swift after the core finishes. Append to head only when
    // window.hljs becomes available so the language plugin sees its host.
    if let swiftScript = document.createElement?("script").object {
        _ = swiftScript.setAttribute?("src", "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/swift.min.js")
        _ = swiftScript.setAttribute?("data-swui-hljs", "swift")
        let onload = JSClosure { _ -> JSValue in
            SyntaxHighlight.apply()
            return .undefined
        }
        swiftScript["onload"] = .object(onload)
        _ = head.appendChild?(swiftScript)
    }
}
#else
private func installThemeCSS() {}
private func installHighlightJS() {}
#endif

installThemeCSS()
installHighlightJS()

let app = Application {
    Route("/")                { HomePage() }
    Route("/learn/hello")     { HelloPage() }
    Route("/learn/state")     { StatePage() }
    Route("/learn/modifiers") { ModifiersPage() }
    Route("/learn/lists")     { ListsPage() }
    Route("/learn/forms")     { FormsPage() }
    Route("/learn/routing")   { RoutingPage() }
    Route("/learn/async")     { AsyncPage() }
    Route("/learn/theming")   { ThemingPage() }
    Route("/learn/a11y")      { A11yPage() }
    Route("/learn/errors")    { ErrorsPage() }
    Route("/learn/ssr")       { SSRPage() }
    Route("/learn/pwa")       { PWAPage() }
}
app.mount()

// Sync initial route to current browser URL. Without this the Router
// boots at "/" regardless of where the user landed (deep-link, refresh,
// shared chapter URL). Framework lacks a built-in window.location bridge.
#if canImport(JavaScriptKit)
if let location = JSObject.global.window.object?.location.object,
   let pathname = location.pathname.string,
   pathname != "/" {
    QueryParamContext.router?.navigate(to: pathname)
}

// SPA nav reuses scrolly DOM nodes across chapters, so `.task` mount
// only fires on the first chapter. Schedule a re-scan after every
// navigation so new chapters install their IntersectionObserver.
@MainActor
private func scheduleScrollyRescan() {
    _ = JSObject.global.queueMicrotask?(JSOneshotClosure { _ in
        scanAndInstallScrollyObservers()
        SyntaxHighlight.apply()
        return .undefined
    })
}

// Intercept anchor clicks so SPA navigation does not trigger full page
// reloads. Without this, every <a href="/learn/...">  click reloads the
// page; the IntersectionObserver scrolly state is lost on every nav.
let document = JSObject.global.document.object!
let clickHandler = JSClosure { args -> JSValue in
    guard let event = args.first?.object,
          var target = event.target.object else { return .undefined }
    // Walk up to the nearest <a>.
    while let tagName = target.tagName.string, tagName.uppercased() != "A" {
        guard let parent = target.parentElement.object else { return .undefined }
        target = parent
    }
    guard let href = target.getAttribute?("href").string,
          href.hasPrefix("/"),
          !href.hasPrefix("//") else { return .undefined }
    _ = event.preventDefault?()
    QueryParamContext.router?.navigate(to: href)
    if let history = JSObject.global.window.object?.history.object {
        _ = history.pushState!(JSValue.null, JSValue.string(""), JSValue.string(href))
    }
    MainActor.assumeIsolated { scheduleScrollyRescan() }
    return .undefined
}
_ = document.addEventListener?("click", clickHandler)

// Listen for back/forward navigation so the browser buttons keep the
// router in sync.
let popHandler = JSClosure { _ -> JSValue in
    if let pathname = JSObject.global.window.object?.location.object?.pathname.string {
        QueryParamContext.router?.navigate(to: pathname)
    }
    MainActor.assumeIsolated { scheduleScrollyRescan() }
    return .undefined
}
_ = JSObject.global.window.object?.addEventListener?("popstate", popHandler)

// Initial scan covers the chapter that hydrated on first load.
MainActor.assumeIsolated { scheduleScrollyRescan() }
#endif
