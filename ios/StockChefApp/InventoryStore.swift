import Foundation

@MainActor
final class InventoryStore: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published private(set) var shoppingList: [ShoppingItem] = []
    @Published private(set) var mealPlan: [MealPlanEntry] = []
    @Published private(set) var recipes: [Recipe] = SampleData.recipes
    @Published var license: AppLicense
    @Published var lastError: String?

    private var repository: SQLiteInventoryRepository?
    private let licenseStore = LicenseStore()
    private var recipeRefreshInFlight = false
    private var lastRecipeAttempt = Date.distantPast
    private let recipeEndpoint = URL(string: "https://btbu.aurelienleleu.fr/stockchef/recipes.json")!
    private var recipeCacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("stockchef-recipes-v1.json")
    }

    init() {
        license = licenseStore.load()
        #if DEBUG
        restoreComplimentaryCreditsIfRequested()
        #endif
        do { repository = try SQLiteInventoryRepository(); load(); seedDemoIfRequested() }
        catch { lastError = error.localizedDescription }
        if let size = try? recipeCacheURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size <= RecipeFeedCodec.maximumBytes,
           let data = try? Data(contentsOf: recipeCacheURL),
           let cached = try? RecipeFeedCodec.decode(data) { recipes = cached }
    }

    func refreshRecipes() async {
        guard !recipeRefreshInFlight, Date().timeIntervalSince(lastRecipeAttempt) >= 900 else { return }
        recipeRefreshInFlight = true
        lastRecipeAttempt = Date()
        defer { recipeRefreshInFlight = false }
        do {
            var request = URLRequest(url: recipeEndpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.url == recipeEndpoint, http.expectedContentLength <= RecipeFeedCodec.maximumBytes else { return }
            var data = Data()
            for try await byte in bytes {
                guard data.count < RecipeFeedCodec.maximumBytes else { return }
                data.append(byte)
            }
            let updated = try RecipeFeedCodec.decode(data)
            try data.write(to: recipeCacheURL, options: .atomic)
            recipes = updated
        } catch { }
    }

    var expiringItems: [InventoryItem] {
        items.filter { $0.expires(within: 3) }.sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    func add(_ item: InventoryItem) {
        items.append(item)
        save()
    }

    func add(parsed lines: [ParsedReceiptLine]) {
        for line in lines {
            if let index = items.firstIndex(where: { RecipeMatcher.normalized($0.name) == RecipeMatcher.normalized(line.name) && $0.unit == line.unit }) {
                items[index].quantity += line.quantity
            } else {
                let estimatedExpiry = Calendar.current.date(byAdding: .day, value: line.category.estimatedShelfLifeDays, to: .now)
                items.append(InventoryItem(name: line.name, category: line.category, quantity: line.quantity, unit: line.unit, expiryDate: estimatedExpiry))
            }
        }
        save()
    }

    func addLeftover(name: String, quantity: Double, unit: FoodUnit, storageLocation: StorageLocation = .fridge) {
        let expiry = Calendar.current.date(byAdding: .day, value: storageLocation == .freezer ? 90 : 2, to: .now)
        add(InventoryItem(name: name, category: .other, quantity: quantity, unit: unit, expiryDate: expiry, storageLocation: storageLocation, isLeftover: true, cookedAt: .now))
    }

    func update(_ item: InventoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func delete(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func cook(_ recipe: Recipe, servings: Int) {
        items = RecipeMatcher.cook(recipe: recipe, servings: servings, inventory: items)
        save()
    }

    func addMissingToShoppingList(_ ingredients: [RecipeIngredient]) {
        for ingredient in ingredients where !ingredient.isPantryStaple {
            if let index = shoppingList.firstIndex(where: { RecipeMatcher.normalized($0.name) == RecipeMatcher.normalized(ingredient.name) && $0.unit == ingredient.unit }) {
                shoppingList[index].quantity += ingredient.baseQuantity
            } else {
                shoppingList.append(ShoppingItem(name: ingredient.name, quantity: ingredient.baseQuantity, unit: ingredient.unit))
            }
        }
        saveShoppingList()
    }

    func toggleShoppingItem(_ item: ShoppingItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        shoppingList[index].isChecked.toggle()
        saveShoppingList()
    }

    func deleteShoppingItems(at offsets: IndexSet) { shoppingList.remove(atOffsets: offsets); saveShoppingList() }

    func schedule(_ recipe: Recipe, date: Date, slot: MealSlot, servings: Int) {
        mealPlan.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.slot == slot }
        mealPlan.append(MealPlanEntry(recipeID: recipe.id, recipeTitle: recipe.title, date: date, slot: slot, servings: servings))
        mealPlan.sort { $0.date < $1.date }
        saveMealPlan()
    }

    func deleteMealPlan(at offsets: IndexSet) { mealPlan.remove(atOffsets: offsets); saveMealPlan() }

    func applyPurchase(productID: String, transactionID: String) {
        switch productID {
        case PurchaseManager.proProductID: license.isProUnlocked = true
        case PurchaseManager.scanPackProductID: license.remainingScanCredits += 20
        default: return
        }
        license.transactionID = transactionID
        licenseStore.save(license)
    }

    func consumeScanCredit() -> Bool {
        guard license.isProUnlocked || license.remainingScanCredits > 0 else { return false }
        if !license.isProUnlocked { license.remainingScanCredits -= 1; licenseStore.save(license) }
        return true
    }

    #if DEBUG
    /// Debug-launch hook used to compensate scans consumed while validating local OCR.
    /// It never revokes Pro and is excluded from distribution builds.
    private func restoreComplimentaryCreditsIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-stockchef_restore_test_credits"), !license.isProUnlocked else { return }
        license.remainingScanCredits = max(license.remainingScanCredits, 5)
        licenseStore.save(license)
    }
    #endif

    func exportBackup() throws -> Data { try StockChefBackup(inventory: items, shoppingList: shoppingList, mealPlan: mealPlan).encoded() }
    func exportEncryptedBackup(password: String) throws -> Data { try EncryptedBackupService.encrypt(exportBackup(), password: password) }

    func importBackup(_ data: Data) throws {
        let backup = try StockChefBackup.decoded(from: data)
        items = backup.inventory
        shoppingList = backup.shoppingList
        mealPlan = backup.mealPlan
        save()
        saveShoppingList()
        saveMealPlan()
    }
    func importEncryptedBackup(_ data: Data, password: String) throws { try importBackup(EncryptedBackupService.decrypt(data, password: password)) }

    private func load() {
        guard let repository else { return }
        do { items = try repository.loadInventory(); shoppingList = try repository.loadShoppingList(); mealPlan = try repository.loadMealPlan() }
        catch { lastError = "Impossible de charger votre inventaire local." }
    }

    private func seedDemoIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-stockchef_demo"), items.isEmpty else { return }
        items = SampleData.inventory
        mealPlan = [MealPlanEntry(recipeID: SampleData.recipes[0].id, recipeTitle: SampleData.recipes[0].title, date: .now, slot: .dinner, servings: 2)]
        save(); saveMealPlan()
    }

    private func save() {
        do { try repository?.saveInventory(items); ExpiryNotificationManager.shared.schedule(for: items) }
        catch { lastError = "Impossible d’enregistrer votre inventaire." }
    }

    private func saveShoppingList() { do { try repository?.saveShoppingList(shoppingList) } catch { lastError = "Impossible d’enregistrer votre liste de courses." } }
    private func saveMealPlan() { do { try repository?.saveMealPlan(mealPlan) } catch { lastError = "Impossible d’enregistrer votre planning." } }
}
