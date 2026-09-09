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
    /// Keys are lowercase-normalized by every transport (fetch() and URLSession).
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

public enum WebUploadError: Error, Equatable {
    /// The request already contains a body, including an empty body.
    case conflictingBody
    /// The request method does not permit this upload body.
    case invalidMethod
}

/// Injected per platform: SwiftWUIDOM = fetch(), SwiftWUIStatic = URLSession,
/// tests = scripted mock. Core ships only the unconfigured default (throws).
public protocol FetchTransport: AnyObject {
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse)
}

@MainActor
/// Optional transport capability for uploading a blob without a whole-resource read.
public protocol _BlobUploadingTransport: FetchTransport {
    func upload(_ request: WebRequest, from blob: WebBlob)
        async throws -> (_FoundationData, WebResponse)
}

final class _UnsupportedTransport: FetchTransport {
    nonisolated deinit { }
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        throw WebFetchError.unsupported
    }
}

/// Per-runtime fetch session, delivered via @Environment(\.webSession) — never
/// a process global (test isolation). Credential policy is a transport-level
/// security invariant: same-origin only, both platforms.
@MainActor
public final class WebSession {
    nonisolated deinit { }
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
    /// Uploads a blob through a capable transport, applying its MIME type as the default content type.
    public func upload(for request: WebRequest, from blob: WebBlob)
        async throws -> (_FoundationData, WebResponse) {
        try Self.validate(request)
        guard request.body == nil else { throw WebUploadError.conflictingBody }
        guard request.method != .get, request.method != .head else {
            throw WebUploadError.invalidMethod
        }
        var effective = request
        if !blob.mimeType.isEmpty,
           !effective.headers.keys.contains(where: { $0.lowercased() == "content-type" }) {
            effective.headers["Content-Type"] = blob.mimeType
        }
        try Self.validate(effective)
        guard !Task.isCancelled else { throw WebFetchError.cancelled }
        guard let uploader = transport as? any _BlobUploadingTransport else {
            throw WebFetchError.unsupported
        }
        return try await uploader.upload(effective, from: blob)
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
        // WHATWG strips tab/LF/CR from anywhere in the input before parsing;
        // they are never legal in a URL — reject outright.
        if url.unicodeScalars.contains(where: { $0 == "\u{09}" || $0 == "\u{0A}" || $0 == "\u{0D}" }) {
            throw WebFetchError.badURL(url)
        }
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

extension WebSession {
    /// Process-wide default, set by platform entry points (DOM boot, StaticSite).
    /// Bare Runtime construction never touches it — parallel native tests that
    /// build their own runtimes cannot race on this global.
    @MainActor public private(set) static var shared: WebSession = .unsupported
    /// Called by platform entry points; repeated calls overwrite silently.
    @MainActor public static func bootstrap(_ session: WebSession) {
        shared = session
    }
    /// Back to .unsupported. For tests and dev tooling.
    @MainActor public static func resetShared() {
        shared = .unsupported
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
