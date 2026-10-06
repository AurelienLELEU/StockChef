import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let scanPackProductID = "fr.stockchef.scans20"
    static let proProductID = "fr.stockchef.pro.lifetime"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do { products = try await Product.products(for: [Self.scanPackProductID, Self.proProductID]).sorted { $0.price < $1.price } }
        catch { errorMessage = "Les offres ne sont pas disponibles actuellement : \(error.localizedDescription)" }
    }

    func purchase(_ product: Product, inventory: InventoryStore) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                inventory.applyPurchase(productID: transaction.productID, transactionID: String(transaction.id))
                await transaction.finish()
            case .pending: errorMessage = "Votre achat est en attente de validation."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { errorMessage = "Achat non finalisé : \(error.localizedDescription)" }
    }

    func restorePurchases(inventory: InventoryStore) async {
        do {
            try await AppStore.sync()
            for await entitlement in Transaction.currentEntitlements {
                let transaction = try checkVerified(entitlement)
                inventory.applyPurchase(productID: transaction.productID, transactionID: String(transaction.id))
            }
        } catch { errorMessage = "Restauration impossible : \(error.localizedDescription)" }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result { case .verified(let safe): return safe; case .unverified: throw PurchaseError.failedVerification }
    }
}

enum PurchaseError: LocalizedError { case failedVerification; var errorDescription: String? { "La vérification sécurisée de l’achat a échoué." } }
