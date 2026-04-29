// TagNodeConvertible.swift - Protocol for converting tags to virtual DOM nodes

/// Protocol that enables converting a `Tag` into a `TagNode` (virtual DOM).
/// All tags must eventually be convertible to TagNode for rendering.
public protocol TagNodeConvertible {
    func toTagNodes() -> [TagNode]
}

// MARK: - Default Implementations

extension Text: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        [.text(content)]
    }
}

extension EmptyTag: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        []
    }
}

extension AnyTag: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        if let convertible = storage as? TagNodeConvertible {
            return convertible.toTagNodes()
        }
        // For non-primitive tags, resolve body recursively
        return resolveTagBody(storage)
    }
}

extension ConditionalTag: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        switch self {
        case .trueContent(let content):
            if let convertible = content as? TagNodeConvertible {
                return convertible.toTagNodes()
            }
            return resolveTagBody(content)
        case .falseContent(let content):
            if let convertible = content as? TagNodeConvertible {
                return convertible.toTagNodes()
            }
            return resolveTagBody(content)
        }
    }
}

extension Optional: TagNodeConvertible where Wrapped: Tag {
    public func toTagNodes() -> [TagNode] {
        guard let self else { return [] }
        if let convertible = self as? TagNodeConvertible {
            return convertible.toTagNodes()
        }
        return resolveTagBody(self)
    }
}

extension Array: TagNodeConvertible where Element: Tag {
    public func toTagNodes() -> [TagNode] {
        flatMap { element -> [TagNode] in
            if let convertible = element as? TagNodeConvertible {
                return convertible.toTagNodes()
            }
            return resolveTagBody(element)
        }
    }
}

extension ModifiedContent: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        // Get the base nodes from the content
        let baseNodes: [TagNode]
        if let convertible = content as? TagNodeConvertible {
            baseNodes = convertible.toTagNodes()
        } else {
            baseNodes = resolveTagBody(content)
        }

        // Apply modifications to each element node
        return baseNodes.map { node in
            guard case .element(var element) = node else { return node }

            // Merge styles
            for (property, value) in styles {
                element.styles[property] = value
            }

            // Merge classes
            element.classes.append(contentsOf: classes)

            // Merge attributes
            for (name, value) in attributes {
                element.attributes[name] = value
            }

            // Merge responsive styles
            for (queryKey, rStyles) in responsiveStyles {
                var existing = element.responsiveStyles[queryKey, default: [:]]
                for (property, value) in rStyles {
                    existing[property] = value
                }
                element.responsiveStyles[queryKey] = existing
            }

            return .element(element)
        }
    }
}

// MARK: - Tag Body Resolution

/// Resolves a tag's body recursively until reaching a TagNodeConvertible.
///
/// Marked `@inlinable` because every Tag → TagNode conversion in user
/// code goes through this function. With WMO + cross-module inlining
/// the existential cast (`as? TagNodeConvertible`) collapses into a
/// direct method dispatch when the concrete `T` is statically known to
/// conform, removing one indirection per node per render. Important
/// for the WASM target where the existential PWT lookup has no inline
/// cache.
@inlinable
public func resolveTagBody<T: Tag>(_ tag: T) -> [TagNode] {
    if let convertible = tag as? TagNodeConvertible {
        return convertible.toTagNodes()
    }
    let body = tag.body
    if let convertible = body as? TagNodeConvertible {
        return convertible.toTagNodes()
    }
    return resolveTagBody(body)
}
