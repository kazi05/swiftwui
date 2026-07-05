import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// SSE over the hijack seam: plain HTTP stream, no upgrade handshake, and the
/// browser EventSource auto-reconnects after CLI restarts (spec D8).
public final class SSEHub: @unchecked Sendable {   // guarded by `lock`
    private let lock = NSLock()
    private var clients: [Int32] = []
    public init() {}

    public var clientCount: Int { lock.lock(); defer { lock.unlock() }; return clients.count }

    /// `lastError`: current build error, replayed to clients that connect mid-breakage.
    public func handler(lastError: @escaping @Sendable () -> String? = { nil }) -> HTTPHandler {
        { [self] request in
            guard request.path == "/__swiftwui/events" else { return nil }
            return HTTPResponse(
                status: 200,
                headers: ["Content-Type": "text/event-stream",
                          "Cache-Control": "no-cache",
                          "Connection": "keep-alive"],
                hijack: { fd in
                    if let err = lastError() {
                        writeAll(fd, Array("event: build-error\ndata: \(err)\n\n".utf8))
                    }
                    self.lock.lock(); self.clients.append(fd); self.lock.unlock()
                })
        }
    }

    /// data MUST be a single line (JSON-encode multiline payloads first).
    public func broadcast(event: String, data: String) {
        lock.lock(); let fds = clients; lock.unlock()
        let frame = Array("event: \(event)\ndata: \(data)\n\n".utf8)
        var dead: [Int32] = []
        for fd in fds {
            // writeAll swallows EPIPE; detect a closed peer via a non-blocking peek.
            writeAll(fd, frame)
            var one = [UInt8](repeating: 0, count: 1)
            let n = recv(fd, &one, 1, Int32(MSG_PEEK | MSG_DONTWAIT))
            if n == 0 { dead.append(fd) }              // orderly close by the browser
        }
        if !dead.isEmpty {
            lock.lock()
            clients.removeAll { dead.contains($0) }
            lock.unlock()
            for fd in dead { close(fd) }
        }
    }
}
