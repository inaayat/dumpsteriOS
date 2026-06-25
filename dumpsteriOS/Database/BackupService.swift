import Foundation
import GRDB

struct AppBackup: Codable {
    var exportDate: Date
    var items: [Item]
    var tags: [Tag]
    var itemTags: [ItemTag]
    var dailyDumps: [DailyDump]
    var masterDocs: [MasterDoc]
    var itemLinks: [ItemLink]
    var tagRelationships: [TagRelationship]
    var hiddenBullets: [HiddenBullet]
}

enum BackupService {

    static func exportAll() throws -> Data {
        let db = DatabaseManager.shared.dbPool

        let backup = try db.read { db in
            AppBackup(
                exportDate: Date(),
                items: try Item.fetchAll(db),
                tags: try Tag.fetchAll(db),
                itemTags: try ItemTag.fetchAll(db),
                dailyDumps: try DailyDump.fetchAll(db),
                masterDocs: try MasterDoc.fetchAll(db),
                itemLinks: try ItemLink.fetchAll(db),
                tagRelationships: try TagRelationship.fetchAll(db),
                hiddenBullets: try HiddenBullet.fetchAll(db)
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func importAll(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackup.self, from: data)

        let db = DatabaseManager.shared.dbPool

        try db.write { db in
            // Clear existing data
            try Item.deleteAll(db)
            try Tag.deleteAll(db)
            try ItemTag.deleteAll(db)
            try DailyDump.deleteAll(db)
            try MasterDoc.deleteAll(db)
            try ItemLink.deleteAll(db)
            try TagRelationship.deleteAll(db)
            try HiddenBullet.deleteAll(db)

            // Insert backup data
            for row in backup.tags { try row.insert(db) }
            for row in backup.items { try row.insert(db) }
            for row in backup.itemTags { try row.insert(db) }
            for row in backup.dailyDumps { try row.insert(db) }
            for row in backup.masterDocs { try row.insert(db) }
            for row in backup.itemLinks { try row.insert(db) }
            for row in backup.tagRelationships { try row.insert(db) }
            for row in backup.hiddenBullets { try row.insert(db) }
        }
    }
}
