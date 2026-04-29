// QueryParam.swift - @QueryParam property wrapper.

import SwiftWUICore

/// A property wrapper that reads a value from the current URL's query
/// string. The wrapper resolves through a global router instance the
/// app installs via `QueryParamContext.router`, so the value updates
/// reactively whenever the user edits the URL or the app navigates.
///
/// ```swift
/// struct PostList: Tag {
///     @QueryParam("page") var page: Int = 1
///
///     var body: some Tag {
///         Text("Showing page \(page)")
///     }
/// }
/// ```
///
/// `Value` must conform to `LosslessStringConvertible` so the wrapper
/// can convert the raw string the URL carries into the typed value
/// the consumer wants. For `String` fields the conversion is a no-op.
@propertyWrapper
public struct QueryParam<Value: LosslessStringConvertible> {
    public let name: String
    public let defaultValue: Value

    public init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }

    public var wrappedValue: Value {
        guard let router = QueryParamContext.router,
              let raw = router.currentSearchParams[name],
              let parsed = Value(raw)
        else {
            return defaultValue
        }
        return parsed
    }
}

extension QueryParam where Value == String {
    /// Convenience initialiser for `String` query params where the
    /// default is `""`.
    public init(_ name: String) {
        self.name = name
        self.defaultValue = ""
    }
}

/// Bridge between `Router` and `@QueryParam`. The application sets
/// `QueryParamContext.router` once during `Application.init` so every
/// `@QueryParam` in the tree reads the same source of truth.
///
/// The router is referenced as `AnyObject` because `QueryParam` lives
/// in `SwiftWUIRouter` itself — a typed `Router` reference would
/// create a self-import cycle. The cast on read goes back to the
/// concrete `Router` type via dynamic dispatch.
public enum QueryParamContext {
    nonisolated(unsafe) public static var router: Router?
}
