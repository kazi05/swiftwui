/// Chapter 13 — Wrap-up: Ship (last page: CTA wraps to the overview).
public enum Ch13 {
    public static let chapter = Chapter(
        slug: "wrap-up-ship", track: .ship, kicker: "WRAP-UP · SHIP",
        title: "Wrap-up: Ship",
        tagline: "SSG, prerender policies, hydration, and deployment — recapped.",
        minutes: 5, kind: .wrapUp,
        recap: [
            "Dual entry: wasm runs the app, native runs StaticSite.generate.",
            "build first, ssg last — prerendered pages must win in dist.",
            "Hydration adopts the prerendered DOM and restores the state snapshot; any mismatch falls back to a cold render.",
            "Prerender policy is per route and resolves most-specific-first; the SWIFTWUI_PRERENDER kill switch beats all of it and fails closed.",
            ".pageMeta writes the head from loaded data, which Page.title cannot; siteURL turns on canonicals and sitemap.xml.",
            "Docker: build + prerender in stage one, a FROM-scratch export stage emits dist/.",
            "PWA is opt-in and hands you the manifest and service worker to own.",
        ],
        quiz: Quiz(questions: [
            Question(prompt: "In what order do build and ssg run?",
                     options: ["build first, then ssg — pages land last", "ssg first, then build", "Order doesn’t matter"],
                     correctIndex: 0,
                     explanation: "The CLI’s dist assembly would clobber prerendered pages; ssg writes last so they win."),
            Question(prompt: "How does hydration attach listeners without rebuilding the page?",
                     options: ["It adopts the prerendered DOM node by node", "It replaces body.innerHTML", "It diffs against an empty tree"],
                     correctIndex: 0,
                     explanation: "Adoption walks the existing DOM against the resolved tree and binds in place."),
            Question(prompt: "What marks a successfully hydrated page?",
                     options: ["data-swui-hydrated=\"true\" on the container", "A console.log line", "Nothing observable"],
                     correctIndex: 0,
                     explanation: "The runtime sets the attribute only when adoption succeeds — silence proves nothing."),
        ]))
}
