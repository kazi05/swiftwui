import Testing
@testable import SwiftWUI

private func findLink(_ node: MockNode, href: String) -> MockNode? {
    if node.tag == "a", node.attrs["href"] == href { return node }
    for child in node.children {
        if let hit = findLink(child, href: href) { return hit }
    }
    return nil
}

private struct SelectionApp: Tag {
    var body: some Tag {
        Router {
            Route("/") {
                Div {
                    Link("/plain") { Text("plain") }
                    Link("/slide") { Text("slide") }
                    Link("/explicit") { Text("explicit") }
                        .pageTransition(.fade.duration(.ms(500)))
                }
            }
            Route("/plain") { Div { Text("plain page") } }
            Route("/slide", transition: .slide()) { Div { Text("slide page") } }
            Route("/explicit", transition: .slide()) { Div { Text("explicit page") } }
        }
        .pageTransition(.fade)
    }
}

@Suite @MainActor struct ViewTransitionSelectionTests {
    func makeRuntime() -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SelectionApp(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func ambientAppliesWhenTheRouteDeclaresNothing() {
        let (runtime, backend, sched) = makeRuntime()
        runtime.navigate(to: "/plain")
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
        #expect(backend.viewTransitions[0].presetName == PageTransition.fade.cssAttributeValue)
        #expect(backend.viewTransitions[0].direction == .push)
    }

    @Test func destinationRouteBeatsAmbient() {
        let (runtime, backend, sched) = makeRuntime()
        runtime.navigate(to: "/slide")
        sched.pump()
        #expect(backend.viewTransitions[0].presetName == PageTransition.slide().cssAttributeValue)
    }

    @Test func explicitCallSiteBeatsTheDestinationRoute() {
        let (runtime, backend, sched) = makeRuntime()
        runtime.navigate(to: "/explicit", transition: .zoom(sourceID: "card"))
        sched.pump()
        #expect(backend.viewTransitions[0].presetName == PageTransition.zoom(sourceID: "card").cssAttributeValue)
    }

    @Test func linkAmbientDoesNotOutrankTheDestinationRoute() {
        // The Link carries `.pageTransition(.fade.duration(.ms(500)))` and the
        // destination declares `.slide()`. The Link's value is AMBIENT, not
        // explicit, so the route must win — routing them through one parameter
        // is exactly the collapse this test exists to prevent.
        let (runtime, backend, sched) = makeRuntime()
        let link = findLink(backend.container, href: "/explicit")!
        runtime.dispatch(link.events["click"]!)
        sched.pump()
        #expect(backend.viewTransitions[0].presetName == PageTransition.slide().cssAttributeValue)
    }

    @Test func popStateUsesTheDestinationsTransitionAndPopDirection() {
        let (runtime, backend, sched) = makeRuntime()
        runtime.navigate(to: "/slide")
        sched.pump()
        runtime.handlePopState(url: "/")
        sched.pump()
        #expect(backend.viewTransitions.count == 2)
        #expect(backend.viewTransitions[1].direction == .pop)
    }

    @Test func redirectStyleReplaceDoesNotAnimate() {
        let (runtime, backend, sched) = makeRuntime()
        runtime.navigate(to: "/plain", replace: true)
        sched.pump()
        #expect(backend.viewTransitions.isEmpty)
        runtime.navigate(to: "/slide", replace: true, transition: .fade)
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
    }

    @Test func firstMatchWinsIncludingATransitionlessRoute() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: OrderedApp(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        runtime.navigate(to: "/todo/new")
        sched.pump()
        // /todo/new declares nothing, so it falls back to the Router ambient —
        // NOT to /todo/:id's slide, which it shadows.
        #expect(backend.viewTransitions[0].presetName == PageTransition.fade.cssAttributeValue)
        runtime.navigate(to: "/todo/7")
        sched.pump()
        #expect(backend.viewTransitions[1].presetName == PageTransition.slide().cssAttributeValue)
    }

    @Test func subtreeAmbientReachesDirectNavigateCalls() {
        // `\.navigate` is a computed key that binds the ambient value, so a
        // component inside a `.pageTransition(...)` subtree animates without
        // passing anything explicitly — and a subtree value beats the Router's.
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SubtreeAmbientApp(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
        #expect(backend.viewTransitions[0].presetName
                == PageTransition.slide().duration(.ms(300)).cssAttributeValue)
    }

    @Test func routeRevealedAndNavigatedInOneEventUsesTheOlderTable() {
        // `RouteBuilder` has buildOptional/buildEither, so the route list is not
        // strictly static. The cache is refreshed by any pass that resolves the
        // Router, so the ONLY stale window is a handler that both reveals a route
        // and navigates to it: `navigate` reads the table before the pass that
        // adds the route runs. Documented, pinned here, not engineered around.
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ConditionalRouteApp(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        // First hop: the Router default, because /admin was not in the table yet.
        #expect(backend.viewTransitions.last?.presetName == PageTransition.fade.cssAttributeValue)
        runtime.navigate(to: "/")
        sched.pump()
        runtime.navigate(to: "/admin")
        sched.pump()
        // Second hop: the route's own transition, now that a pass has seen it.
        #expect(backend.viewTransitions.last?.presetName
                == PageTransition.zoom(sourceID: "panel").cssAttributeValue)
    }

    @Test func routeTableSurvivesASubtreePass() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SubtreeStateApp(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        // NOTE: `tick` and `Router` are both inline in `SubtreeStateApp`'s own
        // body (the sole component boundary in this fixture), so THIS subtree
        // pass re-resolves the Router too (verified: ctx.routerCount == 1
        // here) — it does not, on its own, exercise the `ctx.routerCount > 0`
        // guard. See `routeTableNotBlankedByAnUnrelatedSubtreePass` below for a
        // fixture that isolates the dirty write from the Router.
        sched.pump()
        runtime.navigate(to: "/slide")
        sched.pump()
        #expect(backend.viewTransitions.last?.presetName == PageTransition.slide().cssAttributeValue)
    }

    @Test func routeTableNotBlankedByAnUnrelatedSubtreePass() {
        // Unlike `routeTableSurvivesASubtreePass` above, `Sibling` is its OWN
        // component boundary next to (not containing) `Router`, so a `tick`
        // write triggers a subtree pass rooted at `Sibling` that never resolves
        // `Router` at all (ctx.routerCount == 0 for that pass) — this is the
        // pass the `ctx.routerCount > 0` guard exists to protect against: an
        // unconditional cache write here would blank `routeTransitions` to `[]`
        // and `routerTransitionDefault` to `nil`, and the subsequent
        // `navigate(to: "/slide")` would find no route entry and fall back to
        // no transition at all instead of `.slide()`.
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SiblingStateApp(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        runtime.navigate(to: "/slide")
        sched.pump()
        #expect(backend.viewTransitions.last?.presetName == PageTransition.slide().cssAttributeValue)
    }

    @Test func ambientWithViewTransitionOnATransitionlessRouteStillGetsAPushDirection() {
        // Task 1 review gap, routed here because this task owns direction wiring:
        // `withViewTransition(.fade) { navigate("/x") }` on a route with NO
        // declared transition AND no Router-level ambient default must still
        // arm with `direction: .push`, so the push/pop CSS Task 2 generates can
        // fire. Before the fix, `armViewTransition`'s navigation call returned at
        // `guard let t` (t == nil here) before ever recording the navigation's
        // direction, so the later ambient arm (from `markDirty`, which always
        // passes `direction: nil`) landed with `direction: nil` and no
        // `data-swui-nav` — this app has neither a route nor a router default,
        // so `NoAmbientApp.pageTransition` is never applied and the only source
        // of a transition is the outer `withViewTransition` scope.
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: NoAmbientApp(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        withViewTransition(.fade) { runtime.navigate(to: "/plain") }
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
        #expect(backend.viewTransitions[0].direction == .push)
    }
}

private struct NoAmbientApp: Tag {
    var body: some Tag {
        Router {
            Route("/") { Div { Text("home") } }
            Route("/plain") { Div { Text("plain page") } }      // no transition, no Router default either
        }
    }
}

private struct OrderedApp: Tag {
    var body: some Tag {
        Router {
            Route("/") { Div { Text("home") } }
            Route("/todo/new") { Div { Text("new") } }                    // no transition
            Route("/todo/:id", transition: .slide()) { _ in Div { Text("detail") } }
        }
        .pageTransition(.fade)
    }
}

private struct ConditionalRouteApp: Tag {
    @State var isAdmin = false
    @Environment(\.navigate) private var navigate
    var body: some Tag {
        Div {
            // Reveals the route AND navigates to it in one handler — the only
            // window where the cached table is stale.
            Button("promote") { isAdmin = true; navigate("/admin") }
            Router {
                Route("/") { Div { Text("home") } }
                if isAdmin {
                    Route("/admin", transition: .zoom(sourceID: "panel")) { Div { Text("admin") } }
                }
            }
            .pageTransition(.fade)
        }
    }
}

private struct SubtreeNavigator: Tag {
    @Environment(\.navigate) private var navigate
    var body: some Tag {
        Button("go") { navigate("/plain") }
    }
}

private struct SubtreeAmbientApp: Tag {
    var body: some Tag {
        Router {
            Route("/") {
                SubtreeNavigator()
                    .pageTransition(.slide().duration(.ms(300)))   // beats the Router default
            }
            Route("/plain") { Div { Text("plain") } }              // declares nothing
        }
        .pageTransition(.fade)
    }
}

private struct SubtreeStateApp: Tag {
    @State var tick = 0
    var body: some Tag {
        Div {
            Button("tick") { tick += 1 }
            Router {
                Route("/") { Div { Text("home \(tick)") } }
                Route("/slide", transition: .slide()) { Div { Text("slide") } }
            }
            .pageTransition(.fade)
        }
    }
}

// `Sibling` is a component boundary of its own, separate from `Router` — a
// `tick` write here triggers a subtree pass rooted at `Sibling` alone, which
// never touches `Router` (unlike `SubtreeStateApp` above, where the two are
// inline in the same body).
private struct Sibling: Tag {
    @State var tick = 0
    var body: some Tag {
        Button("tick") { tick += 1 }
    }
}

private struct SiblingStateApp: Tag {
    var body: some Tag {
        Div {
            Sibling()
            Router {
                Route("/") { Div { Text("home") } }
                Route("/slide", transition: .slide()) { Div { Text("slide") } }
            }
            .pageTransition(.fade)
        }
    }
}
