import SwiftUI
import UIKit

struct DocsListView: View {
    @Bindable var appState: AppState
    @State private var docs: [(doc: MasterDoc, tags: [Tag])] = []
    @State private var showNewDoc = false

    var body: some View {
        List {
            if docs.isEmpty {
                ContentUnavailableView {
                    Label("No Documents", systemImage: "doc.text")
                } description: {
                    Text("Tap + to create a doc, or use #save in your daily dump.")
                }
            } else {
                ForEach(docs, id: \.doc.id) { entry in
                    NavigationLink(value: entry.doc) {
                        docRow(entry.doc, tags: entry.tags)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewDoc = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewDoc) {
            NewDocView { _ in reload() }
        }
        .onAppear { reload() }
    }

    private func docRow(_ doc: MasterDoc, tags: [Tag]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(doc.title)
                .font(.inter(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 6) {
                ForEach(tags.prefix(3)) { tag in
                    Text("#\(tag.name)")
                        .font(.inter(11))
                        .foregroundStyle(Theme.accent)
                }
                if tags.count > 3 {
                    Text("+\(tags.count - 3)")
                        .font(.inter(10))
                        .foregroundStyle(Theme.textMuted)
                }
                Text(doc.updatedAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.inter(11))
                    .foregroundStyle(Theme.textMuted)
            }
            let preview = plainTextPreview(doc.content)
            if !preview.isEmpty {
                Text(preview)
                    .font(.inter(12))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func plainTextPreview(_ content: String, maxLength: Int = 100) -> String {
        var plain = content
        if content.hasPrefix("{\\rtf"),
           let data = content.data(using: .utf8),
           let attrStr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            plain = attrStr.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let trimmed = String(plain.prefix(maxLength))
        return plain.count > maxLength ? trimmed + "..." : trimmed
    }

    private func reload() {
        let allDocs = (try? Queries.getAllMasterDocs()) ?? []
        docs = allDocs.map { doc in
            let tags = (try? Queries.getTagsForDoc(docId: doc.id)) ?? []
            return (doc: doc, tags: tags)
        }
    }
}

extension MasterDoc: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
