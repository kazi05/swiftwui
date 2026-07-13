/// Carries an animation (and optional completion group) from a `withAnimation`
/// call through the write → `markDirty` → resolve → apply pipeline (anim spec §4).
public struct Transaction {
    public var animation: Animation?
    /// Non-nil only for `withAnimation(completion:)` — the group the write's
    /// component id gets registered into at `markDirty` time (Runtime.swift).
    var _group: CompletionGroup?

    public init(animation: Animation? = nil) {
        self.animation = animation
    }

    /// Ambient set for the dynamic extent of a `withAnimation` body closure.
    ///
    /// This is the ONE sanctioned `@MainActor` static in this codebase:
    /// `withAnimation` is a free function with no `Runtime` handle in scope,
    /// and there is exactly one app / one `Runtime` per process, so the
    /// ambient just threads the caller's intent into whichever `markDirty`
    /// call the closure's state writes trigger.
    @MainActor static var _active: Transaction?
}

/// Tracks writes made under a `withAnimation(completion:)` block so the
/// completion fires once every write this transaction touched has settled.
/// Armed post-flush (`Runtime.flush`); a group with no pending work at arm
/// time (nothing yet wired `register()`s against it) fires on the next
/// microtask rather than never firing.
@MainActor
final class CompletionGroup {
    private(set) var pending = 0
    private var fired = false
    private var armed = false
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func register() {
        pending += 1
    }

    func settle() {
        pending -= 1
        if armed { fireIfDone() }
    }

    func arm(schedule: (@escaping () -> Void) -> Void) {
        guard !armed else { return }
        armed = true
        if pending == 0 {
            schedule { [self] in fireIfDone() }
        }
    }

    private func fireIfDone() {
        guard !fired, pending <= 0 else { return }
        fired = true
        action()
    }
}

/// Runs `body` with `animation` active as the ambient `Transaction` for every
/// state write it makes (directly, or transitively via a dispatched event
/// handler) — nested calls save/restore, so the innermost `withAnimation`
/// wins for writes made inside it (anim spec §4.1).
///
/// Calling this from inside a `Tag`'s `body` (i.e. during body evaluation) is
/// illegal, same as any other state write during render — the write still
/// routes through `Runtime.markDirty`, whose existing
/// `"State write during body evaluation"` assert already traps it.
@MainActor
public func withAnimation<T>(_ animation: Animation? = .default, _ body: () throws -> T) rethrows -> T {
    let saved = Transaction._active
    Transaction._active = Transaction(animation: animation)
    defer { Transaction._active = saved }
    return try body()
}

/// Overload that fires `completion` once every animated write made inside
/// `body` has settled (or immediately, on the next microtask, if the block
/// made no writes that end up tracked — see `CompletionGroup.arm`).
@MainActor
public func withAnimation<T>(_ animation: Animation? = .default,
                              completion: @escaping () -> Void,
                              _ body: () throws -> T) rethrows -> T {
    let saved = Transaction._active
    var txn = Transaction(animation: animation)
    txn._group = CompletionGroup(action: completion)
    Transaction._active = txn
    defer { Transaction._active = saved }
    return try body()
}
