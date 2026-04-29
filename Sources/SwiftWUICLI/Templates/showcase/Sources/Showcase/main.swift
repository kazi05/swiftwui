import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit

private func installThemeCSS() {
    let css = ThemeCSS.definitions(light: {{PROJECT_NAME}}Theme.light, dark: {{PROJECT_NAME}}Theme.dark)
    guard let document = JSObject.global.document.object,
          let head = document.head.object,
          let style = document.createElement?("style").object else {
        return
    }
    _ = style.setAttribute?("data-swui-theme", "{{project_name}}")
    style.textContent = .string(css)
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
