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
    @State private var showTagEditor = false
    @State private var isEditingText = false
    @State private var editedText = ""
    @FocusState private var textFieldFocused: Bool
    @State private var showCreateResource = false
    @State private var newResourceURL = ""
    @State private var newResourceTitle = ""

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

                        if (item.category == .action || item.category == .brainstorm) && !item.done {
                            Button {
                                try? Queries.completeItem(id: item.id)
                                appState.refreshCounts()
                                loadData()
                            } label: {
                                Label("Done", systemImage: "checkmark.circle.fill")
                                    .font(.inter(13, weight: .semibold))
                                    .foregroundStyle(Theme.successColor)
                            }
                        } else if item.done {
                            Button {
                                try? Queries.uncompleteItem(id: item.id)
                                appState.refreshCounts()
                                loadData()
                            } label: {
                                Label("Reopen", systemImage: "arrow.uturn.left.circle")
                                    .font(.inter(13, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }

                    // Text
                    if isEditingText {
                        TextField("Item text", text: $editedText, axis: .vertical)
                            .font(.inter(17, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1...)
                            .focused($textFieldFocused)
                            .padding(10)
                            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
                            .onSubmit { commitTextEdit() }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { commitTextEdit() }
                                        .font(.inter(14, weight: .semibold))
                                }
                            }
                            .onChange(of: textFieldFocused) { _, focused in
                                if !focused { commitTextEdit() }
                            }
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.text)
                                .font(.inter(17, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                editedText = item.text
                                isEditingText = true
                                textFieldFocused = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                    }

                    // Tags
                    FlowLayout(spacing: 6) {
                        ForEach(tags) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag.name)")
                                    .font(.inter(12, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                Button {
                                    try? Queries.untagItem(itemId: itemId, tagId: tag.id)
                                    loadData()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Theme.textMuted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.accent.opacity(0.1), in: Capsule())
                        }
                        Button {
                            showTagEditor = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text("tag")
                                    .font(.inter(12))
                            }
                            .foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.cardAlt, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .sheet(isPresented: $showTagEditor) {
                        TagEditorView(
                            currentTags: tags.map(\.name),
                            onAdd: { name in
                                try? Queries.tagItemWithNames(itemId: itemId, tagNames: [name])
                                loadData()
                            },
                            onRemove: { name in
                                if let tag = tags.first(where: { $0.name == name }) {
                                    try? Queries.untagItem(itemId: itemId, tagId: tag.id)
                                    loadData()
                                }
                            }
                        )
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

                    // Create linked resource
                    if item.category == .action || item.category == .brainstorm {
                        Button {
                            newResourceURL = ""
                            newResourceTitle = ""
                            showCreateResource = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 13))
                                Text("Create Linked Resource")
                                    .font(.inter(13, weight: .medium))
                            }
                            .foregroundStyle(Theme.resourceColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.resourceColor.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
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
            .sheet(isPresented: $showCreateResource) {
                createResourceSheet
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

    private var createResourceSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Link a resource to this item")
                    .font(.inter(14))
                    .foregroundStyle(Theme.textMuted)

                VStack(alignment: .leading, spacing: 6) {
                    Text("URL")
                        .font(.inter(12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    TextField("https://...", text: $newResourceURL)
                        .font(.inter(14))
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(10)
                        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Title (optional)")
                        .font(.inter(12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    TextField("Resource name", text: $newResourceTitle)
                        .font(.inter(14))
                        .padding(10)
                        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                }

                Spacer()
            }
            .padding(20)
            .background(Theme.canvas)
            .navigationTitle("Create Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateResource = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createLinkedResource() }
                        .font(.inter(14, weight: .semibold))
                        .disabled(newResourceURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createLinkedResource() {
        let url = newResourceURL.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        let title = newResourceTitle.trimmingCharacters(in: .whitespaces)
        let resourceText = title.isEmpty ? url : title

        let resource = Item.new(text: resourceText, category: .resource, url: url, urlTitle: title.isEmpty ? nil : title)
        try? Queries.addItem(resource)

        // Copy tags from parent item to resource
        for tag in tags {
            try? Queries.tagItem(itemId: resource.id, tagId: tag.id)
        }

        // Link the resource to this item
        let link = ItemLink(id: UUID().uuidString, fromItemId: itemId, toItemId: resource.id, relationship: "resource", createdAt: Date())
        try? Queries.addLink(link)

        appState.refreshCounts()
        showCreateResource = false
        loadData()
    }

    private func commitTextEdit() {
        guard var updated = item else { isEditingText = false; return }
        let trimmed = editedText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { isEditingText = false; return }
        updated.text = trimmed
        try? Queries.updateItem(updated)
        self.item = updated
        isEditingText = false
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
