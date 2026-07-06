import SwiftWUI

public struct TutorialApp: App {
    public init() {}

    public static var globalStyles: [Rule] { return TutorialStyles.rules }
    public static var themes: [ThemeDefinition] { [TutorialTheme.definition] }

    public var body: some Tag {
        Router(notFound: { NotFoundPage() }) {
            Route("/") { OverviewPage() }
            Route("/tutorials/:slug") { params in
                routedChapterContent(slug: params["slug"] ?? "")
            }
        }
    }
}

/// Dispatch by curriculum kind (spec §6 "Page dispatch"). DEVIATION from the
/// brief's two candidate forms (both measured to fail PageTests.headTitleFollowsRoute):
/// Router detects `Page` only on the Route closure's DIRECT content
/// (`content.base as? any Page`, top-level-only — Routing/Router.swift). Both
/// the `RoutedChapter` wrapper struct AND a plain `if/else if/else` written
/// straight in the `@TagBuilder` Route closure funnel through
/// `TagBuilder.buildEither`, which wraps the branches in `ConditionalTag<F, S>`
/// — an unrelated Tag, not `Page` — so `content.base`'s dynamic type is never
/// one of the concrete pages and the title never lands. Doing the branching in
/// this ordinary (non-builder) function and returning `AnyTag` sidesteps
/// `buildEither` entirely: `AnyTag.init` unwraps an already-`AnyTag` argument,
/// so the erased `base` ends up as the concrete `ChapterPage`/`WrapUpPage`/
/// `NotFoundPage` instance itself, which the top-level check finds.
@MainActor
func routedChapterContent(slug: String) -> AnyTag {
    guard let ch = Curriculum.chapter(slug: slug) else { return AnyTag(NotFoundPage()) }
    return ch.kind == .wrapUp ? AnyTag(WrapUpPage(chapter: ch)) : AnyTag(ChapterPage(chapter: ch))
}
