package fr.btbu.stockchef

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.btbu.stockchef.core.*
import java.io.File
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Locale
import kotlinx.serialization.encodeToString

private val palette = lightColorScheme(
    primary = Color(0xFF17694C), onPrimary = Color.White,
    primaryContainer = Color(0xFFE3F1E8), onPrimaryContainer = Color(0xFF153D2D),
    secondary = Color(0xFFAC492D), onSecondary = Color.White,
    secondaryContainer = Color(0xFFFFEDE6), onSecondaryContainer = Color(0xFF75301E),
    tertiary = Color(0xFF426C83),
    background = Color(0xFFF3F5F4), onBackground = Color(0xFF202B26),
    surface = Color.White, onSurface = Color(0xFF202B26),
    surfaceVariant = Color(0xFFEBEFEC), onSurfaceVariant = Color(0xFF59665F),
    surfaceContainer = Color.White, surfaceContainerHigh = Color(0xFFF3F5F4),
    surfaceContainerHighest = Color(0xFFEBEFEC), outline = Color(0xFF78857D),
    outlineVariant = Color(0xFFDCE3DE), surfaceTint = Color.Transparent,
)
private val stockTypography = Typography(
    titleLarge = Typography().titleLarge.copy(fontWeight = FontWeight.Bold, fontSize = 23.sp, letterSpacing = 0.sp),
    titleMedium = Typography().titleMedium.copy(fontWeight = FontWeight.SemiBold, letterSpacing = 0.sp),
    labelLarge = Typography().labelLarge.copy(letterSpacing = 0.sp),
    labelMedium = Typography().labelMedium.copy(letterSpacing = 0.sp),
)
private fun quantity(value: Double) = String.format(Locale.FRANCE, "%.2f", value).trimEnd('0').trimEnd(',')

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StockChefApp(model: StockViewModel = viewModel()) {
    val state by model.state.collectAsStateWithLifecycle()
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(model, lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_START) model.refreshRecipes() }
        lifecycleOwner.lifecycle.addObserver(observer)
        model.refreshRecipes()
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    var route by rememberSaveable { mutableStateOf("stock") }
    var selectedId by rememberSaveable { mutableStateOf("") }
    var selectedRecipeJson by rememberSaveable { mutableStateOf("") }
    var discard by remember { mutableStateOf(false) }
    var cameraUri by rememberSaveable { mutableStateOf("") }
    val context = LocalContext.current
    val roots = listOf("stock", "scan", "recipes", "shopping", "more")
    val back = { route = "stock" }
    val editing = route == "item"
    BackHandler(route !in roots) { if (editing) discard = true else back() }
    val photo = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri -> uri?.let(model::photoReceipt) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success -> if (success && cameraUri.isNotBlank()) model.photoReceipt(Uri.parse(cameraUri)) }
    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri -> uri?.let(model::export) }
    val import = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> uri?.let(model::previewImport) }
    val backup = state.backup
    MaterialTheme(colorScheme = palette, typography = stockTypography, shapes = Shapes(small = RoundedCornerShape(8.dp), medium = RoundedCornerShape(8.dp))) {
        Scaffold(containerColor = palette.background, topBar = { CenterAlignedTopAppBar(title = { Text(when (route) { "recipes" -> "Recettes"; "scan" -> "Tickets"; "shopping" -> "Courses"; "more" -> "Planning et réglages"; "item" -> "Aliment"; "recipe" -> "Recette"; else -> "StockChef" }, style = MaterialTheme.typography.titleLarge) }, colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = palette.surface), navigationIcon = { if (route !in roots) IconButton(onClick = { if (editing) discard = true else back() }, enabled = !state.busy) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Retour") } }) },
            bottomBar = { if (route in roots) NavigationBar(containerColor = palette.surface, tonalElevation = 0.dp) {
                listOf(Triple("stock", "Stock", Icons.Default.Kitchen), Triple("scan", "Tickets", Icons.Default.DocumentScanner), Triple("recipes", "Recettes", Icons.Default.RestaurantMenu), Triple("shopping", "Courses", Icons.Default.ShoppingBasket), Triple("more", "Plus", Icons.Default.MoreHoriz)).forEach { (destination, label, icon) -> NavigationBarItem(route == destination, { route = destination }, icon = { Icon(icon, label) }, label = { Text(label, maxLines = 1) }, enabled = !state.busy) }
            } }, floatingActionButton = { if (route == "stock" && backup != null && !state.busy) FloatingActionButton(onClick = { selectedId = ""; route = "item" }) { Icon(Icons.Default.Add, "Ajouter un aliment") } }) { padding ->
            Column(Modifier.fillMaxSize().padding(padding).imePadding()) {
                if (state.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                if (backup == null) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { if (state.busy) CircularProgressIndicator() else Button(onClick = model::load) { Text("Réessayer") } }
                else when (route) {
                    "stock" -> Inventory(backup) { selectedId = it.id; route = "item" }
                    "item" -> ItemEditor(backup.inventory.find { it.id == selectedId }, state.busy, onSave = { model.saveItem(it, back) }, onDelete = { model.deleteItem(it, back) })
                    "recipes" -> Recipes(backup, state.recipes) { selectedId = it.id; selectedRecipeJson = BackupCodec.json.encodeToString(it); route = "recipe" }
                    "recipe" -> runCatching { BackupCodec.json.decodeFromString<Recipe>(selectedRecipeJson) }.getOrNull()?.let { recipe -> RecipeDetail(recipe, backup, state.busy, onCook = { model.cook(recipe, it, back) }, onMissing = { model.addMissing(recipe, it) }, onPlan = { model.schedule(it) { route = "more" } }) }
                    "shopping" -> Shopping(backup, state.busy, model)
                    "scan" -> Scan(state, onPhoto = { photo.launch("image/*") }, onCamera = {
                        runCatching {
                            val directory = File(context.cacheDir, "receipts").apply { mkdirs() }
                            directory.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86_400_000 }?.forEach { it.delete() }
                            val file = File.createTempFile("ticket-", ".jpg", directory)
                            val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
                            cameraUri = uri.toString(); camera.launch(uri)
                        }.onFailure { model.report("Aucun appareil photo disponible. Importez une image du ticket.") }
                    }, onText = model::textReceipt)
                    "more" -> More(state, onExport = { export.launch("StockChef-${LocalDate.now()}.json") }, onImport = { import.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }, onPrevious = model::previous, onDeletePlan = model::deletePlan)
                }
            }
        }
        state.message?.let { text -> AlertDialog(onDismissRequest = model::dismissMessage, text = { Text(text) }, confirmButton = { TextButton(onClick = model::dismissMessage) { Text("Fermer") } }) }
        state.receipt?.let { lines -> ReceiptReview(lines, state.busy, model::dismissReceipt) { model.confirmReceipt(it, back) } }
        state.importPreview?.let { preview -> AlertDialog(onDismissRequest = model::dismissImport, title = { Text("Restaurer cette sauvegarde ?") }, text = { Text("${preview.inventory.size} aliments · ${preview.shoppingList.size} courses · ${preview.mealPlan.size} repas.\n\nL'inventaire actuel sera remplacé. Une copie avant import sera conservée. Les crédits de scan ne sont pas importés.") }, dismissButton = { TextButton(onClick = model::dismissImport, enabled = !state.busy) { Text("Annuler") } }, confirmButton = { TextButton(onClick = model::confirmImport, enabled = !state.busy) { Text("Restaurer") } }) }
        if (discard) AlertDialog(onDismissRequest = { discard = false }, title = { Text("Quitter sans enregistrer ?") }, dismissButton = { TextButton(onClick = { discard = false }) { Text("Continuer") } }, confirmButton = { TextButton(onClick = { discard = false; back() }) { Text("Quitter") } })
    }
}

@Composable private fun Field(label: String, value: String, multiline: Boolean = false, change: (String) -> Unit) {
    OutlinedTextField(value, change, Modifier.fillMaxWidth(), label = { Text(label) }, singleLine = !multiline, minLines = if (multiline) 3 else 1)
}
@Composable private fun Amount(initial: Double, change: (Double?) -> Unit) {
    var text by rememberSaveable { mutableStateOf(quantity(initial)) }
    val parsed = text.replace(',', '.').toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 }
    LaunchedEffect(text) { change(parsed) }
    OutlinedTextField(text, { if (it.length <= 12 && Regex("[0-9]*([.,][0-9]*)?").matches(it)) text = it }, Modifier.fillMaxWidth(), label = { Text("Quantité") }, singleLine = true, isError = parsed == null, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
}
@Composable private fun Section(title: String) { Text(title, Modifier.padding(top = 12.dp), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold) }
@Composable private fun Chips(options: List<String>, selected: String, choose: (Int) -> Unit) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) { items(options.size) { index -> FilterChip(options[index] == selected, { choose(index) }, label = { Text(options[index]) }) } }
}
@Composable private fun Inventory(backup: Backup, open: (InventoryItem) -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    var storage by rememberSaveable { mutableStateOf("Tous") }
    var urgent by rememberSaveable { mutableStateOf(false) }
    val shown = backup.inventory.filter { it.name.contains(search, true) && (storage == "Tous" || it.storageLocation.title == storage) && (!urgent || it.expires()) }.sortedBy { it.expiryDate ?: "9999" }
    LazyColumn(contentPadding = PaddingValues(16.dp, 8.dp, 16.dp, 96.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { Row(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.weight(1f)) { Icon(Icons.Default.Kitchen, null, tint = palette.primary); Text(backup.inventory.size.toString(), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold); Text("Aliments en stock", style = MaterialTheme.typography.bodySmall, color = palette.onSurfaceVariant) }
            Column(Modifier.weight(1f)) { Icon(Icons.Default.Schedule, null, tint = palette.secondary); Text(backup.inventory.count { it.expires() }.toString(), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = palette.secondary); Text("À utiliser bientôt", style = MaterialTheme.typography.bodySmall, color = palette.onSurfaceVariant) }
        } }
        item { OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth(), placeholder = { Text("Rechercher un aliment") }, leadingIcon = { Icon(Icons.Default.Search, null) }, singleLine = true, shape = RoundedCornerShape(8.dp)) }
        item { Chips(listOf("Tous") + StorageLocation.entries.map { it.title }, storage) { storage = (listOf("Tous") + StorageLocation.entries.map { it.title })[it] } }
        item { FilterChip(urgent, { urgent = !urgent }, label = { Text("À utiliser sous 3 jours") }, leadingIcon = { Icon(Icons.Default.Schedule, null, Modifier.size(18.dp)) }) }
        if (shown.isEmpty()) item { Column(Modifier.fillMaxWidth().padding(vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) { Icon(Icons.Default.Kitchen, null, Modifier.size(40.dp), tint = palette.onSurfaceVariant); Text(if (backup.inventory.isEmpty()) "Votre stock est vide" else "Aucun aliment correspondant", style = MaterialTheme.typography.titleMedium) } }
        items(shown, key = { it.id }) { item -> Card(onClick = { open(item) }, modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = palette.surface), shape = RoundedCornerShape(8.dp)) {
            Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Surface(color = if (item.expires()) palette.secondaryContainer else palette.primaryContainer, shape = RoundedCornerShape(8.dp)) { Icon(if (item.isLeftover) Icons.Default.Restaurant else Icons.Default.Kitchen, null, Modifier.padding(10.dp).size(24.dp), tint = if (item.expires()) palette.secondary else palette.primary) }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) { Text(item.name, style = MaterialTheme.typography.titleMedium); Text("${quantity(item.quantity)} ${item.unit.label} · ${item.storageLocation.title}${if (item.isLeftover) " · Restes" else ""}", style = MaterialTheme.typography.bodySmall, color = palette.onSurfaceVariant); item.expiryDate?.let { Text("Date : ${it.take(10)}", style = MaterialTheme.typography.labelMedium, color = if (item.expires()) palette.secondary else palette.onSurfaceVariant) } }
                Icon(Icons.Default.ChevronRight, null, tint = palette.onSurfaceVariant)
            }
        } }
    }
}
@Composable private fun ItemEditor(initial: InventoryItem?, busy: Boolean, onSave: (InventoryItem) -> Unit, onDelete: (String) -> Unit) {
    val saver = Saver<InventoryItem, String>(save = { BackupCodec.json.encodeToString(it) }, restore = { BackupCodec.json.decodeFromString(it) })
    var item by rememberSaveable(initial?.id, stateSaver = saver) { mutableStateOf(initial ?: InventoryItem()) }
    var amountValid by remember { mutableStateOf(true) }
    var expiry by rememberSaveable { mutableStateOf(item.expiryDate?.take(10).orEmpty()) }
    var confirm by remember { mutableStateOf(false) }
    val expiryDay = runCatching { LocalDate.parse(expiry) }.getOrNull()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Field("Nom", item.name) { item = item.copy(name = it) }
        Amount(item.quantity) { amountValid = it != null; if (it != null) item = item.copy(quantity = it) }
        Chips(FoodUnit.entries.map { it.label }, item.unit.label) { item = item.copy(unit = FoodUnit.entries[it]) }
        Section("Catégorie")
        Chips(FoodCategory.entries.map { it.title }, item.category.title) { val category = FoodCategory.entries[it]; item = item.copy(category = category, storageLocation = category.storage) }
        Section("Rangement")
        Chips(StorageLocation.entries.map { it.title }, item.storageLocation.title) { item = item.copy(storageLocation = StorageLocation.entries[it]) }
        Row(verticalAlignment = Alignment.CenterVertically) { Text("Restes cuisinés", Modifier.weight(1f)); Switch(item.isLeftover, { item = item.copy(isLeftover = it, cookedAt = if (it) now() else null); if (it && expiry.isBlank()) expiry = date(if (item.storageLocation == StorageLocation.FREEZER) 90 else 2).take(10) }) }
        OutlinedTextField(expiry, { expiry = it }, Modifier.fillMaxWidth(), label = { Text("Date limite (AAAA-MM-JJ, facultatif)") }, singleLine = true, isError = expiry.isNotBlank() && expiryDay == null)
        Button(onClick = { onSave(item.copy(expiryDate = expiryDay?.atStartOfDay()?.toInstant(ZoneOffset.UTC)?.toString())) }, enabled = !busy && amountValid && item.name.isNotBlank() && (expiry.isBlank() || expiryDay != null), modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.Save, null); Spacer(Modifier.width(8.dp)); Text("Enregistrer") }
        if (initial != null) TextButton(onClick = { confirm = true }, enabled = !busy) { Icon(Icons.Default.Delete, null); Text("Supprimer l'aliment") }
    }
    if (confirm) AlertDialog(onDismissRequest = { confirm = false }, title = { Text("Supprimer cet aliment ?") }, dismissButton = { TextButton(onClick = { confirm = false }) { Text("Annuler") } }, confirmButton = { TextButton(onClick = { onDelete(item.id); confirm = false }) { Text("Supprimer") } })
}
@Composable private fun Recipes(backup: Backup, recipes: List<Recipe>, open: (Recipe) -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    var course by rememberSaveable { mutableStateOf("Tous") }
    var tag by rememberSaveable { mutableStateOf("Tous") }
    var allergen by rememberSaveable { mutableStateOf("Aucun") }
    val matches = recipes.filter { (search.isBlank() || it.title.contains(search, true) || it.ingredients.any { ingredient -> ingredient.name.contains(search, true) }) && (course == "Tous" || it.course.title == course) && (tag == "Tous" || tag in it.dietaryTags) && (allergen == "Aucun" || allergen !in it.allergens) }.map { RecipeMatcher.match(it, backup.inventory, 2) }.sortedWith(compareByDescending<RecipeMatch> { it.score }.thenBy { it.recipe.prepTimeMinutes })
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth(), placeholder = { Text("Recette ou ingrédient") }, leadingIcon = { Icon(Icons.Default.Search, null) }, singleLine = true, shape = RoundedCornerShape(8.dp)) }
        item { Chips(listOf("Tous") + RecipeCourse.entries.map { it.title }, course) { course = (listOf("Tous") + RecipeCourse.entries.map { it.title })[it] } }
        item { Chips(listOf("Tous", "Végétarien", "Vegan", "Sans gluten"), tag) { tag = listOf("Tous", "Végétarien", "Vegan", "Sans gluten")[it] } }
        item { Text("Exclure un allergène", style = MaterialTheme.typography.labelMedium); Chips(listOf("Aucun", "Gluten", "Lait", "Œuf", "Poisson", "Fruits à coque"), allergen) { allergen = listOf("Aucun", "Gluten", "Lait", "Œuf", "Poisson", "Fruits à coque")[it] } }
        item { Text("${matches.size} recettes", style = MaterialTheme.typography.labelMedium, color = palette.onSurfaceVariant, modifier = Modifier.padding(vertical = 8.dp)) }
        if (matches.isEmpty()) item { Text("Aucune recette correspondante", Modifier.padding(vertical = 24.dp)) }
        items(matches, key = { it.recipe.id }) { match -> Card(onClick = { open(match.recipe) }, modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = palette.surface), shape = RoundedCornerShape(8.dp)) {
            Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Surface(color = palette.primaryContainer, shape = RoundedCornerShape(8.dp)) { Icon(Icons.Default.RestaurantMenu, null, Modifier.padding(10.dp).size(24.dp), tint = palette.primary) }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(match.recipe.title, style = MaterialTheme.typography.titleMedium); Text("${match.recipe.prepTimeMinutes} min · ${match.recipe.course.title}", style = MaterialTheme.typography.bodySmall, color = palette.onSurfaceVariant); Text(if (match.cookable) "Prêt à cuisiner" else "${match.missing.size} ingrédient(s) manquant(s)", color = if (match.cookable) palette.primary else palette.secondary, style = MaterialTheme.typography.labelMedium) }
                Icon(Icons.Default.ChevronRight, null, tint = palette.onSurfaceVariant)
            }
        } }
    }
}
@Composable private fun RecipeDetail(recipe: Recipe, backup: Backup, busy: Boolean, onCook: (Int) -> Unit, onMissing: (Int) -> Unit, onPlan: (MealPlanEntry) -> Unit) {
    val uriHandler = LocalUriHandler.current
    var servings by rememberSaveable(recipe.id) { mutableIntStateOf(2) }
    var confirm by remember { mutableStateOf(false) }
    var plan by remember { mutableStateOf(false) }
    val match = RecipeMatcher.match(recipe, backup.inventory, servings)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(recipe.title, style = MaterialTheme.typography.titleLarge)
        Text("${recipe.prepTimeMinutes} min · ${recipe.course.title}")
        if (recipe.allergens.isNotEmpty()) Text("Allergènes : ${recipe.allergens.joinToString()}", color = palette.primary)
        Row(verticalAlignment = Alignment.CenterVertically) { Text("Portions", Modifier.weight(1f)); IconButton(onClick = { servings-- }, enabled = servings > 1) { Icon(Icons.Default.Remove, "Moins de portions") }; Text(servings.toString()); IconButton(onClick = { servings++ }, enabled = servings < 100) { Icon(Icons.Default.Add, "Plus de portions") } }
        Section("Ingrédients")
        recipe.scaled(servings).forEach { Text("${it.name} · ${quantity(it.baseQuantity)} ${it.unit.label}${if (it.isPantryStaple) " · Fond de placard" else ""}") }
        Section("Préparation")
        recipe.instructions.forEachIndexed { index, instruction -> Text("${index + 1}. $instruction") }
        recipe.source?.let { source ->
            HorizontalDivider()
            Section("Source et licence")
            Text(source.attribution, style = MaterialTheme.typography.bodySmall, color = palette.onSurfaceVariant)
            Text(source.changes, style = MaterialTheme.typography.bodySmall, color = palette.onSurfaceVariant)
            TextButton(onClick = { uriHandler.openUri(source.url) }) { Icon(Icons.AutoMirrored.Filled.OpenInNew, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text(source.name) }
            TextButton(onClick = { uriHandler.openUri(source.licenseURL) }) { Icon(Icons.Default.Info, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text(source.license) }
        }
        Button(onClick = { confirm = true }, enabled = !busy && match.cookable, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.Restaurant, null); Spacer(Modifier.width(8.dp)); Text("Cuisiner et déduire du stock") }
        if (!match.cookable) OutlinedButton(onClick = { onMissing(servings) }, enabled = !busy, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.ShoppingBasket, null); Spacer(Modifier.width(8.dp)); Text("Ajouter les manquants aux courses") }
        OutlinedButton(onClick = { plan = true }, enabled = !busy, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.CalendarMonth, null); Spacer(Modifier.width(8.dp)); Text("Planifier ce repas") }
    }
    if (confirm) AlertDialog(onDismissRequest = { confirm = false }, title = { Text("Déduire les ingrédients du stock ?") }, text = { Text("${recipe.title} · $servings portions") }, dismissButton = { TextButton(onClick = { confirm = false }) { Text("Annuler") } }, confirmButton = { TextButton(onClick = { onCook(servings); confirm = false }) { Text("Cuisiner") } })
    if (plan) PlanDialog(recipe, servings, { plan = false }) { onPlan(it); plan = false }
}
@Composable private fun PlanDialog(recipe: Recipe, servings: Int, dismiss: () -> Unit, save: (MealPlanEntry) -> Unit) {
    var day by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    var slot by rememberSaveable { mutableStateOf("Dîner") }
    val parsed = runCatching { LocalDate.parse(day) }.getOrNull()
    AlertDialog(onDismissRequest = dismiss, title = { Text("Planifier") }, text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { Field("Date (AAAA-MM-JJ)", day) { day = it }; Chips(listOf("Déjeuner", "Dîner"), slot) { slot = listOf("Déjeuner", "Dîner")[it] } } }, dismissButton = { TextButton(onClick = dismiss) { Text("Annuler") } }, confirmButton = { TextButton(onClick = { save(MealPlanEntry(recipeID = recipe.id, recipeTitle = recipe.title, date = parsed!!.atStartOfDay().toInstant(ZoneOffset.UTC).toString(), slot = slot, servings = servings)) }, enabled = parsed != null) { Text("Planifier") } })
}
@Composable private fun Shopping(backup: Backup, busy: Boolean, model: StockViewModel) {
    var add by remember { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var amount by remember { mutableStateOf<Double?>(1.0) }
    var unit by rememberSaveable { mutableStateOf(FoodUnit.ITEM) }
    LazyColumn(contentPadding = PaddingValues(16.dp)) {
        item { OutlinedButton(onClick = { add = true }, enabled = !busy, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.Add, null); Text("Ajouter aux courses") } }
        if (backup.shoppingList.isEmpty()) item { Text("La liste de courses est vide.", Modifier.padding(vertical = 24.dp)) }
        items(backup.shoppingList.sortedBy { it.isChecked }, key = { it.id }) { item -> ListItem(headlineContent = { Text(item.name) }, supportingContent = { Text("${quantity(item.quantity)} ${item.unit.label}") }, leadingContent = { Checkbox(item.isChecked, { model.toggleShopping(item.id) }, enabled = !busy) }, trailingContent = { IconButton(onClick = { model.deleteShopping(item.id) }, enabled = !busy) { Icon(Icons.Default.Delete, "Supprimer la course") } }) }
    }
    if (add) AlertDialog(onDismissRequest = { add = false }, title = { Text("Course") }, text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { Field("Nom", name) { name = it }; Amount(1.0) { amount = it }; Chips(FoodUnit.entries.map { it.label }, unit.label) { unit = FoodUnit.entries[it] } } }, dismissButton = { TextButton(onClick = { add = false }) { Text("Annuler") } }, confirmButton = { TextButton(onClick = { model.saveShopping(ShoppingItem(name = name, quantity = amount!!, unit = unit)) { add = false; name = "" } }, enabled = !busy && name.isNotBlank() && amount != null) { Text("Ajouter") } })
}
@Composable private fun Scan(state: StockState, onPhoto: () -> Unit, onCamera: () -> Unit, onText: (String) -> Unit) {
    var text by rememberSaveable { mutableStateOf("") }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("${state.license.remainingScanCredits} scans d'essai disponibles", style = MaterialTheme.typography.titleMedium)
        Button(onClick = onCamera, enabled = !state.busy && state.license.remainingScanCredits > 0, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.CameraAlt, null); Spacer(Modifier.width(8.dp)); Text("Photographier le ticket") }
        OutlinedButton(onClick = onPhoto, enabled = !state.busy && state.license.remainingScanCredits > 0, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.PhotoLibrary, null); Spacer(Modifier.width(8.dp)); Text("Importer une photo") }
        Section("Texte du ticket")
        Field("Ticket", text, true) { text = it }
        OutlinedButton(onClick = { onText(text) }, enabled = !state.busy && text.isNotBlank(), modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.Checklist, null); Spacer(Modifier.width(8.dp)); Text("Préparer les aliments") }
    }
}
private data class ReceiptDraft(val item: InventoryItem, val name: String = item.name, val amount: String = item.quantity.toString(), val expiry: String = item.expiryDate?.take(10).orEmpty()) {
    fun validated(): InventoryItem? = runCatching {
        val parsedAmount = amount.replace(',', '.').toDouble()
        require(name.isNotBlank() && parsedAmount.isFinite() && parsedAmount > 0)
        item.copy(name = name.trim(), quantity = parsedAmount, expiryDate = expiry.takeIf { it.isNotBlank() }?.let { LocalDate.parse(it).atStartOfDay().toInstant(ZoneOffset.UTC).toString() })
    }.getOrNull()
}
@Composable private fun ReceiptReview(initial: List<InventoryItem>, busy: Boolean, dismiss: () -> Unit, confirm: (List<InventoryItem>) -> Unit) {
    var lines by remember(initial) { mutableStateOf(initial.map { ReceiptDraft(it) }) }
    val validated = lines.map { it.validated() }
    AlertDialog(onDismissRequest = { if (!busy) dismiss() }, title = { Text("Vérifier les aliments") }, text = { LazyColumn(Modifier.heightIn(max = 440.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items(lines, key = { it.item.id }) { draft -> Column {
            val update: (ReceiptDraft) -> Unit = { replacement -> lines = lines.map { if (it.item.id == draft.item.id) replacement else it } }
            Row(verticalAlignment = Alignment.CenterVertically) { Text(draft.item.category.title, Modifier.weight(1f), fontWeight = FontWeight.Medium); IconButton(onClick = { lines = lines.filterNot { it.item.id == draft.item.id } }, enabled = !busy) { Icon(Icons.Default.Delete, "Retirer cet aliment") } }
            Field("Nom", draft.name) { update(draft.copy(name = it)) }
            Field("Quantité", draft.amount) { update(draft.copy(amount = it)) }
            Chips(FoodUnit.entries.map { it.label }, draft.item.unit.label) { update(draft.copy(item = draft.item.copy(unit = FoodUnit.entries[it]))) }
            Field("Date estimée (AAAA-MM-JJ)", draft.expiry) { update(draft.copy(expiry = it)) }
            if (draft.validated() == null) Text("Vérifiez le nom, la quantité et la date.", color = MaterialTheme.colorScheme.error)
            HorizontalDivider()
        } }
    } }, dismissButton = { TextButton(onClick = dismiss, enabled = !busy) { Text("Annuler") } }, confirmButton = { TextButton(onClick = { confirm(validated.filterNotNull()) }, enabled = !busy && lines.isNotEmpty() && validated.all { it != null }) { Text("Ajouter au stock") } })
}
@Composable private fun More(state: StockState, onExport: () -> Unit, onImport: () -> Unit, onPrevious: () -> Unit, onDeletePlan: (String) -> Unit) {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Section("Planning") }
        if (state.backup!!.mealPlan.isEmpty()) item { Text("Aucun repas planifié.") }
        items(state.backup.mealPlan.sortedBy { it.date }, key = { it.id }) { entry -> ListItem(headlineContent = { Text(entry.recipeTitle) }, supportingContent = { Text("${entry.date.take(10)} · ${entry.slot} · ${entry.servings} portions") }, trailingContent = { IconButton(onClick = { onDeletePlan(entry.id) }, enabled = !state.busy) { Icon(Icons.Default.Delete, "Retirer le repas") } }) }
        item { HorizontalDivider(); Section("Sauvegardes") }
        item { OutlinedButton(onClick = onExport, enabled = !state.busy, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.FileDownload, null); Text("Exporter la sauvegarde JSON") } }
        item { OutlinedButton(onClick = onImport, enabled = !state.busy, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.FileUpload, null); Text("Importer une sauvegarde") } }
        item { TextButton(onClick = onPrevious, enabled = !state.busy) { Icon(Icons.Default.History, null); Text("Données avant import") } }
        item { HorizontalDivider(); Text("Google Play, sauvegarde chiffrée et rappels : non disponibles dans cette version.", style = MaterialTheme.typography.bodySmall); Text("StockChef Android 0.2.0", style = MaterialTheme.typography.labelSmall) }
    }
}