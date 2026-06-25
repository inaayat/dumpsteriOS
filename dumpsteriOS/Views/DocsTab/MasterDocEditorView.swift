import SwiftUI
import UIKit

// MARK: - Font Helpers

private let defaultFontSize: CGFloat = 16
private let defaultFont = UIFont(name: "Inter-Regular", size: defaultFontSize) ?? .systemFont(ofSize: defaultFontSize)
private let boldFont = UIFont(name: "Inter-Bold", size: defaultFontSize) ?? .boldSystemFont(ofSize: defaultFontSize)

private extension UIFont {
    var isBold: Bool { fontName.lowercased().contains("bold") || fontDescriptor.symbolicTraits.contains(.traitBold) }
    var isItalic: Bool { fontDescriptor.symbolicTraits.contains(.traitItalic) }

    func toggledBold() -> UIFont {
        if isBold {
            return UIFont(name: "Inter-Regular", size: pointSize) ?? UIFont.systemFont(ofSize: pointSize)
        } else {
            return UIFont(name: "Inter-Bold", size: pointSize) ?? UIFont.boldSystemFont(ofSize: pointSize)
        }
    }

    func toggledItalic() -> UIFont {
        let newTraits: UIFontDescriptor.SymbolicTraits
        if isItalic {
            newTraits = fontDescriptor.symbolicTraits.subtracting(.traitItalic)
        } else {
            newTraits = fontDescriptor.symbolicTraits.union(.traitItalic)
        }
        if let desc = fontDescriptor.withSymbolicTraits(newTraits) {
            return UIFont(descriptor: desc, size: pointSize)
        }
        return self
    }
}

// MARK: - List Constants

private enum ListConstants {
    static let markers: [Character] = ["•", "◦", "▪"]
    static let perLevel: CGFloat = 28
    static let markerSpace: CGFloat = 18
}

// MARK: - NotesTextView

class NotesTextView: UITextView {
    var onContentChange: (() -> Void)?

    private var defaultTypingFont: UIFont { defaultFont }

    var defaultAttributes: [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        return [
            .font: defaultTypingFont,
            .foregroundColor: UIColor(Theme.textPrimary),
            .paragraphStyle: para
        ]
    }

    // MARK: Enter key handling

    func handleReturn() {
        guard let storage = textStorage as? NSTextStorage else { return }
        let cursorPos = selectedRange.location
        guard cursorPos > 0 else {
            insertText("\n")
            return
        }

        let nsText = storage.string as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: cursorPos, length: 0))
        let lineText = nsText.substring(with: lineRange)
        let trimmedLine = lineText.trimmingCharacters(in: .newlines)

        // Check if this line is a list item
        if let listInfo = parseListLine(trimmedLine) {
            let contentAfterMarker = listInfo.content.trimmingCharacters(in: .whitespaces)

            if contentAfterMarker.isEmpty {
                // Empty list item → outdent or exit list
                if listInfo.level > 0 {
                    // Outdent: replace current line marker with lower level
                    outdentCurrentLine(lineRange: lineRange, currentLevel: listInfo.level, listType: listInfo.type)
                } else {
                    // Exit list: remove the marker entirely
                    let markerRange = NSRange(location: lineRange.location, length: trimmedLine.count)
                    storage.replaceCharacters(in: markerRange, with: "")
                    let newCursor = lineRange.location
                    selectedRange = NSRange(location: newCursor, length: 0)
                    typingAttributes = defaultAttributes
                }
            } else {
                // Has content → continue list on new line
                let newMarker: String
                if listInfo.type == .numbered {
                    newMarker = "\(listInfo.number + 1). "
                } else {
                    let marker = ListConstants.markers[min(listInfo.level, ListConstants.markers.count - 1)]
                    newMarker = "\(marker) "
                }
                let indent = String(repeating: "\t", count: listInfo.level)
                let insertion = "\n\(indent)\(newMarker)"
                let insertAttrs = paragraphAttributes(level: listInfo.level)
                let attrInsertion = NSAttributedString(string: insertion, attributes: insertAttrs)
                storage.insert(attrInsertion, at: cursorPos)
                selectedRange = NSRange(location: cursorPos + insertion.count, length: 0)
                typingAttributes = insertAttrs
            }
        } else {
            // Not a list item, normal newline
            let attrNewline = NSAttributedString(string: "\n", attributes: typingAttributes)
            storage.insert(attrNewline, at: cursorPos)
            selectedRange = NSRange(location: cursorPos + 1, length: 0)
        }
        onContentChange?()
    }

    // MARK: Backspace handling

    func handleBackspaceAtListStart() -> Bool {
        let cursorPos = selectedRange.location
        guard cursorPos > 0, selectedRange.length == 0 else { return false }

        let nsText = (textStorage.string as NSString)
        let lineRange = nsText.lineRange(for: NSRange(location: cursorPos, length: 0))
        let lineStart = lineRange.location

        // Only handle if cursor is right after the marker
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
        guard let listInfo = parseListLine(lineText) else { return false }

        let markerEnd = lineStart + listInfo.markerLength
        guard cursorPos <= markerEnd else { return false }

        if listInfo.level > 0 {
            outdentCurrentLine(lineRange: lineRange, currentLevel: listInfo.level, listType: listInfo.type)
            onContentChange?()
            return true
        } else {
            // Remove list formatting at level 0
            let removeRange = NSRange(location: lineStart, length: listInfo.markerLength)
            textStorage.replaceCharacters(in: removeRange, with: "")
            let paraRange = (textStorage.string as NSString).lineRange(for: NSRange(location: lineStart, length: 0))
            textStorage.addAttributes(defaultAttributes, range: paraRange)
            selectedRange = NSRange(location: lineStart, length: 0)
            typingAttributes = defaultAttributes
            onContentChange?()
            return true
        }
    }

    // MARK: List Helpers

    struct ListInfo {
        enum ListType { case bullet, numbered }
        let type: ListType
        let level: Int
        let number: Int
        let content: String
        let markerLength: Int
    }

    func parseListLine(_ line: String) -> ListInfo? {
        var remaining = line[line.startIndex...]
        var level = 0

        // Count leading tabs for indent level
        while remaining.hasPrefix("\t") {
            level += 1
            remaining = remaining.dropFirst()
        }
        // Also count 4-space groups
        while remaining.hasPrefix("    ") {
            level += 1
            remaining = remaining.dropFirst(4)
        }

        let afterIndent = String(remaining)

        // Check bullet markers
        for marker in ListConstants.markers {
            if afterIndent.hasPrefix("\(marker) ") {
                let markerLen = line.count - afterIndent.count + 2 // tabs + marker + space
                let content = String(afterIndent.dropFirst(2))
                return ListInfo(type: .bullet, level: level, number: 0, content: content, markerLength: markerLen)
            }
            if afterIndent == String(marker) {
                let markerLen = line.count - afterIndent.count + 1
                return ListInfo(type: .bullet, level: level, number: 0, content: "", markerLength: markerLen)
            }
        }

        // Check "- " style bullets
        if afterIndent.hasPrefix("- ") {
            let markerLen = line.count - afterIndent.count + 2
            let content = String(afterIndent.dropFirst(2))
            return ListInfo(type: .bullet, level: level, number: 0, content: content, markerLength: markerLen)
        }

        // Check numbered "N. "
        if let match = afterIndent.range(of: #"^(\d+)\. "#, options: .regularExpression) {
            let numStr = afterIndent[match].dropLast(2) // drop ". "
            let num = Int(numStr) ?? 1
            let markerLen = line.count - afterIndent.count + afterIndent.distance(from: afterIndent.startIndex, to: match.upperBound)
            let content = String(afterIndent[match.upperBound...])
            return ListInfo(type: .numbered, level: level, number: num, content: content, markerLength: markerLen)
        }

        return nil
    }

    private func outdentCurrentLine(lineRange: NSRange, currentLevel: Int, listType: ListInfo.ListType) {
        let newLevel = currentLevel - 1
        let nsText = textStorage.string as NSString
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        // Build new line with reduced indent
        let newMarker: String
        if listType == .numbered {
            newMarker = "1. "
        } else {
            let marker = ListConstants.markers[min(newLevel, ListConstants.markers.count - 1)]
            newMarker = "\(marker) "
        }
        let indent = String(repeating: "\t", count: newLevel)
        let oldContent = parseListLine(lineText)?.content ?? ""
        let newLine = "\(indent)\(newMarker)\(oldContent)"

        let replaceRange = NSRange(location: lineRange.location, length: lineText.count)
        let attrs = paragraphAttributes(level: newLevel)
        let attrStr = NSAttributedString(string: newLine, attributes: attrs)
        textStorage.replaceCharacters(in: replaceRange, with: attrStr)

        let newCursorPos = lineRange.location + newLine.count
        selectedRange = NSRange(location: newCursorPos, length: 0)
        typingAttributes = attrs
    }

    func paragraphAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        let baseIndent = CGFloat(level) * ListConstants.perLevel
        para.firstLineHeadIndent = baseIndent
        para.headIndent = baseIndent + ListConstants.markerSpace
        para.lineSpacing = 4
        para.paragraphSpacing = 2
        return [
            .font: defaultFont,
            .foregroundColor: UIColor(Theme.textPrimary),
            .paragraphStyle: para
        ]
    }

    // MARK: Formatting Actions

    func toggleBold() {
        if selectedRange.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                guard let font = value as? UIFont else { return }
                textStorage.addAttribute(.font, value: font.toggledBold(), range: range)
            }
            textStorage.endEditing()
        } else {
            let font = (typingAttributes[.font] as? UIFont) ?? defaultFont
            typingAttributes[.font] = font.toggledBold()
        }
        onContentChange?()
    }

    func toggleItalic() {
        if selectedRange.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                guard let font = value as? UIFont else { return }
                textStorage.addAttribute(.font, value: font.toggledItalic(), range: range)
            }
            textStorage.endEditing()
        } else {
            let font = (typingAttributes[.font] as? UIFont) ?? defaultFont
            typingAttributes[.font] = font.toggledItalic()
        }
        onContentChange?()
    }

    func toggleUnderline() {
        if selectedRange.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.underlineStyle, in: selectedRange) { value, range, _ in
                let current = (value as? Int) ?? 0
                let newVal: Int = current > 0 ? 0 : NSUnderlineStyle.single.rawValue
                textStorage.addAttribute(.underlineStyle, value: newVal, range: range)
            }
            textStorage.endEditing()
        } else {
            let current = (typingAttributes[.underlineStyle] as? Int) ?? 0
            typingAttributes[.underlineStyle] = current > 0 ? 0 : NSUnderlineStyle.single.rawValue
        }
        onContentChange?()
    }

    func toggleStrikethrough() {
        if selectedRange.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.strikethroughStyle, in: selectedRange) { value, range, _ in
                let current = (value as? Int) ?? 0
                let newVal: Int = current > 0 ? 0 : NSUnderlineStyle.single.rawValue
                textStorage.addAttribute(.strikethroughStyle, value: newVal, range: range)
            }
            textStorage.endEditing()
        } else {
            let current = (typingAttributes[.strikethroughStyle] as? Int) ?? 0
            typingAttributes[.strikethroughStyle] = current > 0 ? 0 : NSUnderlineStyle.single.rawValue
        }
        onContentChange?()
    }

    func setHeading(_ style: HeadingStyle) {
        let nsText = textStorage.string as NSString
        let lineRange = nsText.lineRange(for: selectedRange)
        let font: UIFont
        switch style {
        case .title:
            font = UIFont(name: "Inter-Bold", size: 26) ?? .boldSystemFont(ofSize: 26)
        case .heading:
            font = UIFont(name: "Inter-Bold", size: 22) ?? .boldSystemFont(ofSize: 22)
        case .subheading:
            font = UIFont(name: "Inter-SemiBold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        case .body:
            font = defaultFont
        }
        textStorage.addAttribute(.font, value: font, range: lineRange)
        onContentChange?()
    }

    enum HeadingStyle { case title, heading, subheading, body }

    func insertBulletList() {
        let nsText = textStorage.string as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        if let info = parseListLine(lineText), info.type == .bullet {
            // Already a bullet → remove it
            let removeRange = NSRange(location: lineRange.location, length: info.markerLength)
            textStorage.replaceCharacters(in: removeRange, with: "")
            let newLineRange = (textStorage.string as NSString).lineRange(for: NSRange(location: lineRange.location, length: 0))
            textStorage.addAttributes(defaultAttributes, range: newLineRange)
            selectedRange = NSRange(location: lineRange.location, length: 0)
            typingAttributes = defaultAttributes
        } else if let info = parseListLine(lineText), info.type == .numbered {
            // Was numbered → convert to bullet
            let marker = ListConstants.markers[min(info.level, ListConstants.markers.count - 1)]
            let indent = String(repeating: "\t", count: info.level)
            let newLine = "\(indent)\(marker) \(info.content)"
            let replaceRange = NSRange(location: lineRange.location, length: lineText.count)
            let attrs = paragraphAttributes(level: info.level)
            textStorage.replaceCharacters(in: replaceRange, with: NSAttributedString(string: newLine, attributes: attrs))
            selectedRange = NSRange(location: lineRange.location + newLine.count, length: 0)
            typingAttributes = attrs
        } else {
            // Not a list → make it a bullet
            let marker = "\(ListConstants.markers[0]) "
            let attrs = paragraphAttributes(level: 0)
            let insertion = NSAttributedString(string: marker, attributes: attrs)
            textStorage.insert(insertion, at: lineRange.location)
            let newPos = lineRange.location + marker.count + lineText.count
            selectedRange = NSRange(location: newPos, length: 0)
            // Apply paragraph style to whole line
            let newLineRange = (textStorage.string as NSString).lineRange(for: NSRange(location: lineRange.location, length: 0))
            textStorage.addAttributes(attrs, range: newLineRange)
            typingAttributes = attrs
        }
        onContentChange?()
    }

    func insertNumberedList() {
        let nsText = textStorage.string as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        if let info = parseListLine(lineText), info.type == .numbered {
            // Already numbered → remove
            let removeRange = NSRange(location: lineRange.location, length: info.markerLength)
            textStorage.replaceCharacters(in: removeRange, with: "")
            let newLineRange = (textStorage.string as NSString).lineRange(for: NSRange(location: lineRange.location, length: 0))
            textStorage.addAttributes(defaultAttributes, range: newLineRange)
            selectedRange = NSRange(location: lineRange.location, length: 0)
            typingAttributes = defaultAttributes
        } else if let info = parseListLine(lineText), info.type == .bullet {
            // Was bullet → convert to numbered
            let indent = String(repeating: "\t", count: info.level)
            let newLine = "\(indent)1. \(info.content)"
            let replaceRange = NSRange(location: lineRange.location, length: lineText.count)
            let attrs = paragraphAttributes(level: info.level)
            textStorage.replaceCharacters(in: replaceRange, with: NSAttributedString(string: newLine, attributes: attrs))
            selectedRange = NSRange(location: lineRange.location + newLine.count, length: 0)
            typingAttributes = attrs
        } else {
            // Not a list → make it numbered
            let marker = "1. "
            let attrs = paragraphAttributes(level: 0)
            let insertion = NSAttributedString(string: marker, attributes: attrs)
            textStorage.insert(insertion, at: lineRange.location)
            let newPos = lineRange.location + marker.count + lineText.count
            selectedRange = NSRange(location: newPos, length: 0)
            let newLineRange = (textStorage.string as NSString).lineRange(for: NSRange(location: lineRange.location, length: 0))
            textStorage.addAttributes(attrs, range: newLineRange)
            typingAttributes = attrs
        }
        onContentChange?()
    }

    func indentLine() {
        let nsText = textStorage.string as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        if let info = parseListLine(lineText) {
            let newLevel = min(info.level + 1, ListConstants.markers.count - 1)
            let newMarker: String
            if info.type == .numbered {
                newMarker = "1. "
            } else {
                let marker = ListConstants.markers[min(newLevel, ListConstants.markers.count - 1)]
                newMarker = "\(marker) "
            }
            let indent = String(repeating: "\t", count: newLevel)
            let newLine = "\(indent)\(newMarker)\(info.content)"
            let replaceRange = NSRange(location: lineRange.location, length: lineText.count)
            let attrs = paragraphAttributes(level: newLevel)
            textStorage.replaceCharacters(in: replaceRange, with: NSAttributedString(string: newLine, attributes: attrs))
            selectedRange = NSRange(location: lineRange.location + newLine.count, length: 0)
            typingAttributes = attrs
        } else {
            // Not a list — just insert a tab
            let insertion = NSAttributedString(string: "\t", attributes: typingAttributes)
            textStorage.insert(insertion, at: selectedRange.location)
            selectedRange = NSRange(location: selectedRange.location + 1, length: 0)
        }
        onContentChange?()
    }

    func outdentLine() {
        let nsText = textStorage.string as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

        guard let info = parseListLine(lineText) else { return }

        if info.level > 0 {
            outdentCurrentLine(lineRange: lineRange, currentLevel: info.level, listType: info.type)
        } else {
            // At level 0 → remove list formatting
            let removeRange = NSRange(location: lineRange.location, length: info.markerLength)
            textStorage.replaceCharacters(in: removeRange, with: "")
            let newLineRange = (textStorage.string as NSString).lineRange(for: NSRange(location: lineRange.location, length: 0))
            textStorage.addAttributes(defaultAttributes, range: newLineRange)
            selectedRange = NSRange(location: lineRange.location, length: 0)
            typingAttributes = defaultAttributes
        }
        onContentChange?()
    }
}

// MARK: - Formatting Toolbar (UIKit InputAccessoryView)

private class FormattingAccessoryView: UIView {
    weak var textView: NotesTextView?

    init(textView: NotesTextView) {
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
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -8),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        // Heading menu
        let headingBtn = makeMenuButton()
        stack.addArrangedSubview(headingBtn)
        stack.addArrangedSubview(makeSeparator())

        // Bold, Italic, Underline, Strikethrough
        stack.addArrangedSubview(makeButton(systemName: "bold", action: #selector(boldTapped)))
        stack.addArrangedSubview(makeButton(systemName: "italic", action: #selector(italicTapped)))
        stack.addArrangedSubview(makeButton(systemName: "underline", action: #selector(underlineTapped)))
        stack.addArrangedSubview(makeButton(systemName: "strikethrough", action: #selector(strikethroughTapped)))
        stack.addArrangedSubview(makeSeparator())

        // Lists
        stack.addArrangedSubview(makeButton(systemName: "list.bullet", action: #selector(bulletTapped)))
        stack.addArrangedSubview(makeButton(systemName: "list.number", action: #selector(numberedTapped)))
        stack.addArrangedSubview(makeSeparator())

        // Indent / Outdent
        stack.addArrangedSubview(makeButton(systemName: "decrease.indent", action: #selector(outdentTapped)))
        stack.addArrangedSubview(makeButton(systemName: "increase.indent", action: #selector(indentTapped)))
        stack.addArrangedSubview(makeSeparator())

        // Dismiss keyboard
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
        btn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return btn
    }

    private func makeMenuButton() -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle("Aa", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.tintColor = UIColor(Theme.textPrimary)
        btn.showsMenuAsPrimaryAction = true
        btn.menu = UIMenu(children: [
            UIAction(title: "Title", handler: { [weak self] _ in self?.textView?.setHeading(.title) }),
            UIAction(title: "Heading", handler: { [weak self] _ in self?.textView?.setHeading(.heading) }),
            UIAction(title: "Subheading", handler: { [weak self] _ in self?.textView?.setHeading(.subheading) }),
            UIAction(title: "Body", handler: { [weak self] _ in self?.textView?.setHeading(.body) }),
        ])
        btn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return btn
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator
        v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        v.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return v
    }

    @objc private func boldTapped() { textView?.toggleBold() }
    @objc private func italicTapped() { textView?.toggleItalic() }
    @objc private func underlineTapped() { textView?.toggleUnderline() }
    @objc private func strikethroughTapped() { textView?.toggleStrikethrough() }
    @objc private func bulletTapped() { textView?.insertBulletList() }
    @objc private func numberedTapped() { textView?.insertNumberedList() }
    @objc private func indentTapped() { textView?.indentLine() }
    @objc private func outdentTapped() { textView?.outdentLine() }
    @objc private func dismissKeyboard() { textView?.resignFirstResponder() }
}

// MARK: - UIViewRepresentable

struct NotesEditorRepresentable: UIViewRepresentable {
    @Binding var rtfContent: String
    var onTextViewReady: ((NotesTextView) -> Void)?

    func makeUIView(context: Context) -> NotesTextView {
        let tv = NotesTextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        tv.alwaysBounceVertical = true

        let toolbar = FormattingAccessoryView(textView: tv)
        tv.inputAccessoryView = toolbar

        tv.onContentChange = { [weak tv] in
            guard let tv = tv else { return }
            context.coordinator.syncToBinding(tv)
        }

        // Load content
        loadContent(into: tv)
        DispatchQueue.main.async { onTextViewReady?(tv) }
        return tv
    }

    func updateUIView(_ uiView: NotesTextView, context: Context) {
        // Only reload if binding changed externally (not from our own edits)
        if context.coordinator.lastSavedContent != rtfContent {
            loadContent(into: uiView)
            context.coordinator.lastSavedContent = rtfContent
        }
    }

    private func loadContent(into tv: NotesTextView) {
        if rtfContent.hasPrefix("{\\rtf") {
            if let data = rtfContent.data(using: .utf8),
               let attrStr = try? NSMutableAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                fixFonts(in: attrStr)
                tv.attributedText = attrStr
            } else {
                tv.attributedText = NSAttributedString(string: rtfContent, attributes: tv.defaultAttributes)
            }
        } else {
            tv.attributedText = NSAttributedString(string: rtfContent, attributes: tv.defaultAttributes)
        }
    }

    private func fixFonts(in attrStr: NSMutableAttributedString) {
        attrStr.enumerateAttribute(.font, in: NSRange(location: 0, length: attrStr.length)) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let size = font.pointSize
            let traits = font.fontDescriptor.symbolicTraits
            let name: String
            if traits.contains(.traitBold) || font.fontName.lowercased().contains("bold") {
                name = "Inter-Bold"
            } else if font.fontName.lowercased().contains("semibold") {
                name = "Inter-SemiBold"
            } else if font.fontName.lowercased().contains("medium") {
                name = "Inter-Medium"
            } else {
                name = "Inter-Regular"
            }
            var interFont = UIFont(name: name, size: size) ?? font
            if traits.contains(.traitItalic) {
                if let desc = interFont.fontDescriptor.withSymbolicTraits(interFont.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                    interFont = UIFont(descriptor: desc, size: size)
                }
            }
            attrStr.addAttribute(.font, value: interFont, range: range)
        }
        attrStr.addAttribute(.foregroundColor, value: UIColor(Theme.textPrimary), range: NSRange(location: 0, length: attrStr.length))
    }

    func makeCoordinator() -> Coordinator { Coordinator(binding: $rtfContent) }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var rtfContent: String
        var lastSavedContent: String = ""

        init(binding: Binding<String>) {
            _rtfContent = binding
            lastSavedContent = binding.wrappedValue
        }

        func syncToBinding(_ tv: NotesTextView) {
            guard let attrText = tv.attributedText, attrText.length > 0 else {
                let empty = ""
                rtfContent = empty
                lastSavedContent = empty
                return
            }
            if let rtfData = try? attrText.data(from: NSRange(location: 0, length: attrText.length),
                                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]),
               let rtfString = String(data: rtfData, encoding: .utf8) {
                rtfContent = rtfString
                lastSavedContent = rtfString
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let tv = textView as? NotesTextView else { return }
            syncToBinding(tv)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard let tv = textView as? NotesTextView else { return true }

            if text == "\n" {
                tv.handleReturn()
                return false
            }

            if text.isEmpty && range.length == 1 {
                // Backspace
                if tv.handleBackspaceAtListStart() {
                    return false
                }
            }

            return true
        }
    }
}

// MARK: - Synthesize Preview (SwiftUI rendered)

private struct SynthesizePreviewText: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(markdown.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                previewLine(line)
            }
        }
    }

    @ViewBuilder
    private func previewLine(_ line: String) -> some View {
        if line.hasPrefix("### ") {
            Text(String(line.dropFirst(4)))
                .font(.inter(14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 6)
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3)))
                .font(.inter(16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)
        } else if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2)))
                .font(.inter(18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 10)
        } else if line.trimmingCharacters(in: .whitespaces) == "---" {
            Divider().padding(.vertical, 4)
        } else if line.hasPrefix("• ") || line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 4) {
                Text("•").font(.inter(12)).foregroundStyle(Theme.textMuted)
                inlinePreview(String(line.dropFirst(2)))
            }
            .padding(.leading, 4)
        } else if line.hasPrefix("→ ") {
            HStack(alignment: .top, spacing: 4) {
                Text("→").font(.inter(12)).foregroundStyle(Theme.successColor)
                inlinePreview(String(line.dropFirst(2)))
            }
            .padding(.leading, 4)
        } else if line.isEmpty {
            Spacer().frame(height: 4)
        } else {
            inlinePreview(line)
        }
    }

    @ViewBuilder
    private func inlinePreview(_ text: String) -> some View {
        if let attr = try? AttributedString(markdown: text) {
            Text(attr).font(.inter(12)).foregroundStyle(Theme.textPrimary)
        } else {
            Text(text).font(.inter(12)).foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: - Markdown → RTF Converter

private enum MarkdownToRTF {
    static func convert(_ markdown: String) -> String {
        let attrStr = attributedString(from: markdown)
        guard let data = try? attrStr.data(from: NSRange(location: 0, length: attrStr.length),
                                            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]),
              let rtf = String(data: data, encoding: .utf8) else {
            return markdown
        }
        return rtf
    }

    static func attributedString(from markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let attrLine = parseLine(line)
            result.append(attrLine)
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        return result
    }

    private static func parseLine(_ line: String) -> NSAttributedString {
        let textColor = UIColor(Theme.textPrimary)

        // Headings
        if line.hasPrefix("### ") {
            let text = String(line.dropFirst(4))
            let font = UIFont(name: "Inter-SemiBold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
        }
        if line.hasPrefix("## ") {
            let text = String(line.dropFirst(3))
            let font = UIFont(name: "Inter-Bold", size: 22) ?? .boldSystemFont(ofSize: 22)
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
        }
        if line.hasPrefix("# ") {
            let text = String(line.dropFirst(2))
            let font = UIFont(name: "Inter-Bold", size: 26) ?? .boldSystemFont(ofSize: 26)
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: textColor])
        }

        // Horizontal rule
        if line.trimmingCharacters(in: .whitespaces) == "---" {
            let font = UIFont(name: "Inter-Regular", size: 16) ?? .systemFont(ofSize: 16)
            return NSAttributedString(string: "───────────────────────", attributes: [
                .font: font, .foregroundColor: UIColor.separator
            ])
        }

        // Detect indent level
        var stripped = line[line.startIndex...]
        var level = 0
        while stripped.hasPrefix("\t") { level += 1; stripped = stripped.dropFirst() }
        while stripped.hasPrefix("    ") { level += 1; stripped = stripped.dropFirst(4) }
        let afterIndent = String(stripped)

        // Bullet list
        if afterIndent.hasPrefix("• ") || afterIndent.hasPrefix("- ") || afterIndent.hasPrefix("* ") {
            let content = String(afterIndent.dropFirst(2))
            let marker = ["•", "◦", "▪"][min(level, 2)]
            return buildListLine(marker: "\(marker) ", content: content, level: level, textColor: textColor)
        }

        // Numbered list
        if let match = afterIndent.range(of: #"^(\d+)\. "#, options: .regularExpression) {
            let marker = String(afterIndent[match])
            let content = String(afterIndent[match.upperBound...])
            return buildListLine(marker: marker, content: content, level: level, textColor: textColor)
        }

        // Regular paragraph with inline formatting
        return buildInlineFormatted(afterIndent, level: level, textColor: textColor)
    }

    private static func buildListLine(marker: String, content: String, level: Int, textColor: UIColor) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        let baseIndent = CGFloat(level) * ListConstants.perLevel
        para.firstLineHeadIndent = baseIndent
        para.headIndent = baseIndent + ListConstants.markerSpace
        para.lineSpacing = 4
        para.paragraphSpacing = 2

        let bodyFont = UIFont(name: "Inter-Regular", size: 16) ?? .systemFont(ofSize: 16)
        let result = NSMutableAttributedString()

        let markerAttr = NSAttributedString(string: marker, attributes: [
            .font: bodyFont, .foregroundColor: textColor, .paragraphStyle: para
        ])
        result.append(markerAttr)

        let contentAttr = inlineFormatted(content, font: bodyFont, textColor: textColor)
        result.append(contentAttr)

        // Apply paragraph style to entire line
        result.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: result.length))
        return result
    }

    private static func buildInlineFormatted(_ text: String, level: Int, textColor: UIColor) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        if level > 0 {
            para.firstLineHeadIndent = CGFloat(level) * ListConstants.perLevel
            para.headIndent = CGFloat(level) * ListConstants.perLevel
        }

        let bodyFont = UIFont(name: "Inter-Regular", size: 16) ?? .systemFont(ofSize: 16)
        let result = inlineFormatted(text, font: bodyFont, textColor: textColor)
        let mutable = NSMutableAttributedString(attributedString: result)
        mutable.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: mutable.length))
        return mutable
    }

    private static func inlineFormatted(_ text: String, font: UIFont, textColor: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Bold: **text**
            if remaining.hasPrefix("**") {
                let afterOpen = remaining.dropFirst(2)
                if let closeRange = afterOpen.range(of: "**") {
                    let boldText = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    let boldFont = UIFont(name: "Inter-Bold", size: font.pointSize) ?? font
                    result.append(NSAttributedString(string: boldText, attributes: [.font: boldFont, .foregroundColor: textColor]))
                    remaining = afterOpen[closeRange.upperBound...]
                    continue
                }
            }

            // Italic: *text*
            if remaining.hasPrefix("*") && !remaining.hasPrefix("**") {
                let afterOpen = remaining.dropFirst(1)
                if let closeIdx = afterOpen.firstIndex(of: "*") {
                    let italicText = String(afterOpen[afterOpen.startIndex..<closeIdx])
                    var italicFont = font
                    if let desc = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                        italicFont = UIFont(descriptor: desc, size: font.pointSize)
                    }
                    result.append(NSAttributedString(string: italicText, attributes: [.font: italicFont, .foregroundColor: textColor]))
                    remaining = afterOpen[afterOpen.index(after: closeIdx)...]
                    continue
                }
            }

            // Inline code: `text`
            if remaining.hasPrefix("`") {
                let afterOpen = remaining.dropFirst(1)
                if let closeIdx = afterOpen.firstIndex(of: "`") {
                    let codeText = String(afterOpen[afterOpen.startIndex..<closeIdx])
                    let codeFont = UIFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
                    result.append(NSAttributedString(string: codeText, attributes: [
                        .font: codeFont, .foregroundColor: textColor,
                        .backgroundColor: UIColor.systemGray6
                    ]))
                    remaining = afterOpen[afterOpen.index(after: closeIdx)...]
                    continue
                }
            }

            // Regular character
            let char = remaining[remaining.startIndex]
            result.append(NSAttributedString(string: String(char), attributes: [.font: font, .foregroundColor: textColor]))
            remaining = remaining.dropFirst()
        }

        return result
    }
}

// MARK: - MasterDocEditorView

// MARK: - Inbox Tab Enum

private enum DocTab: String, CaseIterable {
    case inbox = "Inbox"
    case allItems = "All Items"
}

struct MasterDocEditorView: View {
    let doc: MasterDoc

    @State private var content: String = ""
    @State private var title: String = ""
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var textViewRef: NotesTextView? = nil
    @State private var isSynthesizing = false
    @State private var aiError: String? = nil
    @State private var docTags: [Tag] = []
    @State private var showTagPicker = false
    @State private var selectedTab: DocTab = .inbox
    @State private var inboxItems: [Item] = []
    @State private var allItems: [Item] = []
    @State private var categoryFilter: Category? = nil
    @State private var placementItem: Item? = nil
    @State private var placementHeading: String? = nil
    @State private var showPlacementPreview = false

    private var aiAvailable: Bool {
        if #available(iOS 26.0, *) { return AIService.isAvailable }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tag row
            tagRow

            if isEditingTitle {
                titleEditBar
            }

            // Inbox / All Items tabs
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

            NotesEditorRepresentable(rtfContent: $content, onTextViewReady: { tv in
                textViewRef = tv
            })
            .onChange(of: content) { _, newValue in
                try? Queries.upsertMasterDoc(tagId: doc.tagId, content: newValue, title: title)
            }
        }
        .background(Theme.canvas)
        .navigationTitle(isEditingTitle ? "" : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 14) {
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
        .sheet(isPresented: $showPlacementPreview) {
            if let item = placementItem {
                PlacementPreviewSheet(item: item, suggestedHeading: placementHeading ?? "Uncategorized", content: content) { heading in
                    insertItemUnderHeading(item: item, heading: heading)
                }
            }
        }
        .onAppear {
            content = doc.content
            title = doc.title
            reload()
        }
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

    // MARK: - Items Section (Inbox / All Items)

    private var itemsSection: some View {
        VStack(spacing: 0) {
            // Tab picker
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

            // Content
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
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(inboxItems) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.category.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.categoryColor(item.category).opacity(0.6))
                                    .frame(width: 16)
                                Text(item.text)
                                    .font(.inter(13))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(2)
                                Spacer()
                                Button { addItemToDoc(item) } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Theme.accent)
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
    }

    private var allItemsContent: some View {
        VStack(spacing: 0) {
            // Filter chips
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
                            Image(systemName: item.category.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.categoryColor(item.category).opacity(0.6))
                                .frame(width: 16)
                            Text(item.text)
                                .font(.inter(13))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2)
                            Spacer()
                            if item.incorporatedIntoDoc {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.successColor.opacity(0.5))
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
            try? Queries.upsertMasterDoc(tagId: doc.tagId, content: content, title: title)
        }
        isEditingTitle = false
    }

    // MARK: - Add Item to Doc

    private func addItemToDoc(_ item: Item) {
        guard aiAvailable else {
            insertItemUnderHeading(item: item, heading: "General")
            return
        }
        placementItem = item
        placementHeading = nil

        Task {
            if #available(iOS 26.0, *) {
                let headings = content.components(separatedBy: "\n")
                    .filter { $0.hasPrefix("##") || $0.hasPrefix("# ") }
                    .map { $0.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces) }

                if headings.isEmpty {
                    await MainActor.run {
                        placementHeading = "General"
                        showPlacementPreview = true
                    }
                    return
                }

                do {
                    let session = LanguageModelSession(instructions: "You categorize a note under an existing heading. Respond with ONLY the heading name, nothing else.")
                    let prompt = "HEADINGS:\n\(headings.joined(separator: "\n"))\n\nNOTE: \(item.text)\n\nWhich heading does this belong under? Respond with just the heading name, or 'NEW: [name]' if none fit."
                    let response = try await session.respond(to: prompt)
                    let suggested = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    await MainActor.run {
                        placementHeading = suggested.hasPrefix("NEW: ") ? String(suggested.dropFirst(5)) : suggested
                        showPlacementPreview = true
                    }
                } catch {
                    await MainActor.run {
                        placementHeading = "General"
                        showPlacementPreview = true
                    }
                }
            }
        }
    }

    private func insertItemUnderHeading(item: Item, heading: String) {
        let lines = content.components(separatedBy: "\n")
        let headingIndex = lines.firstIndex { line in
            let clean = line.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            return clean.lowercased() == heading.lowercased()
        }

        if let idx = headingIndex {
            var insertAt = idx + 1
            while insertAt < lines.count && !lines[insertAt].hasPrefix("#") {
                insertAt += 1
            }
            var mutableLines = lines
            mutableLines.insert("• \(item.text)", at: insertAt)
            content = mutableLines.joined(separator: "\n")
        } else {
            content += content.isEmpty ? "## \(heading)\n• \(item.text)" : "\n\n## \(heading)\n• \(item.text)"
        }

        try? Queries.markItemIncorporated(id: item.id)
        reload()
    }

    // MARK: - Sort Trash (Batch)

    private func sortTrash() {
        guard #available(iOS 26.0, *) else { return }
        isSynthesizing = true
        aiError = nil

        Task {
            do {
                let bulletTexts = inboxItems.map(\.text)
                let result = try await AIService.insertBulletsIntoDoc(existingContent: content, bullets: bulletTexts)
                await MainActor.run {
                    content = result
                    for item in inboxItems {
                        try? Queries.markItemIncorporated(id: item.id)
                    }
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

// MARK: - Tag Picker for Docs

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
        content.components(separatedBy: "\n")
            .filter { $0.hasPrefix("##") || $0.hasPrefix("# ") }
            .map { $0.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces) }
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
