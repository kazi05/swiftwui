// State.swift - Reactive state property wrapper

import Observation
import SwiftWUICore

/// A property wrapper that provides reactive mutable state for tags.
///
/// When the value changes, any `StateObserver` tracking the access will
/// be notified and can trigger a re-render.
///
/// ```swift
/// struct Counter: Tag {
///     @State var count = 0
///
///     var body: some Tag {
///         Button(action: { count += 1 }) {
///             Text("Count: \(count)")
///         }
///     }
/// }
/// ```
///
/// Storage is held behind a relocatable `StateSlot` so the runtime's
/// `RenderContext` can graft persisted storage onto a freshly-constructed
/// component (keyed by structural path) before its `body` runs — that is what
/// makes `@State` survive re-renders in nested components. The wrapper's public
/// surface (`wrappedValue`, `projectedValue`) is unaffected.
@propertyWrapper
public struct State<Value>: @unchecked Sendable {
    private let slot: StateSlot<Value>

    public init(wrappedValue: Value) {
        self.slot = StateSlot(StateStorage(value: wrappedValue))
    }

    public var wrappedValue: Value {
        get { slot.storage.value }
        nonmutating set { slot.storage.value = newValue }
    }

    /// Returns a `Binding` to the underlying value.
    ///
    /// Access via the `$` prefix: `$count` returns `Binding<Int>`.
    /// The binding captures the slot, so it always reads/writes whatever storage
    /// the slot currently points at — including storage grafted on after linking.
    public var projectedValue: Binding<Value> {
        let slot = self.slot
        return Binding(
            get: { slot.storage.value },
            set: { slot.storage.value = $0 }
        )
    }
}

extension State: _StatefulProperty {
    public var _storageObject: AnyObject { slot.storage }
    public func _adoptStorage(_ object: AnyObject) {
        if let storage = object as? StateStorage<Value> {
            slot.storage = storage
        }
    }
}

/// Relocatable indirection between a `@State` wrapper and its observable
/// storage. `RenderContext` retargets `storage` to persisted storage during
/// linking; because the slot is a reference type shared by every copy of the
/// wrapper, the graft is visible to the component being rendered and to any
/// closure that captured the slot.
final class StateSlot<Value>: @unchecked Sendable {
    var storage: StateStorage<Value>
    init(_ storage: StateStorage<Value>) {
        self.storage = storage
    }
}

/// Internal observable storage backing `@State`.
///
/// Uses `@Observable` so that property accesses are tracked
/// by the Observation framework.
@Observable
final class StateStorage<Value> {
    var value: Value

    init(value: Value) {
        self.value = value
    }
}
