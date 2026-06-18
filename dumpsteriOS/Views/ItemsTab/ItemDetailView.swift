import SwiftUI

struct ItemDetailView: View {
    @Bindable var appState: AppState
    let itemId: String

    @State private var item: Item?
    @State private var tags: [Tag] = []
    @State private var linkedItems: [Item] = []
    @State private var notesText = ""
    @State private var showDeleteConfirm = false
    @State private var showDatePicker = false
    @State private var editedDate = Date()

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category & Priority header
                    HStack(spacing: 12) {
                        Label(item.category.label, systemImage: item.category.icon)
                            .font(.inter(13, weight: .semibold))
                            .foregroundStyle(Theme.categoryColor(item.category))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.categoryTint(item.category), in: Capsule())

                        Menu {
                            Button { setPriority(.high) } label: { Label("High", systemImage: "arrow.up") }
                            Button { setPriority(.medium) } label: { Label("Standard", systemImage: "minus") }
                            Button { setPriority(.low) } label: { Label("Low", systemImage: "arrow.down") }
                            Button { setPriority(.backlog) } label: { Label("Backlog", systemImage: "archivebox") }
                        } label: {
                            Label(item.priority.rawValue.capitalized, systemImage: priorityIcon(item.priority))
                                .font(.inter(12, weight: .medium))
                                .foregroundStyle(item.priority == .high ? Theme.actionColor : Theme.textMuted)
                        }

                        Spacer()

                        if item.category == .action && !item.done {
                            Button {
                                try? Queries.completeItem(id: item.id)
                                appState.refreshCounts()
                                loadData()
                            } label: {
                                Label("Done", systemImage: "checkmark.circle.fill")
                                    .font(.inter(13, weight: .semibold))
                                    .foregroundStyle(Theme.successColor)
                            }
                        }
                    }

                    // Text
                    Text(item.text)
                        .font(.inter(17, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)

                    // Tags
                    if !tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tags) { tag in
                                Text("#\(tag.name)")
                                    .font(.inter(12, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Theme.accent.opacity(0.1), in: Capsule())
                            }
                        }
                    }

                    // Due date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due Date")
                            .font(.inter(12, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                        Button {
                            editedDate = item.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                            showDatePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                Text(item.dueDate?.formatted(.dateTime.month().day().year()) ?? "Not set")
                                    .font(.inter(13))
                            }
                            .foregroundStyle(item.dueDate != nil ? Theme.textPrimary : Theme.textMuted)
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.inter(12, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                        TextEditor(text: $notesText)
                            .font(.inter(14))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(10)
                            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                            .onChange(of: notesText) { _, newValue in
                                var updated = item
                                updated.notes = newValue.isEmpty ? nil : newValue
                                try? Queries.updateItem(updated)
                                self.item = updated
                            }
                    }

                    // URL
                    if let url = item.url, let link = URL(string: url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Link")
                                .font(.inter(12, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                            Link(destination: link) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                    Text(item.urlTitle ?? url)
                                        .lineLimit(1)
                                }
                                .font(.inter(13))
                                .foregroundStyle(Theme.resourceColor)
                            }
                        }
                    }

                    // Linked items
                    if !linkedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Linked Items")
                                .font(.inter(12, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                            ForEach(linkedItems) { linked in
                                HStack(spacing: 8) {
                                    Image(systemName: linked.category.icon)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.categoryColor(linked.category))
                                    Text(linked.text)
                                        .font(.inter(13))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)

                    // Delete
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Item", systemImage: "trash")
                            .font(.inter(13))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(Theme.canvas)
            .navigationTitle("Item")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    DatePicker("Due Date", selection: $editedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Remove") {
                                    var updated = item
                                    updated.dueDate = nil
                                    try? Queries.updateItem(updated)
                                    self.item = updated
                                    showDatePicker = false
                                }
                                .foregroundStyle(.red)
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Set") {
                                    var updated = item
                                    updated.dueDate = editedDate
                                    try? Queries.updateItem(updated)
                                    self.item = updated
                                    showDatePicker = false
                                }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog("Delete Item?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    try? Queries.deleteItem(id: itemId)
                    appState.refreshCounts()
                }
            }
            .onAppear { loadData() }
        } else {
            ProgressView()
                .onAppear { loadData() }
        }
    }

    private func priorityIcon(_ priority: Priority) -> String {
        switch priority {
        case .high: return "arrow.up"
        case .medium: return "minus"
        case .low: return "arrow.down"
        case .backlog: return "archivebox"
        }
    }

    private func setPriority(_ priority: Priority) {
        guard var updated = item else { return }
        updated.priority = priority
        try? Queries.updateItem(updated)
        self.item = updated
    }

    private func loadData() {
        item = try? Queries.getItem(id: itemId)
        tags = (try? Queries.getTagsForItem(itemId: itemId)) ?? []
        linkedItems = (try? Queries.getLinkedItems(itemId: itemId)) ?? []
        notesText = item?.notes ?? ""
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? 0).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }
    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x + size.width)
            x += size.width + spacing
        }
        return (CGSize(width: maxX, height: y + rowHeight), frames)
    }
}
