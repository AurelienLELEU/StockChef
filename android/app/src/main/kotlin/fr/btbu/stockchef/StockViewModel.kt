package fr.btbu.stockchef

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import fr.btbu.stockchef.core.*
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

data class StockState(val backup: Backup? = null, val license: License = License(), val busy: Boolean = false, val message: String? = null, val receipt: List<InventoryItem>? = null, val receiptUsesCredit: Boolean = false, val importPreview: Backup? = null, val recipes: List<Recipe> = RecipeCatalog.recipes)

class StockViewModel(application: Application) : AndroidViewModel(application) {
    private val database = StockDatabase(application)
    private val recipeRepository = RecipeRepository(application)
    private val recipeMutex = Mutex()
    private var recipesLoaded = false
    private var lastRecipeAttempt = 0L
    private val mutable = MutableStateFlow(StockState())
    val state = mutable.asStateFlow()
    private val mutex = Mutex()
    init { load() }
    fun refreshRecipes() = viewModelScope.launch {
        if (!recipeMutex.tryLock()) return@launch
        try {
            if (!recipesLoaded) {
                val cached = withContext(Dispatchers.IO) { recipeRepository.cached() }
                mutable.update { it.copy(recipes = cached) }
                recipesLoaded = true
            }
            val time = android.os.SystemClock.elapsedRealtime()
            if (lastRecipeAttempt != 0L && time - lastRecipeAttempt < 900_000) return@launch
            lastRecipeAttempt = time
            val recipes = withContext(Dispatchers.IO) { recipeRepository.refresh() }
            mutable.update { it.copy(recipes = recipes) }
        } catch (error: CancellationException) { throw error }
        catch (_: Exception) { }
        finally { recipeMutex.unlock() }
    }
    fun load() = operation { current -> val (backup, license) = database.load(); current.copy(backup = backup, license = license) }
    private fun operation(done: () -> Unit = {}, action: suspend (StockState) -> StockState) {
        viewModelScope.launch { mutex.withLock {
            val current = mutable.value
            mutable.value = current.copy(busy = true, message = null)
            try { mutable.value = withContext(Dispatchers.IO) { action(current) }.copy(busy = false, recipes = mutable.value.recipes); done() }
            catch (error: Exception) { mutable.value = current.copy(busy = false, recipes = mutable.value.recipes, message = error.message ?: "Opération impossible. Les données ont été conservées.") }
        } }
    }
    private fun change(done: () -> Unit = {}, transform: (Backup) -> Backup) = operation(done) { current ->
        val backup = transform(requireNotNull(current.backup))
        BackupCodec.decode(BackupCodec.encode(backup))
        database.save(backup, current.license)
        current.copy(backup = backup)
    }
    fun saveItem(item: InventoryItem, done: () -> Unit) = change(done) { backup ->
        require(item.name.isNotBlank() && item.quantity.isFinite() && item.quantity > 0) { "Vérifiez le nom et la quantité." }
        backup.copy(inventory = backup.inventory.filterNot { it.id == item.id } + item)
    }
    fun deleteItem(id: String, done: () -> Unit) = change(done) { it.copy(inventory = it.inventory.filterNot { item -> item.id == id }) }
    fun cook(recipe: Recipe, servings: Int, done: () -> Unit) = change(done) { it.copy(inventory = RecipeMatcher.cook(recipe, servings, it.inventory)) }
    fun addMissing(recipe: Recipe, servings: Int) = change { RecipeMatcher.addMissing(it, RecipeMatcher.match(recipe, it.inventory, servings).missing) }
    fun saveShopping(item: ShoppingItem, done: () -> Unit) = change(done) { backup -> backup.copy(shoppingList = backup.shoppingList.filterNot { it.id == item.id } + item) }
    fun toggleShopping(id: String) = change { backup -> backup.copy(shoppingList = backup.shoppingList.map { if (it.id == id) it.copy(isChecked = !it.isChecked) else it }) }
    fun deleteShopping(id: String) = change { it.copy(shoppingList = it.shoppingList.filterNot { item -> item.id == id }) }
    fun schedule(entry: MealPlanEntry, done: () -> Unit) = change(done) { backup -> backup.copy(mealPlan = backup.mealPlan.filterNot { it.date.take(10) == entry.date.take(10) && it.slot == entry.slot } + entry) }
    fun deletePlan(id: String) = change { it.copy(mealPlan = it.mealPlan.filterNot { item -> item.id == id }) }
    fun textReceipt(text: String) = operation { current ->
        require(text.length <= 200_000) { "Texte de ticket trop long." }
        val lines = ReceiptParser.parse(text)
        require(lines.isNotEmpty()) { "Aucun aliment reconnu. Corrigez le texte ou ajoutez un aliment manuellement." }
        current.copy(receipt = lines, receiptUsesCredit = false)
    }
    fun photoReceipt(uri: Uri) = operation { current ->
        require(current.license.remainingScanCredits > 0) { "Les cinq scans d'essai sont épuisés. L'ajout manuel reste disponible ; Google Play n'est pas encore intégré." }
        getApplication<Application>().contentResolver.openAssetFileDescriptor(uri, "r")?.use { require(it.length < 0 || it.length <= 20_000_000) { "Image trop volumineuse (20 Mo maximum)." } }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            val image = InputImage.fromFilePath(getApplication(), uri)
            val text = recognizer.process(image).await().text
            val lines = ReceiptParser.parse(text)
            require(lines.isNotEmpty()) { "Aucun aliment reconnu sur cette photo. Aucun crédit n'a été utilisé." }
            current.copy(receipt = lines, receiptUsesCredit = true)
        } finally { recognizer.close() }
    }
    fun confirmReceipt(lines: List<InventoryItem>, done: () -> Unit) = operation(done) { current ->
        require(current.receipt != null) { "Ce ticket a déjà été ajouté ou annulé." }
        require(lines.isNotEmpty()) { "Sélectionnez au moins un aliment." }
        val license = if (current.receiptUsesCredit) {
            require(current.license.remainingScanCredits > 0)
            current.license.copy(remainingScanCredits = current.license.remainingScanCredits - 1)
        } else current.license
        val backup = requireNotNull(current.backup).let { it.copy(inventory = it.inventory + lines) }
        BackupCodec.decode(BackupCodec.encode(backup))
        database.save(backup, license)
        current.copy(backup = backup, license = license, receipt = null, receiptUsesCredit = false)
    }
    fun dismissReceipt() { mutable.value = mutable.value.copy(receipt = null, receiptUsesCredit = false) }
    fun report(message: String) { mutable.value = mutable.value.copy(message = message) }
    fun dismissMessage() { mutable.value = mutable.value.copy(message = null) }
    fun export(uri: Uri) = operation { current ->
        getApplication<Application>().contentResolver.openOutputStream(uri, "wt")?.use { it.write(BackupCodec.encode(requireNotNull(current.backup)).toByteArray(Charsets.UTF_8)) } ?: error("Impossible d'écrire le fichier.")
        current.copy(message = "Sauvegarde exportée.")
    }
    fun previewImport(uri: Uri) = operation { current ->
        val bytes = getApplication<Application>().contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                require(output.size() + count <= 10_000_000) { "Sauvegarde trop volumineuse." }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: error("Fichier illisible.")
        current.copy(importPreview = BackupCodec.decode(bytes.toString(Charsets.UTF_8)))
    }
    fun previous() = operation { it.copy(importPreview = database.previous()) }
    fun confirmImport() = operation { current ->
        val backup = requireNotNull(current.importPreview)
        database.save(backup, current.license, importing = true)
        current.copy(backup = backup, importPreview = null, receipt = null, receiptUsesCredit = false)
    }
    fun dismissImport() { mutable.value = mutable.value.copy(importPreview = null) }
    override fun onCleared() { database.close() }
}