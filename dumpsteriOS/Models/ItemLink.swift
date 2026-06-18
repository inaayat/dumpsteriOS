import Foundation
import GRDB

struct ItemLink: Identifiable, Codable, Equatable {
    var id: String
    var fromItemId: String
    var toItemId: String
    var relationship: String
    var createdAt: Date
}

extension ItemLink: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "item_links"

    enum Columns: String, ColumnExpression {
        case id, fromItemId, toItemId, relationship, createdAt
    }
}
