// OnChangeModifier.swift - onChange(of:) modifier for observing value changes

import SwiftWUICore

/// Global storage for onChange previous values.
public enum OnChangeStorage {
    nonisolated(unsafe) private static var values: [String: Any] = [:]
    #if !arch(wasm32)
    private static let lock = NSLock_OnChange()
    #endif

    static func value(for key: String) -> Any? {
        #if arch(wasm32)
        return values[key]
        #else
        lock.lock()
        let result = values[key]
        lock.unlock()
        return result
        #endif
    }

    static func setValue(_ value: Any, for key: String) {
        #if arch(wasm32)
        values[key] = value
        #else
        lock.lock()
        values[key] = value
        lock.unlock()
        #endif
    }

    public static func clear() {
        #if arch(wasm32)
        values.removeAll()
        #else
        lock.lock()
        values.removeAll()
        lock.unlock()
        #endif
    }
}

#if !arch(wasm32)
import Foundation
typealias NSLock_OnChange = NSLock
#endif

/// A tag wrapper that observes a value and calls an action when it changes.
///
/// The `storageKey` is derived from `#filePath:#line:#column` of the call site by
/// the `.onChange(of:perform:)` extension. This keeps the previous-value lookup
/// stable across re-renders even though the `OnChangeTag` struct is reconstructed
/// every time the body re-evaluates. Without a stable key, every render allocates
/// a fresh `UUID` and the action would never observe a change.
public struct OnChangeTag<Content: Tag, V: Equatable & Sendable>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: Content
    public let getValue: @Sendable () -> V
    public let action: @Sendable (V, V) -> Void
    private let storageKey: String

    public init(
        content: Content,
        getValue: @escaping @Sendable () -> V,
        action: @escaping @Sendable (V, V) -> Void,
        storageKey: String
    ) {
        self.content = content
        self.getValue = getValue
        self.action = action
        self.storageKey = storageKey
    }

    public func toTagNodes() -> [TagNode] {
        let currentValue = getValue()

        if let oldValue = OnChangeStorage.value(for: storageKey) as? V {
            if oldValue != currentValue {
                action(oldValue, currentValue)
            }
        }
        OnChangeStorage.setValue(currentValue, for: storageKey)

        if let convertible = content as? TagNodeConvertible {
            return convertible.toTagNodes()
        }
        return resolveTagBody(content)
    }
}

extension Tag {
    /// Perform an action when the given value changes.
    public func onChange<V: Equatable & Sendable>(
        of value: @autoclosure @escaping @Sendable () -> V,
        perform action: @escaping @Sendable (V, V) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> OnChangeTag<Self, V> {
        OnChangeTag(
            content: self,
            getValue: value,
            action: action,
            storageKey: "\(file):\(line):\(column)"
        )
    }
}
