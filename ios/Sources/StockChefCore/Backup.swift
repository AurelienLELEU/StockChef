import Foundation

public struct StockChefBackup: Codable, Sendable {
    public let version: String
    public let appName: String
    public let exportDate: Date
    public let inventory: [InventoryItem]
    public let shoppingList: [ShoppingItem]
    public let mealPlan: [MealPlanEntry]

    private enum CodingKeys: String, CodingKey { case version, appName, exportDate, inventory, shoppingList, mealPlan }

    public init(version: String = "1.1", appName: String = "StockChef", exportDate: Date = .now, inventory: [InventoryItem], shoppingList: [ShoppingItem] = [], mealPlan: [MealPlanEntry] = []) {
        self.version = version
        self.appName = appName
        self.exportDate = exportDate
        self.inventory = inventory
        self.shoppingList = shoppingList
        self.mealPlan = mealPlan
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        appName = try container.decode(String.self, forKey: .appName)
        exportDate = try container.decode(Date.self, forKey: .exportDate)
        inventory = try container.decode([InventoryItem].self, forKey: .inventory)
        shoppingList = try container.decodeIfPresent([ShoppingItem].self, forKey: .shoppingList) ?? []
        mealPlan = try container.decodeIfPresent([MealPlanEntry].self, forKey: .mealPlan) ?? []
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decoded(from data: Data) throws -> StockChefBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(StockChefBackup.self, from: data)
        guard ["1.0", "1.1"].contains(backup.version), backup.appName == "StockChef" else { throw BackupError.unsupportedFile }
        return backup
    }
}

public enum BackupError: LocalizedError {
    case unsupportedFile
    public var errorDescription: String? { "Ce fichier n’est pas une sauvegarde StockChef compatible." }
}
