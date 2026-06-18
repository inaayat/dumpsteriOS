import SwiftUI

struct TagsView: View {
    @Bindable var appState: AppState
    @State private var topLevelTags: [Tag] = []
    @State private var subTagsMap: [String: [Tag]] = [:]
    @State private var itemCounts: [String: Int] = [:]

    var body: some View {
        List {
            if topLevelTags.isEmpty {
                ContentUnavailableView {
                    Label("No Tags", systemImage: "number")
                } description: {
                    Text("Tags are created automatically when you use #hashtags in your daily dump.")
                }
            } else {
                ForEach(topLevelTags) { tag in
                    Section {
                        NavigationLink(value: tag) {
                            tagRow(tag)
                        }

                        if let children = subTagsMap[tag.id], !children.isEmpty {
                            ForEach(children) { child in
                                NavigationLink(value: child) {
                                    HStack(spacing: 8) {
                                        Text("#\(child.name)")
                                            .font(.inter(13, weight: .medium))
                                            .foregroundStyle(Theme.accent)
                                        Spacer()
                                        Text("\(itemCounts[child.id] ?? 0)")
                                            .font(.inter(11))
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                }
                                .padding(.leading, 20)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let tag = topLevelTags[index]
                        try? Queries.deleteTag(id: tag.id)
                    }
                    reload()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tags")
        .navigationDestination(for: Tag.self) { tag in
            TagDetailView(appState: appState, tag: tag)
        }
        .onAppear { reload() }
    }

    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "number")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text(tag.name)
                .font(.inter(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(itemCounts[tag.id] ?? 0) items")
                .font(.inter(12))
                .foregroundStyle(Theme.textMuted)
        }
    }

    private func reload() {
        let all = (try? Queries.getTopLevelTags()) ?? []
        var subs: [String: [Tag]] = [:]
        var counts: [String: Int] = [:]
        for tag in all {
            subs[tag.id] = (try? Queries.getSubTags(parentTagId: tag.id)) ?? []
            counts[tag.id] = (try? Queries.getItemCountForTag(tagId: tag.id)) ?? 0
            for child in subs[tag.id] ?? [] {
                counts[child.id] = (try? Queries.getItemCountForTag(tagId: child.id)) ?? 0
            }
        }
        topLevelTags = all.sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
        subTagsMap = subs
        itemCounts = counts
    }
}
