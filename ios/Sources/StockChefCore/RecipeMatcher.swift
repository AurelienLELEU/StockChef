import Foundation

public struct RecipeMatch: Identifiable, Sendable {
    public let recipe: Recipe
    public let availableIngredientCount: Int
    public let requiredIngredientCount: Int
    public let missingIngredients: [RecipeIngredient]

    public var id: UUID { recipe.id }
    public var score: Double { requiredIngredientCount == 0 ? 0 : Double(availableIngredientCount) / Double(requiredIngredientCount) }
    public var isCookable: Bool { missingIngredients.isEmpty }
}

public enum RecipeMatcher {
    public static func matches(recipes: [Recipe], inventory: [InventoryItem], servings: Int) -> [RecipeMatch] {
        recipes.map { recipe in
            let scaled = recipe.scaledIngredients(for: servings)
            let required = scaled.filter { !$0.isPantryStaple }
            let missing = required.filter { !isAvailable($0, inventory: inventory) }
            return RecipeMatch(recipe: recipe, availableIngredientCount: required.count - missing.count, requiredIngredientCount: required.count, missingIngredients: missing)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.recipe.prepTimeMinutes < rhs.recipe.prepTimeMinutes }
            return lhs.score > rhs.score
        }
    }

    public static func cook(recipe: Recipe, servings: Int, inventory: [InventoryItem]) -> [InventoryItem] {
        let requirements = recipe.scaledIngredients(for: servings).filter { !$0.isPantryStaple }
        return inventory.compactMap { item in
            guard let ingredient = requirements.first(where: { normalized($0.name) == normalized(item.name) && $0.unit.dimension == item.unit.dimension }) else { return item }
            var updated = item
            updated.quantity -= converted(ingredient.baseQuantity, from: ingredient.unit, to: item.unit)
            return updated.quantity > 0.0001 ? updated : nil
        }
    }

    private static func isAvailable(_ ingredient: RecipeIngredient, inventory: [InventoryItem]) -> Bool {
        inventory.contains { item in
            normalized(item.name) == normalized(ingredient.name)
                && item.unit.dimension == ingredient.unit.dimension
                && item.unit.normalized(item.quantity) + 0.0001 >= ingredient.unit.normalized(ingredient.baseQuantity)
        }
    }

    private static func converted(_ quantity: Double, from source: FoodUnit, to target: FoodUnit) -> Double {
        source.normalized(quantity) / (target == .kilogram || target == .liter ? 1_000 : 1)
    }

    public static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: .alphanumerics.inverted).joined()
    }
}
