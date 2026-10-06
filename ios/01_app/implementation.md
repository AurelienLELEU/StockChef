# StockChef — Implémentation MVP

## Emplacement et démarrage

- Projet Xcode : `StockChef.xcodeproj`
- Cible : iOS 16.0+, SwiftUI, aucune dépendance tierce. Cela couvre les iPhone 8/XR et ultérieurs encore éligibles à iOS 16, dont tous les iPhone 14 et antérieurs compatibles avec cette version.
- Ouvrir le projet, choisir un simulateur ou iPhone, puis lancer le schéma **StockChef**.
- Pour vérifier le moteur pur : `swift test`.

## Architecture locale

- `StockChefApp/` : interface SwiftUI, onboarding, caméra, import de photo, Vision, Keychain, StoreKit, notifications, aide/confidentialité et persistance. L’import de la galerie est un contrôle `PhotosPicker` direct (hors menu), avec une action caméra distincte. Chaque import passe d’abord par un éditeur de recadrage local.
- `Sources/StockChefCore/` : modèles, parsing heuristique de ticket, matching de recettes, débit et format de sauvegarde JSON.
- L’OCR est assuré par `VNRecognizeTextRequest` ; il ne requiert pas de réseau. Avant la lecture, Vision détecte localement le contour du ticket et le confronte aux zones réellement reconnues comme du texte. Un rectangle trop plat ou qui ne couvre pas suffisamment ce texte est rejeté. En cas d’ambiguïté, l’app propose un cadre volontairement haut (92 % de l’image) centré sur le texte, pour ne jamais tronquer le haut ou le bas d’un ticket vertical ; il reste ajustable par quatre poignées. Le recadrage est appliqué aux pixels de définition native sélectionnés, sans réduction de résolution. Une copie de travail en niveaux de gris à contraste renforcé est ensuite produite pour l’OCR ; la photo originale n’est ni modifiée ni transférée. L’ordre de lecture natif de Vision est conservé, y compris sur les tickets froissés ou inclinés. Lorsqu’un poids isolé (`100G`) est clairement aligné juste avant une description, il est rattaché à celle-ci sans réordonner le reste du ticket. Les libellés sont ensuite transformés par un mini-dictionnaire local extensible dans `ReceiptParser`, avec prise en charge des multipacks (par exemple `3×70 g`) et des abréviations fréquentes de supermarché. Les lignes hygiène, animalerie, totaux et réductions sont écartées.
- L’inventaire et la liste de courses sont stockés dans SQLite, dans le conteneur local de l’app. Le JSON est exclusivement le format portable d’export/import. Les crédits sont conservés dans le Keychain.

## Couverture des exigences

| Exigence | Réalisation | Vérification |
| --- | --- | --- |
| Scan de ticket hors-ligne | Contrôle de résolution/netteté, détection de ticket et recadrage local, prix repérés, caméra/PhotosPicker, validation et correction de chaque ligne | Compilation iOS ; à tester sur un ticket réel |
| Inventaire et dates | Édition unitaire, frigo/congélateur/placard, restes, estimation de péremption, alertes à J+3 et notifications optionnelles | Compilation iOS |
| Recettes et convives | 19 recettes locales (entrées, plats, desserts, encas), score local, réglage 1/2/4/6 et quantités recalculées | Tests unitaires |
| Débit après cuisine | Confirmation, unités converties g/kg et ml/L | Test unitaire |
| Backup JSON | Export/import versionné de l’inventaire et de la liste de courses | Test de round-trip |
| Freemium local | 5 crédits Keychain, StoreKit 2 (achat, validation et restauration) | Compilation iOS ; App Store Connect requis |
| Persistance | Tables SQLite `InventoryItems`, `ShoppingItems` et `MealPlans`, avec migration additive | Compilation iOS |
| Planning | Déjeuner/dîner, recette et nombre de convives, persistés localement | Tests UI simulateur |
| Première ouverture | Onboarding de confidentialité et fonctionnement local | Tests UI + capture simulateur |

## Configuration à compléter avant diffusion

- Renseigner l’identifiant d’équipe Apple et un Bundle ID appartenant au compte dans Xcode.
- Créer dans App Store Connect les produits non-consommable `fr.stockchef.pro.lifetime` et consommable `fr.stockchef.scans20`, avec les prix validés. L’app les charge, les achète et les restaure déjà avec StoreKit 2.
- Le dictionnaire local couvre désormais les produits frais, légumineuses, fruits secs, graines et condiments courants. Continuer à l’étendre par enseigne : la reconnaissance d’un ticket réel dépend de ses abréviations.
- Ajouter une source de recettes éditorialisée avec notices allergènes/nutrition si ce périmètre est souhaité.

## Limites connues

- Le parser ne reconnaît volontairement que les aliments de son dictionnaire local : une ligne ménagère ou financière est ignorée ; un aliment absent du dictionnaire est à corriger/ajouter manuellement. Le dictionnaire inclut désormais les abréviations du ticket de test fourni, mais doit continuer à s’enrichir par enseigne avant diffusion large.
- Les données ne sont pas chiffrées au repos au-delà de la protection système d’iOS ; les crédits sont dans Keychain.
- Le build ne constitue pas une validation d’achat réel, de permissions ni un essai fonctionnel du recadrage/OCR sur un ticket physique.
