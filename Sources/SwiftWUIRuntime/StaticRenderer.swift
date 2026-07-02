// StaticRenderer.swift - Static HTML generation (SSG)

import SwiftWUICore
import SwiftWUIPage

/// Generates static HTML files from Pages.
/// Used for Static Site Generation (SSG) mode.
///
/// ```swift
/// let renderer = StaticRenderer()
/// let html = renderer.renderPage(HomePage())
/// ```
///
/// Conforms to `StringRendering` so SSR / SSG callers (Vapor request
/// handlers, the static-site builder, snapshot test helpers) can target
/// any string-emitting backend through the same protocol.
public struct StaticRenderer: StringRendering {
    private let pageRenderer: PageRenderer

    public init() {
        self.pageRenderer = PageRenderer()
    }

    /// Render a single Page to a complete HTML document string.
    public func renderPage<P: Page>(_ page: P) -> String {
        pageRenderer.render(page)
    }

    /// Render a Tag to an HTML fragment string (no html/head/body wrapper).
    public func renderFragment<T: Tag>(_ rootTag: T) -> String {
        let nodes = resolveTagBody(rootTag)
        return nodes.map { renderNode($0, indent: 0) }.joined()
    }

    // MARK: - Node Rendering

    private func renderNode(_ node: TagNode, indent: Int) -> String {
        let padding = String(repeating: " ", count: indent)

        switch node {
        case .text(let text):
            return "\(padding)\(HTMLEscaping.text(text))\n"

        case .element(let element):
            var html = "\(padding)<\(element.tagName)"

            // Attributes
            for (key, value) in element.attributes.sorted(by: { $0.key < $1.key }) {
                html += " \(key)=\"\(HTMLEscaping.text(value))\""
            }

            // Classes
            if !element.classes.isEmpty {
                html += " class=\"\(HTMLEscaping.text(element.classes.joined(separator: " ")))\""
            }

            // Styles
            if !element.styles.isEmpty {
                let styleStr = element.styles
                    .sorted(by: { $0.key < $1.key })
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: "; ")
                html += " style=\"\(HTMLEscaping.text(styleStr))\""
            }

            // Self-closing tags
            let selfClosing: Set<String> = [
                "img", "input", "br", "hr", "meta", "link",
                "source", "area", "base", "col", "embed", "track", "wbr",
            ]

            if selfClosing.contains(element.tagName) {
                html += ">\n"
                return html
            }

            // Check for inline text-only children
            if element.children.count == 1, case .text(let text) = element.children[0] {
                html += ">\(HTMLEscaping.text(text))</\(element.tagName)>\n"
                return html
            }

            html += ">\n"
            for child in element.children {
                html += renderNode(child, indent: indent + 2)
            }
            html += "\(padding)</\(element.tagName)>\n"
            return html

        case .fragment(let children):
            return children.map { renderNode($0, indent: indent) }.joined()
        }
    }
}
