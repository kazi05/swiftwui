import SwiftWUI

/// "Check your understanding" band. Fully client-side @State — this component
/// is the site's proof of hydrated interactivity.
public struct QuizCard: Tag {
    let quiz: Quiz
    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var checked = false

    public init(quiz: Quiz) { self.quiz = quiz }

    /// One state machine for the row, its marker and its verdict — the three
    /// used to branch separately and could disagree.
    private enum OptionState { case rest, selected, correct, wrong }

    private func state(_ i: Int, question: Question) -> OptionState {
        guard checked else { return i == selected ? .selected : .rest }
        if i == question.correctIndex { return .correct }
        return i == selected ? .wrong : .rest
    }

    private func optionClass(_ s: OptionState) -> String {
        switch s {
        case .rest:     return "tut-option tut-option-rest"
        case .selected: return "tut-option tut-option-selected"
        case .correct:  return "tut-option tut-option-correct"
        case .wrong:    return "tut-option tut-option-wrong"
        }
    }

    private func markerClass(_ s: OptionState) -> String {
        switch s {
        case .rest:     return "tut-radio tut-radio-rest"
        case .selected: return "tut-radio tut-radio-selected"
        case .correct:  return "tut-radio tut-radio-ok"
        case .wrong:    return "tut-radio tut-radio-err"
        }
    }

    /// A real `<button type="button">` with `aria-pressed`: the row has to be
    /// reachable by keyboard and announce its own state, which no CSS can fix.
    ///
    /// The two inline declarations are the only pair where a skin rule and the
    /// `.tut-option` base collide on one property at the same specificity, in
    /// the same (non-media) block — `border-left-width` against the base's
    /// `border-width: 1.5px`, and the wrong row's dashed `border-style` against
    /// the base's `solid`. StyleRegistry breaks that tie by hash, so those two
    /// stay inline; every other state is class-only.
    private func optionRow(_ i: Int, _ label: String, question: Question) -> some Tag {
        let s = state(i, question: question)
        var row = Button(type: .button, class: optionClass(s), onClick: {
            guard !checked else { return }
            selected = i
        }) {
            Span(class: markerClass(s)) {
                switch s {
                case .rest:     EmptyTag()
                case .selected: Span(class: "tut-radio-dot")
                case .correct:  "✓"
                case .wrong:    "✕"
                }
            }
            Span(class: "tut-option-label") { Text(label) }
            // Colour is never the only channel: glyph above, label here, 3px
            // left border below.
            if s == .correct {
                Span(class: "tut-option-verdict tut-option-verdict-ok") { "correct" }
            } else if s == .wrong {
                Span(class: "tut-option-verdict tut-option-verdict-err") { "not this one" }
            }
        }
        .attribute("aria-pressed", selected == i ? "true" : "false")

        switch s {
        case .correct:
            row = row
                .borderWidth(.left, .px(3))
                .animation(TutorialMotion.pop, duration: .ms(260),
                           timingFunction: TutorialMotion.ease)
        case .wrong:
            row = row
                .borderWidth(.left, .px(3)).borderStyle(.dashed)
                .animation(TutorialMotion.nudge, duration: .ms(220), iterations: .count(2))
        case .rest, .selected:
            break
        }
        return row
    }

    public var body: some Tag {
        let question = quiz.questions[index]
        let total = quiz.questions.count
        let right = selected == question.correctIndex
        Div(class: "tut-quiz") {
            Div(class: "tut-content") {
                Div(class: "tut-quiz-header") {
                    Div(class: "tut-kicker-row") {
                        Span(class: "tut-kicker") {
                            Span(class: "tut-kicker-slash") { "//" }
                            " check your understanding"
                        }
                        Div(class: "tut-kicker-rule")
                    }
                    H2("Chapter quiz", class: "tut-question")
                    Div(class: "tut-quiz-counter") {
                        Span(class: "tut-quiz-counter-label") {
                            "question \(index + 1) of \(total)"
                        }
                        Div(class: "tut-quiz-progress-track") {
                            Div(class: "tut-quiz-progress")
                                .width(.percent((Double(index + 1) / Double(total) * 100).rounded()))
                        }
                    }
                }
                Div(class: "tut-quiz-card") {
                    P(class: "tut-quiz-prompt") { Text(question.prompt) }
                    ForEach(Array(question.options.enumerated()), id: \.offset) { item in
                        optionRow(item.offset, item.element, question: question)
                    }
                    if checked {
                        Div(class: "tut-explain") {
                            Span(class: right ? "tut-explain-label tut-explain-ok"
                                              : "tut-explain-label tut-explain-no") {
                                right ? "// correct" : "// not quite"
                            }
                            // The prose is never tinted — only its label is.
                            P(class: "tut-explain-body") { Text(question.explanation) }
                        }
                        .transition(.opacity.combined(with: .offset(x: 0, y: 4)).animation(.snappy))
                        if index + 1 < total {
                            Button("Next question",
                                   class: "tut-btn tut-btn-primary tut-quiz-submit", onClick: {
                                index += 1; selected = nil; checked = false
                            })
                        }
                    } else {
                        // No disabled state in this system: submitting with
                        // nothing selected simply does nothing.
                        Button("Check answer",
                               class: "tut-btn tut-btn-primary tut-quiz-submit", onClick: {
                            if selected != nil { checked = true }
                        })
                    }
                }
            }
        }
        // wrap-up routes share the /tutorials/:slug pattern, so @State
        // survives quiz-to-quiz navigation — reset the state machine.
        .onChange(of: quiz) { _, _ in index = 0; selected = nil; checked = false }
    }
}
