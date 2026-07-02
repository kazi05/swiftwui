// PageRenderer.swift - Renders a Page to full HTML string

import Foundation
import SwiftWUICore

/// Renders a `Page` into a complete HTML document string.
/// Used for static HTML generation (SSG mode).
public struct PageRenderer {

    public init() {}

    /// Render a Page to a full HTML document string.
    public func render<P: Page>(_ page: P) -> String {
        var html = "<!DOCTYPE html>\n<html>\n"
        html += renderHead(page)
        html += renderBody(page)
        html += "</html>\n"
        return html
    }

    // MARK: - Head

    private func renderHead<P: Page>(_ page: P) -> String {
        var head = "<head>\n"

        // Meta tags
        for meta in page.meta {
            head += "  <meta"
            for (key, value) in meta.attributes {
                head += " \(key)=\"\(HTMLEscaping.text(value))\""
            }
            head += ">\n"
        }

        // Title
        head += "  <title>\(HTMLEscaping.text(page.title))</title>\n"

        // Stylesheets
        for sheet in page.styleSheets {
            switch sheet.source {
            case .file(let path):
                head += "  <link rel=\"stylesheet\" href=\"\(HTMLEscaping.text(path))\">\n"
            case .url(let url):
                head += "  <link rel=\"stylesheet\" href=\"\(HTMLEscaping.text(url))\">\n"
            case .inline(let css):
                head += "  <style>\(HTMLEscaping.rawTextElement(css))</style>\n"
            }
        }

        head += "</head>\n"
        return head
    }

    // MARK: - Body

    private func renderBody<P: Page>(_ page: P) -> String {
        var body = "<body>\n"
        body += "  <div id=\"app\">\n"

        // Render the page body as static HTML
        let nodes = resolveTagBody(page.body)
        for node in nodes {
            body += renderNode(node, indent: 4)
        }

        body += "  </div>\n"

        // Scripts
        for script in page.scripts {
            body += "  " + renderScript(script) + "\n"
        }

        body += "</body>\n"
        return body
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
            let selfClosing = Set(["img", "input", "br", "hr", "meta", "link", "source", "area", "base", "col", "embed", "track", "wbr"])
            if selfClosing.contains(element.tagName) {
                html += ">\n"
                return html
            }

            html += ">\n"

            // Children
            for child in element.children {
                html += renderNode(child, indent: indent + 2)
            }

            html += "\(padding)</\(element.tagName)>\n"
            return html

        case .fragment(let children):
            return children.map { renderNode($0, indent: indent) }.joined()
        }
    }

    private func renderScript(_ script: ScriptRef) -> String {
        var tag = "<script"
        if let type = script.type { tag += " type=\"\(type)\"" }
        if script.isAsync { tag += " async" }
        if script.isDefer { tag += " defer" }

        switch script.source {
        case .file(let path):
            tag += " src=\"\(HTMLEscaping.text(path))\"></script>"
        case .url(let url):
            tag += " src=\"\(HTMLEscaping.text(url))\"></script>"
        case .inline(let code):
            tag += ">\(HTMLEscaping.rawTextElement(code))</script>"
        }

        return tag
    }
}
