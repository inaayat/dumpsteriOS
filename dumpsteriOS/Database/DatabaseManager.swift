import Foundation
import GRDB

final class DatabaseManager: Sendable {
    static let shared = DatabaseManager()

    let dbPool: DatabasePool

    private init() {
        let dataDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dumpster")
        try! FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let dbPath = dataDir.appendingPathComponent("dumpster.db").path
        dbPool = try! DatabasePool(path: dbPath)

        try! migrator.migrate(dbPool)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "tags") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "tag_relationships") { t in
                t.column("id", .text).primaryKey()
                t.column("parentTagId", .text).notNull().references("tags", onDelete: .cascade)
                t.column("childTagId", .text).notNull().references("tags", onDelete: .cascade)
                t.column("createdAt", .datetime).notNull()
                t.uniqueKey(["parentTagId", "childTagId"])
            }

            try db.create(table: "items") { t in
                t.column("id", .text).primaryKey()
                t.column("text", .text).notNull()
                t.column("category", .text).notNull().defaults(to: "brainstorm")
                t.column("priority", .text).notNull().defaults(to: "medium")
                t.column("done", .boolean).notNull().defaults(to: false)
                t.column("doneAt", .datetime)
                t.column("dueDate", .datetime)
                t.column("url", .text)
                t.column("urlTitle", .text)
                t.column("notes", .text)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "item_tags") { t in
                t.column("itemId", .text).notNull().references("items", onDelete: .cascade)
                t.column("tagId", .text).notNull().references("tags", onDelete: .cascade)
                t.primaryKey(["itemId", "tagId"])
            }

            try db.create(table: "daily_dumps") { t in
                t.column("id", .text).primaryKey()
                t.column("date", .text).notNull().unique()
                t.column("content", .text).notNull().defaults(to: "")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "master_docs") { t in
                t.column("id", .text).primaryKey()
                t.column("tagId", .text).notNull().references("tags", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("content", .text).notNull().defaults(to: "")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "item_links") { t in
                t.column("id", .text).primaryKey()
                t.column("fromItemId", .text).notNull().references("items", onDelete: .cascade)
                t.column("toItemId", .text).notNull().references("items", onDelete: .cascade)
                t.column("relationship", .text).notNull().defaults(to: "related")
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(index: "idx_items_category", on: "items", columns: ["category"])
            try db.create(index: "idx_items_done", on: "items", columns: ["done"])
            try db.create(index: "idx_items_priority", on: "items", columns: ["priority"])
            try db.create(index: "idx_item_tags_tag", on: "item_tags", columns: ["tagId"])
            try db.create(index: "idx_item_tags_item", on: "item_tags", columns: ["itemId"])
            try db.create(index: "idx_tagrel_parent", on: "tag_relationships", columns: ["parentTagId"])
            try db.create(index: "idx_tagrel_child", on: "tag_relationships", columns: ["childTagId"])
            try db.create(index: "idx_dumps_date", on: "daily_dumps", columns: ["date"])
            try db.create(index: "idx_masterdocs_tag", on: "master_docs", columns: ["tagId"])
            try db.create(index: "idx_links_from", on: "item_links", columns: ["fromItemId"])
            try db.create(index: "idx_links_to", on: "item_links", columns: ["toItemId"])
        }

        migrator.registerMigration("v2_incorporatedIntoDoc") { db in
            try db.alter(table: "items") { t in
                t.add(column: "incorporatedIntoDoc", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("v3_hiddenBullets") { db in
            try db.create(table: "hidden_bullets") { t in
                t.column("id", .text).primaryKey()
                t.column("bulletText", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v4_dismissedFromDoc") { db in
            try db.alter(table: "items") { t in
                t.add(column: "dismissedFromDoc", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("v5_multiTagDocs") { db in
            try db.create(table: "master_doc_tags") { t in
                t.column("docId", .text).notNull().references("master_docs", onDelete: .cascade)
                t.column("tagId", .text).notNull().references("tags", onDelete: .cascade)
                t.primaryKey(["docId", "tagId"])
            }
            try db.create(index: "idx_doc_tags_doc", on: "master_doc_tags", columns: ["docId"])
            try db.create(index: "idx_doc_tags_tag", on: "master_doc_tags", columns: ["tagId"])

            // Migrate existing master_docs.tagId into junction table
            let rows = try Row.fetchAll(db, sql: "SELECT id, tagId FROM master_docs")
            for row in rows {
                let docId: String = row["id"]
                let tagId: String = row["tagId"]
                try db.execute(sql: "INSERT OR IGNORE INTO master_doc_tags (docId, tagId) VALUES (?, ?)", arguments: [docId, tagId])
            }
        }

        return migrator
    }
}
