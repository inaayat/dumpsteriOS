import SwiftUI
import UIKit

// MARK: - Markdown Text View

private let bodyFont = UIFont(name: "Inter-Regular", size: 16) ?? .systemFont(ofSize: 16)
private let headingFont = UIFont(name: "Inter-Bold", size: 22) ?? .boldSystemFont(ofSize: 22)
private let subheadingFont = UIFont(name: "Inter-SemiBold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)

class MarkdownTextView: UITextView {
    var onContentChange: ((String) -> Void)?
    private var isApplyingStyle = false

    var defaultAttributes: [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        return [
            .font: bodyFont,
            .foregroundColor: UIColor(Theme.textPrimary),
            .paragraphStyle: para
        ]
    }

    func applyMarkdownStyling() {
        guard !isApplyingStyle else { return }
        isApplyingStyle = true
        defer { isApplyingStyle = false }

        let fullText = text ?? ""
        guard !fullText.isEmpty else { return }

        let cursorPos = selectedRange
        let nsText = fullText as NSString
        let textColor = UIColor(Theme.textPrimary)
        let hiddenColor = UIColor.clear
        let cursorLineRange = nsText.lineRange(for: NSRange(location: cursorPos.location, length: 0))

        textStorage.beginEditing()

        // Reset to default
        let fullRange = NSRange(location: 0, length: nsText.length)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.lineSpacing = 4
        textStorage.setAttributes([
            .font: bodyFont,
            .foregroundColor: textColor,
            .paragraphStyle: defaultPara
        ], range: fullRange)

        // Style each line
        var lineStart = 0
        while lineStart < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: lineStart, length: 0))
            let line = nsText.substring(with: lineRange)
            let trimmedLine = line.trimmingCharacters(in: .newlines)
            let isCursorLine = NSIntersectionRange(lineRange, cursorLineRange).length > 0

            if trimmedLine.hasPrefix("## ") {
                // Heading: hide marker, style text bold 22pt, add top spacing
                let markerLen = 3
                let textStart = lineRange.location + markerLen
                let textLen = trimmedLine.count - markerLen

                let headingPara = NSMutableParagraphStyle()
                headingPara.paragraphSpacingBefore = 16
                headingPara.lineSpacing = 4
                headingPara.paragraphSpacing = 4
                textStorage.addAttribute(.paragraphStyle, value: headingPara, range: NSRange(location: lineRange.location, length: trimmedLine.count))
                textStorage.addAttribute(.font, value: headingFont, range: NSRange(location: lineRange.location, length: trimmedLine.count))
                if !isCursorLine {
                    textStorage.addAttribute(.foregroundColor, value: hiddenColor, range: NSRange(location: lineRange.location, length: markerLen))
                } else {
                    textStorage.addAttribute(.foregroundColor, value: UIColor(Theme.textMuted).withAlphaComponent(0.4), range: NSRange(location: lineRange.location, length: markerLen))
                }
                if textLen > 0 {
                    textStorage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: textStart, length: textLen))
                }
            } else if trimmedLine.hasPrefix("### ") {
                // Subheading: hide marker, style text semibold 18pt, add top spacing
                let markerLen = 4
                let textStart = lineRange.location + markerLen
                let textLen = trimmedLine.count - markerLen

                let subPara = NSMutableParagraphStyle()
                subPara.paragraphSpacingBefore = 12
                subPara.lineSpacing = 4
                subPara.paragraphSpacing = 3
                textStorage.addAttribute(.paragraphStyle, value: subPara, range: NSRange(location: lineRange.location, length: trimmedLine.count))
                textStorage.addAttribute(.font, value: subheadingFont, range: NSRange(location: lineRange.location, length: trimmedLine.count))
                if !isCursorLine {
                    textStorage.addAttribute(.foregroundColor, value: hiddenColor, range: NSRange(location: lineRange.location, length: markerLen))
                } else {
                    textStorage.addAttribute(.foregroundColor, value: UIColor(Theme.textMuted).withAlphaComponent(0.4), range: NSRange(location: lineRange.location, length: markerLen))
                }
                if textLen > 0 {
                    textStorage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: textStart, length: textLen))
                }
            } else if trimmedLine.hasPrefix("• ") || trimmedLine.hasPrefix("◦ ") || trimmedLine.hasPrefix("▪ ") {
                // Bullet: indent under heading
                let para = NSMutableParagraphStyle()
                para.firstLineHeadIndent = 20
                para.headIndent = 34
                para.lineSpacing = 4
                para.paragraphSpacing = 3
                textStorage.addAttribute(.paragraphStyle, value: para, range: NSRange(location: lineRange.location, length: trimmedLine.count))
            } else if trimmedLine.hasPrefix("\t•") || trimmedLine.hasPrefix("\t◦") || trimmedLine.hasPrefix("\t▪") {
                // Sub-bullet: deeper indent
                let level = trimmedLine.prefix(while: { $0 == "\t" }).count
                let para = NSMutableParagraphStyle()
                para.firstLineHeadIndent = CGFloat(level) * 24 + 20
                para.headIndent = CGFloat(level) * 24 + 34
                para.lineSpacing = 4
                para.paragraphSpacing = 3
                textStorage.addAttribute(.paragraphStyle, value: para, range: NSRange(location: lineRange.location, length: trimmedLine.count))
            }

            lineStart = NSMaxRange(lineRange)
        }

        textStorage.endEditing()
        selectedRange = cursorPos
    }

    // MARK: - Enter Key

    func handleReturn() {
        let cursorPos = selectedRange.location
        guard cursorPos > 0 else { insertText("\n"); return }

        let nsText = (text ?? "") as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: cursorPos, length: 0))
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        if let bulletInfo = parseBulletLine(lineText) {
            if bulletInfo.content.trimmingCharacters(in: .whitespaces).isEmpty {
                // Empty bullet → exit list
                let markerRange = NSRange(location: lineRange.location, length: lineText.count)
                textStorage.replaceCharacters(in: markerRange, with: "")
                selectedRange = NSRange(location: lineRange.location, length: 0)
            } else {
                // Continue bullet on next line
                let indent = String(repeating: "\t", count: bulletInfo.level)
                let marker = bulletInfo.marker
                let insertion = "\n\(indent)\(marker) "
                insertText(insertion)
            }
        } else {
            insertText("\n")
        }
        onContentChange?(text ?? "")
    }

    struct BulletInfo {
        let level: Int
        let marker: String
        let content: String
    }

    private func parseBulletLine(_ line: String) -> BulletInfo? {
        var remaining = line[line.startIndex...]
        var level = 0
        while remaining.hasPrefix("\t") { level += 1; remaining = remaining.dropFirst() }

        let afterIndent = String(remaining)
        for marker in ["•", "◦", "▪"] {
            if afterIndent.hasPrefix("\(marker) ") {
                return BulletInfo(level: level, marker: marker, content: String(afterIndent.dropFirst(2)))
            }
            if afterIndent == marker {
                return BulletInfo(level: level, marker: marker, content: "")
            }
        }
        return nil
    }

    // MARK: - Toolbar Actions

    func toggleHeading() {
        let nsText = (text ?? "") as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        if lineText.hasPrefix("### ") {
            // Subheading → Body
            let newLine = String(lineText.dropFirst(4))
            textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: lineText.count), with: newLine)
            selectedRange = NSRange(location: lineRange.location + newLine.count, length: 0)
        } else if lineText.hasPrefix("## ") {
            // Heading → Subheading
            let newLine = "### " + String(lineText.dropFirst(3))
            textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: lineText.count), with: newLine)
            selectedRange = NSRange(location: lineRange.location + newLine.count, length: 0)
        } else {
            // Body → Heading
            let newLine = "## " + lineText
            textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: lineText.count), with: newLine)
            selectedRange = NSRange(location: lineRange.location + newLine.count, length: 0)
        }
        applyMarkdownStyling()
        onContentChange?(text ?? "")
    }

    func toggleBullet() {
        let nsText = (text ?? "") as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        if lineText.hasPrefix("• ") {
            // Remove bullet
            let newLine = String(lineText.dropFirst(2))
            textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: lineText.count), with: newLine)
            selectedRange = NSRange(location: lineRange.location + newLine.count, length: 0)
        } else {
            // Add bullet
            let newLine = "• " + lineText
            textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: lineText.count), with: newLine)
            selectedRange = NSRange(location: lineRange.location + newLine.count, length: 0)
        }
        applyMarkdownStyling()
        onContentChange?(text ?? "")
    }

    func indentLine() {
        let nsText = (text ?? "") as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        textStorage.insert(NSAttributedString(string: "\t", attributes: defaultAttributes), at: lineRange.location)
        selectedRange = NSRange(location: selectedRange.location + 1, length: 0)
        applyMarkdownStyling()
        onContentChange?(text ?? "")
    }

    func outdentLine() {
        let nsText = (text ?? "") as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineText = nsText.substring(with: lineRange)
        if lineText.hasPrefix("\t") {
            textStorage.deleteCharacters(in: NSRange(location: lineRange.location, length: 1))
            selectedRange = NSRange(location: max(lineRange.location, selectedRange.location - 1), length: 0)
            applyMarkdownStyling()
            onContentChange?(text ?? "")
        }
    }
}

// MARK: - Formatting Toolbar

private class MarkdownToolbar: UIView {
    weak var textView: MarkdownTextView?

    init(textView: MarkdownTextView) {
        self.textView = textView
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        backgroundColor = UIColor.systemBackground
        setupButtons()
        addTopBorder()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func addTopBorder() {
        let border = UIView()
        border.backgroundColor = UIColor.separator
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)
        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: topAnchor),
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    private func setupButtons() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])

        // Heading toggle
        let headingBtn = makeButton(title: "Aa", action: #selector(headingTapped))
        headingBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(headingBtn)
        stack.addArrangedSubview(makeSeparator())

        // Bullet
        stack.addArrangedSubview(makeButton(systemName: "list.bullet", action: #selector(bulletTapped)))
        stack.addArrangedSubview(makeSeparator())

        // Indent / Outdent
        stack.addArrangedSubview(makeButton(systemName: "decrease.indent", action: #selector(outdentTapped)))
        stack.addArrangedSubview(makeButton(systemName: "increase.indent", action: #selector(indentTapped)))

        // Spacer + dismiss
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)
        stack.addArrangedSubview(makeButton(systemName: "keyboard.chevron.compact.down", action: #selector(dismissKeyboard)))
    }

    private func makeButton(systemName: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)), for: .normal)
        btn.tintColor = UIColor(Theme.textPrimary)
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.widthAnchor.constraint(equalToConstant: 38).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return btn
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.tintColor = UIColor(Theme.textPrimary)
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.widthAnchor.constraint(equalToConstant: 38).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return btn
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator
        v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        v.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return v
    }

    @objc private func headingTapped() { textView?.toggleHeading() }
    @objc private func bulletTapped() { textView?.toggleBullet() }
    @objc private func indentTapped() { textView?.indentLine() }
    @objc private func outdentTapped() { textView?.outdentLine() }
    @objc private func dismissKeyboard() { textView?.resignFirstResponder() }
}

// MARK: - UIViewRepresentable

struct MarkdownEditorRepresentable: UIViewRepresentable {
    @Binding var content: String
    var docId: String
    var title: String

    func makeUIView(context: Context) -> MarkdownTextView {
        let tv = MarkdownTextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        tv.alwaysBounceVertical = true
        tv.typingAttributes = tv.defaultAttributes

        let toolbar = MarkdownToolbar(textView: tv)
        tv.inputAccessoryView = toolbar

        tv.onContentChange = { [weak tv] newText in
            guard let tv = tv else { return }
            context.coordinator.contentChanged(newText, docId: docId, title: title)
        }

        // Load initial content
        tv.text = content
        tv.applyMarkdownStyling()
        return tv
    }

    func updateUIView(_ uiView: MarkdownTextView, context: Context) {
        // Only update if content changed externally (outline editor, AI, etc.)
        if context.coordinator.lastSyncedContent != content {
            let cursor = uiView.selectedRange
            uiView.text = content
            uiView.applyMarkdownStyling()
            // Restore cursor if still valid
            let maxPos = (uiView.text ?? "").count
            if cursor.location <= maxPos {
                uiView.selectedRange = cursor
            }
            context.coordinator.lastSyncedContent = content
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(binding: $content) }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var content: String
        var lastSyncedContent: String = ""

        init(binding: Binding<String>) {
            _content = binding
            lastSyncedContent = binding.wrappedValue
        }

        func contentChanged(_ newText: String, docId: String, title: String) {
            content = newText
            lastSyncedContent = newText
            // Direct save to DB — bypasses SwiftUI lifecycle entirely
            guard !docId.isEmpty, !newText.isEmpty else { return }
            try? Queries.saveMasterDoc(id: docId, content: newText, title: title)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let tv = textView as? MarkdownTextView else { return }
            tv.applyMarkdownStyling()
            tv.onContentChange?(tv.text ?? "")
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard let tv = textView as? MarkdownTextView else { return true }
            if text == "\n" {
                tv.handleReturn()
                return false
            }
            return true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let tv = textView as? MarkdownTextView else { return }
            tv.applyMarkdownStyling()
        }
    }
}

// MARK: - RTF → Markdown Migration

private enum RTFMigration {
    static func migrateIfNeeded(_ content: String) -> String {
        guard content.hasPrefix("{\\rtf") else { return content }
        guard let data = content.data(using: .utf8),
              let attrStr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else {
            return content
        }

        let fullText = attrStr.string
        let lines = fullText.components(separatedBy: "\n")
        var result: [String] = []
        var charPos = 0

        for line in lines {
            defer { charPos += line.count + 1 }
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                result.append("")
                continue
            }

            guard charPos < attrStr.length else {
                result.append(line)
                continue
            }

            let checkLen = min(max(line.count, 1), attrStr.length - charPos)
            guard checkLen > 0 else { result.append(line); continue }

            var fontSize: CGFloat = 0
            var isBold = false
            attrStr.enumerateAttribute(.font, in: NSRange(location: charPos, length: checkLen)) { val, _, _ in
                if let f = val as? UIFont {
                    fontSize = max(fontSize, f.pointSize)
                    if f.fontName.lowercased().contains("bold") || f.fontDescriptor.symbolicTraits.contains(.traitBold) {
                        isBold = true
                    }
                }
            }

            if fontSize >= 22 {
                let cleanText = trimmed.hasPrefix("## ") ? trimmed : "## \(trimmed)"
                result.append(cleanText)
            } else if fontSize >= 18 && isBold {
                let cleanText = trimmed.hasPrefix("### ") ? trimmed : "### \(trimmed)"
                result.append(cleanText)
            } else if trimmed.hasPrefix("•") || trimmed.hasPrefix("◦") || trimmed.hasPrefix("▪") {
                result.append(line)
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }
}

// MARK: - Inbox Tab Enum

private enum DocTab: String, CaseIterable {
    case inbox = "Inbox"
    case allItems = "All Items"
}

struct PlacementData: Identifiable {
    let id = UUID()
    let item: Item
    let heading: String
}

// MARK: - MasterDocEditorView

struct MasterDocEditorView: View {
    let doc: MasterDoc

    @State private var content: String = ""
    @State private var title: String = ""
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var isSynthesizing = false
    @State private var aiError: String? = nil
    @State private var docTags: [Tag] = []
    @State private var showTagPicker = false
    @State private var selectedTab: DocTab = .inbox
    @State private var inboxItems: [Item] = []
    @State private var allItems: [Item] = []
    @State private var categoryFilter: Category? = nil
    @State private var placementItem: PlacementData? = nil
    @State private var showOutline = false

    private var aiAvailable: Bool {
        if #available(iOS 26.0, *) { return AIService.isAvailable }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            tagRow

            if isEditingTitle {
                titleEditBar
            }

            itemsSection

            if isSynthesizing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Sorting items into doc...")
                        .font(.inter(12)).foregroundStyle(Theme.textMuted)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Theme.accent.opacity(0.06))
            }

            if let err = aiError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(Theme.warnColor)
                    Text(err).font(.inter(11)).foregroundStyle(Theme.warnColor)
                    Spacer()
                    Button("Dismiss") { aiError = nil }
                        .font(.inter(11, weight: .semibold)).foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Theme.warnColor.opacity(0.08))
            }

            MarkdownEditorRepresentable(content: $content, docId: doc.id, title: title)
        }
        .background(Theme.canvas)
        .navigationTitle(isEditingTitle ? "" : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 14) {
                    Button { showOutline = true } label: {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 13))
                    }
                    Button {
                        if isEditingTitle { commitTitleEdit() }
                        else { editedTitle = title; isEditingTitle = true }
                    } label: {
                        Image(systemName: isEditingTitle ? "checkmark" : "pencil")
                            .font(.system(size: 14))
                    }
                }
            }
        }
        .sheet(isPresented: $showTagPicker) {
            DocTagPickerView(docId: doc.id, currentTagIds: Set(docTags.map(\.id))) { reload() }
        }
        .sheet(item: $placementItem) { data in
            PlacementPreviewSheet(item: data.item, suggestedHeading: data.heading, content: content) { heading in
                Task {
                    var rewritten: String? = nil
                    if #available(iOS 26.0, *) {
                        rewritten = try? await AIService.rewriteBullet(data.item.text, forHeading: heading)
                    }
                    await MainActor.run {
                        insertItemUnderHeading(item: data.item, heading: heading, rewrittenText: rewritten)
                    }
                }
            }
        }
        .sheet(isPresented: $showOutline) {
            OutlineEditorView(content: $content, docId: doc.id, onSave: { save() }, onReload: { reload() })
        }
        .onAppear {
            if let fresh = try? Queries.getMasterDocById(id: doc.id), !fresh.content.isEmpty {
                let migrated = RTFMigration.migrateIfNeeded(fresh.content)
                content = migrated
                title = fresh.title
                // Persist migration if content changed
                if migrated != fresh.content {
                    try? Queries.saveMasterDoc(id: doc.id, content: migrated, title: fresh.title)
                }
            } else if content.isEmpty {
                content = RTFMigration.migrateIfNeeded(doc.content)
                title = doc.title
            }
            reload()
        }
    }

    // MARK: - Save

    private func save() {
        try? Queries.saveMasterDoc(id: doc.id, content: content, title: title)
    }

    // MARK: - Tag Row

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(docTags) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag.name)")
                            .font(.inter(12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Button {
                            try? Queries.removeTagFromDoc(docId: doc.id, tagId: tag.id)
                            reload()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.1), in: Capsule())
                }
                Button {
                    showTagPicker = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                        Text("tag").font(.inter(11))
                    }
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.cardAlt, in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.cardBg)
        .overlay(Rectangle().fill(Theme.border).frame(height: 0.5), alignment: .bottom)
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(DocTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.inter(12, weight: selectedTab == tab ? .semibold : .regular))
                            if tab == .inbox && !inboxItems.isEmpty {
                                Text("(\(inboxItems.count))")
                                    .font(.inter(10, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? Theme.accent : Theme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
                Spacer()
                if selectedTab == .inbox && !inboxItems.isEmpty && aiAvailable {
                    Button { sortTrash() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles").font(.system(size: 10))
                            Text("Sort Trash").font(.inter(11, weight: .semibold))
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent.opacity(0.08), in: Capsule())
                    }
                    .disabled(isSynthesizing)
                    .padding(.trailing, 12)
                }
            }
            .padding(.leading, 12)
            .background(Theme.cardBg)
            .overlay(Rectangle().fill(Theme.border).frame(height: 0.5), alignment: .bottom)

            if selectedTab == .inbox {
                inboxContent
            } else {
                allItemsContent
            }
        }
    }

    private var inboxContent: some View {
        Group {
            if inboxItems.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle").font(.system(size: 12)).foregroundStyle(Theme.successColor)
                    Text("Inbox empty — all items incorporated")
                        .font(.inter(12)).foregroundStyle(Theme.textMuted)
                }
                .padding(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(inboxItems.prefix(8)) { item in
                        HStack(spacing: 8) {
                            Button {
                                try? Queries.completeItem(id: item.id)
                                try? Queries.dismissItemFromDoc(id: item.id)
                                reload()
                            } label: {
                                Image(systemName: "circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.textMuted.opacity(0.4))
                            }
                            Image(systemName: item.category.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.categoryColor(item.category).opacity(0.6))
                                .frame(width: 14)
                            Text(item.text)
                                .font(.inter(13))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                try? Queries.dismissItemFromDoc(id: item.id)
                                reload()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.textMuted.opacity(0.4))
                            }
                            Button { addItemToDoc(item) } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        Divider().padding(.leading, 38)
                    }
                    if inboxItems.count > 8 {
                        Text("+\(inboxItems.count - 8) more")
                            .font(.inter(11))
                            .foregroundStyle(Theme.textMuted)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private var allItemsContent: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", selected: categoryFilter == nil) { categoryFilter = nil; reloadAllItems() }
                    filterChip("Actions", selected: categoryFilter == .action) { categoryFilter = .action; reloadAllItems() }
                    filterChip("Brainstorms", selected: categoryFilter == .brainstorm) { categoryFilter = .brainstorm; reloadAllItems() }
                    filterChip("Resources", selected: categoryFilter == .resource) { categoryFilter = .resource; reloadAllItems() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(allItems) { item in
                        HStack(spacing: 8) {
                            Button {
                                if item.done { try? Queries.uncompleteItem(id: item.id) }
                                else { try? Queries.completeItem(id: item.id) }
                                reloadAllItems()
                            } label: {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(item.done ? Theme.successColor : Theme.textMuted.opacity(0.4))
                            }
                            Image(systemName: item.category.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.categoryColor(item.category).opacity(item.done ? 0.3 : 0.6))
                                .frame(width: 14)
                            Text(item.text)
                                .font(.inter(13))
                                .foregroundStyle(item.done ? Theme.textMuted : Theme.textPrimary)
                                .strikethrough(item.done, color: Theme.textMuted)
                                .lineLimit(2)
                            Spacer()
                            if !item.done {
                                HStack(spacing: 4) {
                                    if item.incorporatedIntoDoc {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.successColor.opacity(0.5))
                                    }
                                    Button { addItemToDoc(item) } label: {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Theme.accent.opacity(0.6))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        Divider().padding(.leading, 38)
                    }
                }
            }
            .frame(maxHeight: 160)
        }
    }

    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.inter(11, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : Theme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? Theme.accent : Theme.cardAlt, in: Capsule())
        }
    }

    // MARK: - Title Edit

    private var titleEditBar: some View {
        HStack(spacing: 8) {
            TextField("Document title", text: $editedTitle)
                .font(.inter(16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .submitLabel(.done)
                .onSubmit { commitTitleEdit() }
            Button("Done") { commitTitleEdit() }
                .font(.inter(13, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.cardBg)
        .overlay(Rectangle().fill(Theme.border).frame(height: 0.5), alignment: .bottom)
    }

    private func commitTitleEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            title = trimmed
            save()
        }
        isEditingTitle = false
    }

    // MARK: - Add Item to Doc

    private func addItemToDoc(_ item: Item) {
        guard aiAvailable else {
            placementItem = PlacementData(item: item, heading: "General")
            return
        }

        Task {
            let headings = DocHeadingExtractor.extractHeadings(from: content)
            if headings.isEmpty {
                await MainActor.run { placementItem = PlacementData(item: item, heading: "General") }
                return
            }
            if #available(iOS 26.0, *) {
                do {
                    let suggested = try await AIService.suggestHeading(for: item.text, existingHeadings: headings)
                    await MainActor.run { placementItem = PlacementData(item: item, heading: suggested) }
                } catch {
                    await MainActor.run { placementItem = PlacementData(item: item, heading: headings.first ?? "General") }
                }
            }
        }
    }

    private func insertItemUnderHeading(item: Item, heading: String, rewrittenText: String? = nil, shouldReload: Bool = true) {
        let raw = rewrittenText ?? item.text
        let bulletText = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}"))
        let lines = content.components(separatedBy: "\n")

        // Find the heading line (case-insensitive match)
        let headingIndex = lines.firstIndex { line in
            let clean = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            return clean.lowercased() == heading.lowercased()
        }

        if let idx = headingIndex {
            // Find end of this section
            var insertAt = idx + 1
            while insertAt < lines.count && !lines[insertAt].hasPrefix("## ") && !lines[insertAt].hasPrefix("### ") {
                insertAt += 1
            }
            var mutableLines = lines
            mutableLines.insert("• \(bulletText)", at: insertAt)
            content = mutableLines.joined(separator: "\n")
        } else {
            // Heading doesn't exist — append new section
            let newSection = "\n\n## \(heading)\n• \(bulletText)"
            content += newSection
        }

        save()
        try? Queries.markItemIncorporated(id: item.id)
        if shouldReload { reload() }
    }

    // MARK: - Sort Trash

    private func sortTrash() {
        guard #available(iOS 26.0, *) else { return }
        isSynthesizing = true
        aiError = nil

        let itemsToSort = inboxItems
        let headings = DocHeadingExtractor.extractHeadings(from: content)

        Task {
            do {
                if !headings.isEmpty {
                    for item in itemsToSort {
                        let suggested = (try? await AIService.suggestHeading(for: item.text, existingHeadings: headings)) ?? headings[0]
                        await MainActor.run {
                            insertItemUnderHeading(item: item, heading: suggested, shouldReload: false)
                        }
                    }
                } else {
                    for item in itemsToSort {
                        await MainActor.run {
                            insertItemUnderHeading(item: item, heading: "General", shouldReload: false)
                        }
                    }
                }
                await MainActor.run {
                    isSynthesizing = false
                    reload()
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                    isSynthesizing = false
                }
            }
        }
    }

    // MARK: - Data Loading

    private func reload() {
        docTags = (try? Queries.getTagsForDoc(docId: doc.id)) ?? []
        inboxItems = (try? Queries.getUnincorporatedItemsForDoc(docId: doc.id)) ?? []
        reloadAllItems()
    }

    private func reloadAllItems() {
        allItems = (try? Queries.getAllItemsForDoc(docId: doc.id, category: categoryFilter)) ?? []
    }
}

// MARK: - Tag Picker

struct DocTagPickerView: View {
    let docId: String
    let currentTagIds: Set<String>
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allTags: [Tag] = []
    @State private var assignedTagIds: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(allTags) { tag in
                        let isCurrent = currentTagIds.contains(tag.id)
                        let isOtherDoc = assignedTagIds.contains(tag.id) && !isCurrent

                        Button {
                            guard !isOtherDoc else { return }
                            if isCurrent {
                                try? Queries.removeTagFromDoc(docId: docId, tagId: tag.id)
                            } else {
                                try? Queries.addTagToDoc(docId: docId, tagId: tag.id)
                            }
                            onDone()
                            dismiss()
                        } label: {
                            Text("#\(tag.name)")
                                .font(.inter(13, weight: isCurrent ? .semibold : .regular))
                                .foregroundStyle(isOtherDoc ? Theme.textMuted.opacity(0.4) : (isCurrent ? .white : Theme.accent))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    isCurrent ? Theme.accent : (isOtherDoc ? Theme.cardAlt : Theme.accent.opacity(0.08)),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .disabled(isOtherDoc)
                    }
                }
                .padding(20)
            }
            .background(Theme.canvas)
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                allTags = (try? Queries.getAllTags()) ?? []
                assignedTagIds = Set(allTags.compactMap { tag in
                    (try? Queries.isTagAssignedToDoc(tagId: tag.id)) == true ? tag.id : nil
                })
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Placement Preview

struct PlacementPreviewSheet: View {
    let item: Item
    let suggestedHeading: String
    let content: String
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedHeading: String = ""
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Item")
                        .font(.inter(11, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    Text(item.text)
                        .font(.inter(14))
                        .foregroundStyle(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Will be placed under")
                        .font(.inter(11, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    HStack {
                        Text("→ \(selectedHeading)")
                            .font(.inter(15, weight: .medium))
                            .foregroundStyle(Theme.successColor)
                        Spacer()
                        Button("Change") { showPicker = true }
                            .font(.inter(12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(Theme.canvas)
            .navigationTitle("Placement Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onConfirm(selectedHeading)
                        dismiss()
                    }
                    .font(.inter(14, weight: .semibold))
                }
            }
            .sheet(isPresented: $showPicker) {
                HeadingPickerView(content: content, selected: $selectedHeading)
            }
            .onAppear { selectedHeading = suggestedHeading }
        }
        .presentationDetents([.medium])
    }
}

struct HeadingPickerView: View {
    let content: String
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var newHeading = ""

    private var headings: [String] {
        DocHeadingExtractor.extractHeadings(from: content)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Existing Headings") {
                    ForEach(headings, id: \.self) { heading in
                        Button {
                            selected = heading
                            dismiss()
                        } label: {
                            HStack {
                                Text(heading).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if selected == heading {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                }
                Section("New Heading") {
                    HStack {
                        TextField("Type new heading", text: $newHeading)
                        Button("Use") {
                            guard !newHeading.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            selected = newHeading.trimmingCharacters(in: .whitespaces)
                            dismiss()
                        }
                        .disabled(newHeading.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Choose Heading")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Outline Editor

struct OutlineEditorView: View {
    @Binding var content: String
    let docId: String
    var onSave: () -> Void
    var onReload: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var headings: [OutlineHeading] = []
    @State private var newHeadingText = ""
    @State private var newIsSubheading = false
    @State private var deleteTarget: OutlineHeading? = nil
    @State private var showDeleteAlert = false

    struct OutlineHeading: Identifiable {
        let id = UUID()
        var text: String
        var level: Int
        var lineIndex: Int
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Add new heading
                HStack(spacing: 8) {
                    Toggle("Sub", isOn: $newIsSubheading)
                        .font(.inter(12))
                        .toggleStyle(.button)
                        .tint(Theme.accent)
                    TextField("New category name", text: $newHeadingText)
                        .font(.inter(14))
                        .submitLabel(.done)
                        .onSubmit { addHeading() }
                    Button { addHeading() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.accent)
                    }
                    .disabled(newHeadingText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(14)
                .background(Theme.cardBg)
                .overlay(Rectangle().fill(Theme.border).frame(height: 0.5), alignment: .bottom)

                // Headings list
                List {
                    ForEach(headings) { heading in
                        HStack(spacing: 8) {
                            if heading.level > 1 {
                                Rectangle()
                                    .fill(Theme.accent.opacity(0.3))
                                    .frame(width: 2, height: 20)
                                    .padding(.leading, CGFloat((heading.level - 1) * 16))
                            }
                            Text(heading.text)
                                .font(.inter(heading.level == 1 ? 15 : 13, weight: heading.level == 1 ? .semibold : .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Button {
                                deleteTarget = heading
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red.opacity(0.6))
                            }
                        }
                    }
                    .onMove { from, to in
                        moveHeading(from: from, to: to)
                    }
                }
                .listStyle(.plain)
            }
            .background(Theme.canvas)
            .navigationTitle("Outline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .alert("Delete Category", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { confirmDelete() }
                Button("Cancel", role: .cancel) { deleteTarget = nil }
            } message: {
                Text("Items filed under this category will return to inbox.")
            }
            .onAppear { parseHeadings() }
        }
    }

    private func parseHeadings() {
        let lines = content.components(separatedBy: "\n")
        headings = lines.enumerated().compactMap { index, line in
            if line.hasPrefix("### ") {
                return OutlineHeading(text: String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces), level: 2, lineIndex: index)
            } else if line.hasPrefix("## ") {
                return OutlineHeading(text: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces), level: 1, lineIndex: index)
            }
            return nil
        }
    }

    private func addHeading() {
        let text = newHeadingText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let prefix = newIsSubheading ? "### " : "## "
        let newLine = "\(prefix)\(text)"

        if content.isEmpty {
            content = newLine
        } else {
            content += "\n\n\(newLine)"
        }

        onSave()
        newHeadingText = ""
        parseHeadings()
    }

    private func confirmDelete() {
        guard let heading = deleteTarget else { return }
        var lines = content.components(separatedBy: "\n")
        guard heading.lineIndex < lines.count else { deleteTarget = nil; return }

        let startIdx = heading.lineIndex
        var endIdx = startIdx + 1

        while endIdx < lines.count && !lines[endIdx].hasPrefix("## ") && !lines[endIdx].hasPrefix("### ") {
            let trimmed = lines[endIdx].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("◦") || trimmed.hasPrefix("▪") {
                let bulletText = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                if let items = try? Queries.getAllItemsForDoc(docId: docId),
                   let item = items.first(where: { $0.text == bulletText && $0.incorporatedIntoDoc }) {
                    try? Queries.markItemUnincorporated(id: item.id)
                }
            }
            endIdx += 1
        }

        lines.removeSubrange(startIdx..<endIdx)
        // Clean up extra blank lines
        content = lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")

        onSave()
        onReload()
        parseHeadings()
        deleteTarget = nil
    }

    private func moveHeading(from source: IndexSet, to destination: Int) {
        var reordered = headings
        reordered.move(fromOffsets: source, toOffset: destination)

        let lines = content.components(separatedBy: "\n")

        // Parse sections: each section = heading line + content lines until next heading
        struct Section {
            let heading: String
            var content: [String]
        }

        var sections: [Section] = []
        var preamble: [String] = []
        var currentSection: Section? = nil

        for line in lines {
            if line.hasPrefix("## ") || line.hasPrefix("### ") {
                if let sec = currentSection { sections.append(sec) }
                else { /* preamble already collected */ }
                currentSection = Section(heading: line, content: [])
            } else {
                if currentSection != nil {
                    currentSection!.content.append(line)
                } else {
                    preamble.append(line)
                }
            }
        }
        if let sec = currentSection { sections.append(sec) }

        // Reorder to match new heading order
        var newSections: [Section] = []
        for heading in reordered {
            if let idx = sections.firstIndex(where: { sec in
                let clean = sec.heading
                    .replacingOccurrences(of: "### ", with: "")
                    .replacingOccurrences(of: "## ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return clean.lowercased() == heading.text.lowercased()
            }) {
                newSections.append(sections[idx])
                sections.remove(at: idx)
            }
        }
        newSections.append(contentsOf: sections)

        // Rebuild
        var result = preamble
        for section in newSections {
            result.append(section.heading)
            result.append(contentsOf: section.content)
        }
        content = result.joined(separator: "\n")

        onSave()
        parseHeadings()
    }
}
