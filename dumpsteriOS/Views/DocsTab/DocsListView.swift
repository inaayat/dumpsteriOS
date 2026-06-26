import SwiftUI

struct DocsListView: View {
    @Bindable var appState: AppState
    @State private var docs: [(doc: MasterDoc, tags: [Tag])] = []
    @State private var showNewDoc = false
    @State private var pendingMerge: (source: MasterDoc, target: MasterDoc)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // How it works card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.resourceColor)
                        Text("How Master Docs Work")
                            .font(.inter(14, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        guideRow(icon: "tag.fill", color: Theme.accent, text: "Assign tags — bullets and items with those tags flow into the doc's inbox")
                        guideRow(icon: "tray.and.arrow.down.fill", color: Theme.brainstormColor, text: "Inbox collects unincorporated items — add them one by one or batch with Sort Trash")
                        guideRow(icon: "text.badge.plus", color: Theme.successColor, text: "Use #save in your dump to file a bullet directly into its doc")
                        guideRow(icon: "list.bullet.indent", color: Theme.resourceColor, text: "Organize with category headings — AI places items under the right one")
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.resourceColor.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.resourceColor.opacity(0.15), lineWidth: 1))

                // Docs list
                if docs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.accent.opacity(0.4))
                        Text("Tap + to create your first doc")
                            .font(.inter(13))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else {
                    VStack(spacing: 8) {
                        ForEach(docs, id: \.doc.id) { entry in
                            NavigationLink(value: entry.doc) {
                                docCard(entry.doc, tags: entry.tags)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Menu("Merge Into...") {
                                    ForEach(docs.filter { $0.doc.id != entry.doc.id }, id: \.doc.id) { target in
                                        Button(target.doc.title) {
                                            pendingMerge = (source: entry.doc, target: target.doc)
                                        }
                                    }
                                }
                                Button(role: .destructive) {
                                    try? Queries.deleteMasterDoc(id: entry.doc.id)
                                    reload()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
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

    // MARK: - Components

    private func guideRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 16)
                .padding(.top, 2)
            Text(text)
                .font(.inter(12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func docCard(_ doc: MasterDoc, tags: [Tag]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.resourceColor.opacity(0.6))
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title)
                    .font(.inter(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 5) {
                    ForEach(tags.prefix(3)) { tag in
                        Text("#\(tag.name)")
                            .font(.inter(11, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    if tags.count > 3 {
                        Text("+\(tags.count - 3)")
                            .font(.inter(10))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textMuted.opacity(0.3))
        }
        .padding(14)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 0.5))
    }

    // MARK: - Actions

    private func mergeDocs(source: MasterDoc, into target: MasterDoc) {
        let sourceTags = (try? Queries.getTagsForDoc(docId: source.id)) ?? []
        for tag in sourceTags {
            try? Queries.removeTagFromDoc(docId: source.id, tagId: tag.id)
            try? Queries.addTagToDoc(docId: target.id, tagId: tag.id)
        }

        if !source.content.isEmpty {
            let separator = target.content.isEmpty ? "" : "\n\n---\n\n"
            let combined = target.content + separator + source.content
            try? Queries.upsertMasterDoc(tagId: target.tagId, content: combined, title: target.title)
        }

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
