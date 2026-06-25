import SwiftUI

struct DumpView: View {
    @Bindable var appState: AppState
    @State private var todayDump: DailyDump?
    @State private var pastDumps: [DailyDump] = []
    @State private var content = ""
    @State private var newBulletText = ""
    @State private var expandedPastDays: Set<String> = []
    @State private var attentionItems: [Item] = []
    @FocusState private var isEditorFocused: Bool
    @State private var tagEditorLineIndex: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                if !attentionItems.isEmpty {
                    attentionBar
                }
                dumpHints
                magicTagsGuide
                todaySection
                if !pastDumps.isEmpty {
                    pastSection
                }
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Daily Dump")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.inter(14, weight: .semibold))
            }
        }
        .onAppear { reload() }
        .sheet(isPresented: .init(
            get: { tagEditorLineIndex != nil },
            set: { if !$0 { tagEditorLineIndex = nil } }
        )) {
            if let lineIndex = tagEditorLineIndex {
                let lines = content.components(separatedBy: "\n")
                let line = lineIndex < lines.count ? lines[lineIndex] : ""
                let currentTags = DumpBullet.parse(from: line).first?.tags ?? []
                TagEditorView(
                    currentTags: currentTags,
                    onAdd: { name in addTagToLine(name, at: lineIndex) },
                    onRemove: { name in removeTagFromLine(name, at: lineIndex) }
                )
            }
        }
    }

    // MARK: - Hints

    private var aiIsAvailable: Bool {
        if #available(iOS 26.0, *) { return AIService.isAvailable }
        return false
    }

    private var dumpHints: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                hintChip(icon: "list.bullet", text: "Type * or • to start a bullet")
                hintChip(icon: "tag", text: "#tags auto-categorize bullets")
                hintChip(icon: "link", text: "URLs auto-save as resources")
                if aiIsAvailable {
                    hintChip(icon: "doc.text", text: "#save AI-sorts into Master Doc")
                    hintChip(icon: "sparkles", text: "AI extracts action items")
                } else {
                    hintChip(icon: "doc.text", text: "#save appends to Master Doc")
                }
            }
        }
    }

    private var magicTagsGuide: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.accent)
                    .padding(.trailing, 8)

                magicTagLabel("#action", color: Theme.successColor)
                dot
                magicTagLabel("#prio", color: .red)
                dot
                magicTagLabel("#backlog", color: .gray)
                dot
                magicTagLabel("#brainstorm", color: Theme.brainstormColor)
                dot
                magicTagLabel("#save", color: Theme.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.accent.opacity(0.15), lineWidth: 1))
        }
    }

    private func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.inter(11))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func magicTagLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.inter(11, weight: .semibold))
            .foregroundStyle(color)
    }

    private var dot: some View {
        Text("·")
            .font(.inter(11))
            .foregroundStyle(Theme.textMuted.opacity(0.5))
            .padding(.horizontal, 6)
    }

    // MARK: - Attention Bar

    private var attentionBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.warnColor)
                Text("\(attentionItems.count) items need attention")
                    .font(.inter(12, weight: .semibold))
                    .foregroundStyle(Theme.warnColor)
            }

            ForEach(attentionItems) { item in
                HStack(spacing: 8) {
                    Button {
                        try? Queries.completeItem(id: item.id)
                        appState.refreshCounts()
                        reload()
                    } label: {
                        Image(systemName: "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(item.isOverdue ? .red : (item.isDueToday ? Theme.warnColor : Theme.actionColor))
                    }
                    .buttonStyle(.plain)
                    Text(item.text)
                        .font(.inter(12))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let due = item.dueDate {
                        Text(due.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.inter(10))
                            .foregroundStyle(item.isOverdue ? .red : Theme.textMuted)
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.warnColor.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(DailyDump.displayDate(DailyDump.today()))
                    .font(.inter(13))
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Text("\(bulletCount) bullets")
                    .font(.inter(11))
                    .foregroundStyle(Theme.textMuted)
            }

            // Quick-add input
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)

                TextField("Add a bullet...", text: $newBulletText, axis: .vertical)
                    .font(.inter(15))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1...6)
                    .submitLabel(.done)
                    .onSubmit { addBullet() }
                    .onChange(of: newBulletText) { _, newValue in
                        if newValue.contains("\n") {
                            newBulletText = newValue.replacingOccurrences(of: "\n", with: "")
                            addBullet()
                        }
                    }
            }
            .padding(12)
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))

            // Today's notes: bullet rows when not editing, TextEditor when editing
            if isEditorFocused {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $content)
                        .font(.inter(14))
                        .foregroundStyle(Theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 150, maxHeight: 300)
                        .focused($isEditorFocused)
                        .padding(12)
                        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
                        )
                        .onChange(of: content) { oldValue, newValue in
                            guard isEditorFocused else { return }
                            guard newValue.count > oldValue.count else { saveDraft(); return }
                            var updated = newValue

                            if updated.hasSuffix("* ") {
                                let beforeStar = updated.dropLast(2)
                                if beforeStar.isEmpty || beforeStar.last == "\n" {
                                    updated = String(beforeStar) + "• "
                                }
                            }

                            if updated.hasSuffix("\n") {
                                let lines = updated.components(separatedBy: "\n")
                                if lines.count >= 2 {
                                    let completedLine = lines[lines.count - 2]
                                    if !completedLine.trimmingCharacters(in: .whitespaces).isEmpty {
                                        processLineIfNeeded(completedLine)
                                        processMagicTags(line: completedLine)
                                    }
                                }
                                updated += "• "
                            }

                            if updated != newValue {
                                content = updated
                            }
                            saveDraft()
                        }
                }
            } else if content.isEmpty {
                Text("Today's notes will appear here...")
                    .font(.inter(14))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                    .padding(16)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                    .onTapGesture { isEditorFocused = true }
            } else {
                bulletRows
            }
        }
    }

    // MARK: - Past Days

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Past Days")
                .font(.inter(15, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            ForEach(pastDumps) { dump in
                pastDayRow(dump)
            }
        }
    }

    @ViewBuilder
    private func pastDayRow(_ dump: DailyDump) -> some View {
        let isExpanded = expandedPastDays.contains(dump.date)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedPastDays.remove(dump.date) }
                    else { expandedPastDays.insert(dump.date) }
                }
            } label: {
                HStack {
                    Text(DailyDump.displayDate(dump.date))
                        .font(.inter(13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    let count = dump.content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
                    Text("\(count) bullets")
                        .font(.inter(11))
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(12)
                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(dump.content)
                    .font(.inter(13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Logic

    private func addBullet() {
        let text = newBulletText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let bulletLine = "• \(text)"
        if content.isEmpty {
            content = bulletLine
        } else {
            content += "\n\(bulletLine)"
        }
        processLineIfNeeded(bulletLine)
        processMagicTags(line: bulletLine)
        saveDraft()
        newBulletText = ""
    }

    private var bulletCount: Int {
        content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private var bulletRows: some View {
        let lines = content.components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text(trimmed)
                            .font(.inter(14))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { isEditorFocused = true }
                        Button {
                            tagEditorLineIndex = index
                        } label: {
                            Image(systemName: "tag")
                                .font(.system(size: 12))
                                .foregroundStyle(hasTagsInLine(trimmed) ? Theme.accent : Theme.textMuted.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    if index < lines.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
    }

    private func hasTagsInLine(_ line: String) -> Bool {
        line.range(of: #"#[\w\-]+"#, options: .regularExpression) != nil
    }

    private func addTagToLine(_ name: String, at index: Int) {
        var lines = content.components(separatedBy: "\n")
        guard index < lines.count else { return }
        let tag = "#\(name)"
        guard !lines[index].contains(tag) else { return }
        lines[index] = lines[index] + " \(tag)"
        content = lines.joined(separator: "\n")
        saveDraft()
        processLineIfNeeded(lines[index])
    }

    private func removeTagFromLine(_ name: String, at index: Int) {
        var lines = content.components(separatedBy: "\n")
        guard index < lines.count else { return }
        let updated = lines[index]
            .replacingOccurrences(of: " #\(name)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "#\(name)", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        lines[index] = updated
        content = lines.joined(separator: "\n")
        saveDraft()
    }

    private func processMagicTags(line: String) {
        MagicTagProcessor.processLine(line)
        appState.refreshCounts()
    }

    private func processLineIfNeeded(_ line: String) {
        let bullet = DumpBullet.parse(from: line).first
        guard let bullet else { return }
        for tagName in bullet.tags {
            _ = try? Queries.getOrCreateTag(name: tagName)
        }
    }

    private func saveDraft() {
        guard let dump = todayDump else { return }
        try? Queries.updateDumpContent(id: dump.id, content: content)
    }

    private func reload() {
        todayDump = try? Queries.getOrCreateTodayDump()
        content = todayDump?.content ?? ""
        let all = (try? Queries.getAllDumps()) ?? []
        pastDumps = all.filter { $0.date != DailyDump.today() }

        let overdueDueToday = (try? Queries.getOverdueAndDueToday()) ?? []
        let highPrio = ((try? Queries.getItems(category: nil, done: false)) ?? []).filter { $0.priority == .high }
        var combined: [Item] = []
        var seenIds = Set<String>()
        for item in (overdueDueToday + highPrio) {
            if seenIds.insert(item.id).inserted { combined.append(item) }
        }
        attentionItems = combined
    }
}
