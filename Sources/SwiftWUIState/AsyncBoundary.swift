// AsyncBoundary.swift - Suspense-style wrapper around AsyncResource.

import SwiftWUICore

/// Renders one of three subtrees depending on the phase of an
/// `AsyncResource`: `loading` while the operation is in flight (or
/// before it has run), `error` if it failed, and `success` once a value
/// is available. Idle and loading both render the loading subtree —
/// they look identical to the user, only the developer cares about the
/// distinction.
///
/// Pair with `.task { resource.load { … } }` to kick off work when the
/// boundary mounts.
public struct AsyncBoundary<T, Loading: Tag, ErrorView: Tag, Success: Tag>: Tag,
    TagNodeConvertible
{
    public typealias Body = Never

    public let resource: AsyncResource<T>
    public let loading: () -> Loading
    public let error: (any Error) -> ErrorView
    public let success: (T) -> Success

    public init(
        resource: AsyncResource<T>,
        @TagBuilder loading: @escaping () -> Loading,
        @TagBuilder error: @escaping (any Error) -> ErrorView,
        @TagBuilder success: @escaping (T) -> Success
    ) {
        self.resource = resource
        self.loading = loading
        self.error = error
        self.success = success
    }

    public func toTagNodes() -> [TagNode] {
        switch resource.phase {
        case .idle, .loading:
            return _resolve(loading())
        case .failure(let e):
            return _resolve(error(e))
        case .success(let v):
            return _resolve(success(v))
        }
    }

    private func _resolve<Inner: Tag>(_ tag: Inner) -> [TagNode] {
        if let convertible = tag as? TagNodeConvertible {
            return convertible.toTagNodes()
        }
        return resolveTagBody(tag)
    }
}
