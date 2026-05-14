import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit

private func installThemeCSS() {
    guard let document = JSObject.global.document.object,
          let head = document.head.object,
          let style = document.createElement?("style").object else { return }
    _ = style.setAttribute?("data-swui-theme", "showcase")
    style.textContent = .string(ShowcaseTheme.css)
    _ = head.appendChild?(style)
}
#else
private func installThemeCSS() {}
#endif

installThemeCSS()

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
    return .undefined
}
_ = document.addEventListener?("click", clickHandler)

// Listen for back/forward navigation so the browser buttons keep the
// router in sync.
let popHandler = JSClosure { _ -> JSValue in
    if let pathname = JSObject.global.window.object?.location.object?.pathname.string {
        QueryParamContext.router?.navigate(to: pathname)
    }
    return .undefined
}
_ = JSObject.global.window.object?.addEventListener?("popstate", popHandler)
#endif
