// EventContexts.swift - Thread-local contexts for passing typed event data from JS to Swift closures.
// Lives in SwiftWUICore so both SwiftWUIHTML and SwiftWUIRuntime can access these types.
// Safe because WASM is single-threaded.

/// Context for passing the current input value during an "input" event.
public enum InputEventContext {
    nonisolated(unsafe) public static var currentValue: String?
}

/// Context for passing the current scroll offset during a "scroll" event.
public enum ScrollEventContext {
    nonisolated(unsafe) public static var currentOffset: ScrollOffset?
}

/// Context for passing keyboard event info during "keydown"/"keyup" events.
public enum KeyEventContext {
    nonisolated(unsafe) public static var currentKey: KeyInfo?
}

/// Context for passing pasted text during a "paste" event.
public enum PasteEventContext {
    nonisolated(unsafe) public static var currentText: String?
}

/// Context for passing element size during ResizeObserver callbacks.
public enum ResizeEventContext {
    nonisolated(unsafe) public static var currentSize: ElementSize?
}

/// Context for passing element rect during frame change callbacks.
public enum FrameChangeContext {
    nonisolated(unsafe) public static var currentRect: ElementRect?
}

/// Context for passing intersection ratio during IntersectionObserver callbacks.
public enum IntersectionContext {
    nonisolated(unsafe) public static var currentRatio: Double?
}
