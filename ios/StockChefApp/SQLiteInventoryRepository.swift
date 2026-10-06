import Foundation
import SQLite3

/// SQLite is the source of truth for the local inventory. JSON remains only a portable backup format.
final class SQLiteInventoryRepository {
    private var database: OpaquePointer?
    private let dateFormatter = ISO8601DateFormatter()

    init() throws {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("stockchef.sqlite")
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { throw SQLiteError.open }
        try migrate()
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS InventoryItems (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL, quantity REAL NOT NULL,
            unit TEXT NOT NULL, expiry_date TEXT, added_at TEXT NOT NULL,
            storage_location TEXT NOT NULL DEFAULT 'FRIDGE', is_leftover INTEGER NOT NULL DEFAULT 0, cooked_at TEXT
        );
        CREATE TABLE IF NOT EXISTS ShoppingItems (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, quantity REAL NOT NULL, unit TEXT NOT NULL, is_checked INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS MealPlans (
            id TEXT PRIMARY KEY, recipe_id TEXT NOT NULL, recipe_title TEXT NOT NULL, date TEXT NOT NULL,
            slot TEXT NOT NULL, servings INTEGER NOT NULL
        );
        """)
        if !hasColumn("InventoryItems", named: "storage_location") { try execute("ALTER TABLE InventoryItems ADD COLUMN storage_location TEXT NOT NULL DEFAULT 'FRIDGE';") }
        if !hasColumn("InventoryItems", named: "is_leftover") { try execute("ALTER TABLE InventoryItems ADD COLUMN is_leftover INTEGER NOT NULL DEFAULT 0;") }
        if !hasColumn("InventoryItems", named: "cooked_at") { try execute("ALTER TABLE InventoryItems ADD COLUMN cooked_at TEXT;") }
        try execute("PRAGMA user_version = 3;")
    }

    deinit { sqlite3_close(database) }

    func loadInventory() throws -> [InventoryItem] {
        let statement = try prepare("SELECT id, name, category, quantity, unit, expiry_date, added_at, storage_location, is_leftover, cooked_at FROM InventoryItems ORDER BY added_at DESC;")
        defer { sqlite3_finalize(statement) }
        var result: [InventoryItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = uuid(statement, 0), let name = string(statement, 1), let categoryValue = string(statement, 2), let category = FoodCategory(rawValue: categoryValue), let unitValue = string(statement, 4), let unit = FoodUnit(rawValue: unitValue), let addedAtValue = string(statement, 6), let addedAt = dateFormatter.date(from: addedAtValue) else { continue }
            let expiry = string(statement, 5).flatMap(dateFormatter.date(from:))
            let location = string(statement, 7).flatMap(StorageLocation.init(rawValue:)) ?? category.defaultStorageLocation
            result.append(InventoryItem(id: id, name: name, category: category, quantity: sqlite3_column_double(statement, 3), unit: unit, expiryDate: expiry, addedAt: addedAt, storageLocation: location, isLeftover: sqlite3_column_int(statement, 8) == 1, cookedAt: string(statement, 9).flatMap(dateFormatter.date(from:))))
        }
        return result
    }

    func saveInventory(_ items: [InventoryItem]) throws {
        try execute("BEGIN IMMEDIATE; DELETE FROM InventoryItems;")
        do {
            let statement = try prepare("INSERT INTO InventoryItems (id, name, category, quantity, unit, expiry_date, added_at, storage_location, is_leftover, cooked_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);")
            defer { sqlite3_finalize(statement) }
            for item in items {
                sqlite3_reset(statement)
                bind(item.id.uuidString, to: statement, at: 1)
                bind(item.name, to: statement, at: 2)
                bind(item.category.rawValue, to: statement, at: 3)
                sqlite3_bind_double(statement, 4, item.quantity)
                bind(item.unit.rawValue, to: statement, at: 5)
                if let expiryDate = item.expiryDate { bind(dateFormatter.string(from: expiryDate), to: statement, at: 6) } else { sqlite3_bind_null(statement, 6) }
                bind(dateFormatter.string(from: item.addedAt), to: statement, at: 7)
                bind(item.storageLocation.rawValue, to: statement, at: 8)
                sqlite3_bind_int(statement, 9, item.isLeftover ? 1 : 0)
                if let cookedAt = item.cookedAt { bind(dateFormatter.string(from: cookedAt), to: statement, at: 10) } else { sqlite3_bind_null(statement, 10) }
                guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.write }
            }
            try execute("COMMIT;")
        } catch { try? execute("ROLLBACK;"); throw error }
    }

    func loadMealPlan() throws -> [MealPlanEntry] {
        let statement = try prepare("SELECT id, recipe_id, recipe_title, date, slot, servings FROM MealPlans ORDER BY date ASC, slot ASC;")
        defer { sqlite3_finalize(statement) }
        var result: [MealPlanEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = uuid(statement, 0), let recipeID = uuid(statement, 1), let title = string(statement, 2), let dateText = string(statement, 3), let date = dateFormatter.date(from: dateText), let slotText = string(statement, 4), let slot = MealSlot(rawValue: slotText) else { continue }
            result.append(MealPlanEntry(id: id, recipeID: recipeID, recipeTitle: title, date: date, slot: slot, servings: Int(sqlite3_column_int(statement, 5))))
        }
        return result
    }

    func saveMealPlan(_ entries: [MealPlanEntry]) throws {
        try execute("BEGIN IMMEDIATE; DELETE FROM MealPlans;")
        do {
            let statement = try prepare("INSERT INTO MealPlans (id, recipe_id, recipe_title, date, slot, servings) VALUES (?, ?, ?, ?, ?, ?);")
            defer { sqlite3_finalize(statement) }
            for entry in entries {
                sqlite3_reset(statement)
                bind(entry.id.uuidString, to: statement, at: 1); bind(entry.recipeID.uuidString, to: statement, at: 2); bind(entry.recipeTitle, to: statement, at: 3); bind(dateFormatter.string(from: entry.date), to: statement, at: 4); bind(entry.slot.rawValue, to: statement, at: 5); sqlite3_bind_int(statement, 6, Int32(entry.servings))
                guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.write }
            }
            try execute("COMMIT;")
        } catch { try? execute("ROLLBACK;"); throw error }
    }

    func loadShoppingList() throws -> [ShoppingItem] {
        let statement = try prepare("SELECT id, name, quantity, unit, is_checked FROM ShoppingItems ORDER BY name COLLATE NOCASE;")
        defer { sqlite3_finalize(statement) }
        var result: [ShoppingItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = uuid(statement, 0), let name = string(statement, 1), let unitValue = string(statement, 3), let unit = FoodUnit(rawValue: unitValue) else { continue }
            result.append(ShoppingItem(id: id, name: name, quantity: sqlite3_column_double(statement, 2), unit: unit, isChecked: sqlite3_column_int(statement, 4) == 1))
        }
        return result
    }

    func saveShoppingList(_ items: [ShoppingItem]) throws {
        try execute("BEGIN IMMEDIATE; DELETE FROM ShoppingItems;")
        do {
            let statement = try prepare("INSERT INTO ShoppingItems (id, name, quantity, unit, is_checked) VALUES (?, ?, ?, ?, ?);")
            defer { sqlite3_finalize(statement) }
            for item in items {
                sqlite3_reset(statement)
                bind(item.id.uuidString, to: statement, at: 1); bind(item.name, to: statement, at: 2)
                sqlite3_bind_double(statement, 3, item.quantity); bind(item.unit.rawValue, to: statement, at: 4); sqlite3_bind_int(statement, 5, item.isChecked ? 1 : 0)
                guard sqlite3_step(statement) == SQLITE_DONE else { throw SQLiteError.write }
            }
            try execute("COMMIT;")
        } catch { try? execute("ROLLBACK;"); throw error }
    }

    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else { defer { sqlite3_free(error) }; throw SQLiteError.write }
    }
    private func hasColumn(_ table: String, named column: String) -> Bool {
        guard let statement = try? prepare("PRAGMA table_info(\(table));") else { return false }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW { if string(statement, 1) == column { return true } }
        return false
    }
    private func prepare(_ sql: String) throws -> OpaquePointer? { var statement: OpaquePointer?; guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw SQLiteError.write }; return statement }
    private func bind(_ value: String, to statement: OpaquePointer?, at index: Int32) { sqlite3_bind_text(statement, index, value, -1, nil) }
    private func string(_ statement: OpaquePointer?, _ index: Int32) -> String? { guard let text = sqlite3_column_text(statement, index) else { return nil }; return String(cString: text) }
    private func uuid(_ statement: OpaquePointer?, _ index: Int32) -> UUID? { string(statement, index).flatMap(UUID.init(uuidString:)) }
}

enum SQLiteError: LocalizedError { case open, write; var errorDescription: String? { "Impossible d’accéder à la base locale StockChef." } }
