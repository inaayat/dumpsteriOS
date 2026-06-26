import SwiftUI

struct DocsListView: View {
    @Bindable var appState: AppState
    @State private var docs: [(doc: MasterDoc, tags: [Tag])] = []
    @State private var showNewDoc = false
    @State private var pendingMerge: (source: MasterDoc, target: MasterDoc)? = nil

    var body: some View {
        ScrollView {
            if docs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.textMuted.opacity(0.4))
                    Text("No documents yet")
                        .font(.inter(15, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                    Text("Tap + to create one, or use #save in your dump.")
                        .font(.inter(12))
                        .foregroundStyle(Theme.textMuted.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(docs, id: \.doc.id) { entry in
                        NavigationLink(value: entry.doc) {
                            docCard(entry.doc, tags: entry.tags)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                try? Queries.deleteMasterDoc(id: entry.doc.id)
                                reload()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Menu("Merge Into...") {
                                ForEach(docs.filter { $0.doc.id != entry.doc.id }, id: \.doc.id) { target in
                                    Button(target.doc.title) {
                                        pendingMerge = (source: entry.doc, target: target.doc)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Docs")
        .navigationDestination(for: MasterDoc.self) { doc in
            MasterDocEditorView(doc: doc)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewDoc = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewDoc) {
            NewDocView { _ in reload() }
        }
        .confirmationDialog("Merge Documents?", isPresented: .init(
            get: { pendingMerge != nil },
            set: { if !$0 { pendingMerge = nil } }
        )) {
            if let merge = pendingMerge {
                Button("Merge \"\(merge.source.title)\" into \"\(merge.target.title)\"") {
                    mergeDocs(source: merge.source, into: merge.target)
                    pendingMerge = nil
                }
                Button("Cancel", role: .cancel) { pendingMerge = nil }
            }
        } message: {
            Text("This will move all tags and content from the source doc into the target doc, then delete the source.")
        }
        .onAppear { reload() }
    }

    private func docCard(_ doc: MasterDoc, tags: [Tag]) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(doc.title)
                    .font(.inter(16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    ForEach(tags.prefix(4)) { tag in
                        Text("#\(tag.name)")
                            .font(.inter(11, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    if tags.count > 4 {
                        Text("+\(tags.count - 4)")
                            .font(.inter(10))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textMuted.opacity(0.4))
        }
        .padding(14)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 0.5))
    }

    private func mergeDocs(source: MasterDoc, into target: MasterDoc) {
        // Move source tags to target
        let sourceTags = (try? Queries.getTagsForDoc(docId: source.id)) ?? []
        for tag in sourceTags {
            try? Queries.removeTagFromDoc(docId: source.id, tagId: tag.id)
            try? Queries.addTagToDoc(docId: target.id, tagId: tag.id)
        }

        // Append source content to target
        if !source.content.isEmpty {
            let separator = target.content.isEmpty ? "" : "\n\n---\n\n"
            let combined = target.content + separator + source.content
            try? Queries.upsertMasterDoc(tagId: target.tagId, content: combined, title: target.title)
        }

        // Delete source doc
        try? Queries.deleteMasterDoc(id: source.id)
        reload()
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
