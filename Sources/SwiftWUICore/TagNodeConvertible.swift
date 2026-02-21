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

            return .element(element)
        }
    }
}

// MARK: - Tag Body Resolution

/// Resolves a tag's body recursively until reaching a TagNodeConvertible.
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
