import SwiftWUI
import SwiftWUIDOM

extension ColorToken {
    static let stageBg  = ColorToken("stage-bg")
    static let stageInk = ColorToken("stage-ink")
}

// tutorial:begin bubble
struct Bubble: Tag {
    var body: some Tag {
        P { "Knock, knock." }
            .padding(.px(12))
            .background(.hex("#F2F0EC"))
            .borderRadius(.px(10))
            .fontSize(.rem(1.1))
            .style("backdrop-filter", "blur(4px)")
    }
}
// tutorial:end bubble

struct Stage: Tag {
    @State private var dark = false
    @Environment(\.setTheme) var setTheme
    var body: some Tag {
        Div(class: "stage") {
            Bubble()
            Button("Toggle theme", class: "stage-toggle") {
                dark.toggle()
                setTheme(dark ? "dark" : nil)
            }
        }
    }
}

struct BubbleApp: App {
    var body: some Tag { Stage() }

// tutorial:begin bubble-rules
    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.token(.stageBg))
            p.color(.token(.stageInk))
            p.fontFamily("system-ui, sans-serif")
        }
        Rule(class: "stage") { p in
            p.padding(.px(48))
            p.display(.flex); p.flexDirection(.column); p.gap(.px(16))
            p.alignItems(.flexStart)
        }
        Rule(class: "stage-toggle") { p in
            p.padding(vertical: .px(8), horizontal: .px(14))
            p.borderRadius(.px(8)); p.cursor(.pointer)
            p.hover { h in h.opacity(0.8) }
        }
    }
// tutorial:end bubble-rules

// tutorial:begin bubble-theme
    static var themes: [ThemeDefinition] {
        [
            ThemeDefinition { t in                      // default → :root
                t.set(ColorToken.stageBg, .hex("#faf9f7"))
                t.set(ColorToken.stageInk, .hex("#1c1917"))
            },
            ThemeDefinition(name: "dark") { t in        // → [data-theme="dark"]
                t.set(ColorToken.stageBg, .hex("#17140f"))
                t.set(ColorToken.stageInk, .hex("#f5f1ea"))
            },
        ]
    }
// tutorial:end bubble-theme
}

#if canImport(SwiftWUIStatic)
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: StyleBubble ssg --out <dir> [--static]")
            return
        }
        args.removeFirst()
        var out = "dist"
        var mode = StaticSiteMode.hydrate(wasmScriptPath: "/app/index.js")
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            case "--static": mode = .staticOnly
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate(BubbleApp.self,
                                                   config: .init(outDir: out, mode: mode))
        print("generated \(report.pages.count) pages")
    }
}
#else
@main enum Entry {
    static func main() { BubbleApp.main() }
}
#endif
