import SwiftWUI

/// Mac-window chrome row: three dots + title (Figma 3:28).
struct ChromeBar: Tag {
    let title: String
    var body: some Tag {
        Div(class: "tut-chrome") {
            Span(class: "tut-dot tut-dot-r")
            Span(class: "tut-dot tut-dot-y")
            Span(class: "tut-dot tut-dot-g")
            Span(class: "tut-chrome-title") { Text(title) }
        }
    }
}

/// Highlighted code block. Line split is deterministic; ForEach keys by line
/// index — content is static per page, so index identity is stable (no reorders).
struct CodeView: Tag {
    let code: String
    var body: some Tag {
        Div(class: "tut-code") {
            ForEach(Array(code.split(separator: "\n", omittingEmptySubsequences: false).enumerated()),
                    id: \.offset) { item in
                Div(class: "tut-code-line") {
                    ForEach(Array(SwiftHighlighter.tokenize(line: String(item.element)).enumerated()),
                            id: \.offset) { tok in
                        if let cls = tok.element.kind.cssClass {
                            Span(class: cls) { Text(tok.element.text) }
                        } else {
                            Text(tok.element.text)
                        }
                    }
                    // an empty line still needs height:
                    if item.element.isEmpty { Text(" ") }
                }
            }
        }
    }
}

/// One visual panel (spec §6): code card, terminal, or browser mock.
public struct PanelView: Tag {
    let panel: Panel
    public init(panel: Panel) { self.panel = panel }

    public var body: some Tag {
        switch panel {
        case .code(let card):
            Div(class: "tut-card-dark") {
                ChromeBar(title: card.file)
                CodeView(code: card.code)
            }
        case .terminal(let title, let lines):
            Div(class: "tut-card-dark") {
                ChromeBar(title: title)
                Div(class: "tut-code") {
                    ForEach(Array(lines.enumerated()), id: \.offset) { item in
                        Div(class: "tut-term-line") {
                            switch item.element.kind {
                            case .command:
                                Span(class: "tut-term-prompt") { "$" }
                                Text(" " + item.element.text)
                            case .output:
                                Span(class: "tut-term-out") { Text(item.element.text) }
                            case .note:
                                Span(class: "tut-term-note") { Text(item.element.text) }
                            }
                        }
                    }
                }
            }
        case .browser(let url, let screenshot):
            Div(class: "tut-browser") {
                Div(class: "tut-browser-chrome") {
                    Span(class: "tut-dot tut-dot-r")
                    Span(class: "tut-dot tut-dot-y")
                    Span(class: "tut-dot tut-dot-g")
                    Div(class: "tut-url") { Text(url) }
                }
                Img(src: "/assets/\(screenshot)", alt: "App preview at \(url)", class: "tut-shot")
            }
        }
    }
}
