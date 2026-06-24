import SwiftUI

struct TagDetailView: View {
    @Bindable var appState: AppState
    let tag: Tag

    @State private var items: [Item] = []
    @State private var bullets: [String] = []
    @State private var showCompleted = false

    var body: some View {
        List {
            if !items.isEmpty {
                Section("Items (\(items.count))") {
                    ForEach(items) { item in
                        NavigationLink(value: item.id) {
                            ItemCard(item: item)
                        }
                        .swipeActions(edge: .leading) {
                            if (item.category == .action || item.category == .brainstorm) && !item.done {
                                Button {
                                    try? Queries.completeItem(id: item.id)
                                    appState.refreshCounts()
                                    loadData()
                                } label: {
                                    Label("Done", systemImage: "checkmark")
                                }
                                .tint(Theme.successColor)
                            } else if item.done {
                                Button {
                                    try? Queries.uncompleteItem(id: item.id)
                                    appState.refreshCounts()
                                    loadData()
                                } label: {
                                    Label("Reopen", systemImage: "arrow.uturn.left")
                                }
                                .tint(Theme.accent)
                            }
                        }
                    }
                }
            }

            if !bullets.isEmpty {
                Section("Bullets (\(bullets.count))") {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(spacing: 8) {
                            Text("•")
                                .font(.inter(13))
                                .foregroundStyle(Theme.textMuted)
                            Text(bullet)
                                .font(.inter(13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }

            if items.isEmpty && bullets.isEmpty {
                ContentUnavailableView {
                    Label("No content", systemImage: "tray")
                } description: {
                    Text("Items and bullets tagged with #\(tag.name) will appear here.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("#\(tag.name)")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: String.self) { itemId in
            ItemDetailView(appState: appState, itemId: itemId)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCompleted.toggle()
                    loadData()
                } label: {
                    Image(systemName: showCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                }
            }
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        items = (try? Queries.getItemsForTag(tagId: tag.id, done: showCompleted ? true : false)) ?? []

        let allDumps = (try? Queries.getAllDumps()) ?? []
        var found: [String] = []
        for dump in allDumps {
            for bullet in DumpBullet.parse(from: dump.content) where bullet.tags.contains(tag.name) {
                let clean = bullet.text.replacingOccurrences(of: #"#[\w\-]+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty { found.append(clean) }
            }
        }
        bullets = found
    }
}
