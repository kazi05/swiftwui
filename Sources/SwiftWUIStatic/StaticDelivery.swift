import Foundation

/// Serialization seam between SwiftWUIStatic and SwiftWUIToolchain. Keep this
/// JSON intentionally small: hosts need request-path rules, not Swift types.
public enum StaticDeliveryManifest {
    public static let fileName = "swiftwui-delivery.json"

    public static func json(redirects: [StaticRedirect], routes: [String], trailingSlash: TrailingSlashPolicy,
                            fallback: StaticFallbackPolicy) -> String {
        let rows = redirects.map { redirect in
            let from = jsonString(normalize(redirect.from))
            let to = jsonString(normalize(redirect.to))
            return #"{"from":\#(from),"to":\#(to),"status":\#(redirect.status.rawValue)}"#
        }.joined(separator: ",")
        let paths = routes.map { jsonString(normalize($0)) }.joined(separator: ",")
        return #"{"version":1,"trailingSlash":\#(jsonString(trailingSlash.rawValue)),"fallback":\#(jsonString(fallback.rawValue)),"redirects":[\#(rows)],"routes":[\#(paths)]}"#
    }

    public static func write(redirects: [StaticRedirect], routes: [String], trailingSlash: TrailingSlashPolicy,
                             fallback: StaticFallbackPolicy,
                             outDir: String) throws {
        let path = outDir + "/" + fileName
        do {
            try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
            try json(redirects: redirects, routes: routes, trailingSlash: trailingSlash, fallback: fallback)
                .write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw StaticSiteError.io(path: path, underlying: "\(error)")
        }
    }

    static func normalize(_ path: String) -> String {
        let head = String(path.prefix { $0 != "?" && $0 != "#" })
        if head.isEmpty { return "/" }
        return head.hasPrefix("/") ? head : "/" + head
    }

    static func isLocalPath(_ path: String) -> Bool {
        guard path.hasPrefix("/"), !path.hasPrefix("//"),
              !path.contains("?"), !path.contains("#"),
              !containsUnsafePathCharacter(path),
              let decoded = path.removingPercentEncoding,
              decoded.hasPrefix("/"), !decoded.hasPrefix("//"),
              !decoded.contains("?"), !decoded.contains("#"),
              !containsUnsafePathCharacter(decoded)
        else { return false }
        return !decoded.split(separator: "/", omittingEmptySubsequences: false)
            .contains(where: { $0 == "." || $0 == ".." })
    }

    private static func containsUnsafePathCharacter(_ path: String) -> Bool {
        path.contains(where: {
            $0.isWhitespace || $0 == "$" || $0 == ";" || $0 == "\\" || $0 == "\""
                || $0 == "'" || $0 == "{" || $0 == "}" || $0 == "\0"
        })
    }

    private static func jsonString(_ value: String) -> String {
        // JSONSerialization is a real parser/encoder, unlike hand escaping.
        let data = try! JSONSerialization.data(withJSONObject: [value])
        let array = String(decoding: data, as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }
}
