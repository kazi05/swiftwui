import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // corelibs (Linux); on Darwin URLSession is in Foundation
#endif
import SwiftWUI

/// Build-time transport for `.task(policy: .build)` fetches. SECURITY (spec 8a):
/// runs with the builder's network position — URLs must be trusted/static.
/// Ephemeral session, no cookie storage: the same-origin credential invariant.
final class URLSessionTransport: FetchTransport {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        session = URLSession(configuration: config)
    }
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        guard let url = URL(string: request.url),
              url.scheme == "http" || url.scheme == "https" else {
            // Relative URLs need a document origin — build-time has none.
            throw WebFetchError.badURL(request.url)
        }
        var req = URLRequest(url: url)
        req.httpMethod = request.method.rawValue
        req.httpBody = request.body
        for (k, v) in request.headers { req.setValue(v, forHTTPHeaderField: k) }
        if let t = request.timeout { req.timeoutInterval = Double(t.components.seconds) }
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw WebFetchError.network("non-HTTP response")
            }
            var headers: [String: String] = [:]
            for (k, v) in http.allHeaderFields {
                // HTTPURLResponse preserves server casing — lowercase to match the
                // fetch() transport (WebResponse.headers keys are lowercase-normalized).
                if let ks = k as? String, let vs = v as? String { headers[ks.lowercased()] = vs }
            }
            return (data, WebResponse(status: http.statusCode, headers: headers))
        } catch let e as WebFetchError { throw e }
        catch is CancellationError { throw WebFetchError.cancelled }
        catch { throw WebFetchError.network(String(describing: error)) }
    }
}
