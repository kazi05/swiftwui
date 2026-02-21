// AnyTag.swift - Type-erased tag wrapper

/// A type-erased wrapper for any `Tag`.
/// Used when you need to store heterogeneous tags in collections
/// or return different tag types from a single property.
///
/// ```swift
/// struct MyComponent: Tag {
///     let child: AnyTag
///
///     init<T: Tag>(@TagBuilder content: () -> T) {
///         self.child = AnyTag(content())
///     }
/// }
/// ```
public struct AnyTag: Tag {
    public typealias Body = Never

    /// The boxed tag storage.
    let storage: any Tag

    public init<T: Tag>(_ tag: T) {
        self.storage = tag
    }
}
