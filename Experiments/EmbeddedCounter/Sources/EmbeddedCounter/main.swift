// A reflection-free counter with explicit state and a C/Wasm ABI. It does not
// import SwiftWUI or borrow the light-web-app implementation: this establishes
// only the smallest compilation/export boundary before browser ABI, allocator,
// DOM, or state-hydration work is proposed.
// The ABI is deliberately single-threaded for this probe. A real worker or
// shared-memory profile must replace this with explicit synchronization.
nonisolated(unsafe) private var slot: Int32 = 0

@_cdecl("counterIncrement")
public func counterIncrement(_ delta: Int32) -> Int32 {
    slot &+= delta
    return slot
}

@_cdecl("counterReset")
public func counterReset() { slot = 0 }

@_cdecl("counterValue")
public func counterValue() -> Int32 { slot }

@main struct EmbeddedCounter {
    static func main() {}
}
