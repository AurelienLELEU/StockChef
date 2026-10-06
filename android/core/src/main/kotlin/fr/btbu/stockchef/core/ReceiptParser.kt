package fr.btbu.stockchef.core

import java.text.Normalizer
import java.util.Locale

object ReceiptParser {
    private data class Entry(val terms: List<String>, val name: String, val category: FoodCategory, val unit: FoodUnit)
    private fun entry(terms: String, name: String, category: FoodCategory, unit: FoodUnit) = Entry(terms.split('|'), name, category, unit)
    private val ignored = listOf("total", "tva", "carte", "especes", "merci", "sac", "ticket", "rendu", "paiement", "remise", "coupon", "dentif", "felix", "sheba", "perfect fit", "perf fit", "miroir", "hygiene", "beaute", "essuie")
    private val catalog = listOf(
        entry("jeunes pousse", "Jeunes pousses", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("tomate grappe", "Tomates", FoodCategory.VEGETABLE, FoodUnit.GRAM),
        entry("orange jus|oran jus", "Oranges à jus", FoodCategory.VEGETABLE, FoodUnit.KILOGRAM),
        entry("mandarine", "Mandarines", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("prun myrtille|prune myrtille", "Fruits rouges", FoodCategory.FROZEN, FoodUnit.GRAM),
        entry("burger chicken|burg chicken", "Burger de poulet", FoodCategory.MEAT, FoodUnit.ITEM),
        entry("saumon fume|saumon fum", "Saumon", FoodCategory.MEAT, FoodUnit.GRAM),
        entry("calamar|romaine", "Calamars à la romaine", FoodCategory.FROZEN, FoodUnit.ITEM),
        entry("soupe saumon", "Soupe au saumon", FoodCategory.GROCERY, FoodUnit.MILLILITER),
        entry("wrap plt|wrap avocat", "Tortillas", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("tortel|tortell", "Tortellini", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("pat feuil|pate feuil", "Pâte feuilletée", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("cooki grain|cookie grain", "Cookies aux céréales", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("cocktail gra|cocktail grain", "Cocktail de graines", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("curly|donuts cacah", "Curly cacahuètes", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("snacks pop|snack pop", "Snacks apéritifs", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("gouter ecor|gouter choco", "Goûters chocolat", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("kit fruits", "Gourdes de fruits", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("smoothie berr|smoothie", "Smoothie fruits rouges", FoodCategory.BEVERAGE, FoodUnit.MILLILITER),
        entry("bridelice", "Crème", FoodCategory.DAIRY, FoodUnit.MILLILITER),
        entry("lait mont", "Lait demi-écrémé", FoodCategory.DAIRY, FoodUnit.MILLILITER),
        entry("cheddar rape|cheddar rap", "Cheddar râpé", FoodCategory.DAIRY, FoodUnit.GRAM),
        entry("mel fromage|mel. fromage", "Mélange de fromages râpés", FoodCategory.DAIRY, FoodUnit.GRAM),
        entry("emmental rape|emmental rap", "Fromage râpé", FoodCategory.DAIRY, FoodUnit.GRAM),
        entry("fromage onct|onctueux", "Fromage onctueux", FoodCategory.DAIRY, FoodUnit.GRAM),
        entry("yrt lit|yaourt lit|yogurt lit", "Yaourts", FoodCategory.DAIRY, FoodUnit.ITEM),
        entry("sauce aioli|aioli", "Sauce aïoli", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("rhum", "Rhum", FoodCategory.BEVERAGE, FoodUnit.LITER),
        entry("lait coco|coco lait", "Lait de coco", FoodCategory.GROCERY, FoodUnit.MILLILITER),
        entry("lait|milk", "Lait demi-écrémé", FoodCategory.DAIRY, FoodUnit.LITER),
        entry("beurre|butter", "Beurre", FoodCategory.DAIRY, FoodUnit.GRAM),
        entry("creme|cream", "Crème", FoodCategory.DAIRY, FoodUnit.MILLILITER),
        entry("oeuf|egg", "Œufs", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("tomate", "Tomates", FoodCategory.VEGETABLE, FoodUnit.GRAM),
        entry("courgette", "Courgettes", FoodCategory.VEGETABLE, FoodUnit.GRAM),
        entry("avocat", "Avocats", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("carotte", "Carottes", FoodCategory.VEGETABLE, FoodUnit.GRAM),
        entry("epinard|spinach", "Épinards", FoodCategory.VEGETABLE, FoodUnit.GRAM),
        entry("salade|laitue", "Salade verte", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("poivron", "Poivrons", FoodCategory.VEGETABLE, FoodUnit.GRAM),
        entry("champignon", "Champignons", FoodCategory.VEGETABLE, FoodUnit.GRAM),
        entry("concombre|cucumber", "Concombre", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("citron|lemons", "Citrons", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("poulet|chicken", "Poulet", FoodCategory.MEAT, FoodUnit.GRAM),
        entry("saumon|salmon", "Saumon", FoodCategory.MEAT, FoodUnit.GRAM),
        entry("thon|tuna", "Thon", FoodCategory.MEAT, FoodUnit.GRAM),
        entry("steak|boeuf", "Bœuf haché", FoodCategory.MEAT, FoodUnit.GRAM),
        entry("pates|pasta", "Pâtes", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("riz|rice", "Riz", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("quinoa", "Quinoa", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("semoule|couscous", "Semoule", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("lentille", "Lentilles", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("pois chiche|pois-chiche", "Pois chiches", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("haricot rouge|haricot", "Haricots rouges", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("flocon avoine|avoine", "Flocons d’avoine", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("farine", "Farine", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("chocolat", "Chocolat noir", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("miel", "Miel", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("dattes|date fruit", "Dattes", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("banane", "Bananes", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("pomme", "Pommes", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("fruits rouge|framboise|myrtille", "Fruits rouges", FoodCategory.FROZEN, FoodUnit.GRAM),
        entry("amande", "Amandes", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("noix|walnut", "Noix", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("noisette", "Noisettes", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("cajou|cashew", "Noix de cajou", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("graine chia|chia", "Graines de chia", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("graine courge|courge graines", "Graines de courge", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("oignon|onion", "Oignons", FoodCategory.VEGETABLE, FoodUnit.ITEM),
        entry("fromage|emmental|comte", "Fromage râpé", FoodCategory.DAIRY, FoodUnit.GRAM),
        entry("yaourt|yogurt", "Yaourts", FoodCategory.DAIRY, FoodUnit.ITEM),
        entry("pain|bread", "Pain", FoodCategory.BAKERY, FoodUnit.ITEM),
        entry("tortilla|wrap", "Tortillas", FoodCategory.GROCERY, FoodUnit.ITEM),
        entry("huile olive|huile", "Huile d’olive", FoodCategory.GROCERY, FoodUnit.MILLILITER),
        entry("vinaigre", "Vinaigre", FoodCategory.GROCERY, FoodUnit.MILLILITER),
        entry("moutarde", "Moutarde", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("sauce soja|soja sauce", "Sauce soja", FoodCategory.GROCERY, FoodUnit.MILLILITER),
        entry("pesto", "Pesto", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("curry", "Curry", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("paprika", "Paprika", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("poivre", "Poivre", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("sel", "Sel", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("vanille", "Vanille", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("levure", "Levure chimique", FoodCategory.GROCERY, FoodUnit.GRAM),
        entry("eau|water", "Eau", FoodCategory.BEVERAGE, FoodUnit.LITER),
    )
    fun parse(text: String): List<InventoryItem> = text.lineSequence().mapNotNull { raw ->
        val folded = Normalizer.normalize(raw.lowercase(Locale.ROOT).replace("œ", "oe"), Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "")
        if (folded.length < 3 || ignored.any(folded::contains)) return@mapNotNull null
        val entry = catalog.firstOrNull { it.terms.any(folded::contains) } ?: return@mapNotNull null
        val normalized = folded.replace(',', '.').replace('×', 'x')
        val pack = Regex("(\\d+)\\s*x\\s*(\\d+(?:\\.\\d+)?)\\s*(kg|g|cl|ml|l)\\b").find(normalized)
        val measured = Regex("(\\d+(?:\\.\\d+)?)\\s*(kg|g|cl|ml|l)\\b").find(normalized)
        val quantity: Double
        val unit: FoodUnit
        if (pack != null && entry.unit == FoodUnit.ITEM) {
            quantity = pack.groupValues[1].toDouble(); unit = FoodUnit.ITEM
        } else if (pack != null || measured != null) {
            val match = pack ?: measured!!
            val amount = if (pack != null) match.groupValues[1].toDouble() * match.groupValues[2].toDouble() else match.groupValues[1].toDouble()
            val symbol = match.groupValues.last()
            quantity = if (symbol == "cl") amount * 10 else amount
            unit = when (symbol) { "kg" -> FoodUnit.KILOGRAM; "g" -> FoodUnit.GRAM; "cl", "ml" -> FoodUnit.MILLILITER; else -> FoodUnit.LITER }
        } else {
            quantity = Regex("(?:^|\\s|\\*)\\s*(\\d+)\\s*x\\b").find(normalized)?.groupValues?.get(1)?.toDouble() ?: 1.0
            unit = FoodUnit.ITEM
        }
        if (!quantity.isFinite() || quantity <= 0) return@mapNotNull null
        InventoryItem(name = entry.name, category = entry.category, quantity = quantity, unit = unit, expiryDate = date(entry.category.days))
    }.toList()
}