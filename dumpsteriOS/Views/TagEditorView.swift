import SwiftUI

struct TagEditorView: View {
    let currentTags: [String]
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void

    @State private var input = ""
    @State private var allTags: [Tag] = []
    @Environment(\.dismiss) private var dismiss

    private var suggestions: [Tag] {
        guard !input.isEmpty else { return [] }
        let q = input.lowercased()
        return allTags.filter { $0.name.hasPrefix(q) && !currentTags.contains($0.name) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Current tags
                if currentTags.isEmpty {
                    Text("No tags yet")
                        .font(.inter(13))
                        .foregroundStyle(Theme.textMuted)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(currentTags, id: \.self) { name in
                            HStack(spacing: 4) {
                                Text("#\(name)")
                                    .font(.inter(13, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                Button {
                                    onRemove(name)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.textMuted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.accent.opacity(0.1), in: Capsule())
                        }
                    }
                }

                Divider()

                // Add field
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    TextField("Add a tag...", text: $input)
                        .font(.inter(14))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit { commitInput() }
                    if !input.isEmpty {
                        Button("Add") { commitInput() }
                            .font(.inter(13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(12)
                .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))

                // Suggestions
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Existing tags")
                            .font(.inter(11, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                        FlowLayout(spacing: 6) {
                            ForEach(suggestions) { tag in
                                Button {
                                    onAdd(tag.name)
                                    input = ""
                                } label: {
                                    Text("#\(tag.name)")
                                        .font(.inter(12))
                                        .foregroundStyle(Theme.accent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Theme.cardAlt, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(Theme.canvas)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.inter(14, weight: .semibold))
                }
            }
            .onAppear {
                allTags = (try? Queries.getAllTags()) ?? []
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func commitInput() {
        let name = input.lowercased().trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !currentTags.contains(name) else { input = ""; return }
        onAdd(name)
        input = ""
    }
}
