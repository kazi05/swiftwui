import Foundation
import Testing
@testable import SwiftWUI

@MainActor
final class BlobStorageSpy: _WebBlobStorage {
    nonisolated deinit { }
    let size = 2
    let mimeType = "application/test"
    private(set) var sliceCalls = 0
    private(set) var dataCalls = 0

    func slice(_ range: Range<Int>) throws -> any _WebBlobStorage {
        sliceCalls += 1
        return self
    }

    func data() async throws -> _FoundationData {
        dataCalls += 1
        return _FoundationData([7, 8])
    }
}

@MainActor
private final class UnsupportedBlobStorage: _WebBlobStorage {
    nonisolated deinit { }
    let size = 1
    let mimeType = ""
    func slice(_ range: Range<Int>) throws -> any _WebBlobStorage { self }
}

@Suite @MainActor struct WebBlobTests {
    @Test func nestedSliceReadsOnlySelectedBytes() async throws {
        let blob = WebBlob(data: _FoundationData([10, 20, 30, 40]), mimeType: "TEXT/PLAIN")
        let slice = try blob.slice(1..<4).slice(1..<2)

        #expect(slice.size == 1)
        #expect(slice.mimeType == "text/plain")
        #expect(try await slice.data() == _FoundationData([30]))
        #expect(throws: WebBlobError.invalidRange) { try blob.slice(-1..<2) }
    }

    @Test func wholeAndEmptySlicesUseRelativeBounds() async throws {
        let blob = WebBlob(data: _FoundationData([1, 2, 3]))

        #expect(try await blob.slice(0..<3).data() == _FoundationData([1, 2, 3]))
        #expect(try await blob.slice(3..<3).data().isEmpty)
        #expect(throws: WebBlobError.invalidRange) { try blob.slice(0..<4) }
    }

    @Test func dataInitializerNormalizesMIMEAndOwnsItsValue() async throws {
        var source = _FoundationData([1, 2, 3])
        let blob = WebBlob(data: source, mimeType: "Image/PNG")
        source[1] = 9

        #expect(blob.mimeType == "image/png")
        #expect(try await blob.data() == _FoundationData([1, 2, 3]))
        #expect(WebBlob(data: _FoundationData(), mimeType: "text/\u{001F}plain").mimeType == "")
        #expect(WebBlob(data: _FoundationData(), mimeType: "TEXT/PLAINé").mimeType == "")
    }

    @Test func dataSubsequenceKeepsItsOwnIndexBoundary() async throws {
        let source = _FoundationData([0, 1, 2, 3, 4])
        let blob = WebBlob(data: source[2..<5])

        #expect(blob.size == 3)
        #expect(try await blob.data() == _FoundationData([2, 3, 4]))
        #expect(try await blob.slice(1..<3).data() == _FoundationData([3, 4]))
    }

    @Test func byteBackedBlobDoesNotInventAnObjectURL() {
        let blob = WebBlob(data: _FoundationData([1]))
        #expect(throws: WebFetchError.unsupported) { try blob.makeObjectURL() }
    }

    @Test func storageDefaultsRejectUnsupportedCapabilities() async {
        let blob = WebBlob(storage: UnsupportedBlobStorage())
        await #expect(throws: WebFetchError.unsupported) { _ = try await blob.data() }
        #expect(throws: WebFetchError.unsupported) { _ = try blob.makeObjectURL() }
    }

    @Test func invalidRangeFailsBeforeStorageWork() {
        let storage = BlobStorageSpy()
        let blob = WebBlob(storage: storage)

        #expect(throws: WebBlobError.invalidRange) { try blob.slice(-1..<1) }
        #expect(throws: WebBlobError.invalidRange) { try blob.slice(0..<3) }
        #expect(storage.sliceCalls == 0)
    }

    @Test func objectURLUsesIdentityAndRevokesExactlyOnce() {
        var firstRevocations = 0
        let first = WebObjectURL(url: "blob:first") { firstRevocations += 1 }
        let alias = first
        let second = WebObjectURL(url: "blob:first") {}

        #expect(first == alias)
        #expect(first != second)
        #expect(first.urlString == "blob:first")
        first.revoke()
        first.revoke()
        #expect(firstRevocations == 1)
        #expect(first.isRevoked)
        #expect(first.urlString == nil)
    }

    @Test func objectURLLastOwnerSchedulesExactlyOnceCleanup() async {
        var revocations = 0
        var url: WebObjectURL? = WebObjectURL(url: "blob:fallback") { revocations += 1 }
        weak let weakURL = url

        url = nil
        for _ in 0..<20 where revocations == 0 { await Task.yield() }

        #expect(weakURL == nil)
        #expect(revocations == 1)
    }
}
