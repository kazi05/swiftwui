/// Chapter 9 — Wrap-up: Routing.
public enum Ch09 {
    public static let chapter = Chapter(
        slug: "wrap-up-routing", track: .routing, kicker: "WRAP-UP · ROUTING",
        title: "Wrap-up: Routing",
        tagline: "Routes, links, and identity — recapped.",
        minutes: 5, kind: .wrapUp,
        recap: [
            "Router is a Tag; routes are data — pattern, optional guard, content.",
            "First match wins in declaration order; :param captures arrive as a dictionary.",
            "Link intercepts internal clicks; modified clicks and external URLs stay native.",
            "Identity is keyed by route pattern — param changes keep @State, route changes reset it.",
        ],
        quiz: Quiz(questions: [
            Question(prompt: "You navigate /docs/intro → /docs/api under Route(\"/docs/:page\"). What happens to the page’s @State?",
                     options: ["It is preserved — same route identity", "It resets", "It crashes"],
                     correctIndex: 0,
                     explanation: "Param-only changes keep the keyed identity, so state survives (spec D2 of the routing phase)."),
            Question(prompt: "What does Link render for an external https:// destination?",
                     options: ["A plain <a> the browser handles", "An intercepted SPA link", "A disabled anchor"],
                     correctIndex: 0,
                     explanation: "Only internal root-relative destinations are intercepted into navigate()."),
            Question(prompt: "How many Routers may an app declare?",
                     options: ["Exactly one", "One per page", "Any number, nested"],
                     correctIndex: 0,
                     explanation: "One Router per app — a second one traps in debug builds."),
        ]))
}
