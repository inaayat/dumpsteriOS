import SwiftUI
import UniformTypeIdentifiers

struct GuideView: View {
    @State private var showExportShare = false
    @State private var exportURL: URL?
    @State private var showImportPicker = false
    @State private var importMessage: String?
    @State private var showImportAlert = false

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

                // Refresh App
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.warnColor)
                        Text("Refresh Every 7 Days")
                            .font(.inter(16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Text("The free developer profile expires weekly. To refresh wirelessly:")
                        .font(.inter(13))
                        .foregroundStyle(Theme.textMuted)

                    VStack(alignment: .leading, spacing: 6) {
                        refreshStep("1", text: "Open dumpsteriOS.xcodeproj on your Mac")
                        refreshStep("2", text: "Select your iPhone from the device picker")
                        refreshStep("3", text: "Press ⌘R — rebuilds wirelessly in ~15 seconds")
                    }

                    Text("Both devices must be on the same Wi-Fi network.")
                        .font(.inter(11))
                        .foregroundStyle(Theme.textMuted)
                        .italic()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.warnColor.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.warnColor.opacity(0.2), lineWidth: 1))

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
                        magicTagRow("#save", color: Theme.accent, desc: "Saves bullet to the tag's Master Doc (AI-sorted if available)")
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
                        "Full rich text editing: bold, italic, headings, bullet & numbered lists",
                        "Indent/outdent with toolbar — auto-continues bullets on Return",
                        "Tap any doc to edit it directly",
                        "Swipe left to delete a doc"
                    ]
                )

                // AI Features
                aiSection

                // Backup & Restore
                backupSection

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
                        macOnlyRow(icon: "star.fill", text: "Wins tab — track achievements with #win")
                        macOnlyRow(icon: "rectangle.on.rectangle", text: "Quick Dump panel — global hotkey (Ctrl+Opt+N)")
                        macOnlyRow(icon: "menubar.rectangle", text: "Menu bar icon with quick actions")
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
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let data = try Data(contentsOf: url)
                    try BackupService.importAll(from: data)
                    importMessage = "Restore complete! All data has been imported."
                } catch {
                    importMessage = "Import failed: \(error.localizedDescription)"
                }
                showImportAlert = true
            case .failure(let error):
                importMessage = "Could not open file: \(error.localizedDescription)"
                showImportAlert = true
            }
        }
        .alert("Import", isPresented: $showImportAlert) {
            Button("OK") {}
        } message: {
            Text(importMessage ?? "")
        }
    }

    // MARK: - Backup Section

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.successColor)
                Text("Backup & Restore")
                    .font(.inter(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("Export your data as JSON. Import to restore after reinstalling.")
                .font(.inter(13))
                .foregroundStyle(Theme.textMuted)

            HStack(spacing: 12) {
                Button {
                    exportData()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                        Text("Export Backup")
                            .font(.inter(13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.successColor, in: RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    showImportPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12))
                        Text("Import Backup")
                            .font(.inter(13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.successColor.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.successColor.opacity(0.2), lineWidth: 1))
    }

    private func exportData() {
        do {
            let data = try BackupService.exportAll()
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("dumpster-backup.json")
            try data.write(to: fileURL)
            exportURL = fileURL
            showExportShare = true
        } catch {
            importMessage = "Export failed: \(error.localizedDescription)"
            showImportAlert = true
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
                Text("On-Device AI")
                    .font(.inter(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            if #available(iOS 26.0, *), AIService.isAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.successColor)
                    Text("Apple Intelligence is active on this device")
                        .font(.inter(12, weight: .medium)).foregroundStyle(Theme.successColor)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                    Text("Requires iPhone 15 Pro or later with Apple Intelligence enabled")
                        .font(.inter(12)).foregroundStyle(Theme.textMuted)
                }
            }

            Text("When available, AI enhances the app:")
                .font(.inter(13))
                .foregroundStyle(Theme.textMuted)

            VStack(alignment: .leading, spacing: 6) {
                aiFeatureRow(text: "#save bullets are AI-sorted into the right section of your Master Doc")
                aiFeatureRow(text: "Sort Trash button reorganizes a Master Doc into a structured document")
                aiFeatureRow(text: "All AI runs on-device — no data leaves your phone, no API keys needed")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Without AI (older devices):")
                    .font(.inter(12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 6)
                Text("Everything works normally — #save appends bullets as a list, and the Synthesize button is hidden. No features are lost, just the smart placement.")
                    .font(.inter(12))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.accent.opacity(0.2), lineWidth: 1))
    }

    private func aiFeatureRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 9))
                .foregroundStyle(Theme.accent)
                .padding(.top, 3)
            Text(text)
                .font(.inter(13))
                .foregroundStyle(Theme.textSecondary)
        }
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

    private func refreshStep(_ number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.inter(12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Theme.warnColor, in: Circle())
            Text(text)
                .font(.inter(13))
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
