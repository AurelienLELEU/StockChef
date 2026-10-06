# Checklist App Store — vérifiée le 4 octobre 2026

| Élément | Statut | Preuve / responsable |
| --- | --- | --- |
| Build simulateur iOS 16 | ready | `02_qa/verification.md` |
| Scan local, stockage SQLite et backup chiffré | ready | Sources `StockChefApp/` ; test appareil physique restant |
| Captures iPhone réelles | ready | `screenshots/fr-FR/iPhone-18-Pro/` ; 1206×2622, format PNG |
| Politique de confidentialité publique | owner input | URL BTBU dans `owner-inputs.md` |
| Support public | owner input | URL BTBU dans `owner-inputs.md` |
| Produits in-app purchase | owner input | créer dans App Store Connect puis tester Sandbox |
| Privacy Nutrition Label | owner input | déclarer « no data collected » seulement si cette affirmation reste exacte à la livraison |
| Age Rating et Export Compliance | owner input | questionnaires App Store Connect |
| Signature, archive et TestFlight | unverified | nécessite équipe Apple et appareil / compte BTBU |

Références Apple consultées :

- https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases
- https://developer.apple.com/app-store/user-privacy-and-data-use/
