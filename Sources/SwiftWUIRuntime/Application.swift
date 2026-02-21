// Application.swift - Main entry point for SwiftWUI apps

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import Observation
import SwiftWUICore
import SwiftWUIRouter
import SwiftWUIPage
import SwiftWUIState

/// The main entry point for a SwiftWUI application.
///
/// ```swift
/// import SwiftWUI
///
/// let app = Application {
///     Route("/") { HomePage() }
///     Route("/about") { AboutPage() }
/// }
/// app.mount()
/// ```
public struct Application {
    private let router: Router

    /// Create an application with routes defined using a builder.
    public init(@RouteBuilder routes: () -> [Route]) {
        self.router = Router(routes: routes)
    }

    /// Create an application with a single page (no routing).
    public init(page: @Sendable @escaping () -> some Tag) {
        self.router = Router {
            Route("/") { page() }
        }
    }

    #if canImport(JavaScriptKit)
    /// Mount the application to a DOM element.
    /// - Parameter elementId: The ID of the container element (default: "app").
    public func mount(on elementId: String = "app") {
        guard let container = DOMBridge().getElementById(elementId) else {
            print("SwiftWUI Error: Could not find element with id '\(elementId)'")
            return
        }

        let renderer = DOMRenderer(container: container)
        let bridge = DOMBridge()

        // Mutable render state wrapped for Sendable closure capture.
        // Safe because WASM is single-threaded.
        let state = RenderState()

        nonisolated(unsafe) var renderCycle: (() -> Void)!
        renderCycle = { [router] in
            withObservationTracking {
                let path = router.currentPath

                // Cache the tag per route so @State storage persists across re-renders.
                // Only recreate when the route changes.
                if state.cachedTag == nil || state.cachedPath != path {
                    state.cachedTag = router.matchedTag(for: path)
                    state.cachedPath = path
                }

                guard let tag = state.cachedTag else { return }

                if state.isFirstRender {
                    renderer.render(tag)
                    state.isFirstRender = false
                } else {
                    renderer.update(tag)
                }
            } onChange: {
                guard !state.renderScheduled else { return }
                state.renderScheduled = true
                // Defer re-render to the next microtask so the new value
                // is available (onChange fires during willSet).
                _ = JSObject.global.queueMicrotask!(JSOneshotClosure { _ in
                    state.renderScheduled = false
                    renderCycle()
                    return .undefined
                })
            }
        }

        // Initial render + start tracking
        renderCycle()

        // Set up History API (back/forward buttons)
        bridge.onPopState { [router] path in
            router.navigate(to: path)
        }
    }
    #else
    public func mount(on elementId: String = "app") {
        print("SwiftWUI: mount() is only available in WASM environment")
    }
    #endif
}

/// Mutable render state for the observation loop.
/// `@unchecked Sendable` because WASM is single-threaded.
private final class RenderState: @unchecked Sendable {
    var isFirstRender = true
    var renderScheduled = false
    /// Cached tag for the current route. Preserves `@State` storage across re-renders.
    var cachedTag: AnyTag?
    /// The path that produced `cachedTag`. Used to detect route changes.
    var cachedPath: String?
}
