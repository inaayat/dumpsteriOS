import Foundation
import GRDB

struct MasterDoc: Identifiable, Codable, Equatable {
    var id: String
    var tagId: String
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
}

extension MasterDoc: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "master_docs"

    enum Columns: String, ColumnExpression {
        case id, tagId, title, content, createdAt, updatedAt
    }
}
