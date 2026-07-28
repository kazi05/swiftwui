import SwiftWUI

/// Chapter: "Responsive layout". One card gallery across four surfaces: a
/// structural branch on `\.media`, per-breakpoint values from
/// `responsive(_:sm:md:lg:xl:)`, a container query, and a stylesheet `Rule`.

struct Card: Sendable {
    let id: String
    let name: String
    let blurb: String
}

enum Gallery {
    static let cards: [Card] = [
        Card(id: "grid", name: "Grid", blurb: "Two columns at md, three at lg."),
        Card(id: "box", name: "Container", blurb: "Reads its own width, not the viewport's."),
        Card(id: "rule", name: "Rule", blurb: "The same query at stylesheet level."),
    ]
}

// tutorial:begin tour-responsive-structural
struct ResponsiveDemo: Tag, Styled {
    /// Reserve `\.media` for real tree differences. It reads `false` during
    /// SSG, so the phone list is what prerenders and the grid arrives with
    /// hydration — for pure styling use `responsive()`/`.media()` instead.
    @Environment(\.media) private var media

    var body: some Tag {
        Main(class: "tour") {
            H1("Responsive layout")
            if media.matches(.up(.md)) {
                CardGrid(cards: Gallery.cards)
            } else {
                Ul(class: "compact") {
                    ForEach(Gallery.cards, id: \.id) { card in
                        Li { Strong { Text(card.name) }; Text(" — " + card.blurb) }
                    }
                }
            }
            CardBox(card: Gallery.cards[1])
            P(class: "note") { "A list and a grid are different trees, not one tree styled twice." }
            Link("/") { Span { "Back to the tour" } }
        }
    }
// tutorial:end tour-responsive-structural

// tutorial:begin tour-responsive-rules
    /// Stylesheet level: the query lives in the rule, so nothing flashes before
    /// hydration. `media:` and `container:` are mutually exclusive on one Rule.
    @RulesBuilder var styles: [Rule] {
        Rule(class: "compact") { p in
            p.listStyleType(.none)
            p.padding(.zero)
            p.display(.grid); p.gap(.px(12))
        }
        // Combinators self-parenthesise, so they nest without producing invalid CSS.
        Rule(class: "compact", media: .or(.down(.sm), .orientation(.portrait))) { p in
            p.gap(.px(6))
        }
        Rule(class: "note", media: .prefersColorScheme(.dark)) { p in
            p.color(.hex("#a8a29e"))
        }
    }
// tutorial:end tour-responsive-rules
}

// tutorial:begin tour-responsive-scale
/// Per-breakpoint values. Each one desugars to a base class rule plus
/// non-overlapping `@media` ranges. Never pair a `responsive()` modifier with a
/// plain call for the same property on the same element: the plain call becomes
/// an inline style and out-specifies every override.
struct CardGrid: Tag {
    let cards: [Card]

    var body: some Tag {
        Div {
            ForEach(cards, id: \.id) { card in
                Article(class: "card") {
                    H3(card.name)
                    P { Text(card.blurb) }
                }
                .background(.hex("#ffffff"))
                .borderRadius(.px(10))
            }
        }
        .display(.grid)
        .gap(.px(16))
        .gridTemplateColumns(responsive("1fr", md: "1fr 1fr", lg: "repeat(3, 1fr)"))
        .padding(responsive(.px(12), md: .px(20), lg: .px(28)))
        .fontSize(responsive(.rem(0.95), lg: .rem(1.05)))
    }
}
// tutorial:end tour-responsive-scale

// tutorial:begin tour-responsive-container
/// A container query: the card measures the box it sits in, so the same card
/// restyles itself in a narrow sidebar without either side knowing the viewport
/// width. An unusable container name is dropped, never sanitised.
struct CardBox: Tag {
    let card: Card

    var body: some Tag {
        Section {
            Article(class: "card") {
                H3(card.name)
                P { Text(card.blurb) }
            }
            .borderRadius(.px(10))
            .border(.px(1), .solid, .hex("#e7e5e4"))
            .container(.up(.sm), name: "gallery") { p in
                p.display(.flex)
                p.alignItems(.center)
                p.gap(.px(16))
            }
        }
        .containerType(.inlineSize, name: "gallery")
    }
}
// tutorial:end tour-responsive-container
