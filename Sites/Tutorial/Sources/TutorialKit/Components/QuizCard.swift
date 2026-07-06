import SwiftWUI

/// "Check your understanding" band (Figma 9:26). Fully client-side @State —
/// this component is the site's proof of hydrated interactivity.
public struct QuizCard: Tag {
    let quiz: Quiz
    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var checked = false

    public init(quiz: Quiz) { self.quiz = quiz }

    private func optionClass(_ i: Int, question: Question) -> String {
        if checked {
            if i == question.correctIndex { return "tut-option tut-option-correct" }
            if i == selected { return "tut-option tut-option-wrong" }
            return "tut-option"
        }
        return i == selected ? "tut-option tut-option-selected" : "tut-option"
    }

    // ponytail: StyleRegistry emits hash-ordered rules — the state classes
    // above (still the smoke/test-facing markers) can lose a same-specificity
    // override lottery. These inline declarations always win the cascade.
    private func withOptionState<T: HTMLTag>(_ tag: T, _ i: Int, question: Question) -> T {
        if checked {
            if i == question.correctIndex {
                return tag.style("border", "1.5px solid #5a8c3c").style("background", "rgba(90,140,60,0.08)")
            }
            if i == selected {
                return tag.style("border", "1.5px solid var(--accent)").style("background", "rgba(217,85,47,0.06)")
            }
            return tag
        }
        if i == selected {
            return tag.style("border", "1.5px solid var(--accent)").style("background", "rgba(217,85,47,0.06)")
        }
        return tag
    }

    public var body: some Tag {
        let question = quiz.questions[index]
        Div(class: "tut-quiz") {
            Div(class: "tut-content") {
                Div(class: "tut-quiz-header") {
                    Span(class: "tut-kicker") { "CHECK YOUR UNDERSTANDING" }
                    H2("Question \(index + 1) of \(quiz.questions.count)", class: "tut-question")
                }
                Div(class: "tut-quiz-card") {
                    P(class: "tut-quiz-prompt") { Text(question.prompt) }
                    ForEach(Array(question.options.enumerated()), id: \.offset) { item in
                        withOptionState(
                            Div(class: optionClass(item.offset, question: question)) {
                                Span(class: "tut-radio")
                                Span(class: "tut-option-label") { Text(item.element) }
                            },
                            item.offset, question: question
                        )
                        .on(.click) { _ in
                            guard !checked else { return }
                            selected = item.offset
                        }
                    }
                    if checked {
                        P(class: selected == question.correctIndex
                          ? "tut-explain tut-explain-ok" : "tut-explain tut-explain-no") {
                            Text(question.explanation)
                        }
                        .color(selected == question.correctIndex ? .hex("#5a8c3c") : .token(.accent))
                        if index + 1 < quiz.questions.count {
                            Button("Next question", class: "tut-quiz-submit", onClick: {
                                index += 1; selected = nil; checked = false
                            })
                        }
                    } else {
                        Button("Check answer", class: "tut-quiz-submit", onClick: {
                            if selected != nil { checked = true }
                        })
                    }
                }
            }
        }
    }
}
