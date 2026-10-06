import XCTest
@testable import StockChefCore

final class StockChefCoreTests: XCTestCase {
    func testRecipeFeedAcceptsCatalogAndRejectsInvalidUpdates() throws {
        let recipes = SampleData.recipes
        let encoder = JSONEncoder()
        XCTAssertEqual(try RecipeFeedCodec.decode(encoder.encode(RecipeFeed(recipes: recipes))), recipes)
        XCTAssertThrowsError(try RecipeFeedCodec.decode(encoder.encode(RecipeFeed(schemaVersion: 2, recipes: recipes))))
        XCTAssertThrowsError(try RecipeFeedCodec.decode(encoder.encode(RecipeFeed(recipes: []))))
        XCTAssertThrowsError(try RecipeFeedCodec.decode(encoder.encode(RecipeFeed(recipes: [recipes[0], recipes[0]]))))
        var invalid = recipes[0]
        invalid.baseServings = 0
        XCTAssertThrowsError(try RecipeFeedCodec.decode(encoder.encode(RecipeFeed(recipes: [invalid]))))
    }
    func testRecipeScalesAndDebitsInventory() {
        let recipe = Recipe(title: "Test", baseServings: 2, prepTimeMinutes: 1, instructions: [], ingredients: [RecipeIngredient(name: "Tomates", baseQuantity: 100, unit: .gram)])
        let initial = [InventoryItem(name: "Tomates", category: .vegetable, quantity: 300, unit: .gram)]
        XCTAssertEqual(recipe.scaledIngredients(for: 4).first?.baseQuantity, 200)
        XCTAssertEqual(RecipeMatcher.cook(recipe: recipe, servings: 4, inventory: initial).first?.quantity, 100)
    }

    func testRecipeMatcherConvertsUnits() {
        let recipe = Recipe(title: "Soupe", baseServings: 2, prepTimeMinutes: 1, instructions: [], ingredients: [RecipeIngredient(name: "Lait", baseQuantity: 250, unit: .milliliter)])
        let inventory = [InventoryItem(name: "Lait", category: .dairy, quantity: 1, unit: .liter)]
        XCTAssertTrue(RecipeMatcher.matches(recipes: [recipe], inventory: inventory, servings: 2).first!.isCookable)
    }

    func testReceiptParserCleansKnownFoodAndSkipsTotal() {
        let lines = ReceiptParser.parse(text: "LAIT ENT. 1L 1,25\nTOMATES 500G 2,40\nTOTAL 3,65")
        XCTAssertEqual(lines.map(\.name), ["Lait demi-écrémé", "Tomates"])
        XCTAssertEqual(lines[0].unit, .liter)
        XCTAssertEqual(lines[1].quantity, 500)
    }

    func testReceiptParserKeepsNutsAndCondimentsButSkipsNonFood() {
        let lines = ReceiptParser.parse(text: "AMANDES 125G 3,90\nHUILE OLIVE 75CL 6,50\nSAC REUTILISABLE 1,00\nTOTAL 11,40")
        XCTAssertEqual(lines.map(\.name), ["Amandes", "Huile d’olive"])
        XCTAssertEqual(lines[0].quantity, 125)
        XCTAssertEqual(lines[1].unit, .milliliter)
        XCTAssertEqual(lines[1].quantity, 750)
    }

    func testReceiptParserRecognizesTypicalLongReceiptAndMultipacks() {
        let receipt = """
        *100G JEUNES POUSSES 1,40
        *10X85G BURGER CHICKEN 4,80
        *150G CHEDDAR RAPE 4,90
        *180G WRAP PLT AVOC 3,95
        *200G COCKTAIL GRAIN 2,89
        *230G PAT FEUIL PB 1,39
        *280G TORTEL A POEL 5,98
        *30CL SMOOTHIE BERR 2,49
        *3X70G EMMENTAL RAPE 1,85
        *6X125G YRT LIT FR 2,49
        *50CL LAIT MONT 1,82
        *NOIX DE CAJOU CURRY 4,34
        *SAUCE AIOLI 2,40
        *SAUMON FUME NORVEG 6,00
        *TOMATE GRAPPE 1,17
        *DENTIFRIX 3,78
        *FELIX DELI 1,95
        """

        let lines = ReceiptParser.parse(text: receipt)
        XCTAssertEqual(lines.count, 15)
        XCTAssertTrue(lines.contains { $0.name == "Jeunes pousses" })
        XCTAssertTrue(lines.contains { $0.name == "Tortellini" })
        XCTAssertTrue(lines.contains { $0.name == "Sauce aïoli" })
        XCTAssertFalse(lines.contains { $0.name.localizedCaseInsensitiveContains("Dentif") })
        XCTAssertFalse(lines.contains { $0.name.localizedCaseInsensitiveContains("Felix") })

        let emmental = try? XCTUnwrap(lines.first { $0.name == "Fromage râpé" })
        XCTAssertEqual(emmental?.quantity, 210)
        XCTAssertEqual(emmental?.unit, .gram)

        let yaourts = try? XCTUnwrap(lines.first { $0.name == "Yaourts" })
        XCTAssertEqual(yaourts?.quantity, 6)
        XCTAssertEqual(yaourts?.unit, .item)
    }

    func testRecipeCatalogHasEveryCourse() {
        XCTAssertEqual(Set(SampleData.recipes.map(\.course)), Set(RecipeCourse.allCases))
        XCTAssertGreaterThanOrEqual(SampleData.recipes.count, 18)
    }

    func testBackupRoundTrip() throws {
        let shopping = [ShoppingItem(name: "Riz", quantity: 500, unit: .gram)]
        let backup = StockChefBackup(inventory: SampleData.inventory, shoppingList: shopping)
        let restored = try StockChefBackup.decoded(from: backup.encoded()).inventory
        XCTAssertEqual(restored.map(\.id), SampleData.inventory.map(\.id))
        XCTAssertEqual(restored.map(\.name), SampleData.inventory.map(\.name))
        XCTAssertEqual(restored.map(\.quantity), SampleData.inventory.map(\.quantity))
        XCTAssertEqual(try StockChefBackup.decoded(from: backup.encoded()).shoppingList, shopping)
    }

    func testFoodCategoryProvidesAConservativeExpiryEstimate() {
        XCTAssertLessThan(FoodCategory.meat.estimatedShelfLifeDays, FoodCategory.grocery.estimatedShelfLifeDays)
        XCTAssertEqual(FoodCategory.vegetable.estimatedShelfLifeDays, 4)
    }
}
