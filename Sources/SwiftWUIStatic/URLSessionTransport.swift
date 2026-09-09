import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // corelibs (Linux); on Darwin URLSession is in Foundation
#endif
import SwiftWUI

/// Build-time transport for `.task(policy: .build)` fetches. SECURITY (spec 8a):
/// runs with the builder's network position — URLs must be trusted/static.
/// Ephemeral session, no cookie storage: the same-origin credential invariant.
final class URLSessionTransport: @MainActor _BlobUploadingTransport {
    nonisolated deinit { }
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        session = URLSession(configuration: config)
    }
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        let req = try makeRequest(request, body: request.body)
        do {
            let result = try await session.data(for: req)
            return try response(from: result)
        } catch {
            throw mapError(error)
        }
    }

    func upload(_ request: WebRequest, from blob: WebBlob)
        async throws -> (_FoundationData, WebResponse) {
        guard let data = blob.uploadData else { throw WebFetchError.unsupported }
        let req = try makeRequest(request, body: nil)
        do {
            let result = try await session.upload(for: req, from: data)
            return try response(from: result)
        } catch {
            throw mapError(error)
        }
    }

    private func makeRequest(_ request: WebRequest, body: _FoundationData?) throws -> URLRequest {
        guard let url = URL(string: request.url),
              url.scheme == "http" || url.scheme == "https" else {
            // Relative URLs need a document origin — build-time has none.
            throw WebFetchError.badURL(request.url)
        }
        var req = URLRequest(url: url)
        req.httpMethod = request.method.rawValue
        req.httpBody = body
        for (k, v) in request.headers { req.setValue(v, forHTTPHeaderField: k) }
        if let timeout = request.timeout {
            // URLSession uses an inactivity timeout; DOM uses a total-operation abort timer.
            req.timeoutInterval = Double(timeout.components.seconds)
                + Double(timeout.components.attoseconds) / 1e18
        }
        return req
    }

    private func response(
        from result: (_FoundationData, URLResponse)
    ) throws -> (_FoundationData, WebResponse) {
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else {
            throw WebFetchError.network("non-HTTP response")
        }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            // HTTPURLResponse preserves server casing — lowercase to match the
            // fetch() transport (WebResponse.headers keys are lowercase-normalized).
            if let key = key as? String, let value = value as? String {
                headers[key.lowercased()] = value
            }
        }
        return (data, WebResponse(status: http.statusCode, headers: headers))
    }

    private func mapError(_ error: any Error) -> WebFetchError {
        if let error = error as? WebFetchError { return error }
        if error is CancellationError { return .cancelled }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return .cancelled
            case .timedOut: return .timeout
            default: break
            }
        }
        return .network(String(describing: error))
    }
}
