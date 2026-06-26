import SwiftUI

struct TagsView: View {
    @Bindable var appState: AppState
    @State private var topLevelTags: [Tag] = []
    @State private var subTagsMap: [String: [Tag]] = [:]
    @State private var itemCounts: [String: Int] = [:]
    @State private var bulletCounts: [String: Int] = [:]
    @State private var dropTargetId: String? = nil
    @State private var pendingMerge: (from: Tag, into: Tag)? = nil
    @State private var renamingTag: Tag? = nil
    @State private var renameText = ""

    var body: some View {
        Group {
            if topLevelTags.isEmpty {
                ContentUnavailableView {
                    Label("No Tags", systemImage: "number")
                } description: {
                    Text("Tags are created automatically when you use #hashtags in your daily dump.")
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(topLevelTags) { tag in
                            tagCard(tag)

                            if let children = subTagsMap[tag.id], !children.isEmpty {
                                VStack(spacing: 6) {
                                    ForEach(children) { child in
                                        childCard(child)
                                    }
                                }
                                .padding(.leading, 20)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Theme.canvas)
            }
        }
        .navigationTitle("Tags")
        .navigationDestination(for: Tag.self) { tag in
            TagDetailView(appState: appState, tag: tag)
        }
        .onAppear { reload() }
        .alert("Rename tag", isPresented: .init(
            get: { renamingTag != nil },
            set: { if !$0 { renamingTag = nil } }
        )) {
            TextField("New name", text: $renameText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Rename") {
                if let tag = renamingTag {
                    try? Queries.renameTag(id: tag.id, from: tag.name, to: renameText)
                    reload()
                }
                renamingTag = nil
            }
            Button("Cancel", role: .cancel) { renamingTag = nil }
        } message: {
            if let tag = renamingTag {
                Text("Renaming #\(tag.name) will update all items and dump bullets.")
            }
        }
        .confirmationDialog(mergeDialogTitle, isPresented: .init(
            get: { pendingMerge != nil },
            set: { if !$0 { pendingMerge = nil } }
        ), titleVisibility: .visible) {
            Button("Merge", role: .destructive) {
                if let m = pendingMerge {
                    try? Queries.mergeTags(fromId: m.from.id, intoId: m.into.id)
                    appState.refreshCounts()
                    reload()
                }
                pendingMerge = nil
            }
            Button("Cancel", role: .cancel) { pendingMerge = nil }
        }
    }

    // MARK: - Cards

    private func tagCard(_ tag: Tag) -> some View {
        NavigationLink(value: tag) {
            HStack(spacing: 10) {
                Image(systemName: "number")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text(tag.name)
                    .font(.inter(15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                let items = itemCounts[tag.id] ?? 0
                let bullets = bulletCounts[tag.id] ?? 0
                Text("\(items) items · \(bullets) bullets")
                    .font(.inter(11))
                    .foregroundStyle(Theme.textMuted)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                dropTargetId == tag.id
                    ? Theme.accent.opacity(0.1)
                    : Theme.cardBg,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(
                        dropTargetId == tag.id ? Theme.accent.opacity(0.5) : Theme.border,
                        lineWidth: dropTargetId == tag.id ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .draggable(tag)
        .dropDestination(for: Tag.self) { dropped, _ in
            guard let source = dropped.first, source.id != tag.id else { return false }
            pendingMerge = (from: source, into: tag)
            dropTargetId = nil
            return true
        } isTargeted: { isOver in
            withAnimation(.easeInOut(duration: 0.15)) {
                dropTargetId = isOver ? tag.id : nil
            }
        }
        .contextMenu {
            Button {
                renameText = tag.name
                renamingTag = tag
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                try? Queries.deleteTag(id: tag.id)
                reload()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func childCard(_ child: Tag) -> some View {
        NavigationLink(value: child) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
                Text("#\(child.name)")
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text("\(itemCounts[child.id] ?? 0)")
                    .font(.inter(11))
                    .foregroundStyle(Theme.textMuted)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                dropTargetId == child.id
                    ? Theme.accent.opacity(0.1)
                    : Theme.cardBg,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(
                        dropTargetId == child.id ? Theme.accent.opacity(0.5) : Theme.border,
                        lineWidth: dropTargetId == child.id ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .draggable(child)
        .dropDestination(for: Tag.self) { dropped, _ in
            guard let source = dropped.first, source.id != child.id else { return false }
            pendingMerge = (from: source, into: child)
            dropTargetId = nil
            return true
        } isTargeted: { isOver in
            withAnimation(.easeInOut(duration: 0.15)) {
                dropTargetId = isOver ? child.id : nil
            }
        }
        .contextMenu {
            Button {
                renameText = child.name
                renamingTag = child
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                try? Queries.deleteTag(id: child.id)
                reload()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private var mergeDialogTitle: String {
        guard let m = pendingMerge else { return "" }
        return "Merge #\(m.from.name) into #\(m.into.name)? All items will move to #\(m.into.name) and #\(m.from.name) will be deleted."
    }

    private func reload() {
        let all = (try? Queries.getTopLevelTags()) ?? []
        var subs: [String: [Tag]] = [:]
        var counts: [String: Int] = [:]
        var bCounts: [String: Int] = [:]
        for tag in all {
            subs[tag.id] = (try? Queries.getSubTags(parentTagId: tag.id)) ?? []
            counts[tag.id] = (try? Queries.getItemCountForTag(tagId: tag.id)) ?? 0
            bCounts[tag.id] = (try? Queries.getBulletCountForTag(tagName: tag.name)) ?? 0
            for child in subs[tag.id] ?? [] {
                counts[child.id] = (try? Queries.getItemCountForTag(tagId: child.id)) ?? 0
                bCounts[child.id] = (try? Queries.getBulletCountForTag(tagName: child.name)) ?? 0
            }
        }
        topLevelTags = all.sorted { ((counts[$0.id] ?? 0) + (bCounts[$0.id] ?? 0)) > ((counts[$1.id] ?? 0) + (bCounts[$1.id] ?? 0)) }
        subTagsMap = subs
        itemCounts = counts
        bulletCounts = bCounts
    }
}
