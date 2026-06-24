import Foundation
import GRDB
import CoreTransferable
import UniformTypeIdentifiers

struct Tag: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var createdAt: Date
}

extension Tag: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "tags"

    enum Columns: String, ColumnExpression {
        case id, name, createdAt
    }
}

extension Tag {
    static func new(name: String) -> Tag {
        Tag(id: UUID().uuidString, name: name.lowercased().trimmingCharacters(in: .whitespaces), createdAt: Date())
    }
}

extension Tag: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

struct ItemTag: Codable, Equatable {
    var itemId: String
    var tagId: String
}

extension ItemTag: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "item_tags"

    enum Columns: String, ColumnExpression {
        case itemId, tagId
    }
}
