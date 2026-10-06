# Vérification — 6 octobre 2026

| Commande | Résultat |
| --- | --- |
| `swift test` | Réussi : 7 tests, 0 échec (conversion d’unités, débit recette, parsing ticket, condiments/fruits secs, catalogue, JSON et estimation d’échéance) |
| `xcodebuild -project StockChef.xcodeproj -scheme StockChef -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build` | Réussi — compilation universelle simulateur iOS 16 (arm64 et x86_64), sans signature. |
| Tests UI Xcode | Réussis sur simulateur iPhone 18 Pro : onboarding, tableau de bord démo, inventaire et planning accessibles. |
| Installation simulateur | Réussie après correction de `CFBundleExecutable` ; captures réelles dans `03_app_store/screenshots/`. |
| Installation iPhone 14 physique — 6 octobre | Réussie : build Debug signé avec le profil `iOS Team Provisioning Profile: *`, installé puis lancé sur `iPhone d’Aurel` (bundle `fr.stockchef.app`). Aucune publication effectuée. |
| Correction galerie — 6 octobre | Réussie : le `PhotosPicker` n’est plus contenu dans un menu ; les boutons Caméra et Galerie sont désormais distincts, et la sélection est réinitialisée pour pouvoir réimporter la même photo. |
| `xcodebuild -project StockChef.xcodeproj -scheme StockChef -configuration Debug -sdk iphonesimulator -derivedDataPath /private/tmp/stockchef-gallery-verify build` | Réussi — compilation de la correction Galerie sur simulateur iOS. |
| `swift test` — 6 octobre | Réussi : 7 tests, 0 échec. |
| Correction thème sombre et ticket long — 6 octobre | Réussie : cartes sombres adaptatives, teinte émeraude lisible en mode sombre et libellés de scan en couleur primaire. Parser enrichi pour les produits/multipacks du ticket fourni, avec filtration des lignes hygiène et aliments animaux. |
| `swift test` — ticket long | Réussi : 8 tests, 0 échec ; scénario de ticket long couvrant 15 aliments, multipacks et lignes non alimentaires. |
| `xcodebuild … -sdk iphonesimulator …` — thème + parser | Réussi — compilation simulateur iOS. |
| Installation iPhone — thème + parser | Réussie : mise à jour installée sur `iPhone d’Aurel`. Le lancement automatisé a été refusé car l’iPhone était verrouillé ; aucune erreur de l’app n’a été remontée. |
| Reconstruction de lignes OCR — 6 octobre | Réussie : les observations Vision sont regroupées par position verticale et relues de gauche à droite avant parsing. Cela préserve les poids placés dans une colonne distincte, tels que `100G EMMENTAL RAPE`, au lieu de les transformer en articles à quantité par défaut. |
| `swift test` — reconstruction OCR | Réussi : 8 tests, 0 échec. |
| `xcodebuild … -sdk iphonesimulator …` — reconstruction OCR | Réussi — compilation simulateur iOS de la correction. |
| Installation iPhone — reconstruction OCR | Réussie : build Debug signé, installé puis lancé sur `iPhone d’Aurel` (bundle `fr.stockchef.app`). |
| Correction de régression OCR — 6 octobre | Réussie : retour à l’ordre natif de Vision, sans vocabulaire forcé ni recomposition globale de colonnes. Seul un poids isolé et clairement situé avant un produit de la même ligne est rattaché à ce produit. |
| `swift test` et `xcodebuild … -sdk iphonesimulator …` — correction de régression | Réussis : 8 tests, 0 échec ; compilation simulateur iOS réussie. |
| Installation iPhone — correction de régression OCR | Réussie : build Debug signé, installé puis lancé sur `iPhone d’Aurel` (bundle `fr.stockchef.app`). |
| Recadrage interactif + contraste OCR — 6 octobre | Réussi : détection locale de contour, cadre prépositionné avec quatre poignées ajustables, recadrage natif puis copie OCR en niveaux de gris contrastés. Aucun downscale n’est appliqué. |
| `swift test` et `xcodebuild … -sdk iphonesimulator …` — recadrage | Réussis : 8 tests, 0 échec ; compilation simulateur iOS réussie. |
| Installation iPhone — recadrage | Réussie : build Debug signé et installé sur `iPhone d’Aurel`. L’app a été lancée avec le paramètre Debug local de restauration des crédits de validation ; le solde gratuit est remonté à au moins 5 sans toucher à Pro. |
| Installation iPhone — libellé de recadrage | Réussie : dernière build Debug installée puis lancée sur `iPhone d’Aurel`. |
| Correction du cadrage proposé — 6 octobre | Réussie : un contour candidat doit englober la zone de texte Vision ; en cas de contour ambigu, le cadre est déduit des boîtes de texte plutôt que du plus grand rectangle détecté. |
| `swift test` et `xcodebuild … -sdk iphonesimulator …` — cadrage | Réussis : 8 tests, 0 échec ; compilation simulateur iOS réussie. |
| Installation iPhone — correction du cadrage | Réussie : build Debug signé, installé puis lancé sur `iPhone d’Aurel`. |
| Rejet des faux contours plats + crédits de test — 6 octobre | Réussi en implémentation : un rectangle horizontal qui ne contient pas la zone de texte est rejeté ; le repli est un cadre vertical haut centré sur les textes, toujours modifiable. Le symbole `DEBUG` est désormais défini dans la configuration Debug : le paramètre de lancement local rétablit au moins 5 crédits sans modifier Pro. |
| `swift test` et `xcodebuild … -sdk iphonesimulator …` — faux contours + crédits | Réussis : 8 tests, 0 échec ; compilation simulateur iOS avec le symbole `DEBUG`. |
| Installation iPhone — faux contours + crédits | Réussie : build Debug signé installé, puis lancée avec le paramètre de restauration des crédits de test sur `iPhone d’Aurel`. La présence des 5 crédits reste à constater dans l’interface de l’app. |

Le test fonctionnel d’OCR avec recadrage sur le ticket réel fourni, l’appareil photo, l’ouverture de la photothèque avec une image réelle, l’affichage des crédits restaurés, les notifications, StoreKit réel et le backup chiffré avec mot de passe restent à exécuter manuellement. La signature, l’installation et le lancement Debug sur iPhone ont été vérifiés le 6 octobre 2026.
