import Foundation

/// Toolchain-side reader for `SwiftWUIStatic.StaticDeliveryManifest`. This is
/// intentionally duplicated at the module boundary: SwiftWUIToolchain stays
/// usable by projects that do not link the native static renderer.
public struct StaticDelivery: Equatable, Sendable {
    public static let descriptorName = "swiftwui-delivery.json"

    public struct Redirect: Codable, Equatable, Sendable {
        public var from: String
        public var to: String
        public var status: Int
    }

    public var trailingSlash: TrailingSlash
    public var fallback: Fallback
    public var redirects: [Redirect]
    public var routes: [String]

    public enum TrailingSlash: String, Codable, Equatable, Sendable {
        case preserve, always, never
    }
    public enum Fallback: String, Codable, Equatable, Sendable { case spa, notFound }

    public init(trailingSlash: TrailingSlash = .preserve, fallback: Fallback = .spa,
                redirects: [Redirect] = [], routes: [String] = []) {
        self.trailingSlash = trailingSlash; self.fallback = fallback; self.redirects = redirects; self.routes = routes
    }

    private struct File: Codable { var version: Int; var trailingSlash: TrailingSlash; var fallback: Fallback?; var redirects: [Redirect]; var routes: [String]? }

    public static func read(distDir: String) -> StaticDelivery? {
        let path = distDir + "/" + descriptorName
        guard let data = FileManager.default.contents(atPath: path),
              let file = try? JSONDecoder().decode(File.self, from: data), file.version == 1,
              file.redirects.allSatisfy({ [301, 302, 308].contains($0.status) && validPath($0.from) && validPath($0.to) }),
              (file.routes ?? []).allSatisfy(validPath)
        else { return nil }
        return StaticDelivery(trailingSlash: file.trailingSlash, fallback: file.fallback ?? .spa, redirects: file.redirects,
                              routes: file.routes ?? [])
    }

    static func validPath(_ path: String) -> Bool {
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

    func response(for requestPath: String) -> HTTPResponse? {
        let path = normalized(requestPath)
        if let redirect = redirects.first(where: { normalized($0.from) == path }) {
            return HTTPResponse(status: redirect.status, headers: ["Location": normalized(redirect.to)])
        }
        switch trailingSlash {
        case .preserve: return nil
        case .always:
            guard path != "/", !path.hasSuffix("/"), routes.contains(path) else { return nil }
            return redirect(path + "/")
        case .never:
            guard path.count > 1, path.hasSuffix("/"), routes.contains(String(path.dropLast())) else { return nil }
            return redirect(String(path.dropLast()))
        }
    }

    func permitsSPAFallback(for requestPath: String) -> Bool {
        fallback == .spa
    }

    private func redirect(_ location: String) -> HTTPResponse {
        HTTPResponse(status: 308, headers: ["Location": location])
    }

    private func normalized(_ path: String) -> String {
        let head = String(path.prefix { $0 != "?" && $0 != "#" })
        return head.isEmpty ? "/" : (head.hasPrefix("/") ? head : "/" + head)
    }

}
