import Foundation

public enum FoodCategory: String, CaseIterable, Codable, Sendable {
    case dairy = "DAIRY"
    case vegetable = "VEGETABLE"
    case meat = "MEAT"
    case grocery = "GROCERY"
    case beverage = "BEVERAGE"
    case bakery = "BAKERY"
    case frozen = "FROZEN"
    case other = "OTHER"

    public var displayName: String {
        switch self {
        case .dairy: "Frais"
        case .vegetable: "Légumes"
        case .meat: "Viandes & poissons"
        case .grocery: "Épicerie"
        case .beverage: "Boissons"
        case .bakery: "Boulangerie"
        case .frozen: "Surgelés"
        case .other: "Autres"
        }
    }

    public var estimatedShelfLifeDays: Int {
        switch self {
        case .dairy: 5
        case .vegetable: 4
        case .meat: 2
        case .bakery: 2
        case .frozen: 90
        case .grocery: 30
        case .beverage: 30
        case .other: 14
        }
    }

    public var defaultStorageLocation: StorageLocation {
        switch self {
        case .dairy, .vegetable, .meat, .bakery: .fridge
        case .frozen: .freezer
        case .grocery, .beverage, .other: .pantry
        }
    }
}

public enum StorageLocation: String, CaseIterable, Codable, Sendable {
    case fridge = "FRIDGE"
    case freezer = "FREEZER"
    case pantry = "PANTRY"

    public var displayName: String {
        switch self { case .fridge: "Frigo"; case .freezer: "Congélateur"; case .pantry: "Placard" }
    }
    public var icon: String {
        switch self { case .fridge: "refrigerator"; case .freezer: "snowflake"; case .pantry: "cabinet" }
    }
}

public enum FoodUnit: String, CaseIterable, Codable, Sendable {
    case gram = "g"
    case kilogram = "kg"
    case milliliter = "ml"
    case liter = "L"
    case item = "unités"

    public var dimension: String {
        switch self {
        case .gram, .kilogram: "mass"
        case .milliliter, .liter: "volume"
        case .item: "count"
        }
    }

    public func normalized(_ quantity: Double) -> Double {
        switch self {
        case .kilogram: quantity * 1_000
        case .liter: quantity * 1_000
        default: quantity
        }
    }
}

public struct InventoryItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var category: FoodCategory
    public var quantity: Double
    public var unit: FoodUnit
    public var expiryDate: Date?
    public var addedAt: Date
    public var storageLocation: StorageLocation
    public var isLeftover: Bool
    public var cookedAt: Date?

    public init(id: UUID = UUID(), name: String, category: FoodCategory, quantity: Double, unit: FoodUnit, expiryDate: Date? = nil, addedAt: Date = .now, storageLocation: StorageLocation? = nil, isLeftover: Bool = false, cookedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.expiryDate = expiryDate
        self.addedAt = addedAt
        self.storageLocation = storageLocation ?? category.defaultStorageLocation
        self.isLeftover = isLeftover
        self.cookedAt = cookedAt
    }

    private enum CodingKeys: String, CodingKey { case id, name, category, quantity, unit, expiryDate, addedAt, storageLocation, isLeftover, cookedAt }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        category = try values.decode(FoodCategory.self, forKey: .category)
        quantity = try values.decode(Double.self, forKey: .quantity)
        unit = try values.decode(FoodUnit.self, forKey: .unit)
        expiryDate = try values.decodeIfPresent(Date.self, forKey: .expiryDate)
        addedAt = try values.decode(Date.self, forKey: .addedAt)
        storageLocation = try values.decodeIfPresent(StorageLocation.self, forKey: .storageLocation) ?? category.defaultStorageLocation
        isLeftover = try values.decodeIfPresent(Bool.self, forKey: .isLeftover) ?? false
        cookedAt = try values.decodeIfPresent(Date.self, forKey: .cookedAt)
    }

    public func expires(within days: Int, from date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let expiryDate else { return false }
        guard let limit = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date)) else { return false }
        return expiryDate <= limit
    }
}

public struct RecipeIngredient: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var baseQuantity: Double
    public var unit: FoodUnit
    public var isPantryStaple: Bool

    public init(id: UUID = UUID(), name: String, baseQuantity: Double, unit: FoodUnit, isPantryStaple: Bool = false) {
        self.id = id
        self.name = name
        self.baseQuantity = baseQuantity
        self.unit = unit
        self.isPantryStaple = isPantryStaple
    }
}

public struct Recipe: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var baseServings: Int
    public var prepTimeMinutes: Int
    public var instructions: [String]
    public var ingredients: [RecipeIngredient]
    public var dietaryTags: Set<DietaryTag>
    public var allergens: Set<Allergen>
    public var course: RecipeCourse

    public init(id: UUID = UUID(), title: String, baseServings: Int, prepTimeMinutes: Int, instructions: [String], ingredients: [RecipeIngredient], dietaryTags: Set<DietaryTag> = [], allergens: Set<Allergen> = [], course: RecipeCourse = .main) {
        self.id = id
        self.title = title
        self.baseServings = baseServings
        self.prepTimeMinutes = prepTimeMinutes
        self.instructions = instructions
        self.ingredients = ingredients
        self.dietaryTags = dietaryTags
        self.allergens = allergens
        self.course = course
    }

    public func scaledIngredients(for servings: Int) -> [RecipeIngredient] {
        let factor = Double(servings) / Double(baseServings)
        return ingredients.map { ingredient in
            var scaled = ingredient
            scaled.baseQuantity *= factor
            return scaled
        }
    }
}

public enum RecipeCourse: String, CaseIterable, Codable, Sendable {
    case starter = "Entrées"
    case main = "Plats"
    case dessert = "Desserts"
    case snack = "Encas & à emporter"
}

public struct RecipeFeed: Codable, Sendable {
    public var schemaVersion: Int
    public var recipes: [Recipe]

    public init(schemaVersion: Int = 1, recipes: [Recipe]) {
        self.schemaVersion = schemaVersion
        self.recipes = recipes
    }
}

public enum RecipeFeedCodec {
    public static let maximumBytes = 2_000_000
    public enum FeedError: Error { case invalidCatalog }

    public static func decode(_ data: Data) throws -> [Recipe] {
        guard data.count <= maximumBytes else { throw FeedError.invalidCatalog }
        let feed = try JSONDecoder().decode(RecipeFeed.self, from: data)
        guard feed.schemaVersion == 1, (1...1000).contains(feed.recipes.count),
              Set(feed.recipes.map(\.id)).count == feed.recipes.count else { throw FeedError.invalidCatalog }
        for recipe in feed.recipes {
            guard !recipe.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, recipe.title.count <= 200,
                  (1...100).contains(recipe.baseServings), (1...1440).contains(recipe.prepTimeMinutes),
                  (1...100).contains(recipe.instructions.count),
                  recipe.instructions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 4000 }),
                  (1...100).contains(recipe.ingredients.count),
                  Set(recipe.ingredients.map(\.id)).count == recipe.ingredients.count else { throw FeedError.invalidCatalog }
            for ingredient in recipe.ingredients {
                guard !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, ingredient.name.count <= 200,
                      ingredient.baseQuantity.isFinite, ingredient.baseQuantity > 0, ingredient.baseQuantity <= 1_000_000 else { throw FeedError.invalidCatalog }
            }
        }
        return feed.recipes
    }
}

public enum DietaryTag: String, CaseIterable, Codable, Sendable {
    case vegetarian = "Végétarien"
    case vegan = "Vegan"
    case glutenFree = "Sans gluten"
}

public enum Allergen: String, CaseIterable, Codable, Sendable {
    case gluten = "Gluten"
    case milk = "Lait"
    case egg = "Œuf"
    case fish = "Poisson"
    case nuts = "Fruits à coque"
    case soy = "Soja"
    case peanuts = "Arachides"
    case celery = "Céleri"
    case mustard = "Moutarde"
    case sesame = "Sésame"
    case sulphites = "Sulfites"
    case lupin = "Lupin"
    case molluscs = "Mollusques"
    case crustaceans = "Crustacés"
}

public enum MealSlot: String, CaseIterable, Codable, Sendable {
    case lunch = "Déjeuner"
    case dinner = "Dîner"
}

public struct MealPlanEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var recipeID: UUID
    public var recipeTitle: String
    public var date: Date
    public var slot: MealSlot
    public var servings: Int
    public init(id: UUID = UUID(), recipeID: UUID, recipeTitle: String, date: Date, slot: MealSlot, servings: Int) {
        self.id = id; self.recipeID = recipeID; self.recipeTitle = recipeTitle; self.date = date; self.slot = slot; self.servings = servings
    }
}

public struct ShoppingItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var quantity: Double
    public var unit: FoodUnit
    public var isChecked: Bool

    public init(id: UUID = UUID(), name: String, quantity: Double, unit: FoodUnit, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.isChecked = isChecked
    }
}

public struct AppLicense: Codable, Equatable, Sendable {
    public var isProUnlocked: Bool
    public var remainingScanCredits: Int
    public var transactionID: String?

    public init(isProUnlocked: Bool = false, remainingScanCredits: Int = 5, transactionID: String? = nil) {
        self.isProUnlocked = isProUnlocked
        self.remainingScanCredits = remainingScanCredits
        self.transactionID = transactionID
    }
}
