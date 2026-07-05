import Testing
import Foundation
@testable import SwiftWUIToolchain
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

@Suite struct ToolchainSSETests {
    @Test func injectionAfterHeadAndHeadlessPrepend() {
        let doc = "<!doctype html>\n<html>\n<HEAD><title>x</title></HEAD><body></body></html>"
        let out = DevInjection.inject(into: doc)
        #expect(out.contains("<HEAD><script>window.__swiftwui_dev = true;"))
        let headless = "<p>hi</p>"
        #expect(DevInjection.inject(into: headless).hasPrefix("<script>window.__swiftwui_dev"))
    }

    @Test func jsonStringLiteralEscapes() {
        #expect(DevInjection.jsonStringLiteral("a\"b\nc") == #""a\"b\nc""#)
    }

    @Test func sseStreamDeliversBroadcast() async throws {
        let hub = SSEHub()
        let server = HTTPServer(handlers: [hub.handler()])
        try server.start(port: 0); defer { server.stop() }
        // Raw-socket client: URLSession buffers SSE; a plain socket shows frames as written.
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = server.boundPort.bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        _ = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        writeAll(fd, Array("GET /__swiftwui/events HTTP/1.1\r\nHost: x\r\n\r\n".utf8))
        // Wait for the hub to register the client, then broadcast.
        for _ in 0..<100 where hub.clientCount == 0 { try await Task.sleep(nanoseconds: 10_000_000) }
        #expect(hub.clientCount == 1)
        hub.broadcast(event: "reload", data: "{}")
        var buf = [UInt8](repeating: 0, count: 4096)
        var received = ""
        for _ in 0..<100 {
            let n = recv(fd, &buf, buf.count, Int32(MSG_DONTWAIT))
            if n > 0 { received += String(decoding: buf[0..<n], as: UTF8.self) }
            if received.contains("event: reload\ndata: {}\n\n") { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        close(fd)
        #expect(received.contains("event: reload\ndata: {}\n\n"))
    }
}
