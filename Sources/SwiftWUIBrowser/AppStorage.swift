// AppStorage.swift - Property wrapper for browser localStorage

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import Observation
import SwiftWUICore
import SwiftWUIState

/// A property wrapper that reads and writes to browser localStorage.
///
/// Values persist across browser sessions (unlike ``SessionStorage``).
/// The generic `Value` must conform to `LosslessStringConvertible` so it
/// can be serialised to/from the string-based localStorage API.
///
/// ```swift
/// struct Settings: Tag {
///     @AppStorage("username") var username = "Guest"
///
///     var body: some Tag {
///         Text("Hello, \(username)")
///     }
/// }
/// ```
@propertyWrapper
public struct AppStorage<Value: LosslessStringConvertible>: @unchecked Sendable {
    private let storage: AppStorageStorage<Value>

    public init(wrappedValue: Value, _ key: String) {
        self.storage = AppStorageStorage(key: key, defaultValue: wrappedValue)
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

/// Internal observable storage backing ``AppStorage``.
///
/// Uses `@Observable` so that property accesses are tracked by the
/// Observation framework, triggering re-renders when the value changes.
@Observable
final class AppStorageStorage<Value: LosslessStringConvertible>: @unchecked Sendable {
    private let key: String
    private let defaultValue: Value
    private var _cachedValue: Value?

    var value: Value {
        get {
            if let cached = _cachedValue { return cached }
            #if arch(wasm32)
            let stored = JSObject.global.localStorage.object!.getItem!(key)
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
            _ = JSObject.global.localStorage.object!.setItem!(key, String(newValue))
            #endif
        }
    }

    init(key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }
}
