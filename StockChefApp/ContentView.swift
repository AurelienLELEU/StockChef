import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Aujourd’hui", systemImage: "sparkles") }
            InventoryView()
                .tabItem { Label("Mon stock", systemImage: "refrigerator") }
            RecipesView()
                .tabItem { Label("Recettes", systemImage: "fork.knife") }
            ShoppingListView()
                .tabItem { Label("Courses", systemImage: "cart") }
            MealPlannerView()
                .tabItem { Label("Planning", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: InventoryStore
    @State private var showScanner = false

    private var bestMatch: RecipeMatch? { RecipeMatcher.matches(recipes: SampleData.recipes, inventory: store.items, servings: 2).first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Bonjour 👋").font(.title.bold())
                        Text("Moins de gaspillage, plus de bonnes idées.").foregroundStyle(.secondary)
                    }
                    Button { showScanner = true } label: {
                        Label("Scanner un ticket", systemImage: "doc.viewfinder")
                            .font(.headline).frame(maxWidth: .infinity).padding(18)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Importez une photo de ticket et validez les produits détectés")
                    if !store.expiringItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("À utiliser bientôt", systemImage: "clock.badge.exclamationmark").font(.headline).foregroundStyle(Color("Terracotta"))
                            ForEach(store.expiringItems) { item in
                                HStack { Text(item.name); Spacer(); Text(item.expiryDate?.formatted(date: .abbreviated, time: .omitted) ?? "") .foregroundStyle(.secondary) }
                            }
                        }.cardStyle()
                    }
                    if let bestMatch {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggestion du jour").font(.headline)
                            Text(bestMatch.recipe.title).font(.title3.bold())
                            Text(bestMatch.isCookable ? "Vous avez tout ce qu’il faut" : "Il manque : \(bestMatch.missingIngredients.map(\.name).joined(separator: ", "))")
                                .foregroundStyle(bestMatch.isCookable ? Color("Emerald") : .secondary)
                            Label("\(bestMatch.recipe.prepTimeMinutes) min · pour 2", systemImage: "timer").font(.subheadline).foregroundStyle(.secondary)
                        }.cardStyle()
                    } else {
                        EmptyState(title: "Votre frigo est prêt", icon: "refrigerator", message: "Ajoutez vos courses pour recevoir une idée de recette.")
                    }
                }.padding()
            }
            .navigationTitle("StockChef")
            .sheet(isPresented: $showScanner) { ScanReceiptView() }
        }
    }
}

private extension View {
    func cardStyle() -> some View { padding().frame(maxWidth: .infinity, alignment: .leading).background(Color("Cream"), in: RoundedRectangle(cornerRadius: 18)) }
}

struct EmptyState: View {
    let title: String
    let icon: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 38)).foregroundStyle(Color("Emerald"))
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(32).accessibilityElement(children: .combine)
    }
}
