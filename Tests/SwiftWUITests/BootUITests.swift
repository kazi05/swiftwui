import Testing
@testable import SwiftWUI

private struct Spinner: Tag { var body: some Tag { Div(class: "spin") { Text("Loading") } } }

private struct OverlayPage: Page {
    var title: String { "overlay" }
    var bootUI: BootUI { .overlay(after: .ms(120)) { Spinner() } }
    var body: some Tag { Div { Text("body") } }
}
private struct SilentPage: Page {
    var title: String { "silent" }
    var bootUI: BootUI { .none }
    var body: some Tag { Div { Text("body") } }
}
private struct DefaultPage: Page {
    var title: String { "default" }
    var body: some Tag { Div { Text("body") } }
}

private struct TwoPageApp: App {
    static var bootUI: BootUI { .overlay { Spinner() } }
    var body: some Tag {
        Router {
            Route("/overlay") { OverlayPage() }
            Route("/silent") { SilentPage() }
            Route("/default") { DefaultPage() }
        }
    }
}

@Suite @MainActor struct BootUITests {
    @Test func defaultsAreNoneAndInherit() {
        #expect(TwoPageApp.self is any App.Type)
        #expect(DefaultPage().bootUI._isInherit)
        #expect(BootUI.none._isNone)
        #expect(BootUI.overlay { Spinner() }._delayMS == 300)
        #expect(BootUI.overlay(after: .s(1)) { Spinner() }._delayMS == 1000)
    }

    @Test func routerPublishesTheMatchedPagesBootUI() {
        let runtime = Runtime(backend: MockBackend(), container: MockNode(),
                              root: TwoPageApp().body, initialPath: "/overlay",
                              scheduleMicrotask: { $0() })
        runtime.mount()
        #expect(runtime._bootUI?._delayMS == 120)
        #expect(runtime._bootUI?._isInherit == false)
    }

    @Test func aPageThatDeclaresNothingReportsInherit() {
        let runtime = Runtime(backend: MockBackend(), container: MockNode(),
                              root: TwoPageApp().body, initialPath: "/default",
                              scheduleMicrotask: { $0() })
        runtime.mount()
        #expect(runtime._bootUI?._isInherit == true)
    }
}
