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
            TutorialTopBar(
                currentChapter: SiteChromeHelpers.currentChapterID(),
                stepTitles: SiteChromeHelpers.stepTitles(),
                currentStep: SiteChromeHelpers.currentStep()
            )
            Main { content }
                .style("min-height", "calc(100vh - 160px)")
                .attribute("data-swui-main", "true")
            footer
        }
        .backgroundColor(.token("swui-bg"))
        .foregroundColor(.token("swui-fg"))
        .fontFamily("var(--font-text)")
        .attribute("data-swui-chrome", "true")
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
            .margin(.zero, .auto)
            .style("padding", "32px \(Layout.pageHorizontalPadding)")
        }
        .borderTop(width: .px(1), style: .solid, color: .token("swui-border"))
        .attribute("data-swui-footer", "true")
    }
}

enum SiteChromeHelpers {
    static func currentChapterID() -> String {
        // `#if arch(wasm32)`, not `canImport(JavaScriptKit)`. JavaScriptKit imports
        // fine on the macOS host (it's a dependency in Package.swift), but its
        // bridge globals abort when there is no JS runtime. Confining the lookup
        // to the wasm target keeps `body` evaluation safe on the host so
        // snapshot tests using `StaticRenderer().renderFragment(...)` don't
        // SIGABRT.
        #if arch(wasm32)
        if let path = JSObject.global.window.object?.location.object?.pathname.string,
           let chapter = ChapterRegistry.chapter(forPath: path) {
            return chapter.id
        }
        #endif
        return "home"
    }

    static func stepTitles() -> [String] {
        return ScrollyStepRegistry.titles
    }

    static func currentStep() -> Int {
        return ScrollyStepRegistry.currentStep
    }
}
