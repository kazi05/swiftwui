// ObservedObject.swift - Observe external @Observable objects

import Observation

/// A property wrapper that observes an external `@Observable` object.
///
/// Use `@ObservedObject` when the observable object is owned elsewhere
/// and passed into your tag. For state owned by the tag itself, use `@State`.
///
/// ```swift
/// @Observable
/// class AppModel {
///     var username = ""
/// }
///
/// struct Profile: Tag {
///     @ObservedObject var model: AppModel
///
///     var body: some Tag {
///         Text(model.username)
///     }
/// }
/// ```
@propertyWrapper
public struct ObservedObject<ObjectType: AnyObject & Observable> {
    private let object: ObjectType

    public init(wrappedValue: ObjectType) {
        self.object = wrappedValue
    }

    public var wrappedValue: ObjectType { object }

    /// Provides dynamic member lookup for creating bindings to object properties.
    ///
    /// Access via `$model.username` to get `Binding<String>`.
    public var projectedValue: Wrapper { Wrapper(object: object) }

    @dynamicMemberLookup
    public struct Wrapper {
        let object: ObjectType

        public subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Value>) -> Binding<Value> {
            Binding(
                get: { object[keyPath: keyPath] },
                set: { object[keyPath: keyPath] = $0 }
            )
        }
    }
}
