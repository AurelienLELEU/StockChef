package fr.btbu.stockchef.core

import java.text.Normalizer
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import java.util.Locale
import java.util.UUID
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject

fun id(): String = UUID.randomUUID().toString()
fun now(): String = Instant.now().truncatedTo(ChronoUnit.SECONDS).toString()
fun date(days: Long = 0): String = LocalDate.now().plusDays(days).atStartOfDay().toInstant(ZoneOffset.UTC).toString()
fun normalized(text: String): String = Normalizer.normalize(text.lowercase(Locale.ROOT).replace("œ", "oe"), Normalizer.Form.NFD).replace(Regex("[^a-z0-9]"), "")

@Serializable enum class StorageLocation(val title: String) { FRIDGE("Frigo"), FREEZER("Congélateur"), PANTRY("Placard") }
@Serializable enum class FoodCategory(val title: String, val days: Long, val storage: StorageLocation) {
    DAIRY("Frais", 5, StorageLocation.FRIDGE), VEGETABLE("Légumes", 4, StorageLocation.FRIDGE), MEAT("Viandes & poissons", 2, StorageLocation.FRIDGE), GROCERY("Épicerie", 30, StorageLocation.PANTRY), BEVERAGE("Boissons", 30, StorageLocation.PANTRY), BAKERY("Boulangerie", 2, StorageLocation.FRIDGE), FROZEN("Surgelés", 90, StorageLocation.FREEZER), OTHER("Autres", 14, StorageLocation.PANTRY)
}
@Serializable enum class FoodUnit(val label: String, val dimension: String, val factor: Double) {
    @SerialName("g") GRAM("g", "mass", 1.0), @SerialName("kg") KILOGRAM("kg", "mass", 1000.0), @SerialName("ml") MILLILITER("ml", "volume", 1.0), @SerialName("L") LITER("L", "volume", 1000.0), @SerialName("unités") ITEM("unités", "count", 1.0)
}
@Serializable enum class RecipeCourse(val title: String) {
    @SerialName("Entrées") STARTER("Entrées"), @SerialName("Plats") MAIN("Plats"), @SerialName("Desserts") DESSERT("Desserts"), @SerialName("Encas & à emporter") SNACK("Encas & à emporter")
}
@Serializable data class InventoryItem(
    val id: String = id(), val name: String = "", val category: FoodCategory = FoodCategory.OTHER,
    val quantity: Double = 1.0, val unit: FoodUnit = FoodUnit.ITEM,
    val expiryDate: String? = null, val addedAt: String = now(),
    val storageLocation: StorageLocation = category.storage, val isLeftover: Boolean = false, val cookedAt: String? = null,
) {
    fun expires(days: Long = 3): Boolean = expiryDate?.let { Instant.parse(it) <= Instant.parse(date(days)) } ?: false
}
@Serializable data class RecipeIngredient(val id: String = id(), val name: String, val baseQuantity: Double, val unit: FoodUnit, val isPantryStaple: Boolean = false)
@Serializable data class Recipe(
    val id: String = id(), val title: String, val baseServings: Int = 2, val prepTimeMinutes: Int,
    val instructions: List<String>, val ingredients: List<RecipeIngredient>,
    val dietaryTags: Set<String> = emptySet(), val allergens: Set<String> = emptySet(), val course: RecipeCourse = RecipeCourse.MAIN,
) {
    fun scaled(servings: Int): List<RecipeIngredient> {
        require(servings in 1..100 && baseServings > 0)
        return ingredients.map { it.copy(baseQuantity = it.baseQuantity * servings / baseServings) }
    }
}
@Serializable data class ShoppingItem(val id: String = id(), val name: String, val quantity: Double = 1.0, val unit: FoodUnit = FoodUnit.ITEM, val isChecked: Boolean = false)
@Serializable data class MealPlanEntry(val id: String = id(), val recipeID: String, val recipeTitle: String, val date: String, val slot: String = "Dîner", val servings: Int = 2)
@Serializable data class Backup(val version: String = "1.1", val appName: String = "StockChef", val exportDate: String = now(), val inventory: List<InventoryItem> = emptyList(), val shoppingList: List<ShoppingItem> = emptyList(), val mealPlan: List<MealPlanEntry> = emptyList())
@Serializable data class License(val remainingScanCredits: Int = 5)

object BackupCodec {
    val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    fun encode(backup: Backup): String = json.encodeToString(backup.copy(exportDate = now()))
    fun decode(text: String): Backup {
        require(text.toByteArray(Charsets.UTF_8).size <= 10_000_000) { "Sauvegarde trop volumineuse (10 Mo maximum)." }
        val tree = json.parseToJsonElement(text).jsonObject
        require(listOf("inventory", "appName", "version", "exportDate").all(tree::containsKey)) { "Métadonnées ou inventaire absents de la sauvegarde." }
        val backup = json.decodeFromString<Backup>(text)
        require(backup.appName == "StockChef" && backup.version in listOf("1.0", "1.1")) { "Sauvegarde StockChef incompatible." }
        Instant.parse(backup.exportDate)
        require(backup.inventory.map { it.id }.distinct().size == backup.inventory.size)
        require(backup.shoppingList.map { it.id }.distinct().size == backup.shoppingList.size)
        require(backup.mealPlan.map { it.id }.distinct().size == backup.mealPlan.size)
        backup.inventory.forEach { item ->
            require(item.name.isNotBlank() && item.quantity.isFinite() && item.quantity > 0) { "Aliment invalide dans la sauvegarde." }
            item.expiryDate?.let(Instant::parse)
            item.cookedAt?.let(Instant::parse)
            Instant.parse(item.addedAt)
        }
        backup.shoppingList.forEach { require(it.name.isNotBlank() && it.quantity.isFinite() && it.quantity > 0) }
        backup.mealPlan.forEach { require(it.servings in 1..100 && it.slot in listOf("Déjeuner", "Dîner")); Instant.parse(it.date) }
        return backup
    }
}

data class RecipeMatch(val recipe: Recipe, val missing: List<RecipeIngredient>, val score: Double) { val cookable: Boolean get() = missing.isEmpty() }

object RecipeMatcher {
    private fun key(name: String, unit: FoodUnit): String = normalized(name) + ":" + unit.dimension
    private fun requirements(recipe: Recipe, servings: Int): List<RecipeIngredient> = recipe.scaled(servings).filterNot { it.isPantryStaple }.groupBy { key(it.name, it.unit) }.values.map { group -> group.first().copy(baseQuantity = group.sumOf { it.baseQuantity * it.unit.factor } / group.first().unit.factor) }

    fun match(recipe: Recipe, inventory: List<InventoryItem>, servings: Int): RecipeMatch {
        val required = requirements(recipe, servings)
        val missing = required.mapNotNull { ingredient ->
            val available = inventory.filter { key(it.name, it.unit) == key(ingredient.name, ingredient.unit) }.sumOf { it.quantity * it.unit.factor }
            val shortfall = ingredient.baseQuantity * ingredient.unit.factor - available
            if (shortfall > 0.0001) ingredient.copy(baseQuantity = shortfall / ingredient.unit.factor) else null
        }
        return RecipeMatch(recipe, missing, if (required.isEmpty()) 0.0 else (required.size - missing.size).toDouble() / required.size)
    }

    fun cook(recipe: Recipe, servings: Int, inventory: List<InventoryItem>): List<InventoryItem> {
        require(match(recipe, inventory, servings).cookable) { "Il manque des ingrédients pour ces portions." }
        val remaining = inventory.toMutableList()
        requirements(recipe, servings).forEach { ingredient ->
            var needed = ingredient.baseQuantity * ingredient.unit.factor
            val candidates = remaining.filter { key(it.name, it.unit) == key(ingredient.name, ingredient.unit) }.sortedBy { it.expiryDate ?: "9999" }
            candidates.forEach { item ->
                if (needed > 0.0001) {
                    val used = minOf(item.quantity * item.unit.factor, needed)
                    needed -= used
                    val quantity = item.quantity - used / item.unit.factor
                    val index = remaining.indexOfFirst { it.id == item.id }
                    if (quantity <= 0.0001) remaining.removeAt(index) else remaining[index] = item.copy(quantity = quantity)
                }
            }
        }
        return remaining
    }

    fun addMissing(backup: Backup, ingredients: List<RecipeIngredient>): Backup {
        val shopping = backup.shoppingList.toMutableList()
        ingredients.filterNot { it.isPantryStaple }.forEach { ingredient ->
            val index = shopping.indexOfFirst { normalized(it.name) == normalized(ingredient.name) && it.unit == ingredient.unit && !it.isChecked }
            if (index < 0) shopping += ShoppingItem(name = ingredient.name, quantity = ingredient.baseQuantity, unit = ingredient.unit)
            else shopping[index] = shopping[index].copy(quantity = shopping[index].quantity + ingredient.baseQuantity)
        }
        return backup.copy(shoppingList = shopping)
    }
}