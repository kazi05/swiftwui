import SwiftWUI

/// The glass file bar (spec §7, signature moment 2): a language chip and the
/// filename, sticky over the listing that scrolls beneath it. It replaces the
/// three fake mac-window dots, which are deleted from both panels.
struct PanelBar: Tag {
    let language: String
    let file: String
    var body: some Tag {
        Div(class: "tut-panel-bar") {
            Span(class: "tut-lang-chip") { Text(language) }
            Span(class: "tut-panel-file") { Text(file) }
        }
    }
}

/// The chip vocabulary is exactly three words. Anything that is not Swift and
/// not a web asset — Dockerfile, shell scripts, config — reads as `sh`.
private func chipLanguage(forFile file: String) -> String {
    switch file.split(separator: ".").last?.lowercased() {
    case "swift": "swift"
    case "html", "css", "js": "web"
    default: "sh"
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
                PanelBar(language: chipLanguage(forFile: card.file), file: card.file)
                CodeView(code: card.code)
            }
            // Also declared in the .tut-card-dark rule; kept here so the compact
            // code variant cannot silently stop matching (spec risk 7).
            .containerType(.inlineSize)
        case .terminal(let title, let lines):
            Div(class: "tut-card-dark") {
                PanelBar(language: "sh", file: title)
                // Terminal lines live inside .tut-code so they inherit its font,
                // feature settings and compact-container step.
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
            .containerType(.inlineSize)
        case .browser(let url, let screenshot):
            Div(class: "tut-browser") {
                Div(class: "tut-browser-chrome") {
                    Div(class: "tut-url") { Text(url) }
                }
                Div(class: "tut-shot-frame") {
                    Img(src: "/assets/\(screenshot)", alt: "App preview at \(url)", class: "tut-shot")
                }
            }
        }
    }
}
