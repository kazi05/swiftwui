// SessionStorage.swift - Property wrapper for browser sessionStorage

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import Observation
import SwiftWUICore
import SwiftWUIState

/// A property wrapper that reads and writes to browser sessionStorage.
///
/// Data persists only for the current browser session (until the tab is
/// closed). For persistent storage use ``AppStorage`` instead.
///
/// ```swift
/// struct WizardStep: Tag {
///     @SessionStorage("step") var currentStep = 1
///
///     var body: some Tag {
///         Text("Step \(currentStep)")
///     }
/// }
/// ```
@propertyWrapper
public struct SessionStorage<Value: LosslessStringConvertible>: @unchecked Sendable {
    private let storage: SessionStorageStorage<Value>

    public init(wrappedValue: Value, _ key: String) {
        self.storage = SessionStorageStorage(key: key, defaultValue: wrappedValue)
    }

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    /// A binding to the stored value, obtained via the `$` prefix.
    public var projectedValue: Binding<Value> {
        Binding(
            get: { storage.value },
            set: { storage.value = $0 }
        )
    }
}

/// Internal observable storage backing ``SessionStorage``.
///
/// Uses `@Observable` so that property accesses are tracked by the
/// Observation framework, triggering re-renders when the value changes.
@Observable
final class SessionStorageStorage<Value: LosslessStringConvertible>: @unchecked Sendable {
    private let key: String
    private let defaultValue: Value
    private var _cachedValue: Value?

    var value: Value {
        get {
            if let cached = _cachedValue { return cached }
            #if arch(wasm32)
            let stored = JSObject.global.sessionStorage.object!.getItem!(key)
            if let str = stored.string, let val = Value(str) {
                _cachedValue = val
                return val
            }
            #endif
            return defaultValue
        }
        set {
            _cachedValue = newValue
            #if arch(wasm32)
            _ = JSObject.global.sessionStorage.object!.setItem!(key, String(newValue))
            #endif
        }
    }

    init(key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }
}
