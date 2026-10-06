# StockChef

Le projet SwiftUI est conservé dans [ios/README.md](ios/README.md). Ouvrir `ios/StockChef.xcodeproj` sur macOS ; le package Swift et ses tests restent dans `ios/`. Les écrans iOS utilisent désormais le catalogue commun BTBU.

La version native Kotlin/Compose est dans [android/README.md](android/README.md). Les données sont locales ; les achats Apple ne deviennent pas des achats Google Play. La première version Android ne comprend pas encore les achats, les rappels ni la sauvegarde chiffrée iOS.

Les deux applications téléchargent `https://btbu.aurelienleleu.fr/stockchef/recipes.json` au démarrage et au retour au premier plan, avec une tentative au maximum toutes les 15 minutes par session. Elles gardent le dernier catalogue valide en cache et les recettes embarquées en secours. Le catalogue se modifie dans `WebSite/src/stockchef/recipes.json`, dans le dépôt GitHub du site ; son guide d'édition est `WebSite/src/stockchef/README.md`. Après déploiement du site, les recettes changent sans nouvelle version des applications déjà équipées de ce chargeur. Les versions déjà installées avant cette évolution nécessitent une mise à jour initiale.

Le transfert HTTPS ne contient ni inventaire, ni ticket, ni sauvegarde : les données personnelles restent locales. Il nécessite désormais une connexion réseau pour les mises à jour, mais pas pour consulter les recettes en cache. Aucun commit, push ou déploiement automatique n'est lancé par les scripts locaux.