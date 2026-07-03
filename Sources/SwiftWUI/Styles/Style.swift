/// Reusable named bundle (spec §10): declarations land on the inline path,
/// pseudo blocks become registry rules — on whichever surface it's applied.
public protocol Style {
    func build(_ s: inout StyleProxy)
}

extension HTMLTag {
    public func style(_ style: some Style) -> Self {
        var proxy = StyleProxy(); style.build(&proxy)
        var copy = self
        for d in proxy.declarations { copy._attributes.addStyle(d) }
        for block in proxy.pseudoBlocks {
            copy._attributes.addPendingRule(PendingStyleRule(pseudo: block.pseudo, media: nil,
                                                             declarations: block.declarations))
        }
        for block in proxy.mediaBlocks {
            copy._attributes.addPendingRule(PendingStyleRule(pseudo: nil, media: block.media,
                                                             declarations: block.declarations))
        }
        return copy
    }
}

extension Tag {
    public func style(_ style: some Style) -> _StyledTag<Self> {
        var proxy = StyleProxy(); style.build(&proxy)
        return _StyledTag(content: self, declarations: proxy.declarations,
                          rules: proxy.pseudoBlocks.map {
                              PendingStyleRule(pseudo: $0.pseudo, media: nil, declarations: $0.declarations)
                          } + proxy.mediaBlocks.map {
                              PendingStyleRule(pseudo: nil, media: $0.media, declarations: $0.declarations)
                          })
    }
}

extension _StyledTag {
    public func style(_ style: some Style) -> Self {
        var proxy = StyleProxy(); style.build(&proxy)
        var copy = self
        copy.declarations.append(contentsOf: proxy.declarations)
        copy.rules.append(contentsOf: proxy.pseudoBlocks.map {
            PendingStyleRule(pseudo: $0.pseudo, media: nil, declarations: $0.declarations)
        })
        copy.rules.append(contentsOf: proxy.mediaBlocks.map {
            PendingStyleRule(pseudo: nil, media: $0.media, declarations: $0.declarations)
        })
        return copy
    }
}
