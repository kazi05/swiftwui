import Foundation
import Testing
@testable import SwiftWUIToolchain

@Suite struct SHA256Tests {
    // Official FIPS 180-4 test vectors.
    @Test func emptyInput() {
        #expect(SHA256.hex(SHA256.digest([])) ==
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
    @Test func abc() {
        #expect(SHA256.hex(SHA256.digest(Array("abc".utf8))) ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    @Test func twoBlockMessage() {
        let msg = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        #expect(SHA256.hex(SHA256.digest(Array(msg.utf8))) ==
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }
    @Test func millionA() {
        let msg = [UInt8](repeating: UInt8(ascii: "a"), count: 1_000_000)
        #expect(SHA256.hex(SHA256.digest(msg)) ==
            "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }
    @Test func base64MatchesIntegrityFormat() {
        // "abc" digest, base64 — the form fetch()'s integrity option needs.
        #expect(SHA256.base64(SHA256.digest(Array("abc".utf8))) ==
            "ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=")
    }
}
