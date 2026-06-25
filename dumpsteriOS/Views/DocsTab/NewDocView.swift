import SwiftUI

struct NewDocView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var allTags: [Tag] = []
    @State private var assignedTagIds: Set<String> = []
    @State private var selectedTagIds: Set<String> = []

    var onCreate: ((MasterDoc) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.inter(12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    TextField("Document name", text: $title)
                        .font(.inter(16))
                        .padding(12)
                        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.inter(12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    Text("Select tags to associate with this doc. Grayed tags are already in another doc.")
                        .font(.inter(11))
                        .foregroundStyle(Theme.textMuted)

                    FlowLayout(spacing: 8) {
                        ForEach(allTags) { tag in
                            let isAssigned = assignedTagIds.contains(tag.id)
                            let isSelected = selectedTagIds.contains(tag.id)

                            Button {
                                guard !isAssigned else { return }
                                if isSelected { selectedTagIds.remove(tag.id) }
                                else { selectedTagIds.insert(tag.id) }
                            } label: {
                                Text("#\(tag.name)")
                                    .font(.inter(13, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isAssigned ? Theme.textMuted.opacity(0.4) : (isSelected ? .white : Theme.accent))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        isSelected ? Theme.accent : (isAssigned ? Theme.cardAlt : Theme.accent.opacity(0.08)),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .disabled(isAssigned)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(Theme.canvas)
            .navigationTitle("New Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createDoc() }
                        .font(.inter(14, weight: .semibold))
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedTagIds.isEmpty)
                }
            }
            .onAppear { loadTags() }
        }
    }

    private func loadTags() {
        allTags = (try? Queries.getAllTags()) ?? []
        assignedTagIds = Set(allTags.compactMap { tag in
            (try? Queries.isTagAssignedToDoc(tagId: tag.id)) == true ? tag.id : nil
        })
    }

    private func createDoc() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty, !selectedTagIds.isEmpty else { return }
        if let doc = try? Queries.createMasterDoc(title: trimmedTitle, tagIds: Array(selectedTagIds)) {
            onCreate?(doc)
        }
        dismiss()
    }
}
