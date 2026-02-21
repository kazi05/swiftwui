// OnChangeModifier.swift - onChange(of:) modifier for observing value changes

import Foundation
import SwiftWUICore

/// Global storage for onChange previous values.
enum OnChangeStorage {
    nonisolated(unsafe) private static var values: [String: Any] = [:]

    static func value(for key: String) -> Any? { values[key] }
    static func setValue(_ value: Any, for key: String) { values[key] = value }
    static func clear() { values.removeAll() }
}

/// A tag wrapper that observes a value and calls an action when it changes.
public struct OnChangeTag<Content: Tag, V: Equatable & Sendable>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: Content
    public let getValue: @Sendable () -> V
    public let action: @Sendable (V, V) -> Void
    private let storageKey: String

    public init(content: Content, getValue: @escaping @Sendable () -> V, action: @escaping @Sendable (V, V) -> Void) {
        self.content = content
        self.getValue = getValue
        self.action = action
        self.storageKey = UUID().uuidString
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
        perform action: @escaping @Sendable (V, V) -> Void
    ) -> OnChangeTag<Self, V> {
        OnChangeTag(content: self, getValue: value, action: action)
    }
}
