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
