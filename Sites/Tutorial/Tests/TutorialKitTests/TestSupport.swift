import Foundation
import SwiftWUI
@testable import TutorialKit

/// Sites/Tutorial (this package's root), derived from #filePath —
/// stable regardless of the runner's cwd.
let siteRoot: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // TutorialKitTests
    .deletingLastPathComponent()   // Tests
    .deletingLastPathComponent()   // Sites/Tutorial
/// SwiftWUI repo root.
let repoRoot: URL = siteRoot
    .deletingLastPathComponent()   // Sites
    .deletingLastPathComponent()   // repo

/// Manual microtask pump (mirrors the framework's RuntimeE2ETests helper —
/// that helper is internal to the framework's test target, so the site keeps
/// its own copy).
@MainActor final class TestScheduler {
    private var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func pump() { while !queue.isEmpty { queue.removeFirst()() } }
}

@MainActor
func findFirst(_ node: MockNode, tag: String) -> MockNode? {
    if node.tag == tag { return node }
    for c in node.children { if let f = findFirst(c, tag: tag) { return f } }
    return nil
}

@MainActor
func findAll(_ node: MockNode, tag: String) -> [MockNode] {
    var out: [MockNode] = []
    if node.tag == tag { out.append(node) }
    for c in node.children { out += findAll(c, tag: tag) }
    return out
}

/// First descendant whose class attribute contains `cls` (space-separated match).
@MainActor
func findFirst(_ node: MockNode, class cls: String) -> MockNode? {
    if let classes = node.attrs["class"]?.split(separator: " ").map(String.init),
       classes.contains(cls) { return node }
    for c in node.children { if let f = findFirst(c, class: cls) { return f } }
    return nil
}

@MainActor
func findAll(_ node: MockNode, class cls: String) -> [MockNode] {
    var out: [MockNode] = []
    if let classes = node.attrs["class"]?.split(separator: " ").map(String.init),
       classes.contains(cls) { out.append(node) }
    for c in node.children { out += findAll(c, class: cls) }
    return out
}

/// All text content beneath a node, concatenated in document order.
@MainActor
func textContent(_ node: MockNode) -> String {
    var out = node.text ?? ""
    for c in node.children { out += textContent(c) }
    return out
}

/// Runs the mock's animation clock to the end. A tag that leaves under a
/// `.transition` stays in the DOM (inert) until its exit animation settles —
/// MockBackend never settles on its own, so anything asserting that a
/// transitioned surface is GONE has to call this first.
@MainActor
func settleAnimations(_ backend: MockBackend, _ sched: TestScheduler) {
    var i = 0
    while i < backend.animations.count {   // settling can enqueue more
        backend.settleAnimation(at: i)
        i += 1
    }
    sched.pump()
}

@MainActor
func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
    let backend = MockBackend()
    let sched = TestScheduler()
    let rt = Runtime(backend: backend, container: backend.container,
                     root: root, scheduleMicrotask: sched.schedule)
    return (rt, backend, sched)
}
