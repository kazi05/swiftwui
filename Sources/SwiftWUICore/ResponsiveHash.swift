// ResponsiveHash.swift - Deterministic CSS class name generation for responsive styles

/// Generates a deterministic CSS class name from a media query string and style declarations.
///
/// Uses FNV-1a hash for fast, stable hashing. The same inputs always produce the same
/// class name, enabling the Reconciler to diff responsive styles as class changes.
///
/// - Parameters:
///   - mediaQuery: The CSS media query string (e.g., `@media (max-width: 767px)`).
///   - styles: Style declarations to include in the hash.
/// - Returns: A class name like `swui-r1a2b3c4d5e6f7g8`.
public func responsiveClassName(mediaQuery: String, styles: [String: String]) -> String {
    let sortedDeclarations = styles
        .sorted(by: { $0.key < $1.key })
        .map { "\($0.key):\($0.value)" }
        .joined(separator: ";")
    let input = "\(mediaQuery){\(sortedDeclarations)}"

    // FNV-1a 64-bit hash
    var hash: UInt64 = 14695981039346656037 // FNV offset basis
    for byte in input.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1099511628211 // FNV prime
    }

    return "swui-r\(String(hash, radix: 16))"
}

/// Convert responsive styles dictionary to a set of CSS class names.
///
/// Used by the Reconciler to translate `TagNode.Element.responsiveStyles`
/// into class names for diffing.
public func responsiveClassNames(for responsiveStyles: [String: [String: String]]) -> Set<String> {
    Set(responsiveStyles.map { (query, styles) in
        responsiveClassName(mediaQuery: query, styles: styles)
    })
}
