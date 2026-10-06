import SwiftUI

@main
struct StockChefApp: App {
    @StateObject private var store = InventoryStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("stockchef.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !ProcessInfo.processInfo.arguments.contains("-stockchef_reset_onboarding") && (hasCompletedOnboarding || ProcessInfo.processInfo.arguments.contains("-stockchef_skip_onboarding")) {
                    ContentView().environmentObject(store).tint(Color("Emerald"))
                        .task { await store.refreshRecipes() }
                        .onChange(of: scenePhase) { _, phase in
                            if phase == .active { Task { await store.refreshRecipes() } }
                        }
                }
                else { OnboardingView(isComplete: $hasCompletedOnboarding) }
            }
        }
    }
}
