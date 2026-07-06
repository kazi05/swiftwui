import Foundation
import Testing
@testable import TutorialKit

extension Chapter {
    /// Every panel on the page: hero + section defaults + step overrides.
    var allPanels: [Panel] {
        var out: [Panel] = []
        if let heroPanel { out.append(heroPanel) }
        for s in sections {
            out.append(s.panel)
            out += s.steps.compactMap(\.panel)
        }
        return out
    }
}

/// spec §9.2 — code panels are pinned to compiled sample sources.
@Suite struct ExcerptSyncTests {
    private func fileText(_ repoRelative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(repoRelative), encoding: .utf8)
    }

    /// Lines strictly between `// tutorial:begin <marker>` and `// tutorial:end <marker>`.
    private func markedRegion(of text: String, marker: String) -> String? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let begin = lines.firstIndex(where: { $0 == "// tutorial:begin \(marker)" }),
              let end = lines.firstIndex(where: { $0 == "// tutorial:end \(marker)" }),
              begin + 1 <= end - 1 || begin + 1 == end
        else { return nil }
        return lines[(begin + 1)..<end].joined(separator: "\n")
    }

    @Test func everyCodePanelMatchesItsSource() throws {
        for ch in Curriculum.chapters {
            for panel in ch.allPanels {
                guard case .code(let card) = panel else { continue }
                switch card.origin {
                case .sample(let path, let marker):
                    let text = try fileText(path)
                    let region = markedRegion(of: text, marker: marker)
                    #expect(region != nil, "\(ch.slug): marker '\(marker)' not found in \(path)")
                    #expect(region == card.code,
                            "\(ch.slug): panel '\(card.file)' drifted from \(path) [\(marker)]")
                case .fragment(let path):
                    let text = try fileText(path)
                    #expect(text.contains(card.code),
                            "\(ch.slug): panel '\(card.file)' is not a verbatim fragment of \(path)")
                }
            }
        }
    }

    @Test func ch4HasAStepPanelOverride() {
        // spec §9.1: the smoke's panel-swap check needs a target in ch. 4
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        let hasOverride = ch.sections.contains { $0.steps.contains { $0.panel != nil } }
        #expect(hasOverride)
    }
}

@Suite struct SampleSyncTests {
    @Test func shipCounterRunsTheExactCh4Code() throws {
        let text = try String(contentsOf: repoRoot.appendingPathComponent(
            "Sites/Tutorial/Samples/ShipCounter/Sources/main.swift"), encoding: .utf8)
        #expect(text.contains(Ch04.counterCode),
                "ShipCounter.Counter drifted from Examples/Counter — the screenshot app must run the code the page shows")
    }

    @Test func allExpectedMarkersResolve() throws {
        let expectations: [(String, String)] = [
            ("Examples/Counter/Sources/main.swift", "counter"),
            ("Examples/Counter/Sources/Hello.swift", "hello"),
            ("Sites/Tutorial/Samples/StyleBubble/Sources/main.swift", "bubble"),
            ("Sites/Tutorial/Samples/StyleBubble/Sources/main.swift", "bubble-rules"),
            ("Sites/Tutorial/Samples/StyleBubble/Sources/main.swift", "bubble-theme"),
            ("Sites/Tutorial/Samples/ChatRouter/Sources/main.swift", "chat-routes"),
            ("Sites/Tutorial/Samples/ChatRouter/Sources/main.swift", "chat-links"),
            ("Sites/Tutorial/Samples/ShipCounter/Sources/main.swift", "ship-ssg"),
            ("Sites/Tutorial/Samples/ShipCounter/Sources/main.swift", "ship-static"),
        ]
        for (path, marker) in expectations {
            let text = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            #expect(text.contains("// tutorial:begin \(marker)"), "\(path): missing begin \(marker)")
            #expect(text.contains("// tutorial:end \(marker)"), "\(path): missing end \(marker)")
        }
    }
}
