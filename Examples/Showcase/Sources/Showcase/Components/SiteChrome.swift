// SiteChrome.swift — shared navbar + footer wrapper for the showcase.

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
        .foregroundColor(.token("swui-fg"))
        .fontFamily("var(--font-text)")
        .attribute("data-swui-chrome", "true")
    }

    private var navbar: some Tag {
        Div {
            Div {
                A(href: "/") { Text("SwiftWUI") }
                    .fontWeight(.w700)
                    .foregroundColor(.token("swui-fg"))
                    .textDecoration(.none)
                    .fontFamily("var(--font-display)")
                Div { EmptyTag() }.flex(1)
                Button(onclick: { toggleTheme() }) { Text("☀︎ / ☾") }
                    .style("border", "1px solid var(--swui-border-strong)")
                    .borderRadius(.px(14))
                    .padding(.px(4), .px(12))
                    .style("background", "transparent")
                    .foregroundColor(.token("swui-fg"))
                    .fontSize(.px(11))
                    .cursor(.pointer)
                    .attribute("aria-label", "Toggle colour theme")
            }
            .display(.flex)
            .alignItems(.center)
            .gap(.px(16))
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "12px \(Layout.pageHorizontalPadding)")
        }
        .style("background", "color-mix(in srgb, var(--swui-surface) 92%, transparent)")
        .style("border-bottom", "1px solid var(--swui-border)")
        .position(.sticky)
        .top(.zero)
        .zIndex(50)
        .style("backdrop-filter", "saturate(180%) blur(20px)")
        .attribute("data-swui-navbar", "true")
    }

    private var footer: some Tag {
        Div {
            Div {
                P { Text("Built with SwiftWUI · Real Swift in WebAssembly.") }
                    .foregroundColor(.token("swui-fg-3"))
                    .fontSize(.px(12))
                    .margin(.zero)
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
