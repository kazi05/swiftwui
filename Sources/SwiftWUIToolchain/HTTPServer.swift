import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

public struct HTTPRequest {
    public var method: String
    public var path: String                    // percent-decoded, no query
    public var headers: [String: String]       // lowercased keys
}

public struct HTTPResponse {
    public var status: Int
    public var headers: [String: String]
    public var body: [UInt8]
    /// When set, the server writes status+headers, hands the socket over, and
    /// never closes it. Used by SSE (Task 4).
    public var hijack: ((Int32) -> Void)?

    public init(status: Int = 200, headers: [String: String] = [:], body: [UInt8] = [], hijack: ((Int32) -> Void)? = nil) {
        self.status = status; self.headers = headers; self.body = body; self.hijack = hijack
    }
    public static func text(_ s: String, status: Int = 200, contentType: String = "text/plain; charset=utf-8") -> HTTPResponse {
        HTTPResponse(status: status, headers: ["Content-Type": contentType], body: Array(s.utf8))
    }
    public static func notFound() -> HTTPResponse { .text("404 not found", status: 404) }
    public static func file(bytes: [UInt8], mime: String) -> HTTPResponse {
        HTTPResponse(status: 200, headers: ["Content-Type": mime], body: bytes)
    }
}

public typealias HTTPHandler = @Sendable (HTTPRequest) -> HTTPResponse?

public enum MIME {
    static let types: [String: String] = [
        "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8",
        "mjs": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
        "wasm": "application/wasm",              // load-bearing: streaming instantiation
        "json": "application/json", "map": "application/json",
        "svg": "image/svg+xml", "png": "image/png", "jpg": "image/jpeg",
        "jpeg": "image/jpeg", "ico": "image/x-icon", "txt": "text/plain; charset=utf-8",
    ]
    public static func type(forPath p: String) -> String {
        let ext = (p as NSString).pathExtension.lowercased()
        return types[ext] ?? "application/octet-stream"
    }
}

/// EPIPE-safe full write. macOS: SO_NOSIGPIPE is set per-socket at accept;
/// Linux would need MSG_NOSIGNAL — dev tool targets macOS/Linux, guard both.
public func writeAll(_ fd: Int32, _ bytes: [UInt8]) {
    var off = 0
    bytes.withUnsafeBufferPointer { buf in
        while off < buf.count {
            #if canImport(Glibc)
            let n = send(fd, buf.baseAddress! + off, buf.count - off, Int32(MSG_NOSIGNAL))
            #else
            let n = write(fd, buf.baseAddress! + off, buf.count - off)
            #endif
            if n <= 0 { return }
            off += n
        }
    }
}

/// Hand-rolled HTTP/1.1 server for the dev loop: 127.0.0.1 only, GET/HEAD only,
/// Connection: close, per-connection thread. ponytail: fine for one developer;
/// swap for NIO if this ever serves anything but localhost.
public final class HTTPServer: @unchecked Sendable {   // guarded by `lock`
    private let handlers: [HTTPHandler]
    private var listenFD: Int32 = -1
    private var running = false
    private let lock = NSLock()
    public private(set) var boundPort: UInt16 = 0

    public init(handlers: [HTTPHandler]) { self.handlers = handlers }

    public func start(port: UInt16) throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ToolchainError.io("socket() failed: errno \(errno)") }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))   // localhost ONLY
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bindResult == 0 else {
            close(fd)
            if errno == EADDRINUSE { throw ToolchainError.portInUse(port) }
            throw ToolchainError.io("bind() failed: errno \(errno)")
        }
        guard listen(fd, 16) == 0 else { close(fd); throw ToolchainError.io("listen() failed: errno \(errno)") }
        var bound = sockaddr_in(); var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &bound) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = getsockname(fd, $0, &len) }
        }
        lock.lock(); listenFD = fd; running = true; boundPort = UInt16(bigEndian: bound.sin_port); lock.unlock()
        let t = Thread { [weak self] in self?.acceptLoop(fd) }
        t.name = "swiftwui-http-accept"
        t.start()
    }

    public func stop() {
        lock.lock(); running = false; let fd = listenFD; listenFD = -1; lock.unlock()
        if fd >= 0 { close(fd) }
    }

    private var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return running }

    private func acceptLoop(_ fd: Int32) {
        while isRunning {
            let client = accept(fd, nil, nil)
            guard client >= 0 else { continue }
            #if canImport(Darwin)
            var yes: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            #endif
            let t = Thread { [handlers] in Self.handle(client, handlers: handlers) }
            t.start()
        }
    }

    private static func handle(_ fd: Int32, handlers: [HTTPHandler]) {
        // Read until end of headers (16 KB cap — dev requests carry no bodies we care about).
        var raw: [UInt8] = []
        var buf = [UInt8](repeating: 0, count: 4096)
        while raw.count < 16_384 {
            let n = read(fd, &buf, buf.count)
            if n <= 0 { break }
            raw.append(contentsOf: buf[0..<n])
            if raw.count >= 4, findHeaderEnd(raw) != nil { break }
        }
        guard let headerEnd = findHeaderEnd(raw) else { close(fd); return }
        let head = String(decoding: raw[..<headerEnd], as: UTF8.self)
        var lines = head.split(separator: "\r\n", omittingEmptySubsequences: false)[...]
        guard let requestLine = lines.popFirst() else { close(fd); return }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { close(fd); return }
        let method = String(parts[0])
        var target = String(parts[1])
        if let q = target.firstIndex(of: "?") { target = String(target[..<q]) }
        let path = target.removingPercentEncoding ?? target
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard method == "GET" || method == "HEAD" else {
            send(HTTPResponse.text("405 method not allowed", status: 405), to: fd, headOnly: false); close(fd); return
        }
        let request = HTTPRequest(method: method, path: path, headers: headers)
        var response: HTTPResponse = .notFound()
        for h in handlers { if let r = h(request) { response = r; break } }
        if let hijack = response.hijack {
            sendHead(response, to: fd, contentLength: nil)
            hijack(fd)                 // hijacker owns the fd now (SSE)
            return
        }
        send(response, to: fd, headOnly: method == "HEAD")
        close(fd)
    }

    private static func findHeaderEnd(_ raw: [UInt8]) -> Int? {
        let sep: [UInt8] = [13, 10, 13, 10]
        guard raw.count >= 4 else { return nil }
        for i in 0...(raw.count - 4) where Array(raw[i..<i+4]) == sep { return i }
        return nil
    }

    private static func sendHead(_ r: HTTPResponse, to fd: Int32, contentLength: Int?) {
        var head = "HTTP/1.1 \(r.status) \(r.status == 200 ? "OK" : "X")\r\n"
        var headers = r.headers
        if let contentLength { headers["Content-Length"] = String(contentLength) }
        headers["Connection"] = headers["Connection"] ?? (contentLength == nil ? "keep-alive" : "close")
        for (k, v) in headers { head += "\(k): \(v)\r\n" }
        head += "\r\n"
        writeAll(fd, Array(head.utf8))
    }

    private static func send(_ r: HTTPResponse, to fd: Int32, headOnly: Bool) {
        sendHead(r, to: fd, contentLength: r.body.count)
        if !headOnly { writeAll(fd, r.body) }
    }
}

public enum StaticFiles {
    /// Serve files under `root` for URLs starting with `urlPrefix`.
    /// Directory / extensionless resolution: exact file → `<path>/index.html` →
    /// (spaFallback) `<root>/index.html` → nil (fall through).
    public static func handler(urlPrefix: String, root: String, spaFallback: Bool = false) -> HTTPHandler {
        let rootResolved = URL(fileURLWithPath: root).standardizedFileURL.path
        return { request in
            guard request.path.hasPrefix(urlPrefix) else { return nil }
            let rel = String(request.path.dropFirst(urlPrefix.count))
            func fileResponse(_ fsPath: String) -> HTTPResponse? {
                let resolved = URL(fileURLWithPath: fsPath).standardizedFileURL.path
                guard resolved == rootResolved || resolved.hasPrefix(rootResolved + "/") else { return nil }   // traversal guard (incl. sibling-prefix)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir) else { return nil }
                if isDir.boolValue { return fileResponse(resolved + "/index.html") }
                guard let data = FileManager.default.contents(atPath: resolved) else { return nil }
                return .file(bytes: Array(data), mime: MIME.type(forPath: resolved))
            }
            let candidate = rootResolved + "/" + rel
            if let r = fileResponse(candidate) { return r }
            if !rel.contains(".") , let r = fileResponse(candidate + "/index.html") { return r }
            if spaFallback, !rel.contains("."), let r = fileResponse(rootResolved + "/index.html") { return r }
            return nil
        }
    }
}
