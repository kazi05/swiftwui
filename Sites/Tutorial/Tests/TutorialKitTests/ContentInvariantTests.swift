import Foundation
import Testing
@testable import TutorialKit

@Suite struct ContentInvariantTests {
    @Test func slugsAreUniqueAndKebabCase() {
        let slugs = Curriculum.chapters.map(\.slug)
        #expect(Set(slugs).count == slugs.count)
        for s in slugs {
            #expect(!s.isEmpty)
            #expect(s.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }, "bad slug: \(s)")
        }
    }

    @Test func curriculumShape() {
        #expect(Curriculum.chapters.count == 12)
        #expect(Curriculum.chapters[0].kind == .overview)
        #expect(Curriculum.chapters.filter { $0.kind == .wrapUp }.count == 4)
        #expect(Curriculum.ssgPaths.count == 11)
        #expect(Curriculum.ssgPaths.allSatisfy { $0.hasPrefix("/tutorials/") })
    }

    @Test func nextChainResolves() {
        // Every non-overview chapter has a next; the last wraps to the overview.
        for ch in Curriculum.chapters where ch.kind != .overview {
            #expect(Curriculum.next(after: ch) != nil, "no next after \(ch.slug)")
        }
        let last = Curriculum.chapters.last!
        #expect(Curriculum.next(after: last)?.kind == .overview)
        #expect(Curriculum.next(after: Curriculum.overview) == nil)
    }

    @Test func wrapUpsCarryRecapAndQuizOnceAuthored() {
        for ch in Curriculum.chapters where ch.kind == .wrapUp {
            // Stubs (sections empty AND recap nil) are exempt until their
            // content task lands; an authored wrap-up must be complete.
            let authored = ch.recap != nil || ch.quiz != nil
            guard authored else { continue }
            #expect(ch.recap?.isEmpty == false, "\(ch.slug): recap missing")
            #expect(ch.quiz != nil, "\(ch.slug): quiz missing")
            #expect(ch.sections.isEmpty, "\(ch.slug): wrap-ups have no sections (spec §3)")
        }
    }

    @Test func quizzesHaveExactlyThreeValidQuestions() {
        for ch in Curriculum.chapters {
            guard let quiz = ch.quiz else { continue }
            #expect(quiz.questions.count == 3, "\(ch.slug): quiz must have 3 questions")
            for q in quiz.questions {
                #expect(q.options.count >= 2)
                #expect(q.options.indices.contains(q.correctIndex), "\(ch.slug): correctIndex out of range")
                #expect(!q.explanation.isEmpty)
            }
        }
    }

    @Test func sectionAnchorsUniquePerChapter() {
        for ch in Curriculum.chapters {
            let anchors = ch.sections.map(\.anchor)
            #expect(Set(anchors).count == anchors.count, "\(ch.slug): duplicate anchors")
        }
    }

    @Test func browserPanelScreenshotsExistOnDisk() {
        for ch in Curriculum.chapters {
            for section in ch.sections {
                for panel in [section.panel] + section.steps.compactMap(\.panel) {
                    guard case .browser(_, let shot) = panel else { continue }
                    let url = siteRoot.appendingPathComponent("Assets/\(shot)")
                    #expect(FileManager.default.fileExists(atPath: url.path),
                            "\(ch.slug): missing screenshot Assets/\(shot)")
                }
            }
        }
    }
}
