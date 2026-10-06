# Achats intégrés à créer dans App Store Connect

Avant de commencer : accepter le **Paid Apps Agreement**, puis renseigner les coordonnées bancaires et fiscales de BTBU. Créer les produits dans **Apps → StockChef → Monetization → In-App Purchases → +**.

| Référence interne | Type Apple | Product ID exact | Proposition de prix TTC | Ce que cela donne | Restorable ? | Réglages importants |
| --- | --- | --- | ---: | --- | --- | --- |
| Recharge 20 scans | Consumable | `fr.stockchef.scans20` | 4,99 € | +20 scans de tickets | Non : un consommable est dépensé et Apple ne le restaure pas | Localisation française : « Recharge 20 scans » ; description « 20 analyses de tickets supplémentaires » |
| StockChef Pro Lifetime | Non-Consumable | `fr.stockchef.pro.lifetime` | 11,99 € | Scans illimités, recettes avancées et inventaire sans limite | Oui, via « Restaurer mes achats » | Localisation française : « StockChef Pro Lifetime » ; description « Débloquez StockChef à vie, sans abonnement » ; Family Sharing : à décider par BTBU |

## Étapes après création

1. Vérifier que les Product ID sont exactement ceux du tableau : ils sont déjà intégrés dans l’app.
2. Renseigner la localisation, la disponibilité, le prix et l’image promotionnelle éventuelle dans App Store Connect.
3. Attendre jusqu’à une heure si les produits n’apparaissent pas dans l’environnement Sandbox.
4. Créer un compte Sandbox Tester, puis effectuer l’achat et la restauration sur iPhone/TestFlight.
5. Ajouter les deux produits à la première soumission de la version App Store : Apple demande que le premier achat de chaque type soit soumis avec une nouvelle version.

## Choix produit assumé

Les 20 scans sont volontairement un **consommable**. Sans compte ni serveur, le solde est stocké localement et protégé contre une simple réinstallation par le Trousseau iOS, mais Apple ne fournit pas de restauration inter-appareil pour un consommable. Le Pro Lifetime est le choix recommandé pour une portabilité durable.

Références Apple vérifiées le 4 octobre 2026 :

- https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases
- https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase
