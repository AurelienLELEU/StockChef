package fr.btbu.stockchef.core

import kotlin.test.*
import kotlinx.serialization.encodeToString

class StockChefTest {
    private fun recipe() = Recipe(title = "Test", prepTimeMinutes = 1, instructions = emptyList(), ingredients = listOf(RecipeIngredient(name = "Tomates", baseQuantity = 100.0, unit = FoodUnit.GRAM)))
    @Test fun scalesAndDebits() {
        val stock = listOf(InventoryItem(name = "Tomates", quantity = 300.0, unit = FoodUnit.GRAM))
        assertEquals(200.0, recipe().scaled(4).single().baseQuantity)
        assertEquals(100.0, RecipeMatcher.cook(recipe(), 4, stock).single().quantity)
    }
    @Test fun convertsUnits() {
        val recipe = Recipe(title = "Soupe", prepTimeMinutes = 1, instructions = emptyList(), ingredients = listOf(RecipeIngredient(name = "Lait", baseQuantity = 250.0, unit = FoodUnit.MILLILITER)))
        assertTrue(RecipeMatcher.match(recipe, listOf(InventoryItem(name = "Lait", quantity = 1.0, unit = FoodUnit.LITER)), 2).cookable)
    }
    @Test fun multipleLotsAreDebitedOnlyOnceOldestFirst() {
        val stock = listOf(InventoryItem(name = "Tomates", quantity = 60.0, unit = FoodUnit.GRAM, expiryDate = date(1)), InventoryItem(name = "Tomates", quantity = 140.0, unit = FoodUnit.GRAM, expiryDate = date(5)))
        val cooked = RecipeMatcher.cook(recipe(), 2, stock)
        assertEquals(1, cooked.size)
        assertEquals(stock[1].id, cooked.single().id)
        assertEquals(100.0, cooked.single().quantity)
    }
    @Test fun missingStockCannotBeCooked() {
        assertFailsWith<IllegalArgumentException> { RecipeMatcher.cook(recipe(), 2, emptyList()) }
    }
    @Test fun basicReceipt() {
        val lines = ReceiptParser.parse("LAIT ENT. 1L 1,25\nTOMATES 500G 2,40\nTOTAL 3,65")
        assertEquals(listOf("Lait demi-écrémé", "Tomates"), lines.map { it.name })
        assertEquals(FoodUnit.LITER, lines.first().unit)
        assertEquals(500.0, lines[1].quantity)
    }
    @Test fun nutsCondimentsAndNonFood() {
        val lines = ReceiptParser.parse("AMANDES 125G 3,90\nHUILE OLIVE 75CL 6,50\nSAC REUTILISABLE 1,00\nTOTAL 11,40")
        assertEquals(listOf("Amandes", "Huile d’olive"), lines.map { it.name })
        assertEquals(750.0, lines[1].quantity)
    }
    @Test fun longReceiptAndMultipacks() {
        val lines = ReceiptParser.parse("*100G JEUNES POUSSES 1,40\n*10X85G BURGER CHICKEN 4,80\n*150G CHEDDAR RAPE 4,90\n*180G WRAP PLT AVOC 3,95\n*200G COCKTAIL GRAIN 2,89\n*230G PAT FEUIL PB 1,39\n*280G TORTEL A POEL 5,98\n*30CL SMOOTHIE BERR 2,49\n*3X70G EMMENTAL RAPE 1,85\n*6X125G YRT LIT FR 2,49\n*50CL LAIT MONT 1,82\n*NOIX DE CAJOU CURRY 4,34\n*SAUCE AIOLI 2,40\n*SAUMON FUME NORVEG 6,00\n*TOMATE GRAPPE 1,17\n*DENTIFRIX 3,78\n*FELIX DELI 1,95")
        assertEquals(15, lines.size)
        assertEquals(210.0, lines.first { it.name == "Fromage râpé" }.quantity)
        assertEquals(6.0, lines.first { it.name == "Yaourts" }.quantity)
    }
    @Test fun backupsRoundTripPreserveAllThreeCollections() {
        val backup = Backup(inventory = listOf(InventoryItem(name = "Tomates", isLeftover = true)), shoppingList = listOf(ShoppingItem(name = "Riz", quantity = 500.0, unit = FoodUnit.GRAM)), mealPlan = listOf(MealPlanEntry(recipeID = "recipe", recipeTitle = "Repas", date = date())))
        val restored = BackupCodec.decode(BackupCodec.encode(backup))
        assertEquals(backup.inventory, restored.inventory)
        assertEquals(backup.shoppingList, restored.shoppingList)
        assertEquals(backup.mealPlan, restored.mealPlan)
    }
    @Test fun rejectsForeignAndIncompleteBackups() {
        assertFailsWith<IllegalArgumentException> { BackupCodec.decode("{\"appName\":\"Other\",\"inventory\":[]}") }
        assertFailsWith<IllegalArgumentException> { BackupCodec.decode("{}") }
        assertFailsWith<IllegalArgumentException> { BackupCodec.decode("{\"inventory\":[]}") }
        val shopping = ShoppingItem(name = "Riz")
        assertFailsWith<IllegalArgumentException> { BackupCodec.decode(BackupCodec.encode(Backup(shoppingList = listOf(shopping, shopping)))) }
        val plan = MealPlanEntry(recipeID = "recipe", recipeTitle = "Repas", date = date())
        assertFailsWith<IllegalArgumentException> { BackupCodec.decode(BackupCodec.encode(Backup(mealPlan = listOf(plan, plan)))) }
    }
    @Test fun legacyBackupsMayOmitShoppingAndMealPlan() {
        val backup = BackupCodec.decode("{\"appName\":\"StockChef\",\"version\":\"1.0\",\"exportDate\":\"2026-01-01T00:00:00Z\",\"inventory\":[]}")
        assertTrue(backup.shoppingList.isEmpty())
        assertTrue(backup.mealPlan.isEmpty())
    }
    @Test fun expiryEstimateIsConservative() {
        assertTrue(FoodCategory.MEAT.days < FoodCategory.GROCERY.days)
        assertEquals(4, FoodCategory.VEGETABLE.days.toInt())
    }
    @Test fun completeCatalogHasEveryCourseAndStableIds() {
        assertEquals(19, RecipeCatalog.recipes.size)
        assertEquals(RecipeCourse.entries.toSet(), RecipeCatalog.recipes.map { it.course }.toSet())
        assertEquals(19, RecipeCatalog.recipes.map { it.id }.distinct().size)
        assertTrue(RecipeCatalog.recipes.all { it.ingredients.isNotEmpty() && it.instructions.isNotEmpty() })
    }
    @Test fun remoteCatalogRoundTripsAndRejectsInvalidUpdates() {
        fun decode(recipes: List<Recipe>, version: Int = 1) = RecipeFeedCodec.decode(BackupCodec.json.encodeToString(RecipeFeed(version, recipes)))
        assertEquals(RecipeCatalog.recipes, decode(RecipeCatalog.recipes))
        assertFailsWith<IllegalArgumentException> { decode(emptyList()) }
        assertFailsWith<IllegalArgumentException> { decode(RecipeCatalog.recipes, 3) }
        val first = RecipeCatalog.recipes.first()
        assertFailsWith<IllegalArgumentException> { decode(listOf(first, first)) }
        assertFailsWith<IllegalArgumentException> { decode(listOf(first.copy(baseServings = 0))) }
        assertFailsWith<IllegalArgumentException> { decode(listOf(first.copy(allergens = setOf("Inconnu")))) }
    }
    @Test fun websiteCatalogIsCompatibleWithAndroid() {
        val path = System.getProperty("stockchef.recipeFeed") ?: return
        val recipes = RecipeFeedCodec.decode(java.io.File(path).readText(Charsets.UTF_8))
        assertTrue(recipes.isNotEmpty())
        assertEquals(recipes.size, recipes.map { it.id }.distinct().size)
    }
    @Test fun recipeAttributionSurvivesAndUnsafeSourceIsRejected() {
        val source = RecipeSource("Wikilivres", "https://fr.wikibooks.org/wiki/Livre_de_cuisine/Ratatouille", "CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/", "Contributeurs de Wikilivres", "Etapes adaptees")
        val recipe = RecipeCatalog.recipes.first().copy(source = source)
        fun decode(value: Recipe) = RecipeFeedCodec.decode(BackupCodec.json.encodeToString(RecipeFeed(2, listOf(value)))).single()
        assertEquals(source, decode(recipe).source)
        assertFailsWith<IllegalArgumentException> { RecipeFeedCodec.decode(BackupCodec.json.encodeToString(RecipeFeed(1, listOf(recipe)))) }
        assertFailsWith<IllegalArgumentException> { decode(recipe.copy(source = source.copy(url = "javascript:alert(1)"))) }
        assertFailsWith<IllegalArgumentException> { decode(recipe.copy(source = source.copy(licenseURL = "http://example.com"))) }
        assertFailsWith<IllegalArgumentException> { decode(recipe.copy(source = source.copy(attribution = ""))) }
    }
}