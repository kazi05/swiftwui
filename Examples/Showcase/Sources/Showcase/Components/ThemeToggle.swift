// ThemeToggle.swift — sun/moon switcher in the top bar.

import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public struct ThemeToggle: Tag {
    public init() {}

    public var body: some Tag {
        Button(onclick: { ThemeToggle.toggle() }) {
            Span { Text("☼") }.style("--icon", "sun").style("display", "inline")
            Span { Text("☾") }.style("--icon", "moon").style("display", "none")
        }
        .attribute("data-swui-theme-toggle", "true")
        .attribute("aria-label", "Toggle theme")
        .backgroundColor(.token("swui-surface"))
        .border(.px(1), .solid, .token("swui-border"))
        .borderRadius(.px(6))
        .cursor(.pointer)
        .padding(.px(6), .px(10))
        .fontSize(.px(13))
        .foregroundColor(.token("swui-fg-2"))
    }

    static func toggle() {
        #if canImport(JavaScriptKit)
        guard let doc = JSObject.global.document.object,
              let root = doc.documentElement.object else { return }
        let current = root.getAttribute?("data-theme").string ?? ""
        let next = current == "dark" ? "light" : "dark"
        _ = root.setAttribute?("data-theme", JSValue.string(next))
        _ = JSObject.global.localStorage.object?.setItem?("swui-theme", JSValue.string(next))
        #endif
    }
}
