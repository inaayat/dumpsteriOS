import Foundation
import GRDB

struct HiddenBullet: Identifiable, Codable, Equatable {
    var id: String
    var bulletText: String
    var createdAt: Date
}

extension HiddenBullet: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "hidden_bullets"

    enum Columns: String, ColumnExpression {
        case id, bulletText, createdAt
    }
}

extension HiddenBullet {
    static func new(text: String) -> HiddenBullet {
        HiddenBullet(id: UUID().uuidString, bulletText: text, createdAt: Date())
    }
}
