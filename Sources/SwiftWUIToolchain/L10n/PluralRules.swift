/// CLDR cardinal rules, specialised for `Int` (v=w=f=t=0, n = i), emitted only
/// for declared languages. Keeping them in generated Swift is what makes wasm
/// and native SSG agree without `Intl.PluralRules`.
public enum PluralRules {
    public static let supported: Set<String> = [
        "en", "de", "it", "es", "nl", "sv", "da", "nb", "fi", "el", "hu", "tr",
        "fr", "pt", "ru", "uk", "pl", "cs", "sk", "ar", "ja", "zh", "ko",
    ]

    /// Body of `static func <lang>(_ value: Int) -> _PluralCategory`.
    ///
    /// Known ceiling: rules are picked by PRIMARY subtag, and pt-PT is the one
    /// regional variant among the 23 that disagrees with its base (CLDR: pt 0 →
    /// one, pt-PT 0 → other). A `Locales/pt-PT.json` catalog therefore renders
    /// pt's "one" branch at count 0. Region-aware bodies if that ever bites.
    ///
    /// CLDR's `n` is the absolute value, but `abs(Int.min)` traps — and this code
    /// runs inside the user's app, so the trap would be theirs. `magnitude` is the
    /// unsigned absolute value and is total; every other input agrees with `abs`.
    public static func swiftBody(language: String) -> String? {
        switch language {
        case "ja", "zh", "ko":
            return "        return .other"
        case "en", "de", "nl", "sv", "da", "nb", "fi", "el", "hu", "tr":
            return "        return value == 1 ? .one : .other"
        // CLDR 38+ gave the Romance four a `many` for exact millions
        // (`i != 0 and i % 1000000 = 0`, integers only). `magnitude % 1_000_000`
        // is total — `Int.min` has no `abs`, but it does have a magnitude.
        case "es", "it":
            return """
                    let n = value.magnitude
                    if n == 1 { return .one }
                    if n != 0 && n % 1_000_000 == 0 { return .many }
                    return .other
            """
        case "fr", "pt":
            return """
                    let n = value.magnitude
                    if n <= 1 { return .one }
                    if n % 1_000_000 == 0 { return .many }
                    return .other
            """
        case "ru", "uk":
            return """
                    let n = value.magnitude
                    let mod10 = n % 10, mod100 = n % 100
                    if mod10 == 1 && mod100 != 11 { return .one }
                    if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
                    return .many
            """
        case "pl":
            return """
                    let n = value.magnitude
                    let mod10 = n % 10, mod100 = n % 100
                    if n == 1 { return .one }
                    if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
                    return .many
            """
        case "cs", "sk":
            return """
                    let n = value.magnitude
                    if n == 1 { return .one }
                    if (2...4).contains(n) { return .few }
                    return .other
            """
        case "ar":
            return """
                    let n = value.magnitude
                    if n == 0 { return .zero }
                    if n == 1 { return .one }
                    if n == 2 { return .two }
                    let mod100 = n % 100
                    if (3...10).contains(mod100) { return .few }
                    if (11...99).contains(mod100) { return .many }
                    return .other
            """
        default:
            return nil
        }
    }
}
