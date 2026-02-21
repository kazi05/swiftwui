// Link.swift - Navigation link component

import SwiftWUICore

/// A navigation link that triggers client-side routing.
///
/// ```swift
/// Link("/about") {
///     Text("About Us")
/// }
/// ```
public struct Link: Tag {
    public typealias Body = Never

    let destination: String
    let children: [AnyTag]

    public init(_ destination: String, @TagBuilder content: () -> some Tag) {
        self.destination = destination
        self.children = [AnyTag(content())]
    }

    public init(_ title: String, destination: String) {
        self.destination = destination
        self.children = [AnyTag(Text(title))]
    }
}

extension Link: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        let childNodes = children.flatMap { child -> [TagNode] in
            resolveTagBody(child)
        }

        return [.element(.init(
            tagName: "a",
            attributes: [
                "href": destination,
                "data-swiftwui-link": "true",
            ],
            children: childNodes
        ))]
    }
}
