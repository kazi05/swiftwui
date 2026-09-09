import Testing
@testable import SwiftWUI

@MainActor private final class RootVisibilityLog {
    nonisolated deinit { }
    var parentPasses = 0
    var values: [String] = []
}

private struct RootVisibilityLeaf: Tag {
    let log: RootVisibilityLog
    @State private var revision = 0

    var body: some Tag {
        Section {
            Span().onVisibilityChange(root: .ancestor(id: "timeline")) { [revision] value in
                log.values.append("\(revision):\(value)")
            }
            Button("leaf") { revision += 1 }
        }
    }
}

private struct RootVisibilityParent: Tag {
    let log: RootVisibilityLog

    var body: some Tag {
        log.parentPasses += 1
        return Div { RootVisibilityLeaf(log: log) }.visibilityRoot(id: "timeline")
    }
}

private struct RootVisibilityModifier: TagModifier {
    let log: RootVisibilityLog
    @State private var revision = 0

    func body(content: Content) -> some Tag {
        Section {
            content
            Span().onVisibilityChange(root: .ancestor(id: "timeline")) { [revision] value in
                log.values.append("\(revision):\(value)")
            }
            Button("modifier") { revision += 1 }
        }
    }
}

private struct RootReparentFixture: Tag {
    let log: RootVisibilityLog
    @State private var right = false
    @State private var key = 1

    var body: some Tag {
        Section {
            Button("move") { right.toggle(); key += 1 }
            Div {
                ForEach(right ? [] : [key], id: \.self) { value in
                    Span().onVisibilityChange(root: .ancestor(id: "timeline")) { visible in
                        log.values.append("\(value):\(visible)")
                    }
                }
            }.visibilityRoot(id: "timeline")
            Div {
                ForEach(right ? [key] : [], id: \.self) { value in
                    Span().onVisibilityChange(root: .ancestor(id: "timeline")) { visible in
                        log.values.append("\(value):\(visible)")
                    }
                }
            }.visibilityRoot(id: "timeline")
        }
    }
}

@MainActor private final class LegacyRootBackend: RendererBackend {
    nonisolated deinit { }
    typealias HostNode = Int

    func createElement(_ tag: String) -> Int { 0 }
    func createTextNode(_ text: String) -> Int { 0 }
    func setText(_ node: Int, _ text: String) {}
    func setAttribute(_ node: Int, name: String, value: String) {}
    func removeAttribute(_ node: Int, name: String) {}
    func setProperty(_ node: Int, name: String, value: PropertyValue) {}
    func setEventListener(_ node: Int, event: String, id: ListenerID) {}
    func removeEventListener(_ node: Int, event: String) {}
    func insert(_ child: Int, into parent: Int, before anchor: Int?) {}
    func remove(_ child: Int, from parent: Int) {}
    func setStylesheet(_ text: String) {}
    func pushState(path: String) {}
    func replaceState(path: String) {}
    func historyBack() {}
    func setTitle(_ title: String) {}
    func setMetaTags(_ tags: [MetaTag]) {}
    func setLinks(_ links: [LinkTag]) {}
    func childCount(of node: Int) -> Int { 0 }
    func child(of node: Int, at index: Int) -> Int { 0 }
    func tagName(of node: Int) -> String? { nil }
    func setDocumentLanguage(_ lang: String, dir: String?) {}
    func preferredLanguages() -> [String] { [] }
    func readCookie(_ name: String) -> String? { nil }
    func writeCookie(_ name: String, value: String, maxAgeDays: Int, secure: Bool) {}
}

@Suite @MainActor struct ConfiguredVisibilityLifecycleTests {
    private func node(_ tag: String, id: NodeIdentity, root: _ResolvedVisibilityRoot? = nil,
                      children: [Node] = [], threshold: Double = 0,
                      margin: VisibilityMargin = .zero) -> Node {
        var element = ElementNode(identity: id, tag: tag, attributes: [:], listeners: [:],
                                  observers: [:], children: children, key: nil)
        if let root {
            element.configuredVisibility = [
                .init(id: .init(owner: id, event: "configured"), root: root,
                      threshold: threshold, margin: margin)
            ]
        }
        return .element(element)
    }

    private func attach(_ node: Node, _ applier: TreeApplier<MockBackend>,
                        _ backend: MockBackend) -> MountedNode<MockNode> {
        let mounted = applier.mount(node, hostParent: backend.container, before: nil)
        mounted.parent = applier.root
        mounted.indexInParent = applier.root.children.count
        applier.root.children.append(mounted)
        return mounted
    }

    @Test func isolatedPassKeepsRootAndRefreshesClosureWithoutChurn() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = RootVisibilityLog()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: RootVisibilityParent(log: log),
                              scheduleMicrotask: scheduler.schedule)

        runtime.mount()

        let record = backend.visibilityObservations[0]
        guard case .ancestor(let host) = record.root else {
            Issue.record("Expected exact ancestor host")
            return
        }
        #expect(host === findFirst(backend.container, tag: "div"))
        #expect(record.attachedAfterInsertion)

        clickFirst(backend, runtime, tag: "button", sched: scheduler)

        #expect(log.parentPasses == 1)
        #expect(backend.visibilityObservations.count == 1)
        backend.emitVisibility(at: 0, value: true)
        scheduler.pump()
        #expect(log.values == ["1:true"])
    }

    @Test func missingFalseAndOldOptionsCannotReachNewGeneration() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let applier = TreeApplier(backend: backend, container: backend.container)
        applier.scheduleVisibility = scheduler.schedule
        var values: [Bool] = []
        applier.dispatchVisibility = { _, value in values.append(value) }
        let old = node("div", id: .root, root: .unavailable)
        let mounted = attach(old, applier, backend)

        applier.commitVisibility()
        let new = node("div", id: .root, root: .viewport, threshold: 0.5,
                       margin: .init(bottom: .px(-20)))
        applier.apply(Reconciler().diff(old: old, new: new), to: mounted)
        applier.commitVisibility()
        backend.emitVisibility(at: 0, value: false, includingCancelled: true)
        backend.emitVisibility(at: 1, value: true)
        scheduler.pump()

        #expect(values == [true])
        #expect(backend.visibilityObservations[0].cancelled)
        #expect(backend.visibilityObservations[1].threshold == 0.5)
        #expect(backend.visibilityObservations[1].margin == .init(bottom: .px(-20)))
    }

    @Test func replacementCleanupCannotUnindexNewHost() {
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let rootID = NodeIdentity.root.appending(.child(0))
        let childID = rootID.appending(.child(0))
        let old = node("div", id: rootID,
                       children: [node("span", id: childID, root: .ancestor(rootID))])
        let mounted = attach(old, applier, backend)
        applier.commitVisibility()
        let previousHost = mounted.host!
        let new = node("section", id: rootID,
                       children: [node("span", id: childID, root: .ancestor(rootID))])

        applier.apply(Reconciler().diff(old: old, new: new), to: mounted)
        applier.commitVisibility()

        let replacement = applier.elementIndex[rootID]!
        #expect(replacement.host !== previousHost)
        guard case .ancestor(let bound) = backend.visibilityObservations.last!.root else {
            Issue.record("Expected replacement root")
            return
        }
        #expect(bound === replacement.host)
        #expect(backend.visibilityObservations[0].cancelled)
    }

    @Test func exitDisconnectsBeforePhysicalRemovalAndEqualGhostAdoptionRebinds() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let applier = TreeApplier(backend: backend, container: backend.container)
        applier.scheduleVisibility = scheduler.schedule
        var values: [Bool] = []
        applier.dispatchVisibility = { _, value in values.append(value) }
        let registry = TransitionRegistry()
        applier.transitionsRef = registry
        registry.register(.opacity.animation(.linear(duration: 10)), for: .root)
        let tree = node("div", id: .root, root: .viewport)
        _ = attach(tree, applier, backend)
        applier.commitVisibility()
        applier.animationPass = AnimationPassContext(transactions: [:], reduceMotion: false,
                                                     suppressTransitions: false,
                                                     defaultTransaction: nil)

        applier.applyChildren(.init(slots: [], removedOldIndices: [0], removedNodes: [tree]),
                              on: applier.root)

        #expect(backend.container.children.count == 1)
        #expect(backend.visibilityObservations[0].cancelled)
        backend.emitVisibility(at: 0, value: true, includingCancelled: true)
        scheduler.pump()
        #expect(values.isEmpty)

        applier.applyChildren(.init(slots: [.fresh(tree)], removedOldIndices: []),
                              on: applier.root)
        applier.commitVisibility()

        #expect(backend.visibilityObservations.count == 2)
        backend.emitVisibility(at: 0, value: false, includingCancelled: true)
        backend.emitVisibility(at: 1, value: true)
        scheduler.pump()
        #expect(values == [true])
        applier.animationPass = nil
    }

    @Test func cancellationInvalidatesQueuedEventsAndBuildNeverObserves() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        var values: [Bool] = []
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Div().onVisibilityChange(root: .viewport) { values.append($0) },
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        backend.emitVisibility(at: 0, value: true)

        runtime._effects._cancelAll()
        scheduler.pump()

        #expect(values.isEmpty && backend.visibilityObservations[0].cancelled)

        let buildBackend = MockBackend()
        let build = Runtime(backend: buildBackend, container: buildBackend.container,
                            root: Div().onVisibilityChange(root: .ancestor(id: "missing")) {
                                values.append($0)
                            }, scheduleMicrotask: scheduler.schedule)
        build._effects._buildMode = true
        build.mount()
        scheduler.pump()

        #expect(buildBackend.visibilityObservations.isEmpty && values.isEmpty)
    }

    @Test func modifierScopedRerenderKeepsAncestorScope() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = RootVisibilityLog()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Div {
                                  Span().modifier(RootVisibilityModifier(log: log))
                              }.visibilityRoot(id: "timeline"),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        clickFirst(backend, runtime, tag: "button", sched: scheduler)

        #expect(backend.visibilityObservations.count == 1)
        backend.emitVisibility(at: 0, value: true)
        scheduler.pump()
        #expect(log.values == ["1:true"])
    }

    @Test func adoptionUsesExistingExactHost() {
        let base = MockBackend()
        let div = base.createElement("div")
        let span = base.createElement("span")
        base.insert(div, into: base.container, before: nil)
        base.insert(span, into: div, before: nil)
        let created = base.counts["createElement"]
        let adopting = AdoptingBackend(base: base, container: base.container)
        let scheduler = TestScheduler()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: Div {
                                  Span().onVisibilityChange(root: .ancestor(id: "timeline")) { _ in }
                              }.visibilityRoot(id: "timeline"),
                              scheduleMicrotask: scheduler.schedule)

        runtime.mount()

        #expect(adopting.finishAdoption())
        #expect(base.counts["createElement"] == created)
        guard case .ancestor(let bound) = base.visibilityObservations[0].root else {
            Issue.record("Expected adopted ancestor")
            return
        }
        #expect(bound === div && base.visibilityObservations[0].target === span)
    }

    @Test func rekeyAndReparentBindNewChainAndRejectOldCallback() {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let log = RootVisibilityLog()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: RootReparentFixture(log: log),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()

        clickFirst(backend, runtime, tag: "button", sched: scheduler)

        #expect(backend.visibilityObservations.count == 2)
        guard case .ancestor(let before) = backend.visibilityObservations[0].root,
              case .ancestor(let after) = backend.visibilityObservations[1].root else {
            Issue.record("Expected ancestor roots")
            return
        }
        #expect(before !== after)
        backend.emitVisibility(at: 0, value: false, includingCancelled: true)
        backend.emitVisibility(at: 1, value: true)
        scheduler.pump()
        #expect(log.values == ["2:true"])
    }

    @Test func oldBackendInheritsNoOpAndPublicEnumsRemainExhaustive() {
        let backend = LegacyRootBackend()
        var called = false

        let cancel = backend.observeVisibility(0, root: .unavailable, threshold: 0,
                                               rootMargin: .zero,
                                               onChange: { _ in called = true })

        #expect(cancel == nil && !called)
        func observerName(_ value: ObserverKind) -> String {
            switch value {
            case .visibility: return "visibility"
            case .size: return "size"
            }
        }
        func nodeName(_ value: Node) -> String {
            switch value {
            case .text: return "text"
            case .element: return "element"
            case .component: return "component"
            }
        }
        func propertyName(_ value: PropertyValue) -> String {
            switch value {
            case .string: return "string"
            case .bool: return "bool"
            }
        }
        #expect(observerName(.size) == "size")
        #expect(nodeName(.text("x")) == "text")
        #expect(propertyName(.bool(true)) == "bool")
    }
}
