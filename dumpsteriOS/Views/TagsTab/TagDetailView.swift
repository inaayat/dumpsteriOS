import SwiftUI

struct TagDetailView: View {
    @Bindable var appState: AppState
    let tag: Tag

    @State private var items: [Item] = []
    @State private var bullets: [String] = []
    @State private var showCompleted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !items.isEmpty {
                    sectionHeader("Items", count: items.count)
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            itemRow(item)
                            if item.id != items.last?.id {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }

                if !bullets.isEmpty {
                    sectionHeader("Bullets", count: bullets.count)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(bullets.enumerated()), id: \.offset) { index, bullet in
                            bulletRow(bullet)
                            if index < bullets.count - 1 {
                                Divider().padding(.leading, 22)
                            }
                        }
                    }
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }

                if items.isEmpty && bullets.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textMuted.opacity(0.4))
                        Text("No content tagged #\(tag.name)")
                            .font(.inter(13))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.top, 12)
        }
        .background(Theme.canvas)
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
                        .foregroundStyle(showCompleted ? Theme.successColor : Theme.textMuted)
                }
            }
        }
        .onAppear { loadData() }
    }

    // MARK: - Row Views

    private func itemRow(_ item: Item) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Completion circle — fixed width so all rows align
            Button {
                if item.done {
                    try? Queries.uncompleteItem(id: item.id)
                } else {
                    try? Queries.completeItem(id: item.id)
                }
                appState.refreshCounts()
                loadData()
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(item.done ? Theme.successColor : Theme.textMuted.opacity(0.35))
                    .frame(width: 44, alignment: .leading)
            }
            .padding(.top, 10)

            // Text + metadata fills the rest of the row
            NavigationLink(value: item.id) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayText)
                        .font(.inter(14))
                        .foregroundStyle(item.done ? Theme.textMuted : Theme.textPrimary)
                        .strikethrough(item.done, color: Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Label(item.category.label, systemImage: item.category.icon)
                            .font(.inter(11))
                            .foregroundStyle(Theme.categoryColor(item.category))

                        if item.priority == .high {
                            Text("High")
                                .font(.inter(10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.actionColor, in: Capsule())
                        }

                        if let dueDate = item.dueDate {
                            Text(dueDate.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.inter(10, weight: .medium))
                                .foregroundStyle(item.isOverdue ? .red : Theme.textMuted)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.trailing, 14)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
    }

    private func bulletRow(_ bullet: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.inter(14, weight: .medium))
                .foregroundStyle(Theme.accent.opacity(0.6))
                .padding(.top, 1)
            Text(bullet)
                .font(.inter(14))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.inter(12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            Text("\(count)")
                .font(.inter(11))
                .foregroundStyle(Theme.textMuted.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    // MARK: - Data

    private func loadData() {
        items = (try? Queries.getItemsForTag(tagId: tag.id, done: showCompleted ? nil : false)) ?? []

        let allDumps = (try? Queries.getAllDumps()) ?? []
        var found: [String] = []
        for dump in allDumps {
            for bullet in DumpBullet.parse(from: dump.content) where bullet.tags.contains(tag.name.lowercased()) {
                let clean = bullet.text
                    .replacingOccurrences(of: #"#[\w\-]+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty { found.append(clean) }
            }
        }
        bullets = found
    }
}
