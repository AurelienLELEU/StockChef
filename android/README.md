# StockChef Android

Première version native Kotlin/Jetpack Compose, Android 8.0 (API 26) minimum. Identifiant `fr.btbu.stockchef`, version 0.1.0. L'application iOS originale est conservée sous `../ios/`.

## Disponible

Inventaire local SQLite, catégories et lieux de stockage, dates de péremption, restes, recherche et filtres ; catalogue des 19 recettes originales avec portions, régimes et allergènes ; consommation du stock par lots, ingrédients manquants vers les courses, liste de courses et planning déjeuner/dîner.

Tickets par photographie, import d'image ou texte. Le modèle OCR ML Kit est embarqué ; la permission Internet sert désormais au téléchargement du catalogue BTBU. Les lignes reconnues sont vérifiables et corrigibles avant ajout. Cinq scans photo d'essai : un crédit est débité uniquement après confirmation réussie, aucun en cas d'annulation, d'échec ou de ticket vide. Ajout manuel et analyse de texte restent disponibles sans crédit. Une réinstallation peut réinitialiser les crédits : ce n'est pas une protection commerciale.

Les recettes proviennent de `https://btbu.aurelienleleu.fr/stockchef/recipes.json`, publié depuis le dépôt GitHub du site. Chargement du cache local en premier, puis actualisation HTTPS au démarrage ou au retour au premier plan, au maximum une tentative toutes les 15 minutes par session. Les catalogues invalides, trop volumineux ou indisponibles sont ignorés. Sans cache, les 19 recettes embarquées restent accessibles. Aucun inventaire, ticket ou fichier de sauvegarde n'est envoyé par la requête catalogue.

Import/export des sauvegardes JSON StockChef 1.0 et 1.1, inventaire/courses/planning, dates ISO 8601. Import avec aperçu puis confirmation et copie locale avant remplacement. Les licences et crédits ne sont pas transférés, notamment depuis Apple. Les ID des recettes Android sont stables ; un planning importé conserve le titre du repas mais son ID iOS n'est pas remappé. Les fichiers exportés sont en clair, à conserver dans un emplacement sûr.

## Pas encore porté

Google Play Billing, Pro et achat de crédits, rappels Android, sauvegarde chiffrée et toute synchronisation distante. Aucun achat réel n'est proposé. Les estimations de conservation du ticket ne remplacent pas la date de l'emballage. Cette version n'est pas prête à être publiée telle quelle sur Google Play.

## Construire sous Windows

```powershell
& './StockChef/android/tools/build.ps1'
& './StockChef/android/tools/build.ps1' -CoreOnly
& './StockChef/android/tools/build.ps1' -Tasks @(':app:assembleDebug', ':app:lintDebug', ':app:assembleDebugAndroidTest')
```

Depuis la racine du workspace. JDK 17, Gradle 8.11.1, SDK Android 36, Build Tools 35.0.0. Le script réutilise `CashDraft/android/.toolchain` si disponible, sinon installe les outils dans `android/.toolchain`. Les licences Android doivent être acceptées par le développeur. Le cache Gradle et les sorties de compilation sont placés sous `%LOCALAPPDATA%` pour éviter les verrouillages OneDrive. Les APK sont copiés sous `android/artifacts/` (ignoré par Git).

Pour Android Studio : ouvrir ce dossier, choisir JDK 17 et installer le SDK 36. Les tâches usuelles `:core:test`, `:app:assembleDebug`, `:app:lintDebug` et `:app:connectedDebugAndroidTest` sont disponibles via le wrapper.

## Vérification

Quatorze tests JVM couvrent le parseur, les multipacks, la conversion des unités, les portions, le débit de plusieurs lots, les sauvegardes et le catalogue distant, dont la compatibilité avec le JSON du site lorsqu'il est présent dans le workspace. Des tests instrumentés vérifient SQLite, la persistance des crédits, la copie avant import, les gros documents sans débordement CursorWindow et la conservation du cache des recettes en cas d'échec ; ils utilisent des fichiers temporaires propres à chaque test, jamais les données utilisateur.

L'APK debug et le lint sont vérifiés sur Windows. Les tests instrumentés demandent un téléphone ou émulateur connecté ; leur compilation seule ne prouve pas leur exécution. L'OCR, la caméra, l'apparence et les interactions doivent encore être essayés sur appareil. La compilation Xcode n'est pas disponible sur cette machine.