import SwiftWUI

struct PlaceholderPage: Tag {
    let title: String
    var body: some Tag {
        Div {
            H1 { Text(title) }
            P { Text("Coming soon — chapter content lands in Phase 4.") }
        }
        .padding(.px(48))
        .style("font-family", "system-ui, sans-serif")
    }
}

let app = Application {
    Route("/")                { PlaceholderPage(title: "Showcase") }
    Route("/learn/hello")     { PlaceholderPage(title: "Hello, SwiftWUI") }
    Route("/learn/state")     { PlaceholderPage(title: "State & Bindings") }
    Route("/learn/modifiers") { PlaceholderPage(title: "Modifiers") }
    Route("/learn/lists")     { PlaceholderPage(title: "Lists & ForEach") }
    Route("/learn/forms")     { PlaceholderPage(title: "Forms & Inputs") }
    Route("/learn/routing")   { PlaceholderPage(title: "Routing & Guards") }
    Route("/learn/async")     { PlaceholderPage(title: "Async & Resources") }
    Route("/learn/theming")   { PlaceholderPage(title: "Theming") }
    Route("/learn/a11y")      { PlaceholderPage(title: "Accessibility") }
    Route("/learn/errors")    { PlaceholderPage(title: "Error Handling") }
    Route("/learn/ssr")       { PlaceholderPage(title: "SSR & Hydration") }
    Route("/learn/pwa")       { PlaceholderPage(title: "PWA") }
}
app.mount()
