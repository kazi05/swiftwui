// SiteChrome.swift — shared navbar + footer wrapper for the {{project_name}}.

import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public struct SiteChrome<Content: Tag>: Tag {
    let content: Content

    public init(@TagBuilder _ content: () -> Content) {
        self.content = content()
    }

    public var body: some Tag {
        Div {
            navbar
            Main { content }
                .style("min-height", "calc(100vh - 160px)")
                .attribute("data-swui-main", "true")
            footer
        }
        .style("background", "var(--swui-bg)")
        .style("color", "var(--swui-fg)")
        .style("font-family", "var(--font-text)")
        .attribute("data-swui-chrome", "true")
    }

    private var navbar: some Tag {
        Div {
            Div {
                A(href: "/") { Text("SwiftWUI") }
                    .style("font-weight", "700")
                    .style("color", "var(--swui-fg)")
                    .style("text-decoration", "none")
                    .style("font-family", "var(--font-display)")
                Div { EmptyTag() }.style("flex", "1")
                Button(onclick: { toggleTheme() }) { Text("☀︎ / ☾") }
                    .style("border", "1px solid var(--swui-border-strong)")
                    .style("border-radius", "14px")
                    .style("padding", "4px 12px")
                    .style("background", "transparent")
                    .style("color", "var(--swui-fg)")
                    .style("font-size", "11px")
                    .style("cursor", "pointer")
                    .attribute("aria-label", "Toggle colour theme")
            }
            .style("display", "flex")
            .style("align-items", "center")
            .style("gap", "16px")
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "12px \(Layout.pageHorizontalPadding)")
        }
        .style("background", "color-mix(in srgb, var(--swui-surface) 92%, transparent)")
        .style("border-bottom", "1px solid var(--swui-border)")
        .style("position", "sticky")
        .style("top", "0")
        .style("z-index", "50")
        .style("backdrop-filter", "saturate(180%) blur(20px)")
        .attribute("data-swui-navbar", "true")
    }

    private var footer: some Tag {
        Div {
            Div {
                P { Text("Built with SwiftWUI · Real Swift in WebAssembly.") }
                    .style("color", "var(--swui-fg-3)")
                    .style("font-size", "12px")
                    .style("margin", "0")
            }
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "32px \(Layout.pageHorizontalPadding)")
        }
        .style("border-top", "1px solid var(--swui-border)")
        .attribute("data-swui-footer", "true")
    }
}

#if canImport(JavaScriptKit)
private func toggleTheme() {
    guard let html = JSObject.global.document.object?.documentElement.object else { return }
    let current = html.getAttribute?("data-theme").string ?? ""
    let next = current == "dark" ? "light" : "dark"
    _ = html.setAttribute?("data-theme", next)
    _ = JSObject.global.localStorage.object?.setItem?("swui-theme", next)
}
#else
private func toggleTheme() {}
#endif
