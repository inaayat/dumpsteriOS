import SwiftUI

struct DocsListView: View {
    @Bindable var appState: AppState
    @State private var docs: [(doc: MasterDoc, tag: Tag?)] = []

    var body: some View {
        List {
            if docs.isEmpty {
                ContentUnavailableView {
                    Label("No Documents", systemImage: "doc.text")
                } description: {
                    Text("Create a doc from any tag, or use #save in your daily dump to append to a tag's document.")
                }
            } else {
                ForEach(docs, id: \.doc.id) { entry in
                    NavigationLink(value: entry.doc) {
                        docRow(entry.doc, tag: entry.tag)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        try? Queries.deleteMasterDoc(id: docs[index].doc.id)
                    }
                    reload()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Docs")
        .navigationDestination(for: MasterDoc.self) { doc in
            MasterDocEditorView(doc: doc)
        }
        .onAppear { reload() }
    }

    private func docRow(_ doc: MasterDoc, tag: Tag?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(doc.title)
                .font(.inter(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 8) {
                if let tag {
                    Text("#\(tag.name)")
                        .font(.inter(11))
                        .foregroundStyle(Theme.accent)
                }
                Text(doc.updatedAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.inter(11))
                    .foregroundStyle(Theme.textMuted)
            }
            if !doc.content.isEmpty {
                Text(doc.content.prefix(80) + (doc.content.count > 80 ? "..." : ""))
                    .font(.inter(12))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func reload() {
        let allDocs = (try? Queries.getAllMasterDocs()) ?? []
        docs = allDocs.map { doc in
            let tag = try? Queries.getTag(id: doc.tagId)
            return (doc: doc, tag: tag)
        }
    }
}

extension MasterDoc: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
