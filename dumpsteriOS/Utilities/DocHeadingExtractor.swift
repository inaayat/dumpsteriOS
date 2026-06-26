import UIKit

enum DocHeadingExtractor {
    static func extractHeadings(from content: String) -> [String] {
        // RTF fallback for legacy docs that haven't been migrated yet
        if content.hasPrefix("{\\rtf"),
           let data = content.data(using: .utf8),
           let attrStr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            let lines = attrStr.string.components(separatedBy: "\n")
            var charPos = 0
            return lines.compactMap { line in
                defer { charPos += line.count + 1 }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, charPos < attrStr.length else { return nil }
                let checkLen = min(line.count, attrStr.length - charPos)
                guard checkLen > 0 else { return nil }
                var fontSize: CGFloat = 0
                attrStr.enumerateAttribute(.font, in: NSRange(location: charPos, length: checkLen)) { val, _, _ in
                    if let f = val as? UIFont { fontSize = max(fontSize, f.pointSize) }
                }
                return fontSize >= 18 ? trimmed : nil
            }
        }

        // Markdown: extract ## and ### headings
        return content.components(separatedBy: "\n")
            .compactMap { line in
                if line.hasPrefix("### ") {
                    return String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("## ") {
                    return String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                return nil
            }
            .filter { !$0.isEmpty }
    }
}
