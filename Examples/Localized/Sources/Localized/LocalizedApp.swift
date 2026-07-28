import SwiftWUI
import SwiftWUIDOM

// A language switcher built entirely from the environment: `\.availableLocales`
// is the declared locale set, so this component never imports the generated
// `L10n` and keeps working when a catalog is added.
struct LocaleSwitcher: Tag {
    @Environment(\.availableLocales) private var locales
    @Environment(\.locale) private var current
    @Environment(\.setLocale) private var setLocale

    var body: some Tag {
        Nav(class: "switcher") {
            ForEach(locales, id: \.identifier) { locale in
                Button(locale.identifier, disabled: locale == current) { setLocale(locale) }
            }
        }
    }
}

struct Home: Tag {
    @State private var count = 0
    @State private var query = ""

    var body: some Tag {
        Main {
            H1 { Text(L10n.welcomeTitle(name: "SwiftWUI")) }
            Img(src: "/logo.svg", alt: L10n.logoAlt(), width: 64, height: 64)

            // One key, one call site: the plural category is picked by the
            // locale's own CLDR rule inside the generated code.
            P { Text(count == 0 ? L10n.cartEmpty() : L10n.itemsCount(count: count)) }
            Div {
                Button(L10n.addItem()) { count += 1 }
                Button(L10n.reset(), disabled: count == 0) { count = 0 }
            }

            Input(value: $query, placeholder: L10n.searchPlaceholder())
            DirectionDemo()

            // Internal, prefix-free path — `Link` adds the locale prefix to the
            // href itself. Passing "/ru/about" here would match no route.
            Link("/about") { Text(L10n.navAbout()) }
        }
        .pageMeta(title: L10n.welcomeTitle(name: "SwiftWUI"))
    }
}

struct About: Tag {
    var body: some Tag {
        Main {
            H1 { Text(L10n.aboutTitle()) }
            P { Text(L10n.aboutBody()) }
            Link("/") { Text(L10n.navHome()) }
        }
        .pageMeta(title: L10n.aboutTitle())
    }
}

// RTL demo. `<html dir>` is written by the runtime on every locale change, so
// switching to `ar` mirrors the whole document without any work here; this
// component only reports what the environment says.
struct DirectionDemo: Tag {
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var direction

    var body: some Tag {
        Section(class: "direction") {
            P { Text(L10n.directionNote()) }
            // The escape hatch: `resolved(for:)` turns a `LocalizedText` into a
            // plain String for APIs that have no localized overload — here,
            // string interpolation.
            P { Text("\(locale.identifier)/\(direction.rawValue): \(L10n.directionNote().resolved(for: locale))") }
            // A localized attribute. It is applied after every plain attribute
            // of the same name, whatever order the modifiers were written in.
            Span { "?" }.attribute("title", L10n.directionNote())
        }
    }
}

@main
struct LocalizedApp: App {
    static var localization: Localization? {
        Localization(catalog: L10n.self, default: .en, strategy: .pathPrefix())
    }

    var body: some Tag {
        Div {
            LocaleSwitcher()
            Router {
                Route("/") { Home() }
                Route("/about") { About() }
            }
        }
    }
}
