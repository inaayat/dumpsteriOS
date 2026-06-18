import SwiftUI

struct ItemsView: View {
    @Bindable var appState: AppState
    @State private var items: [Item] = []
    @State private var itemTags: [String: [Tag]] = [:]
    @State private var selectedCategory: Category? = .action
    @State private var showCompleted = false
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
            List {
                ForEach(sortedItems) { item in
                    NavigationLink(value: item.id) {
                        ItemCard(item: item, tags: itemTags[item.id] ?? [])
                    }
                    .swipeActions(edge: .leading) {
                        if item.category == .action && !item.done {
                            Button {
                                try? Queries.completeItem(id: item.id)
                                appState.refreshCounts()
                                reload()
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(Theme.successColor)
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
            }
            .listStyle(.plain)
            .navigationDestination(for: String.self) { itemId in
                ItemDetailView(appState: appState, itemId: itemId)
            }
        }
        .background(Theme.canvas)
        .navigationTitle("Items")
        .searchable(text: $searchQuery, prompt: "Search items")
        .onChange(of: searchQuery) { _, _ in reload() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCompleted.toggle()
                    reload()
                } label: {
                    Image(systemName: showCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                }
            }
        }
        .onAppear { reload() }
    }

    private var sortedItems: [Item] {
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
        counts = (try? Queries.getCategoryCounts()) ?? [:]
    }
}
