import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var page = 0

    private let pages: [(icon: String, title: String, message: String)] = [
        ("lock.shield.fill", "Vos courses restent privées", "StockChef analyse vos tickets, recettes et inventaire sur votre iPhone. Aucune donnée de cuisine n’est envoyée dans le cloud."),
        ("doc.viewfinder", "Scannez, vérifiez, ajoutez", "Prenez votre ticket en photo. L’app le recadre, relève les aliments puis vous laisse corriger chaque ligne avant l’ajout."),
        ("fork.knife", "Cuisinez ce que vous avez", "Choisissez vos convives : les recettes, le planning et la liste de courses s’adaptent à votre stock.")
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: pages[page].icon).font(.system(size: 64, weight: .medium)).foregroundStyle(Color("Emerald")).accessibilityHidden(true)
            VStack(spacing: 12) { Text(pages[page].title).font(.largeTitle.bold()).multilineTextAlignment(.center); Text(pages[page].message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 28) }
            HStack(spacing: 8) { ForEach(pages.indices, id: \.self) { index in Capsule().fill(index == page ? Color("Emerald") : .gray.opacity(0.25)).frame(width: index == page ? 24 : 8, height: 8) } }
            Spacer()
            Button(page == pages.count - 1 ? "Commencer" : "Continuer") { if page == pages.count - 1 { isComplete = true } else { withAnimation { page += 1 } } }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity).padding(.horizontal, 24)
            if page < pages.count - 1 { Button("Passer") { isComplete = true }.foregroundStyle(.secondary) }
        }.padding(.vertical, 40).background(Color("Cream").ignoresSafeArea())
    }
}
