/// CLDR cardinal rules, specialised for `Int` (v=w=f=t=0, n = i), emitted only
/// for declared languages. Keeping them in generated Swift is what makes wasm
/// and native SSG agree without `Intl.PluralRules`.
public enum PluralRules {
    public static let supported: Set<String> = [
        "en", "de", "it", "es", "nl", "sv", "da", "nb", "fi", "el", "hu", "tr",
        "fr", "pt", "ru", "uk", "pl", "cs", "sk", "ar", "ja", "zh", "ko",
    ]

    /// Body of `static func <lang>(_ value: Int) -> _PluralCategory`.
    public static func swiftBody(language: String) -> String? {
        switch language {
        case "ja", "zh", "ko":
            return "        return .other"
        case "en", "de", "it", "es", "nl", "sv", "da", "nb", "fi", "el", "hu", "tr":
            return "        return value == 1 ? .one : .other"
        case "fr", "pt":
            return "        return (value == 0 || value == 1) ? .one : .other"
        case "ru", "uk":
            return """
                    let n = abs(value)
                    let mod10 = n % 10, mod100 = n % 100
                    if mod10 == 1 && mod100 != 11 { return .one }
                    if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
                    return .many
            """
        case "pl":
            return """
                    let n = abs(value)
                    let mod10 = n % 10, mod100 = n % 100
                    if n == 1 { return .one }
                    if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
                    return .many
            """
        case "cs", "sk":
            return """
                    let n = abs(value)
                    if n == 1 { return .one }
                    if (2...4).contains(n) { return .few }
                    return .other
            """
        case "ar":
            return """
                    let n = abs(value)
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
