#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH"
    case delete = "DELETE", head = "HEAD"
}

/// URLRequest-shaped value (no FoundationNetworking on wasm). URL may be
/// absolute http(s) or origin-relative ("/api/x", "api/x", "?q=1").
public struct WebRequest {
    public var url: String
    public var method: HTTPMethod = .get
    public var headers: [String: String] = [:]
    public var body: _FoundationData? = nil
    /// Enforced by the transport (fetch: abort timer; URLSession: timeoutInterval).
    public var timeout: Duration? = nil
    public init(url: String) { self.url = url }
}

public struct WebResponse: Equatable {
    public let status: Int
    public let headers: [String: String]
    public var isSuccess: Bool { (200..<300).contains(status) }
    public init(status: Int, headers: [String: String]) {
        self.status = status; self.headers = headers
    }
}

public enum WebFetchError: Error, Equatable {
    case badURL(String)
    case invalidHeader(String)
    case network(String)
    case cancelled
    case timeout
    case decoding(String)
    /// Thrown ONLY by the Codable sugar on non-2xx (URLSession parity:
    /// data(for:) never treats status as an error).
    case httpStatus(Int, _FoundationData)
    case unsupported
}

/// Injected per platform: SwiftWUIDOM = fetch(), SwiftWUIStatic = URLSession,
/// tests = scripted mock. Core ships only the unconfigured default (throws).
public protocol FetchTransport: AnyObject {
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse)
}

final class _UnsupportedTransport: FetchTransport {
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        throw WebFetchError.unsupported
    }
}

/// Per-runtime fetch session, delivered via @Environment(\.webSession) — never
/// a process global (test isolation). Credential policy is a transport-level
/// security invariant: same-origin only, both platforms.
@MainActor
public final class WebSession {
    public static let unsupported = WebSession(transport: _UnsupportedTransport())
    private let transport: FetchTransport
    public init(transport: FetchTransport) { self.transport = transport }

    public func data(for request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        try Self.validate(request)
        return try await transport.perform(request)
    }
    public func data(from url: String) async throws -> (_FoundationData, WebResponse) {
        try await data(for: WebRequest(url: url))
    }
    public func json<T: Decodable>(from url: String, as type: T.Type = T.self) async throws -> T {
        let (data, resp) = try await data(from: url)
        guard resp.isSuccess else { throw WebFetchError.httpStatus(resp.status, data) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw WebFetchError.decoding(String(describing: error)) }
    }
    public func send<B: Encodable, T: Decodable>(
        _ method: HTTPMethod, _ url: String, json body: B) async throws -> T {
        var req = WebRequest(url: url)
        req.method = method
        req.headers["Content-Type"] = "application/json"
        do { req.body = try JSONEncoder().encode(body) }
        catch { throw WebFetchError.decoding(String(describing: error)) }
        let (data, resp) = try await data(for: req)
        guard resp.isSuccess else { throw WebFetchError.httpStatus(resp.status, data) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw WebFetchError.decoding(String(describing: error)) }
    }

    /// Boundary validation (spec 8a security): http/https only — narrower than
    /// sanitizeURL's attribute allowlist; CR/LF/NUL rejected in header names AND values.
    static func validate(_ request: WebRequest) throws {
        let url = request.url
        guard !url.isEmpty else { throw WebFetchError.badURL(url) }
        // WHATWG parsers strip leading C0/space and treat '\' as '/' in special
        // schemes — validate against the normalized view, not raw bytes.
        if let first = url.unicodeScalars.first, first <= " " || first == "\u{7F}" {
            throw WebFetchError.badURL(url)
        }
        let head = Array(url.prefix(2))
        if head.count == 2, (head[0] == "/" || head[0] == "\\"),
           (head[1] == "/" || head[1] == "\\") {
            throw WebFetchError.badURL(url)   // protocol-relative = absolute cross-origin
        }
        let beforePathOrQuery = url.prefix { $0 != "/" && $0 != "\\" && $0 != "?" && $0 != "#" }
        if beforePathOrQuery.contains(":") {                       // has a scheme
            let scheme = url.prefix { $0 != ":" }.lowercased()
            guard scheme == "http" || scheme == "https" else {
                throw WebFetchError.badURL(url)
            }
        }                                                           // else: relative — OK
        for (name, value) in request.headers {
            for scalar in name.unicodeScalars where scalar == "\r" || scalar == "\n" || scalar == "\0" {
                _ = scalar; throw WebFetchError.invalidHeader(name)
            }
            for scalar in value.unicodeScalars where scalar == "\r" || scalar == "\n" || scalar == "\0" {
                _ = scalar; throw WebFetchError.invalidHeader(name)
            }
        }
    }
}

struct _WebSessionKey: EnvironmentKey {
    static let defaultValue: WebSession? = nil
}
extension EnvironmentValues {
    /// The runtime's fetch session. Outside a configured runtime every request
    /// throws WebFetchError.unsupported.
    public var webSession: WebSession {
        self[_WebSessionKey.self] ?? WebSession.unsupported
    }
    var _webSessionOptional: WebSession? {
        get { self[_WebSessionKey.self] }
        set { self[_WebSessionKey.self] = newValue }
    }
}
