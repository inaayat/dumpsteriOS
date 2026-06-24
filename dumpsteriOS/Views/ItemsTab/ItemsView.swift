import SwiftUI

struct ItemsView: View {
    @Bindable var appState: AppState
    @State private var items: [Item] = []
    @State private var itemTags: [String: [Tag]] = [:]
    @State private var selectedCategory: Category? = .action
    @State private var showCompleted = false
    @State private var groupByTags = false
    @State private var groupedItems: [(tag: Tag?, items: [Item])] = []
    @State private var searchQuery = ""
    @State private var counts: [String: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", count: counts["all"], selected: selectedCategory == nil) {
                        selectedCategory = nil; reload()
                    }
                    filterChip("Actions", count: counts["action"], selected: selectedCategory == .action, color: Theme.actionColor) {
                        selectedCategory = .action; reload()
                    }
                    filterChip("Brainstorm", count: counts["brainstorm"], selected: selectedCategory == .brainstorm, color: Theme.brainstormColor) {
                        selectedCategory = .brainstorm; reload()
                    }
                    filterChip("Resource", count: counts["resource"], selected: selectedCategory == .resource, color: Theme.resourceColor) {
                        selectedCategory = .resource; reload()
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            // Items list
            if groupByTags {
                groupedListView
            } else {
                flatListView
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Items")
        .searchable(text: $searchQuery, prompt: "Search items")
        .onChange(of: searchQuery) { _, _ in reload() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        groupByTags.toggle()
                        reload()
                    } label: {
                        Image(systemName: groupByTags ? "rectangle.3.group.fill" : "rectangle.3.group")
                    }
                    Button {
                        showCompleted.toggle()
                        reload()
                    } label: {
                        Image(systemName: showCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                }
            }
        }
        .onAppear { reload() }
    }

    private var flatListView: some View {
        List {
            ForEach(sortedItems) { item in
                itemRow(item)
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: String.self) { itemId in
            ItemDetailView(appState: appState, itemId: itemId)
        }
    }

    private var groupedListView: some View {
        List {
            ForEach(Array(groupedItems.enumerated()), id: \.offset) { index, _ in
                groupSection(at: index)
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: String.self) { itemId in
            ItemDetailView(appState: appState, itemId: itemId)
        }
    }

    @ViewBuilder
    private func groupSection(at index: Int) -> some View {
        let group = groupedItems[index]
        let tagName = group.tag?.name ?? "Untagged"
        let count = group.items.count
        Section {
            ForEach(sortItems(group.items)) { item in
                itemRow(item)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: group.tag != nil ? "number" : "tag.slash")
                    .font(.system(size: 10, weight: group.tag != nil ? .bold : .regular))
                    .foregroundStyle(group.tag != nil ? Theme.accent : Theme.textMuted)
                Text(tagName)
                    .font(.inter(13, weight: .semibold))
                    .foregroundStyle(group.tag != nil ? Theme.textPrimary : Theme.textMuted)
                Text("\(count)")
                    .font(.inter(11))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ item: Item) -> some View {
        NavigationLink(value: item.id) {
            ItemCard(item: item, tags: itemTags[item.id] ?? [])
        }
        .swipeActions(edge: .leading) {
            if (item.category == .action || item.category == .brainstorm) && !item.done {
                Button {
                    try? Queries.completeItem(id: item.id)
                    appState.refreshCounts()
                    reload()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .tint(Theme.successColor)
            } else if item.done {
                Button {
                    try? Queries.uncompleteItem(id: item.id)
                    appState.refreshCounts()
                    reload()
                } label: {
                    Label("Reopen", systemImage: "arrow.uturn.left")
                }
                .tint(Theme.accent)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                try? Queries.deleteItem(id: item.id)
                appState.refreshCounts()
                reload()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var sortedItems: [Item] {
        sortItems(items)
    }

    private func sortItems(_ items: [Item]) -> [Item] {
        items.sorted { a, b in
            if a.priority.sortOrder != b.priority.sortOrder {
                return a.priority.sortOrder < b.priority.sortOrder
            }
            if let aDate = a.dueDate, let bDate = b.dueDate {
                return aDate < bDate
            }
            if a.dueDate != nil { return true }
            if b.dueDate != nil { return false }
            return a.createdAt > b.createdAt
        }
    }

    private func filterChip(_ label: String, count: Int?, selected: Bool, color: Color = Theme.accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label).font(.inter(12, weight: .semibold))
                if let count {
                    Text("\(count)").font(.inter(10)).opacity(0.7)
                }
            }
            .foregroundStyle(selected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? color : color.opacity(0.12), in: Capsule())
        }
    }

    private func reload() {
        if groupByTags {
            let search = searchQuery.isEmpty ? nil : searchQuery
            groupedItems = (try? Queries.getItemsGroupedByTag(
                category: selectedCategory,
                done: showCompleted,
                searchQuery: search
            )) ?? []
            let allGroupedItems = groupedItems.flatMap { $0.items }
            var tagMap: [String: [Tag]] = [:]
            for item in allGroupedItems {
                tagMap[item.id] = (try? Queries.getTagsForItem(itemId: item.id)) ?? []
            }
            itemTags = tagMap
            items = []
        } else {
            if !searchQuery.isEmpty {
                items = (try? Queries.searchItems(query: searchQuery)) ?? []
            } else if showCompleted {
                items = (try? Queries.getItems(category: selectedCategory, done: true)) ?? []
            } else {
                items = (try? Queries.getItems(category: selectedCategory, done: false)) ?? []
            }

            var tagMap: [String: [Tag]] = [:]
            for item in items {
                tagMap[item.id] = (try? Queries.getTagsForItem(itemId: item.id)) ?? []
            }
            itemTags = tagMap
            groupedItems = []
        }
        counts = (try? Queries.getCategoryCounts()) ?? [:]
    }
}
