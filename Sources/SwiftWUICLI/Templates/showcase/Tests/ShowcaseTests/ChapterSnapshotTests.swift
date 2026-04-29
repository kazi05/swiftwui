// ChapterSnapshotTests.swift — Snapshot tests for chapters 2–12.
//
// Each test asserts:
//   • data-scrolly-step="1" and data-scrolly-step="<lastStep>" are present.
//   • A canary substring from the chapter's canonical-code subject is present.
//   • data-swui-chapter-footer is present (confirms SiteChrome + ChapterFooter wired).

import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("Chapter snapshots")
struct ChapterSnapshotTests {

    @Test func statePage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(StatePage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("@State"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func modifiersPage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(ModifiersPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("padding"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func listsPage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(ListsPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("ForEach"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func formsPage_hasFivePlusSteps() {
        let html = StaticRenderer().renderFragment(FormsPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"5\""))
        #expect(html.contains("Slider"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func routingPage_hasFivePlusSteps() {
        let html = StaticRenderer().renderFragment(RoutingPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"5\""))
        #expect(html.contains("RouteGuardResult"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func asyncPage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(AsyncPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains(".task"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func themingPage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(ThemingPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("ThemeCSS"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func a11yPage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(A11yPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("aria"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func errorsPage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(ErrorsPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("ErrorBoundary"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func ssrPage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(SSRPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("StaticRenderer"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func pwaPage_hasFourPlusSteps() {
        let html = StaticRenderer().renderFragment(PWAPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("WebAppManifest"))
        #expect(html.contains("data-swui-chapter-footer"))
    }
}
