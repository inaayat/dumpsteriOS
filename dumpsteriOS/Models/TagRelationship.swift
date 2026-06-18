import Foundation
import GRDB

struct TagRelationship: Identifiable, Codable, Equatable {
    var id: String
    var parentTagId: String
    var childTagId: String
    var createdAt: Date
}

extension TagRelationship: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "tag_relationships"

    enum Columns: String, ColumnExpression {
        case id, parentTagId, childTagId, createdAt
    }
}
