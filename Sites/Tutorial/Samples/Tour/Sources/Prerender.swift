import SwiftWUI

/// Chapter: "Prerender on your terms". A product page whose `<head>` is
/// computed from data loaded at build time — the case `Page.title` cannot
/// serve, because `Router` snapshots that before `@State` is grafted.

struct Product: Sendable {
    let slug: String
    let name: String
    let blurb: String
    let priceUSD: Int
}

enum Catalog {
    static let all: [Product] = [
        Product(slug: "nimbus-7", name: "Nimbus 7", blurb: "A desk lamp that reads the room.", priceUSD: 189),
        Product(slug: "harbor-mug", name: "Harbor mug", blurb: "Stoneware, 340 ml, dishwasher-safe.", priceUSD: 34),
        Product(slug: "field-notes", name: "Field notes", blurb: "Three ruled notebooks, sewn spine.", priceUSD: 17),
    ]

    /// Stands in for the API call a real catalogue would make. `Prerender.paths`
    /// awaits this once per `generate()` run.
    static func allSlugs() async -> [String] { all.map { "/product/\($0.slug)" } }

    static func load(slug: String) async -> Product? { all.first { $0.slug == slug } }
}

// tutorial:begin tour-pagemeta
struct ProductPage: Tag {
    @RouteParam("id") var id: String?
    @State private var product: Product?

    var body: some Tag {
        Main(class: "tour") {
            if let product {
                H1(product.name)
                P { Text(product.blurb) }
                P { Text("$\(product.priceUSD)") }
            } else {
                P { "Loading…" }
            }
            Link("/") { Span { "Back to the tour" } }
        }
        .staticTask { product = await Catalog.load(slug: id ?? "") }
        .pageMeta(title: product.map { "\($0.name) — SwiftWUI Tour" },
                  meta: product.map { [.description($0.blurb)] },
                  structuredData: product.map { [Self.productJSONLD($0)] })
    }

    static func productJSONLD(_ p: Product) -> String {
        """
        {"@context":"https://schema.org","@type":"Product",\
        "name":"\(p.name)","description":"\(p.blurb)",\
        "offers":{"@type":"Offer","price":"\(p.priceUSD)","priceCurrency":"USD"}}
        """
    }
}
// tutorial:end tour-pagemeta
