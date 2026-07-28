extension HTMLTag {
    func _pendingRule(pseudo: String?, media: String?, _ body: (inout StyleProxy) -> Void) -> Self {
        var proxy = StyleProxy()
        body(&proxy)
        assert(proxy.pseudoBlocks.isEmpty, "pseudo blocks inside an element rule modifier are not supported — chain .hover/.focus/.active instead")
        var copy = self
        copy._attributes.addPendingRule(PendingStyleRule(pseudo: pseudo, media: media,
                                                         declarations: proxy.declarations))
        return copy
    }
    public func hover(_ body: (inout StyleProxy) -> Void) -> Self  { _pendingRule(pseudo: ":hover", media: nil, body) }
    public func focus(_ body: (inout StyleProxy) -> Void) -> Self  { _pendingRule(pseudo: ":focus", media: nil, body) }
    public func focusVisible(_ body: (inout StyleProxy) -> Void) -> Self { _pendingRule(pseudo: ":focus-visible", media: nil, body) }
    public func active(_ body: (inout StyleProxy) -> Void) -> Self { _pendingRule(pseudo: ":active", media: nil, body) }
    public func media(_ query: MediaQuery, _ body: (inout StyleProxy) -> Void) -> Self {
        _pendingRule(pseudo: nil, media: query.condition, body)
    }
}
