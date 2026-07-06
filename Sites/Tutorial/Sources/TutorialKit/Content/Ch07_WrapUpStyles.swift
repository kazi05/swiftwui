/// Chapter 7 — Wrap-up: Styles.
public enum Ch07 {
    public static let chapter = Chapter(
        slug: "wrap-up-styles", track: .styles, kicker: "WRAP-UP · STYLES",
        title: "Wrap-up: Styles",
        tagline: "Modifiers, rules, and themes — recapped.",
        minutes: 5, kind: .wrapUp,
        recap: [
            "Type-safe modifiers collapse into one inline style attribute per element.",
            "Rule(class:) in globalStyles emits a real stylesheet with pseudo and media support.",
            "ColorToken + ThemeDefinition give CSS-variable theming; switching themes is one attribute write.",
            ".style(\"property\", \"value\") covers what the DSL doesn’t — values are validated, never escaped into selectors.",
        ],
        quiz: Quiz(questions: [
            Question(prompt: "Where do chained .padding()-style modifiers land in the DOM?",
                     options: ["One collapsed inline style attribute", "A generated CSS file per component", "JavaScript style calls at runtime"],
                     correctIndex: 0,
                     explanation: "Consecutive style modifiers append to the same wrapper and serialize as one style attribute."),
            Question(prompt: "What emits a [data-theme=\"dark\"] rule block?",
                     options: ["ThemeDefinition(name: \"dark\")", "Rule(class: \"dark\")", "An inline .style() call"],
                     correctIndex: 0,
                     explanation: "Named themes render as [data-theme] selectors; the default theme renders as :root."),
            Question(prompt: "The DSL has no backdrop-filter modifier. What do you do?",
                     options: [".style(\"backdrop-filter\", \"blur(4px)\")", "Edit the generated CSS in dist", "Add JavaScript"],
                     correctIndex: 0,
                     explanation: "The escape hatch takes any property/value pair and validates it before emitting."),
        ]))
}
