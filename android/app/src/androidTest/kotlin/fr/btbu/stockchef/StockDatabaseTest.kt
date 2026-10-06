package fr.btbu.stockchef

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import fr.btbu.stockchef.core.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import kotlinx.serialization.encodeToString

@RunWith(AndroidJUnit4::class)
class StockDatabaseTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val name = "test-${id()}.sqlite"
    private var database = StockDatabase(context, name)

    @After fun cleanup() { database.close(); context.deleteDatabase(name) }

    @Test fun dataAndCreditsSurviveReopening() {
        val backup = Backup(inventory = listOf(InventoryItem(name = "Tomates")), shoppingList = listOf(ShoppingItem(name = "Riz")), mealPlan = listOf(MealPlanEntry(recipeID = id(), recipeTitle = "Repas", date = date())))
        database.save(backup, License(3))
        database.close()
        database = StockDatabase(context, name)
        val (restored, license) = database.load()
        assertEquals(backup.inventory, restored.inventory)
        assertEquals(backup.shoppingList, restored.shoppingList)
        assertEquals(backup.mealPlan, restored.mealPlan)
        assertEquals(3, license.remainingScanCredits)
    }

    @Test fun importKeepsPreviousStockAndCurrentCredits() {
        val previous = Backup(inventory = listOf(InventoryItem(name = "Lait")))
        database.save(previous, License(2))
        val imported = Backup(inventory = listOf(InventoryItem(name = "Tomates")))
        database.save(imported, database.load().second, importing = true)
        assertEquals(previous.inventory, database.previous().inventory)
        assertEquals(imported.inventory, database.load().first.inventory)
        assertEquals(2, database.load().second.remainingScanCredits)
    }

    @Test fun payloadLargerThanCursorWindowIsReadInChunks() {
        val backup = Backup(inventory = List(4000) { InventoryItem(name = "Tomates " + "a".repeat(600)) })
        assertTrue(BackupCodec.encode(backup).length > 2_000_000)
        database.save(backup, License())
        assertEquals(backup.inventory, database.load().first.inventory)
    }
    @Test fun invalidAndOfflineCatalogUpdatesPreserveTheCache() {
        val cacheName = "test-${id()}.json"
        val updated = listOf(RecipeCatalog.recipes.first().copy(title = "Recette mise à jour"))
        var payload = BackupCodec.json.encodeToString(RecipeFeed(1, updated))
        val repository = RecipeRepository(context, cacheName) { payload }
        try {
            assertEquals(RecipeCatalog.recipes, repository.cached())
            assertEquals(updated, repository.refresh())
            payload = "{\"schemaVersion\":2,\"recipes\":[]}"
            assertThrows(Exception::class.java) { repository.refresh() }
            assertEquals(updated, repository.cached())
            val offline = RecipeRepository(context, cacheName) { error("Hors ligne") }
            assertThrows(Exception::class.java) { offline.refresh() }
            assertEquals(updated, offline.cached())
        } finally { android.util.AtomicFile(java.io.File(context.filesDir, cacheName)).delete() }
    }
}