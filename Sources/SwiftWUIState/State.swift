// State.swift - Reactive state property wrapper

import Observation

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
@propertyWrapper
public struct State<Value>: @unchecked Sendable {
    private let storage: StateStorage<Value>

    public init(wrappedValue: Value) {
        self.storage = StateStorage(value: wrappedValue)
    }

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    /// Returns a `Binding` to the underlying value.
    ///
    /// Access via the `$` prefix: `$count` returns `Binding<Int>`.
    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.storage.value },
            set: { self.storage.value = $0 }
        )
    }
}

/// Internal observable storage backing `@State`.
///
/// Uses `@Observable` so that property accesses are tracked
/// by the Observation framework and swift-navigation's `observe()`.
@Observable
final class StateStorage<Value> {
    var value: Value

    init(value: Value) {
        self.value = value
    }
}
