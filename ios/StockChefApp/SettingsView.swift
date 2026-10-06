import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: InventoryStore
    @StateObject private var purchases = PurchaseManager()
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: JSONDocument?
    @State private var encryptedExportDocument: JSONDocument?
    @State private var statusMessage: String?
    @State private var backupPassword = ""
    @State private var showEncryptedExporter = false
    @State private var showEncryptedImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section("Confidentialité") {
                    Label("100 % local et hors-ligne", systemImage: "lock.shield")
                    Text("Vos tickets, votre inventaire et vos recettes restent sur cet iPhone.").font(.footnote).foregroundStyle(.secondary)
                    Button("Activer les rappels anti-gaspi") { Task { do { let granted = try await ExpiryNotificationManager.shared.requestAuthorization(); statusMessage = granted ? "Rappels activés." : "Les rappels n’ont pas été autorisés." } catch { statusMessage = error.localizedDescription } } }
                    NavigationLink("Lire la politique de confidentialité") { PrivacyView() }
                    NavigationLink("Aide & support") { SupportView() }
                }
                Section("Sauvegarde") {
                    Button { prepareExport() } label: { Label("Exporter mon inventaire JSON", systemImage: "square.and.arrow.up") }
                    Button { showImporter = true } label: { Label("Restaurer une sauvegarde JSON", systemImage: "square.and.arrow.down") }
                    SecureField("Mot de passe de sauvegarde chiffrée", text: $backupPassword).textContentType(.password)
                    Button { prepareEncryptedExport() } label: { Label("Exporter une sauvegarde chiffrée", systemImage: "lock.doc") }.disabled(backupPassword.count < 8)
                    Button { showEncryptedImporter = true } label: { Label("Restaurer une sauvegarde chiffrée", systemImage: "lock.open") }.disabled(backupPassword.count < 8)
                    Text("Le mot de passe ne quitte jamais votre iPhone et n’est pas mémorisé. Sans lui, la sauvegarde ne peut pas être restaurée.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Formule") {
                    LabeledContent("Scans disponibles", value: store.license.isProUnlocked ? "Illimités" : "\(store.license.remainingScanCredits)")
                    if purchases.isLoading { ProgressView("Chargement des offres…") }
                    ForEach(purchases.products, id: \.id) { product in
                        Button { Task { await purchases.purchase(product, inventory: store) } } label: { HStack { Text(product.displayName); Spacer(); Text(product.displayPrice) } }
                    }
                    Button("Restaurer mes achats") { Task { await purchases.restorePurchases(inventory: store) } }
                    Text("Les offres sont validées et sécurisées par l’App Store ; aucun paiement ne passe par StockChef.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Réglages")
            .task { await purchases.loadProducts() }
            .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json, defaultFilename: "stockchef-sauvegarde") { result in
                switch result {
                case .success: statusMessage = "Sauvegarde exportée."
                case .failure(let error): statusMessage = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                do { let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; try store.importBackup(Data(contentsOf: url)); statusMessage = "Inventaire restauré." }
                catch { statusMessage = error.localizedDescription }
            }
            .fileExporter(isPresented: $showEncryptedExporter, document: encryptedExportDocument, contentType: .data, defaultFilename: "stockchef-sauvegarde-chiffree.stockchef") { result in
                switch result { case .success: statusMessage = "Sauvegarde chiffrée exportée."; case .failure(let error): statusMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $showEncryptedImporter, allowedContentTypes: [.data]) { result in
                do { let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }; try store.importEncryptedBackup(Data(contentsOf: url), password: backupPassword); statusMessage = "Sauvegarde chiffrée restaurée." }
                catch { statusMessage = error.localizedDescription }
            }
            .alert("StockChef", isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(statusMessage ?? "") }
            .alert("Achats", isPresented: Binding(get: { purchases.errorMessage != nil }, set: { if !$0 { purchases.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(purchases.errorMessage ?? "") }
        }
    }

    private func prepareExport() { do { exportDocument = JSONDocument(data: try store.exportBackup()); showExporter = true } catch { statusMessage = error.localizedDescription } }
    private func prepareEncryptedExport() { do { encryptedExportDocument = JSONDocument(data: try store.exportEncryptedBackup(password: backupPassword)); showEncryptedExporter = true } catch { statusMessage = error.localizedDescription } }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
