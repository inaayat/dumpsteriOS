import SwiftUI

struct GuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.accent)
                        Text("Dumpster")
                            .font(.inter(28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("Your personal thought dumpster. Capture everything, sort later.")
                        .font(.inter(14))
                        .foregroundStyle(Theme.textMuted)
                }

                // Daily Dump
                guideSection(
                    icon: "flame.fill",
                    color: Theme.actionColor,
                    title: "Daily Dump",
                    items: [
                        "Type bullets — press Return to auto-start a new one",
                        "Type * at the start of a line to get a • bullet",
                        "Use #hashtags to categorize bullets (e.g. #work #ideas)",
                        "Tags are created automatically when you type them",
                        "Your dump saves as you type"
                    ]
                )

                // Magic Tags
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.accent)
                        Text("Magic Tags")
                            .font(.inter(16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Text("Add these to any bullet to trigger an action on Return:")
                        .font(.inter(13))
                        .foregroundStyle(Theme.textMuted)

                    VStack(alignment: .leading, spacing: 6) {
                        magicTagRow("#action", color: Theme.actionColor, desc: "Creates an action item (task)")
                        magicTagRow("#brainstorm", color: Theme.brainstormColor, desc: "Creates a brainstorm item (idea)")
                        magicTagRow("#resource", color: Theme.resourceColor, desc: "Creates a resource item (link/reference)")
                        magicTagRow("#prio", color: .red, desc: "Creates a high-priority action item")
                        magicTagRow("#backlog", color: .gray, desc: "Creates a backlog item (low priority)")
                        magicTagRow("#save", color: Theme.accent, desc: "Appends bullet to the tag's Master Doc")
                        magicTagRow("#delete", color: .red, desc: "Deletes matching item from Items")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))

                // Items
                guideSection(
                    icon: "square.stack.fill",
                    color: Theme.brainstormColor,
                    title: "Items",
                    items: [
                        "Filter by category: Actions, Brainstorms, Resources",
                        "Swipe right on an action to mark it done",
                        "Swipe left to delete",
                        "Tap any item to see full detail, notes, and links",
                        "Set priority and due dates in the detail view"
                    ]
                )

                // Tags
                guideSection(
                    icon: "number",
                    color: Theme.accent,
                    title: "Tags",
                    items: [
                        "Tags are created automatically from #hashtags in your dump",
                        "Tap a tag to see all its items and bullets",
                        "Swipe left to delete a tag",
                        "Sub-tags are shown nested under parent tags"
                    ]
                )

                // Docs
                guideSection(
                    icon: "doc.text.fill",
                    color: Theme.resourceColor,
                    title: "Master Docs",
                    items: [
                        "Each tag can have a Master Doc — a living document",
                        "Use #save in your dump to append a bullet to the tag's doc",
                        "Tap any doc to edit it directly",
                        "Swipe left to delete a doc"
                    ]
                )

                // macOS Only
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                        Text("macOS-Only Features")
                            .font(.inter(16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Text("These features are available in the macOS desktop app:")
                        .font(.inter(13))
                        .foregroundStyle(Theme.textMuted)

                    VStack(alignment: .leading, spacing: 8) {
                        macOnlyRow(icon: "sparkles", text: "AI analysis — analyze dumps and synthesize docs")
                        macOnlyRow(icon: "star.fill", text: "Wins tab — track achievements with #win")
                        macOnlyRow(icon: "rectangle.on.rectangle", text: "Quick Dump panel — global hotkey (Ctrl+Opt+N)")
                        macOnlyRow(icon: "menubar.rectangle", text: "Menu bar icon with quick actions")
                        macOnlyRow(icon: "arrow.triangle.merge", text: "Drag-and-drop tag merging")
                        macOnlyRow(icon: "square.and.arrow.up", text: "Export all data to Markdown")
                        macOnlyRow(icon: "moon.fill", text: "Bro mode (dark theme) — iOS uses system dark mode")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.textMuted.opacity(0.05), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Components

    private func guideSection(icon: String, color: Color, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(title)
                    .font(.inter(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.inter(13))
                            .foregroundStyle(color)
                        Text(item)
                            .font(.inter(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
    }

    private func magicTagRow(_ tag: String, color: Color, desc: String) -> some View {
        HStack(spacing: 10) {
            Text(tag)
                .font(.inter(12, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 90, alignment: .leading)
            Text(desc)
                .font(.inter(12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func macOnlyRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 20)
            Text(text)
                .font(.inter(13))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
