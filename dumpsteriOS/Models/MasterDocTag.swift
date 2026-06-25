import Foundation
import GRDB

struct MasterDocTag: Codable, Equatable {
    var docId: String
    var tagId: String
}

extension MasterDocTag: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "master_doc_tags"

    enum Columns: String, ColumnExpression {
        case docId, tagId
    }
}
