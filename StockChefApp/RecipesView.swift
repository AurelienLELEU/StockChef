import SwiftUI

struct RecipesView: View {
    @EnvironmentObject private var store: InventoryStore
    @State private var servings = 2
    @State private var dietaryFilter: DietaryTag?
    @State private var excludedAllergens: Set<Allergen> = []
    @State private var courseFilter: RecipeCourse?

    private var matches: [RecipeMatch] {
        RecipeMatcher.matches(recipes: SampleData.recipes, inventory: store.items, servings: servings)
            .filter { dietaryFilter == nil || $0.recipe.dietaryTags.contains(dietaryFilter!) }
            .filter { $0.recipe.allergens.isDisjoint(with: excludedAllergens) }
            .filter { courseFilter == nil || $0.recipe.course == courseFilter }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Convives", selection: $servings) { ForEach([1, 2, 4, 6], id: \.self) { Text("\($0) \($0 == 1 ? "personne" : "personnes")").tag($0) } }.pickerStyle(.segmented)
                } header: { Text("Pour combien de personnes ?") }
                Section("Préférences") {
                    Picker("Type de recette", selection: $courseFilter) { Text("Toutes les recettes").tag(RecipeCourse?.none); ForEach(RecipeCourse.allCases, id: \.self) { Text($0.rawValue).tag(RecipeCourse?.some($0)) } }
                    Picker("Style alimentaire", selection: $dietaryFilter) { Text("Tous les styles").tag(DietaryTag?.none); ForEach(DietaryTag.allCases, id: \.self) { Text($0.rawValue).tag(DietaryTag?.some($0)) } }
                    Menu("Exclure des allergènes") { ForEach(Allergen.allCases, id: \.self) { allergen in Button { if excludedAllergens.contains(allergen) { excludedAllergens.remove(allergen) } else { excludedAllergens.insert(allergen) } } label: { Label(allergen.rawValue, systemImage: excludedAllergens.contains(allergen) ? "checkmark" : "") } } }
                }
                ForEach(matches) { match in
                    NavigationLink { RecipeDetailView(match: match, servings: servings) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(match.recipe.title).font(.headline); Spacer(); Text("\(match.recipe.prepTimeMinutes) min").foregroundStyle(.secondary) }
                            if match.isCookable { Label("Prête à cuisiner", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(Color("Emerald")) }
                            else { Text("Manque : \(match.missingIngredients.map(\.name).joined(separator: ", "))").font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
                        }.padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Recettes anti-gaspi")
        }
    }
}

struct RecipeDetailView: View {
    @EnvironmentObject private var store: InventoryStore
    let match: RecipeMatch
    let servings: Int
    @State private var showCookConfirmation = false
    @State private var didCook = false
    @State private var showPlanner = false

    var body: some View {
        List {
            Section {
                HStack { Label("\(match.recipe.prepTimeMinutes) min", systemImage: "timer"); Spacer(); Label("\(servings) pers.", systemImage: "person.2") }
            }
            Section("Ingrédients") {
                ForEach(match.recipe.scaledIngredients(for: servings)) { ingredient in
                    HStack {
                        Image(systemName: ingredient.isPantryStaple || match.missingIngredients.contains(where: { $0.id == ingredient.id }) ? "circle" : "checkmark.circle.fill")
                            .foregroundStyle(ingredient.isPantryStaple || match.missingIngredients.contains(where: { $0.id == ingredient.id }) ? .secondary : Color("Emerald"))
                        Text(ingredient.name); Spacer(); Text("\(ingredient.baseQuantity.formatted(.number.precision(.fractionLength(0...1)))) \(ingredient.unit.rawValue)").foregroundStyle(.secondary)
                    }
                }
            }
            if !match.recipe.allergens.isEmpty {
                Section("Allergènes") { Text(match.recipe.allergens.map(\.rawValue).sorted().joined(separator: " · ")).foregroundStyle(Color("Terracotta")); Text("Vérifiez toujours les étiquettes de vos produits : les recettes ne remplacent pas les informations fabricant.").font(.footnote).foregroundStyle(.secondary) }
            }
            Section("Préparation") { ForEach(Array(match.recipe.instructions.enumerated()), id: \.offset) { index, instruction in Label(instruction, systemImage: "\(index + 1).circle") } }
            Section("Sécurité alimentaire") { Label("Respectez les dates, la chaîne du froid et les températures de cuisson. En cas de doute sur un aliment, ne le consommez pas.", systemImage: "shield.lefthalf.filled").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle(match.recipe.title)
        .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !match.isCookable { Button("Ajouter les manquants à ma liste") { store.addMissingToShoppingList(match.missingIngredients) }.buttonStyle(.bordered) }
                Button("Planifier ce repas") { showPlanner = true }.buttonStyle(.bordered)
                Button { showCookConfirmation = true } label: { Text(didCook ? "Bon appétit !" : "Cuisiner !").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 5) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!match.isCookable || didCook)
            }.padding()
        }
        .alert("Déduire les ingrédients ?", isPresented: $showCookConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Oui, cuisiner !") { store.cook(match.recipe, servings: servings); didCook = true }
        } message: { Text("Les quantités seront retirées de votre inventaire local.") }
        .sheet(isPresented: $showPlanner) { MealPlanEditor(recipe: match.recipe, servings: servings) }
    }
}

struct MealPlannerView: View {
    @EnvironmentObject private var store: InventoryStore
    var body: some View {
        NavigationStack {
            Group {
                if store.mealPlan.isEmpty { EmptyState(title: "Votre planning est vide", icon: "calendar", message: "Planifiez une recette depuis sa fiche pour organiser vos repas.") }
                else { List { ForEach(store.mealPlan) { entry in HStack { Image(systemName: entry.slot == .lunch ? "sun.max" : "moon.stars").foregroundStyle(Color("Terracotta")); VStack(alignment: .leading) { Text(entry.recipeTitle).font(.headline); Text("\(entry.date.formatted(date: .abbreviated, time: .omitted)) · \(entry.slot.rawValue) · \(entry.servings) pers.").font(.subheadline).foregroundStyle(.secondary) } } }.onDelete(perform: store.deleteMealPlan) }.listStyle(.insetGrouped) }
            }.navigationTitle("Planning repas")
        }
    }
}

struct MealPlanEditor: View {
    @EnvironmentObject private var store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let servings: Int
    @State private var date = Date()
    @State private var slot: MealSlot = .dinner
    var body: some View {
        NavigationStack { Form { Section(recipe.title) { DatePicker("Date", selection: $date, displayedComponents: .date); Picker("Moment", selection: $slot) { ForEach(MealSlot.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; LabeledContent("Convives", value: "\(servings)") } }.navigationTitle("Planifier").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Ajouter") { store.schedule(recipe, date: date, slot: slot, servings: servings); dismiss() } } } }
    }
}

struct ShoppingListView: View {
    @EnvironmentObject private var store: InventoryStore
    var body: some View {
        NavigationStack {
            Group {
                if store.shoppingList.isEmpty { EmptyState(title: "Votre liste est vide", icon: "cart", message: "Ajoutez les ingrédients manquants depuis une recette.") }
                else { List { ForEach(store.shoppingList) { item in Button { store.toggleShoppingItem(item) } label: { HStack { Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle").foregroundStyle(item.isChecked ? Color("Emerald") : .secondary); Text(item.name).strikethrough(item.isChecked); Spacer(); Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...1)))) \(item.unit.rawValue)").foregroundStyle(.secondary) } }.accessibilityLabel("Cocher \(item.name)") }.onDelete(perform: store.deleteShoppingItems) }.listStyle(.insetGrouped) }
            }.navigationTitle("Liste de courses")
        }
    }
}
