import Foundation
import GRDB

struct Queries {
    private static var db: DatabasePool { DatabaseManager.shared.dbPool }

    // MARK: - Items

    static func addItem(_ item: Item) throws {
        try db.write { db in try item.insert(db) }
    }

    static func updateItem(_ item: Item) throws {
        try db.write { db in try item.update(db) }
    }

    static func deleteItem(id: String) throws {
        try db.write { db in
            _ = try ItemLink.filter(ItemLink.Columns.fromItemId == id || ItemLink.Columns.toItemId == id).deleteAll(db)
            _ = try ItemTag.filter(ItemTag.Columns.itemId == id).deleteAll(db)
            _ = try Item.filter(Item.Columns.id == id).deleteAll(db)
        }
    }

    static func getItem(id: String) throws -> Item? {
        try db.read { db in try Item.filter(Item.Columns.id == id).fetchOne(db) }
    }

    static func getAllItems(done: Bool? = nil) throws -> [Item] {
        try db.read { db in
            var request = Item.all()
            if let done { request = request.filter(Item.Columns.done == done) }
            return try request.order(Item.Columns.createdAt.desc).fetchAll(db)
        }
    }

    static func getItems(category: Category? = nil, done: Bool? = nil) throws -> [Item] {
        try db.read { db in
            var request = Item.all()
            if let category { request = request.filter(Item.Columns.category == category) }
            if let done { request = request.filter(Item.Columns.done == done) }
            return try request.order(Item.Columns.createdAt.desc).fetchAll(db)
        }
    }

    static func searchItems(query: String) throws -> [Item] {
        try db.read { db in
            try Item
                .filter(Item.Columns.text.like("%\(query)%"))
                .order(Item.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    static func completeItem(id: String) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE items SET done = 1, doneAt = ? WHERE id = ?",
                arguments: [Date(), id]
            )
        }
    }

    static func uncompleteItem(id: String) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE items SET done = 0, doneAt = NULL WHERE id = ?",
                arguments: [id]
            )
        }
    }

    static func getOverdueAndDueToday() throws -> [Item] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return try db.read { db in
            try Item
                .filter(Item.Columns.done == false)
                .filter(Item.Columns.dueDate != nil)
                .filter(Item.Columns.dueDate < tomorrow)
                .order(Item.Columns.dueDate.asc)
                .fetchAll(db)
        }
    }

    static func promoteDueSoonToHigh() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let dayAfterTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: today)!
        try db.write { db in
            try db.execute(
                sql: """
                    UPDATE items SET priority = ?
                    WHERE done = 0 AND dueDate IS NOT NULL AND dueDate < ? AND priority != ?
                    """,
                arguments: [Priority.high.rawValue, dayAfterTomorrow, Priority.high.rawValue]
            )
        }
    }

    static func getCategoryCounts() throws -> [String: Int] {
        try db.read { db in
            var counts: [String: Int] = [:]
            let rows = try Row.fetchAll(db, sql: "SELECT category, COUNT(*) as count FROM items WHERE done = 0 GROUP BY category")
            for row in rows { counts[row["category"]] = row["count"] }
            counts["all"] = try Item.filter(Item.Columns.done == false).fetchCount(db)
            counts["completed"] = try Item.filter(Item.Columns.done == true).fetchCount(db)
            return counts
        }
    }

    // MARK: - Tags

    static func getOrCreateTag(name: String) throws -> Tag {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        return try db.write { db in
            if let existing = try Tag.filter(Tag.Columns.name == normalized).fetchOne(db) {
                return existing
            }
            let tag = Tag.new(name: normalized)
            try tag.insert(db)
            return tag
        }
    }

    static func getAllTags() throws -> [Tag] {
        try db.read { db in try Tag.order(Tag.Columns.name.asc).fetchAll(db) }
    }

    static func getTag(id: String) throws -> Tag? {
        try db.read { db in try Tag.filter(Tag.Columns.id == id).fetchOne(db) }
    }

    static func getTagByName(_ name: String) throws -> Tag? {
        try db.read { db in try Tag.filter(Tag.Columns.name == name.lowercased()).fetchOne(db) }
    }

    static func deleteTag(id: String) throws {
        try db.write { db in
            _ = try Tag.filter(Tag.Columns.id == id).deleteAll(db)
        }
    }

    static func renameTag(id: String, from oldName: String, to newName: String) throws {
        let normalized = newName.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return }
        try db.write { db in
            try db.execute(sql: "UPDATE tags SET name = ? WHERE id = ?", arguments: [normalized, id])
        }
        // Replace #oldname with #newname in all dump bullet text
        let dumps = try getAllDumps()
        for dump in dumps {
            let updated = dump.content
                .replacingOccurrences(of: "#\(oldName)", with: "#\(normalized)", options: .caseInsensitive)
            if updated != dump.content {
                try updateDumpContent(id: dump.id, content: updated)
            }
        }
    }

    static func getTagsForItem(itemId: String) throws -> [Tag] {
        try db.read { db in
            try Tag.fetchAll(db, sql: """
                SELECT t.* FROM tags t
                JOIN item_tags it ON it.tagId = t.id
                WHERE it.itemId = ?
                ORDER BY t.name
                """, arguments: [itemId])
        }
    }

    static func getItemsForTag(tagId: String, done: Bool? = nil) throws -> [Item] {
        try db.read { db in
            var sql = """
                SELECT i.* FROM items i
                JOIN item_tags it ON it.itemId = i.id
                WHERE it.tagId = ?
                """
            var args: [DatabaseValueConvertible] = [tagId]
            if let done {
                sql += " AND i.done = ?"
                args.append(done)
            }
            sql += " ORDER BY i.createdAt DESC"
            return try Item.fetchAll(db, sql: sql, arguments: StatementArguments(args))
        }
    }

    static func getItemCountForTag(tagId: String) throws -> Int {
        try db.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM item_tags it
                JOIN items i ON i.id = it.itemId
                WHERE it.tagId = ? AND i.done = 0
                """, arguments: [tagId]) ?? 0
        }
    }

    static func tagItem(itemId: String, tagId: String) throws {
        try db.write { db in
            let itemTag = ItemTag(itemId: itemId, tagId: tagId)
            try itemTag.insert(db)
        }
    }

    static func untagItem(itemId: String, tagId: String) throws {
        try db.write { db in
            _ = try ItemTag
                .filter(ItemTag.Columns.itemId == itemId && ItemTag.Columns.tagId == tagId)
                .deleteAll(db)
        }
    }

    static func tagItemWithNames(itemId: String, tagNames: [String]) throws {
        for name in tagNames {
            let tag = try getOrCreateTag(name: name)
            try? tagItem(itemId: itemId, tagId: tag.id)
        }
    }

    static func mergeTags(fromId: String, intoId: String) throws {
        // Merge MasterDocs before deleting the source tag
        let sourceDoc = try getMasterDoc(tagId: fromId)
        let targetDoc = try getMasterDoc(tagId: intoId)
        if let src = sourceDoc {
            if let tgt = targetDoc {
                // Both exist — append source content under a divider
                let combined = tgt.content + "\n\n---\n\n" + src.content
                try upsertMasterDoc(tagId: intoId, content: combined, title: tgt.title)
            } else {
                // Only source has a doc — reassign it to the target tag
                try upsertMasterDoc(tagId: intoId, content: src.content, title: src.title)
            }
            try deleteMasterDoc(id: src.id)
        }

        try db.write { db in
            let existing = try ItemTag
                .filter(ItemTag.Columns.tagId == intoId)
                .fetchAll(db)
                .map(\.itemId)
            let toReassign = try ItemTag
                .filter(ItemTag.Columns.tagId == fromId)
                .fetchAll(db)
            for row in toReassign where !existing.contains(row.itemId) {
                try ItemTag(itemId: row.itemId, tagId: intoId).insert(db)
            }
            _ = try ItemTag.filter(ItemTag.Columns.tagId == fromId).deleteAll(db)
            _ = try TagRelationship
                .filter(TagRelationship.Columns.parentTagId == fromId || TagRelationship.Columns.childTagId == fromId)
                .deleteAll(db)
            _ = try Tag.filter(Tag.Columns.id == fromId).deleteAll(db)
        }
    }

    // MARK: - Tag Relationships

    static func addSubTag(parentTagId: String, childTagId: String) throws {
        try db.write { db in
            let rel = TagRelationship(id: UUID().uuidString, parentTagId: parentTagId, childTagId: childTagId, createdAt: Date())
            try rel.insert(db)
        }
    }

    static func getSubTags(parentTagId: String) throws -> [Tag] {
        try db.read { db in
            try Tag.fetchAll(db, sql: """
                SELECT t.* FROM tags t
                JOIN tag_relationships tr ON tr.childTagId = t.id
                WHERE tr.parentTagId = ?
                ORDER BY t.name
                """, arguments: [parentTagId])
        }
    }

    static func getTopLevelTags() throws -> [Tag] {
        try db.read { db in
            try Tag.fetchAll(db, sql: """
                SELECT t.* FROM tags t
                WHERE t.id NOT IN (SELECT childTagId FROM tag_relationships)
                ORDER BY t.name
                """)
        }
    }

    // MARK: - Items Grouped by Tag

    static func getItemsGroupedByTag(category: Category? = nil, done: Bool = false, searchQuery: String? = nil) throws -> [(tag: Tag?, items: [Item])] {
        try db.read { db in
            let baseSQL = "SELECT i.* FROM items i"
            var conditions: [String] = ["i.done = ?"]
            var args: [DatabaseValueConvertible] = [done]

            if let category {
                conditions.append("i.category = ?")
                args.append(category)
            }
            if let searchQuery, !searchQuery.isEmpty {
                conditions.append("i.text LIKE ?")
                args.append("%\(searchQuery)%")
            }

            let whereClause = conditions.isEmpty ? "" : " WHERE " + conditions.joined(separator: " AND ")
            let sql = baseSQL + whereClause + " ORDER BY i.createdAt DESC"
            let allItems = try Item.fetchAll(db, sql: sql, arguments: StatementArguments(args))

            var taggedGroups: [String: (tag: Tag, items: [Item])] = [:]
            var untagged: [Item] = []

            // Batch: fetch all item-tag pairs in one JOIN instead of N+1 queries
            let itemIds = allItems.map { $0.id }
            var tagsByItemId: [String: [Tag]] = [:]
            if !itemIds.isEmpty {
                let placeholders = itemIds.map { _ in "?" }.joined(separator: ",")
                let rows = try Row.fetchAll(db, sql: """
                    SELECT it.itemId, t.id as tagId, t.name, t.createdAt
                    FROM item_tags it
                    JOIN tags t ON t.id = it.tagId
                    WHERE it.itemId IN (\(placeholders))
                    ORDER BY t.name
                    """, arguments: StatementArguments(itemIds))
                for row in rows {
                    let itemId: String = row["itemId"]
                    let tag = Tag(id: row["tagId"], name: row["name"], createdAt: row["createdAt"])
                    tagsByItemId[itemId, default: []].append(tag)
                }
            }

            for item in allItems {
                let tags = tagsByItemId[item.id] ?? []
                if tags.isEmpty {
                    untagged.append(item)
                } else {
                    for tag in tags {
                        if taggedGroups[tag.id] == nil {
                            taggedGroups[tag.id] = (tag: tag, items: [])
                        }
                        taggedGroups[tag.id]!.items.append(item)
                    }
                }
            }

            var result: [(tag: Tag?, items: [Item])] = taggedGroups.values
                .sorted { $0.items.count > $1.items.count }
                .map { (tag: $0.tag as Tag?, items: $0.items) }

            if !untagged.isEmpty {
                result.append((tag: nil, items: untagged))
            }

            return result
        }
    }

    // MARK: - Daily Dumps

    static func getOrCreateTodayDump() throws -> DailyDump {
        let today = DailyDump.today()
        return try db.write { db in
            if let existing = try DailyDump.filter(DailyDump.Columns.date == today).fetchOne(db) {
                return existing
            }
            let dump = DailyDump.new(date: today)
            try dump.insert(db)
            return dump
        }
    }

    static func updateDumpContent(id: String, content: String) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE daily_dumps SET content = ?, updatedAt = ? WHERE id = ?",
                arguments: [content, Date(), id]
            )
        }
    }

    static func getAllDumps() throws -> [DailyDump] {
        try db.read { db in
            try DailyDump.order(DailyDump.Columns.date.desc).fetchAll(db)
        }
    }

    static func appendToDump(date: String, bullet: String) throws {
        let dump = try getOrCreateTodayDump()
        let newContent = dump.content.isEmpty ? "• \(bullet)" : "\(dump.content)\n• \(bullet)"
        try updateDumpContent(id: dump.id, content: newContent)
    }

    // MARK: - Master Docs

    static func getMasterDoc(tagId: String) throws -> MasterDoc? {
        try db.read { db in
            // Check junction table first
            if let docId = try String.fetchOne(db, sql: "SELECT docId FROM master_doc_tags WHERE tagId = ? LIMIT 1", arguments: [tagId]),
               let doc = try MasterDoc.filter(MasterDoc.Columns.id == docId).fetchOne(db) {
                return doc
            }
            // Fallback to legacy tagId column
            return try MasterDoc.filter(MasterDoc.Columns.tagId == tagId).fetchOne(db)
        }
    }

    static func getAllMasterDocs() throws -> [MasterDoc] {
        try db.read { db in
            try MasterDoc.order(MasterDoc.Columns.updatedAt.desc).fetchAll(db)
        }
    }

    static func saveMasterDoc(id: String, content: String, title: String) throws {
        try db.write { db in
            guard var doc = try MasterDoc.filter(MasterDoc.Columns.id == id).fetchOne(db) else { return }
            doc.content = content
            doc.title = title
            doc.updatedAt = Date()
            try doc.update(db)
        }
    }

    static func upsertMasterDoc(tagId: String, content: String, title: String) throws {
        try db.write { db in
            // First check junction table for existing doc
            if let docId = try String.fetchOne(db, sql: "SELECT docId FROM master_doc_tags WHERE tagId = ? LIMIT 1", arguments: [tagId]),
               var existing = try MasterDoc.filter(MasterDoc.Columns.id == docId).fetchOne(db) {
                existing.content = content
                existing.title = title
                existing.updatedAt = Date()
                try existing.update(db)
            } else if var existing = try MasterDoc.filter(MasterDoc.Columns.tagId == tagId).fetchOne(db) {
                // Fallback to legacy tagId column
                existing.content = content
                existing.title = title
                existing.updatedAt = Date()
                try existing.update(db)
            } else {
                let doc = MasterDoc(id: UUID().uuidString, tagId: tagId, title: title, content: content, createdAt: Date(), updatedAt: Date())
                try doc.insert(db)
                try db.execute(sql: "INSERT OR IGNORE INTO master_doc_tags (docId, tagId) VALUES (?, ?)", arguments: [doc.id, tagId])
            }
        }
    }

    static func deleteMasterDoc(id: String) throws {
        try db.write { db in
            _ = try MasterDoc.filter(MasterDoc.Columns.id == id).deleteAll(db)
        }
    }

    static func getBulletCountForTag(tagName: String) throws -> Int {
        try getAllBulletCounts(tagNames: [tagName])[tagName] ?? 0
    }

    static func getAllBulletCounts(tagNames: [String]) throws -> [String: Int] {
        try db.read { db in
            let contents = try String.fetchAll(db, sql: "SELECT content FROM daily_dumps")
            let lowerNames = tagNames.map { $0.lowercased() }
            var counts: [String: Int] = [:]
            for content in contents {
                let lines = content.components(separatedBy: "\n")
                for lowerTag in lowerNames {
                    let needle = "#\(lowerTag)"
                    counts[lowerTag, default: 0] += lines.filter { $0.lowercased().contains(needle) }.count
                }
            }
            return counts
        }
    }

    // MARK: - Master Doc Tags (Multi-Tag Support)

    static func getTagsForDoc(docId: String) throws -> [Tag] {
        try db.read { db in
            try Tag.fetchAll(db, sql: """
                SELECT t.* FROM tags t
                JOIN master_doc_tags mdt ON mdt.tagId = t.id
                WHERE mdt.docId = ?
                ORDER BY t.name ASC
                """, arguments: [docId])
        }
    }

    static func getDocForTag(tagId: String) throws -> MasterDoc? {
        try db.read { db in
            try MasterDoc.fetchOne(db, sql: """
                SELECT md.* FROM master_docs md
                JOIN master_doc_tags mdt ON mdt.docId = md.id
                WHERE mdt.tagId = ?
                LIMIT 1
                """, arguments: [tagId])
        }
    }

    static func addTagToDoc(docId: String, tagId: String) throws {
        try db.write { db in
            try db.execute(sql: "INSERT OR IGNORE INTO master_doc_tags (docId, tagId) VALUES (?, ?)", arguments: [docId, tagId])
        }
    }

    static func removeTagFromDoc(docId: String, tagId: String) throws {
        try db.write { db in
            try db.execute(sql: "DELETE FROM master_doc_tags WHERE docId = ? AND tagId = ?", arguments: [docId, tagId])
        }
    }

    static func isTagAssignedToDoc(tagId: String) throws -> Bool {
        try db.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM master_doc_tags WHERE tagId = ?", arguments: [tagId]) ?? 0
            return count > 0
        }
    }

    static func createMasterDoc(title: String, tagIds: [String]) throws -> MasterDoc {
        try db.write { db in
            let doc = MasterDoc(id: UUID().uuidString, tagId: tagIds.first ?? "", title: title, content: "", createdAt: Date(), updatedAt: Date())
            try doc.insert(db)
            for tagId in tagIds {
                try db.execute(sql: "INSERT OR IGNORE INTO master_doc_tags (docId, tagId) VALUES (?, ?)", arguments: [doc.id, tagId])
            }
            return doc
        }
    }

    static func getUnincorporatedItemsForDoc(docId: String) throws -> [Item] {
        try db.read { db in
            try Item.fetchAll(db, sql: """
                SELECT DISTINCT i.* FROM items i
                JOIN item_tags it ON it.itemId = i.id
                JOIN master_doc_tags mdt ON mdt.tagId = it.tagId
                WHERE mdt.docId = ? AND i.incorporatedIntoDoc = 0 AND i.dismissedFromDoc = 0
                ORDER BY i.createdAt DESC
                """, arguments: [docId])
        }
    }

    static func getAllItemsForDoc(docId: String, category: Category? = nil) throws -> [Item] {
        try db.read { db in
            var sql = """
                SELECT DISTINCT i.* FROM items i
                JOIN item_tags it ON it.itemId = i.id
                JOIN master_doc_tags mdt ON mdt.tagId = it.tagId
                WHERE mdt.docId = ?
                """
            var args: [DatabaseValueConvertible] = [docId]
            if let category {
                sql += " AND i.category = ?"
                args.append(category.rawValue)
            }
            sql += " ORDER BY i.createdAt DESC"
            return try Item.fetchAll(db, sql: sql, arguments: StatementArguments(args))
        }
    }

    static func markItemIncorporated(id: String) throws {
        try db.write { db in
            try db.execute(sql: "UPDATE items SET incorporatedIntoDoc = 1 WHERE id = ?", arguments: [id])
        }
    }

    static func markItemUnincorporated(id: String) throws {
        try db.write { db in
            try db.execute(sql: "UPDATE items SET incorporatedIntoDoc = 0 WHERE id = ?", arguments: [id])
        }
    }

    static func dismissItemFromDoc(id: String) throws {
        try db.write { db in
            try db.execute(sql: "UPDATE items SET dismissedFromDoc = 1 WHERE id = ?", arguments: [id])
        }
    }

    static func undismissItem(id: String) throws {
        try db.write { db in
            try db.execute(sql: "UPDATE items SET dismissedFromDoc = 0 WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Hidden Bullets

    static func hideBullet(text: String) throws {
        try db.write { db in
            guard try HiddenBullet.filter(HiddenBullet.Columns.bulletText == text).fetchCount(db) == 0 else { return }
            try HiddenBullet.new(text: text).insert(db)
        }
    }

    static func unhideBullet(text: String) throws {
        try db.write { db in
            _ = try HiddenBullet.filter(HiddenBullet.Columns.bulletText == text).deleteAll(db)
        }
    }

    static func getHiddenBulletTexts() throws -> Set<String> {
        try db.read { db in
            Set(try HiddenBullet.fetchAll(db).map { $0.bulletText })
        }
    }

    // MARK: - Item Links

    static func addLink(_ link: ItemLink) throws {
        try db.write { db in try link.insert(db) }
    }

    static func getLinkedItems(itemId: String) throws -> [Item] {
        try db.read { db in
            try Item.fetchAll(db, sql: """
                SELECT i.* FROM items i
                JOIN item_links l ON (l.toItemId = i.id AND l.fromItemId = ?) OR (l.fromItemId = i.id AND l.toItemId = ?)
                """, arguments: [itemId, itemId])
        }
    }

    static func removeLink(fromId: String, toId: String) throws {
        try db.write { db in
            try db.execute(
                sql: "DELETE FROM item_links WHERE (fromItemId = ? AND toItemId = ?) OR (fromItemId = ? AND toItemId = ?)",
                arguments: [fromId, toId, toId, fromId]
            )
        }
    }
}
