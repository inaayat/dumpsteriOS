import SwiftUI

struct MasterDocEditorView: View {
    let doc: MasterDoc

    @State private var content: String = ""
    @State private var title: String = ""

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $content)
                .font(.inter(14))
                .scrollContentBackground(.hidden)
                .padding(16)
                .onChange(of: content) { _, newValue in
                    try? Queries.upsertMasterDoc(tagId: doc.tagId, content: newValue, title: title)
                }
        }
        .background(Theme.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            content = doc.content
            title = doc.title
        }
    }
}
