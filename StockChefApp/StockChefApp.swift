import SwiftUI

@main
struct StockChefApp: App {
    @StateObject private var store = InventoryStore()
    @AppStorage("stockchef.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !ProcessInfo.processInfo.arguments.contains("-stockchef_reset_onboarding") && (hasCompletedOnboarding || ProcessInfo.processInfo.arguments.contains("-stockchef_skip_onboarding")) { ContentView().environmentObject(store).tint(Color("Emerald")) }
                else { OnboardingView(isComplete: $hasCompletedOnboarding) }
            }
        }
    }
}
