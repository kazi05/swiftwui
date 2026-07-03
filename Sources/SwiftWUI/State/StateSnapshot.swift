/// Snapshot plumbing (spec §7, D7). The core never touches JSON itself —
/// SwiftWUIStatic injects the encoder (JSONEncoder), SwiftWUIDOM the decoder
/// (JSONDecoder/FoundationEssentials). Slot convention: one JSON fragment per
/// @State slot, always a single-element array "[<value>]".
public typealias SnapshotDecode = (String, any Decodable.Type) -> (any Decodable)?
public typealias SnapshotEncode = (any Encodable) -> String?
