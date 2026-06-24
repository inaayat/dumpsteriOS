import Foundation
import GRDB

struct DailyDump: Identifiable, Codable, Equatable {
    var id: String
    var date: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    static func today() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    static func displayDate(_ dateStr: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateFormat = "EEEE, MMM d, yyyy"
        return display.string(from: date)
    }

    static func new(date: String? = nil) -> DailyDump {
        let d = date ?? today()
        return DailyDump(id: UUID().uuidString, date: d, content: "", createdAt: Date(), updatedAt: Date())
    }
}

extension DailyDump: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "daily_dumps"

    enum Columns: String, ColumnExpression {
        case id, date, content, createdAt, updatedAt
    }
}

struct DumpBullet: Identifiable {
    let id = UUID()
    var text: String
    var tags: [String]
    var magicTags: [MagicTag]
    var rawLine: String

    static func parse(from content: String) -> [DumpBullet] {
        content
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                var cleaned = line
                if cleaned.hasPrefix("• ") { cleaned = String(cleaned.dropFirst(2)) }
                else if cleaned.hasPrefix("* ") { cleaned = String(cleaned.dropFirst(2)) }
                cleaned = cleaned.trimmingCharacters(in: .whitespaces)
                let allTags = extractTags(from: cleaned)
                let magic = allTags.compactMap { MagicTag(rawValue: $0) }
                let topicTags = allTags.filter { MagicTag(rawValue: $0) == nil }
                return DumpBullet(text: cleaned, tags: topicTags, magicTags: magic, rawLine: line)
            }
    }

    static func extractTags(from text: String) -> [String] {
        let pattern = #"#([\w\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range]).lowercased()
        }
    }
}

enum MagicTag: String {
    case action
    case brainstorm
    case resource
    case win
    case save
    case prio
    case backlog
    case delete
}

enum MagicTagProcessor {
    static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: #"#[\w\-]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // Returns (url, bracketTitle, remainingText) where remainingText has the URL and brackets stripped.
    static func extractURLAndTitle(from text: String) -> (url: String?, title: String?, remainder: String) {
        var working = text

        var title: String? = nil
        let bracketPattern = #"\[([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: bracketPattern),
           let match = regex.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)) {
            if let titleRange = Range(match.range(at: 1), in: working) {
                title = String(working[titleRange])
            }
            if let fullRange = Range(match.range, in: working) {
                working.removeSubrange(fullRange)
            }
        }

        var url: String? = nil
        let urlPattern = #"https?://\S+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern),
           let match = regex.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)),
           let range = Range(match.range, in: working) {
            var extracted = String(working[range])
            while let last = extracted.last, ".,;:)>\"'".contains(last) { extracted.removeLast() }
            url = extracted
            working.removeSubrange(range)
        }

        return (url, title, working.trimmingCharacters(in: .whitespaces))
    }

    static func processLine(_ line: String) {
        let bullet = DumpBullet.parse(from: line).first
        guard let bullet else { return }

        if !bullet.magicTags.isEmpty {
            let cleanText = stripTags(bullet.text)
            guard !cleanText.isEmpty else { return }

            let isHighPrio = bullet.magicTags.contains(.prio)
            let isBacklog = bullet.magicTags.contains(.backlog)

            for magic in bullet.magicTags {
                switch magic {
                case .action:
                    if let existing = existingItem(text: cleanText) {
                        if isHighPrio && existing.priority != .high {
                            var upgraded = existing; upgraded.priority = .high
                            try? Queries.updateItem(upgraded)
                        }
                    } else {
                        let item = Item.new(text: cleanText, category: .action, priority: isHighPrio ? .high : isBacklog ? .backlog : .medium)
                        try? Queries.addItem(item)
                        try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                    }
                case .brainstorm:
                    guard !itemAlreadyExists(text: cleanText) else { break }
                    let item = Item.new(text: cleanText, category: .brainstorm)
                    try? Queries.addItem(item)
                    try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                case .resource:
                    let (extractedURL, urlTitle, remainder) = extractURLAndTitle(from: cleanText)
                    let itemText = urlTitle ?? (remainder.isEmpty ? (extractedURL ?? cleanText) : remainder)
                    guard !itemAlreadyExists(text: itemText) else { break }
                    let item = Item.new(text: itemText, category: .resource, url: extractedURL, urlTitle: urlTitle)
                    try? Queries.addItem(item)
                    try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                case .win:
                    break // Wins skipped on iOS
                case .save:
                    for tagName in bullet.tags {
                        guard let tag = try? Queries.getOrCreateTag(name: tagName) else { break }
                        let existing = (try? Queries.getMasterDoc(tagId: tag.id))?.content ?? ""
                        guard !existing.contains(cleanText) else { break }
                        let title = (try? Queries.getMasterDoc(tagId: tag.id))?.title
                            ?? tagName.replacingOccurrences(of: "-", with: " ").capitalized

                        // If AI is available and doc has content, use AI to insert intelligently
                        if #available(iOS 26.0, *), AIService.isAvailable, !existing.isEmpty {
                            Task {
                                if let result = try? await AIService.insertBulletsIntoDoc(existingContent: existing, bullets: [cleanText]) {
                                    try? Queries.upsertMasterDoc(tagId: tag.id, content: result, title: title)
                                }
                            }
                        } else {
                            let newContent = existing.isEmpty ? "• \(cleanText)" : "\(existing)\n• \(cleanText)"
                            try? Queries.upsertMasterDoc(tagId: tag.id, content: newContent, title: title)
                        }
                    }
                case .prio:
                    if !bullet.magicTags.contains(.action) && !bullet.magicTags.contains(.brainstorm) {
                        guard !itemAlreadyExists(text: cleanText) else { break }
                        let item = Item.new(text: cleanText, category: .action, priority: .high)
                        try? Queries.addItem(item)
                        try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                    }
                case .backlog:
                    if !bullet.magicTags.contains(.action) && !bullet.magicTags.contains(.brainstorm) {
                        guard !itemAlreadyExists(text: cleanText) else { break }
                        let item = Item.new(text: cleanText, category: .action, priority: .backlog)
                        try? Queries.addItem(item)
                        try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                    }
                case .delete:
                    if let allItems = try? Queries.searchItems(query: cleanText) {
                        for item in allItems where stripTags(item.text).trimmingCharacters(in: .whitespaces) == cleanText {
                            try? Queries.deleteItem(id: item.id)
                        }
                    }
                }
            }
        }

        // Auto-resource: URL in bullet with no #resource magic tag
        if !bullet.magicTags.contains(.resource) {
            let (url, title, remainder) = extractURLAndTitle(from: bullet.text)
            guard let url else { return }
            let itemText = title ?? (remainder.isEmpty ? url : remainder)
            guard !itemAlreadyExists(text: itemText) else { return }
            let item = Item.new(text: itemText, category: .resource, url: url, urlTitle: title)
            try? Queries.addItem(item)
            try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
        }
    }

    private static func existingItem(text: String) -> Item? {
        guard let existing = try? Queries.searchItems(query: text) else { return nil }
        return existing.first { stripTags($0.text).trimmingCharacters(in: .whitespaces) == text }
    }

    private static func itemAlreadyExists(text: String) -> Bool {
        existingItem(text: text) != nil
    }
}
