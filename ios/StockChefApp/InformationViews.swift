import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Notre principe") { Text("StockChef fonctionne localement : l’inventaire, les photos analysées, les recettes, le planning et les sauvegardes restent sur votre appareil.") }
            Section("Données utilisées") { Label("Photos de tickets : utilisées uniquement pour l’analyse Vision sur l’iPhone, jamais téléversées.", systemImage: "photo"); Label("Inventaire et préférences : stockés dans la base SQLite locale.", systemImage: "internaldrive"); Label("Achats : gérés par Apple via StoreKit ; StockChef ne reçoit aucune donnée de paiement.", systemImage: "creditcard") }
            Section("Partage") { Text("L’app n’intègre ni publicité, ni analytics, ni compte utilisateur, ni partage de données avec des tiers. Une sauvegarde chiffrée ne peut être ouverte qu’avec le mot de passe choisi par vous.") }
            Section("Vos choix") { Text("Vous pouvez supprimer des aliments, réinitialiser l’app ou exporter vos données à tout moment. Les rappels et la caméra nécessitent votre autorisation iOS.") }
        }.navigationTitle("Confidentialité")
    }
}

struct SupportView: View {
    var body: some View {
        List {
            Section("Bien démarrer") { Label("Scannez un ticket net, posé à plat et bien éclairé.", systemImage: "doc.viewfinder"); Label("Corrigez les lignes avant de les ajouter au stock.", systemImage: "pencil"); Label("Exportez une sauvegarde chiffrée avant de changer d’iPhone.", systemImage: "lock.doc") }
            Section("Questions fréquentes") {
                DisclosureGroup("Pourquoi un aliment n’est-il pas détecté ?") { Text("Les tickets emploient des abréviations qui varient selon les enseignes. Ajoutez ou corrigez l’aliment manuellement : aucun contenu n’est envoyé à un serveur.") }
                DisclosureGroup("Puis-je restaurer Pro Lifetime ?") { Text("Oui : utilisez « Restaurer mes achats » dans Réglages. Les crédits de scans sont consommables et restent liés au stockage local de l’appareil.") }
                DisclosureGroup("Comment signaler un problème ?") { Text("Avant publication, configurez l’adresse ou l’URL de support BTBU dans App Store Connect. Joignez une capture du ticket concerné uniquement si vous acceptez de la transmettre au support.") }
            }
        }.navigationTitle("Aide & support")
    }
}
