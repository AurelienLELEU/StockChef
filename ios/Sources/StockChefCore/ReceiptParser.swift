import Foundation

public struct ParsedReceiptLine: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var name: String
    public var category: FoodCategory
    public var quantity: Double
    public var unit: FoodUnit
    public var estimatedPrice: Double?

    public init(name: String, category: FoodCategory, quantity: Double = 1, unit: FoodUnit = .item, estimatedPrice: Double? = nil) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.estimatedPrice = estimatedPrice
    }
}

public enum ReceiptParser {
    private static let ignoredTerms = [
        "total", "tva", "carte", "especes", "merci", "sac", "ticket", "rendu", "paiement", "sous total", "remise", "coupon",
        "dentif", "felix", "sheba", "perfect fit", "perf fit", "miroir", "hygiene", "beaute", "essuie"
    ]
    private static let catalog: [(terms: [String], name: String, category: FoodCategory, unit: FoodUnit)] = [
        // Abréviations de tickets de caisse courantes — les libellés les plus précis doivent rester en tête.
        (["jeunes pousse"], "Jeunes pousses", .vegetable, .item),
        (["tomate grappe"], "Tomates", .vegetable, .gram),
        (["orange jus", "oran jus"], "Oranges à jus", .vegetable, .kilogram),
        (["mandarine"], "Mandarines", .vegetable, .item),
        (["prun myrtille", "prune myrtille"], "Fruits rouges", .frozen, .gram),
        (["burger chicken", "burg chicken"], "Burger de poulet", .meat, .item),
        (["saumon fume", "saumon fum"], "Saumon", .meat, .gram),
        (["calamar", "romaine"], "Calamars à la romaine", .frozen, .item),
        (["soupe saumon"], "Soupe au saumon", .grocery, .milliliter),
        (["wrap plt", "wrap avocat"], "Tortillas", .grocery, .item),
        (["tortel", "tortell"], "Tortellini", .grocery, .gram),
        (["pat feuil", "pate feuil"], "Pâte feuilletée", .grocery, .item),
        (["cooki grain", "cookie grain"], "Cookies aux céréales", .grocery, .item),
        (["cocktail gra", "cocktail grain"], "Cocktail de graines", .grocery, .gram),
        (["curly", "donuts cacah"], "Curly cacahuètes", .grocery, .item),
        (["snacks pop", "snack pop"], "Snacks apéritifs", .grocery, .item),
        (["gouter ecor", "gouter choco"], "Goûters chocolat", .grocery, .item),
        (["kit fruits"], "Gourdes de fruits", .grocery, .item),
        (["smoothie berr", "smoothie"], "Smoothie fruits rouges", .beverage, .milliliter),
        (["bridelice"], "Crème", .dairy, .milliliter),
        (["lait mont"], "Lait demi-écrémé", .dairy, .milliliter),
        (["cheddar rape", "cheddar rap"], "Cheddar râpé", .dairy, .gram),
        (["mel fromage", "mel. fromage"], "Mélange de fromages râpés", .dairy, .gram),
        (["emmental rape", "emmental rap"], "Fromage râpé", .dairy, .gram),
        (["fromage onct", "onctueux"], "Fromage onctueux", .dairy, .gram),
        (["yrt lit", "yaourt lit", "yogurt lit"], "Yaourts", .dairy, .item),
        (["oeuf blanc", "oeufs blanc"], "Œufs", .grocery, .item),
        (["sauce aioli", "aioli"], "Sauce aïoli", .grocery, .gram),
        (["rhum"], "Rhum", .beverage, .liter),
        (["lait coco", "coco lait"], "Lait de coco", .grocery, .milliliter),
        (["lait", "milk"], "Lait demi-écrémé", .dairy, .liter),
        (["beurre", "butter"], "Beurre", .dairy, .gram),
        (["creme", "cream"], "Crème", .dairy, .milliliter),
        (["oeuf", "oeufs", "egg"], "Œufs", .grocery, .item),
        (["tomate", "tomates"], "Tomates", .vegetable, .gram),
        (["courgette", "courgettes"], "Courgettes", .vegetable, .gram),
        (["avocat", "avocats"], "Avocats", .vegetable, .item),
        (["carotte", "carottes"], "Carottes", .vegetable, .gram),
        (["epinard", "spinach"], "Épinards", .vegetable, .gram),
        (["salade", "laitue"], "Salade verte", .vegetable, .item),
        (["poivron", "poivrons"], "Poivrons", .vegetable, .gram),
        (["champignon", "champignons"], "Champignons", .vegetable, .gram),
        (["concombre", "cucumber"], "Concombre", .vegetable, .item),
        (["citron", "lemons"], "Citrons", .vegetable, .item),
        (["poulet", "chicken"], "Poulet", .meat, .gram),
        (["saumon", "salmon"], "Saumon", .meat, .gram),
        (["thon", "tuna"], "Thon", .meat, .gram),
        (["steak", "boeuf", "bœuf"], "Bœuf haché", .meat, .gram),
        (["pates", "pasta"], "Pâtes", .grocery, .gram),
        (["riz", "rice"], "Riz", .grocery, .gram),
        (["quinoa"], "Quinoa", .grocery, .gram),
        (["semoule", "couscous"], "Semoule", .grocery, .gram),
        (["lentille", "lentilles"], "Lentilles", .grocery, .gram),
        (["pois chiche", "pois-chiche"], "Pois chiches", .grocery, .gram),
        (["haricot rouge", "haricot"], "Haricots rouges", .grocery, .gram),
        (["flocon avoine", "avoine"], "Flocons d’avoine", .grocery, .gram),
        (["farine"], "Farine", .grocery, .gram),
        (["chocolat noir", "chocolat"], "Chocolat noir", .grocery, .gram),
        (["miel"], "Miel", .grocery, .gram),
        (["dattes", "date fruit"], "Dattes", .grocery, .gram),
        (["banane", "bananes"], "Bananes", .vegetable, .item),
        (["pomme", "pommes"], "Pommes", .vegetable, .item),
        (["fruits rouge", "framboise", "myrtille"], "Fruits rouges", .frozen, .gram),
        (["amande", "amandes"], "Amandes", .grocery, .gram),
        (["noix", "walnut"], "Noix", .grocery, .gram),
        (["noisette", "noisettes"], "Noisettes", .grocery, .gram),
        (["cajou", "cashew"], "Noix de cajou", .grocery, .gram),
        (["graine chia", "chia"], "Graines de chia", .grocery, .gram),
        (["graine courge", "courge graines"], "Graines de courge", .grocery, .gram),
        (["oignon", "onion"], "Oignons", .vegetable, .item),
        (["fromage", "emmental", "comte"], "Fromage râpé", .dairy, .gram),
        (["yaourt", "yogurt"], "Yaourts", .dairy, .item),
        (["pain", "bread"], "Pain", .bakery, .item),
        (["tortilla", "wrap"], "Tortillas", .grocery, .item),
        (["huile olive", "huile"], "Huile d’olive", .grocery, .milliliter),
        (["vinaigre"], "Vinaigre", .grocery, .milliliter),
        (["moutarde"], "Moutarde", .grocery, .gram),
        (["sauce soja", "soja sauce"], "Sauce soja", .grocery, .milliliter),
        (["pesto"], "Pesto", .grocery, .gram),
        (["curry"], "Curry", .grocery, .gram),
        (["paprika"], "Paprika", .grocery, .gram),
        (["poivre"], "Poivre", .grocery, .gram),
        (["sel"], "Sel", .grocery, .gram),
        (["vanille"], "Vanille", .grocery, .gram),
        (["levure"], "Levure chimique", .grocery, .gram),
        (["eau", "water"], "Eau", .beverage, .liter)
    ]

    public static func parse(text: String) -> [ParsedReceiptLine] {
        text.components(separatedBy: .newlines).compactMap(parseLine)
    }

    private static func parseLine(_ raw: String) -> ParsedReceiptLine? {
        let text = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard text.count >= 3, !ignoredTerms.contains(where: { text.contains($0) }) else { return nil }
        guard let entry = catalog.first(where: { entry in entry.terms.contains(where: { text.contains($0) }) }) else { return nil }
        let quantity = quantity(in: text, fallbackUnit: entry.unit)
        return ParsedReceiptLine(name: entry.name, category: entry.category, quantity: quantity.value, unit: quantity.unit, estimatedPrice: price(in: text))
    }

    private static func quantity(in text: String, fallbackUnit: FoodUnit) -> (value: Double, unit: FoodUnit) {
        let lower = text.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "×", with: "x")
        let range = NSRange(lower.startIndex..., in: lower)
        let multipackExpression = try? NSRegularExpression(pattern: "(\\d+)\\s*x\\s*(\\d+(?:\\.\\d+)?)\\s*(kg|g|cl|ml|l)\\b", options: [.caseInsensitive])
        if let match = multipackExpression?.firstMatch(in: lower, range: range),
           let countRange = Range(match.range(at: 1), in: lower),
           let amountRange = Range(match.range(at: 2), in: lower),
           let unitRange = Range(match.range(at: 3), in: lower),
           let count = Double(lower[countRange]), let amount = Double(lower[amountRange]) {
            // Pour les œufs et yaourts, le nombre de pots/pièces est plus utile que le poids total du lot.
            if fallbackUnit == .item { return (count, .item) }
            return measuredQuantity(amount * count, unit: lower[unitRange].lowercased())
        }
        let expression = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)\\s*(kg|g|cl|ml|l)\\b", options: [.caseInsensitive])
        if let match = expression?.firstMatch(in: lower, range: range),
           let numberRange = Range(match.range(at: 1), in: lower),
           let unitRange = Range(match.range(at: 2), in: lower),
           let number = Double(lower[numberRange]) {
            return measuredQuantity(number, unit: lower[unitRange].lowercased())
        }
        let countExpression = try? NSRegularExpression(pattern: "(?:^|\\s|\\*)\\s*(\\d+)\\s*x\\b", options: [])
        if let match = countExpression?.firstMatch(in: lower, range: range), let countRange = Range(match.range(at: 1), in: lower), let count = Double(lower[countRange]) { return (count, .item) }
        // Sans poids fiable, une unité représente honnêtement un article, plutôt qu’un faux "1 g".
        return (1, .item)
    }

    private static func measuredQuantity(_ amount: Double, unit: String) -> (value: Double, unit: FoodUnit) {
        switch unit {
        case "kg": return (amount, .kilogram)
        case "g": return (amount, .gram)
        case "cl": return (amount * 10, .milliliter)
        case "ml": return (amount, .milliliter)
        default: return (amount, .liter)
        }
    }

    private static func price(in text: String) -> Double? {
        let expression = try? NSRegularExpression(pattern: "\\d+[,.]\\d{2}", options: [])
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression?.matches(in: text, range: range).last, let valueRange = Range(match.range, in: text) else { return nil }
        return Double(text[valueRange].replacingOccurrences(of: ",", with: "."))
    }
}
