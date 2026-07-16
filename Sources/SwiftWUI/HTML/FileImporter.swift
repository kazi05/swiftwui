/// Click-to-pick file dialog (DnD spec §3.3) — SwiftUI's fileImporter shape.
/// First production TagModifier: the component boundary gives it @State.
/// Docs caveat: flip `isPresented` from a user-gesture handler — file dialogs
/// need transient activation (the microtask flush preserves it).
struct _FileImporterModifier: TagModifier {
    let isPresented: Binding<Bool>
    let allowedContentTypes: [FileType]
    let allowsMultipleSelection: Bool
    let onCompletion: ([WebFile]) -> Void
    @State private var clickNonce = 0

    func body(content: Content) -> some Tag {
        content
        hiddenInput
            .onChange(of: isPresented.wrappedValue) { _, presented in
                if presented { clickNonce += 1 }
            }
    }

    private var hiddenInput: some Tag {
        var input = Input(type: .file,
                          accept: FileType.acceptString(allowedContentTypes),
                          multiple: allowsMultipleSelection)
        input._attributes.setProperty("swui:cmd:click", .string(String(clickNonce)))
        // Modern browsers fire "cancel" on dismissed pickers; older ones
        // leave the binding true until the next selection (documented).
        input._attributes.addHandler("cancel") { [isPresented] in
            isPresented.wrappedValue = false
        }
        return input
            .onFileSelection { files in
                onCompletion(files)
                isPresented.wrappedValue = false
            }
            .display(.none)
    }
}

extension Tag {
    public func fileImporter(
        isPresented: Binding<Bool>,
        allowedContentTypes: [FileType] = [],
        allowsMultipleSelection: Bool = false,
        onCompletion: @escaping ([WebFile]) -> Void
    ) -> some Tag {
        modifier(_FileImporterModifier(isPresented: isPresented,
                                       allowedContentTypes: allowedContentTypes,
                                       allowsMultipleSelection: allowsMultipleSelection,
                                       onCompletion: onCompletion))
    }
}
