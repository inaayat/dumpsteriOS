import Foundation
import GRDB

enum Category: String, Codable, CaseIterable, DatabaseValueConvertible {
    case action, brainstorm, resource

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .action: return "bolt.fill"
        case .brainstorm: return "cloud.bolt.fill"
        case .resource: return "bookmark.fill"
        }
    }
}

enum Priority: String, Codable, CaseIterable, DatabaseValueConvertible {
    case high, medium, low, backlog

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .backlog: return 3
        }
    }
}

struct Item: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var category: Category
    var priority: Priority
    var done: Bool
    var doneAt: Date?
    var dueDate: Date?
    var url: String?
    var urlTitle: String?
    var notes: String?
    var incorporatedIntoDoc: Bool
    var dismissedFromDoc: Bool
    var createdAt: Date

    var isOverdue: Bool {
        guard let dueDate, !done else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard let dueDate, !done else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isDueSoon: Bool {
        guard let dueDate, !done else { return false }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return Calendar.current.isDate(dueDate, inSameDayAs: tomorrow)
    }
}

extension Item: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "items"

    enum Columns: String, ColumnExpression {
        case id, text, category, priority, done, doneAt, dueDate, url, urlTitle, notes, incorporatedIntoDoc, dismissedFromDoc, createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, text, category, priority, done, doneAt, dueDate, url, urlTitle, notes, incorporatedIntoDoc, dismissedFromDoc, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        category = try container.decode(Category.self, forKey: .category)
        priority = try container.decode(Priority.self, forKey: .priority)
        done = try container.decode(Bool.self, forKey: .done)
        doneAt = try container.decodeIfPresent(Date.self, forKey: .doneAt)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        urlTitle = try container.decodeIfPresent(String.self, forKey: .urlTitle)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        incorporatedIntoDoc = try container.decodeIfPresent(Bool.self, forKey: .incorporatedIntoDoc) ?? false
        dismissedFromDoc = try container.decodeIfPresent(Bool.self, forKey: .dismissedFromDoc) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

extension Item {
    static func new(text: String, category: Category = .brainstorm, priority: Priority = .medium, dueDate: Date? = nil, url: String? = nil, urlTitle: String? = nil) -> Item {
        Item(
            id: UUID().uuidString,
            text: text,
            category: category,
            priority: priority,
            done: false,
            doneAt: nil,
            dueDate: dueDate,
            url: url,
            urlTitle: urlTitle,
            notes: nil,
            incorporatedIntoDoc: false,
            dismissedFromDoc: false,
            createdAt: Date()
        )
    }
}
