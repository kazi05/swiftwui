// Application.swift - Main entry point for SwiftWUI apps

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import Observation
import SwiftWUICore
import SwiftWUIRouter
import SwiftWUIPage
import SwiftWUIState
import SwiftWUIStyles

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
        QueryParamContext.router = self.router
    }

    /// Create an application with a single page (no routing).
    public init(page: @Sendable @escaping () -> some Tag) {
        self.router = Router {
            Route("/") { page() }
        }
        QueryParamContext.router = self.router
    }

    /// Render the application's currently-matched route into an arbitrary
    /// `Renderer`. Intended for native unit tests, snapshot tests, and
    /// alternative backends (TUI, headless SSR, native canvas) that do
    /// not need the WASM observation loop / History API integration.
    ///
    /// Returns the resolved tag for the current path so tests can drive
    /// subsequent `update` calls after mutating its state.
    @discardableResult
    public func renderOnce<R: Renderer>(in renderer: R) -> AnyTag? {
        let tag = router.matchedTag(for: router.currentPath)
        if let tag {
            renderer.render(tag)
        }
        return tag
    }

    /// Render the application as a one-shot HTML string. The supplied
    /// renderer drives the conversion; callers typically use the
    /// `StaticRenderer` from this module or any custom `StringRendering`
    /// implementation (e.g. a streaming variant).
    public func renderToString<R: StringRendering>(in renderer: R) -> String {
        guard let tag = router.matchedTag(for: router.currentPath) else { return "" }
        return renderer.renderFragment(tag)
    }

    #if canImport(JavaScriptKit)
    /// Mount over an existing server-rendered DOM. Identical to
    /// `mount(on:)` except the renderer adopts the pre-rendered markup
    /// instead of recreating it. Pair with
    /// `Application.renderHTMLDocument(_:)` on the server side: the
    /// server emits the SSR HTML, the client boots the WASM, and this
    /// call attaches event listeners + observers without flashing the
    /// page.
    ///
    /// Subsequent state-driven re-renders go through the same
    /// observation loop / `update(_:)` path as the non-hydrated mount.
    public func hydrate(on elementId: String = "app") {
        guard let container = DOMBridge().getElementById(elementId) else {
            print("SwiftWUI Error: Could not find element with id '\(elementId)'")
            return
        }
        let renderer = DOMRenderer(container: container)
        let bridge = DOMBridge()
        let state = RenderState()

        nonisolated(unsafe) var renderCycle: (() -> Void)!
        renderCycle = { [router] in
            let animation = AnimationContext.current
            AnimationContext.current = nil

            withObservationTracking {
                let path = router.currentPath
                if state.cachedTag == nil || state.cachedPath != path {
                    state.cachedTag = router.matchedTag(for: path)
                    state.cachedPath = path
                }
                guard let tag = state.cachedTag else { return }

                if state.isFirstRender {
                    renderer.hydrate(tag)
                    state.isFirstRender = false
                } else {
                    renderer.update(tag, animation: animation)
                }
            } onChange: {
                guard !state.renderScheduled else { return }
                state.renderScheduled = true
                _ = JSObject.global.queueMicrotask!(JSOneshotClosure { _ in
                    state.renderScheduled = false
                    renderCycle()
                    return .undefined
                })
            }
        }

        renderCycle()

        bridge.onPopState { [router] path in
            router.navigate(to: path)
        }
    }

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
            // Capture and clear animation context (set by withAnimation).
            // Must be captured before the render so we know which animation to apply.
            let animation = AnimationContext.current
            AnimationContext.current = nil

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
                    renderer.update(tag, animation: animation)
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
