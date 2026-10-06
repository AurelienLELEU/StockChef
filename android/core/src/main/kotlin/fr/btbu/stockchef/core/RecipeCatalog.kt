package fr.btbu.stockchef.core

import java.util.UUID
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonArray
import fr.btbu.stockchef.core.FoodUnit.*
import fr.btbu.stockchef.core.RecipeCourse.*

@Serializable data class RecipeFeed(val schemaVersion: Int, val recipes: List<Recipe>)

object RecipeFeedCodec {
    const val MAX_BYTES = 2_000_000
    private val uuid = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    private val tags = setOf("Végétarien", "Vegan", "Sans gluten")
    private val allergens = setOf("Gluten", "Lait", "Œuf", "Poisson", "Fruits à coque", "Soja", "Arachides", "Céleri", "Moutarde", "Sésame", "Sulfites", "Lupin", "Mollusques", "Crustacés")
    fun decode(text: String): List<Recipe> {
        require(text.toByteArray(Charsets.UTF_8).size <= MAX_BYTES)
        val tree = BackupCodec.json.parseToJsonElement(text).jsonObject
        tree.getValue("recipes").jsonArray.forEach { element ->
            val recipe = element.jsonObject
            require(recipe.keys.containsAll(listOf("id", "title", "baseServings", "prepTimeMinutes", "instructions", "ingredients", "dietaryTags", "allergens", "course")))
            recipe.getValue("ingredients").jsonArray.forEach {
                require(it.jsonObject.keys.containsAll(listOf("id", "name", "baseQuantity", "unit", "isPantryStaple")))
            }
        }
        val feed = BackupCodec.json.decodeFromString<RecipeFeed>(text)
        require(tree.containsKey("schemaVersion") && feed.schemaVersion == 1 && feed.recipes.size in 1..1000)
        require(feed.recipes.map { it.id.lowercase() }.distinct().size == feed.recipes.size)
        feed.recipes.forEach { recipe ->
            require(uuid.matches(recipe.id) && recipe.title.isNotBlank() && recipe.title.length <= 200)
            require(recipe.baseServings in 1..100 && recipe.prepTimeMinutes in 1..1440)
            require(recipe.instructions.size in 1..100 && recipe.instructions.all { it.isNotBlank() && it.length <= 4000 })
            require(recipe.ingredients.size in 1..100 && recipe.ingredients.map { it.id.lowercase() }.distinct().size == recipe.ingredients.size)
            require(tags.containsAll(recipe.dietaryTags) && allergens.containsAll(recipe.allergens))
            recipe.ingredients.forEach { require(uuid.matches(it.id) && it.name.isNotBlank() && it.name.length <= 200 && it.baseQuantity.isFinite() && it.baseQuantity > 0 && it.baseQuantity <= 1_000_000) }
        }
        return feed.recipes
    }
}

object RecipeCatalog {
    private fun ingredient(name: String, quantity: Double, unit: FoodUnit, staple: Boolean = false) = RecipeIngredient(id = UUID.nameUUIDFromBytes("$name-$unit".toByteArray(Charsets.UTF_8)).toString(), name = name, baseQuantity = quantity, unit = unit, isPantryStaple = staple)
    private fun recipe(title: String, minutes: Int, course: RecipeCourse, instructions: List<String>, ingredients: List<RecipeIngredient>, tags: Set<String> = emptySet(), allergens: Set<String> = emptySet(), servings: Int = 2) = Recipe(id = UUID.nameUUIDFromBytes(title.toByteArray(Charsets.UTF_8)).toString(), title = title, prepTimeMinutes = minutes, course = course, instructions = instructions, ingredients = ingredients, dietaryTags = tags, allergens = allergens, baseServings = servings)
    private val vegetarian = setOf("Végétarien")
    private val vegan = setOf("Végétarien", "Vegan", "Sans gluten")
    private val vegetarianGlutenFree = setOf("Végétarien", "Sans gluten")
    val recipes = listOf(
        recipe("Bruschettas tomate-pesto", 10, STARTER, listOf("Faites griller le pain.", "Coupez les tomates et assaisonnez-les.", "Tartinez le pesto puis ajoutez les tomates."), listOf(ingredient("Pain", 4.0, ITEM), ingredient("Tomates", 250.0, GRAM), ingredient("Pesto", 40.0, GRAM), ingredient("Huile d’olive", 10.0, MILLILITER, true)), vegetarian, setOf("Gluten", "Fruits à coque")),
        recipe("Salade quinoa, avocat et pois chiches", 20, STARTER, listOf("Faites cuire le quinoa puis refroidissez-le.", "Rincez les pois chiches et coupez l'avocat.", "Mélangez avec citron et huile d'olive."), listOf(ingredient("Quinoa", 140.0, GRAM), ingredient("Pois chiches", 250.0, GRAM), ingredient("Avocats", 1.0, ITEM), ingredient("Citrons", 1.0, ITEM), ingredient("Huile d’olive", 15.0, MILLILITER, true)), vegan),
        recipe("Velouté carotte-coco", 30, STARTER, listOf("Faites revenir les oignons et carottes.", "Couvrez d'eau et laissez mijoter.", "Ajoutez le lait de coco et mixez."), listOf(ingredient("Carottes", 500.0, GRAM), ingredient("Oignons", 1.0, ITEM), ingredient("Lait de coco", 200.0, MILLILITER), ingredient("Curry", 5.0, GRAM, true)), vegan),
        recipe("Pâtes crémeuses aux légumes", 20, MAIN, listOf("Faites cuire les pâtes.", "Faites revenir les courgettes et tomates.", "Ajoutez le lait et le fromage, puis mélangez."), listOf(ingredient("Pâtes", 180.0, GRAM), ingredient("Courgettes", 250.0, GRAM), ingredient("Tomates", 200.0, GRAM), ingredient("Lait demi-écrémé", 150.0, MILLILITER), ingredient("Fromage râpé", 60.0, GRAM), ingredient("Huile d’olive", 10.0, MILLILITER, true)), vegetarian, setOf("Gluten", "Lait")),
        recipe("Omelette aux tomates", 12, MAIN, listOf("Battez les œufs.", "Faites revenir les tomates.", "Versez les œufs et cuisez à feu doux."), listOf(ingredient("Œufs", 4.0, ITEM), ingredient("Tomates", 180.0, GRAM), ingredient("Fromage râpé", 40.0, GRAM)), vegetarianGlutenFree, setOf("Lait", "Œuf")),
        recipe("Poulet coco-curry et riz", 30, MAIN, listOf("Faites cuire le riz.", "Saisissez le poulet avec l'oignon.", "Ajoutez curry et lait de coco, puis laissez réduire."), listOf(ingredient("Poulet", 300.0, GRAM), ingredient("Riz", 160.0, GRAM), ingredient("Lait de coco", 250.0, MILLILITER), ingredient("Oignons", 1.0, ITEM), ingredient("Curry", 8.0, GRAM, true)), setOf("Sans gluten")),
        recipe("Chili végétarien express", 25, MAIN, listOf("Faites revenir oignon et poivron.", "Ajoutez haricots rouges, tomates et épices.", "Laissez mijoter puis servez avec le riz."), listOf(ingredient("Haricots rouges", 250.0, GRAM), ingredient("Tomates", 300.0, GRAM), ingredient("Poivrons", 200.0, GRAM), ingredient("Oignons", 1.0, ITEM), ingredient("Riz", 150.0, GRAM), ingredient("Paprika", 5.0, GRAM, true)), vegan),
        recipe("Saumon citronné, quinoa et épinards", 25, MAIN, listOf("Faites cuire le quinoa.", "Cuisez le saumon à la poêle.", "Faites tomber les épinards et ajoutez le citron."), listOf(ingredient("Saumon", 280.0, GRAM), ingredient("Quinoa", 150.0, GRAM), ingredient("Épinards", 250.0, GRAM), ingredient("Citrons", 1.0, ITEM), ingredient("Huile d’olive", 10.0, MILLILITER, true)), setOf("Sans gluten"), setOf("Poisson")),
        recipe("Dahl de lentilles corail", 30, MAIN, listOf("Faites revenir l'oignon avec le curry.", "Ajoutez les lentilles, tomates et lait de coco.", "Laissez cuire jusqu'à ce que les lentilles soient fondantes."), listOf(ingredient("Lentilles", 180.0, GRAM), ingredient("Tomates", 300.0, GRAM), ingredient("Lait de coco", 200.0, MILLILITER), ingredient("Oignons", 1.0, ITEM), ingredient("Curry", 8.0, GRAM, true)), vegan),
        recipe("Wraps thon-avocat", 12, MAIN, listOf("Écrasez l'avocat avec le citron.", "Répartissez thon, salade et avocat dans les tortillas.", "Roulez et servez."), listOf(ingredient("Tortillas", 4.0, ITEM), ingredient("Thon", 200.0, GRAM), ingredient("Avocats", 1.0, ITEM), ingredient("Salade verte", 1.0, ITEM), ingredient("Citrons", 1.0, ITEM)), allergens = setOf("Gluten", "Poisson")),
        recipe("Pancakes banane et avoine", 15, DESSERT, listOf("Mixez banane, œufs et flocons.", "Cuisez de petites louches de pâte à la poêle.", "Servez avec un filet de miel."), listOf(ingredient("Bananes", 2.0, ITEM), ingredient("Œufs", 2.0, ITEM), ingredient("Flocons d’avoine", 100.0, GRAM), ingredient("Miel", 20.0, GRAM, true)), vegetarian, setOf("Œuf", "Gluten")),
        recipe("Crumble pommes-amandes", 40, DESSERT, listOf("Coupez les pommes et placez-les dans un plat.", "Mélangez farine, beurre et amandes.", "Parsemez et enfournez 25 minutes à 180 °C."), listOf(ingredient("Pommes", 5.0, ITEM), ingredient("Farine", 150.0, GRAM), ingredient("Beurre", 90.0, GRAM), ingredient("Amandes", 70.0, GRAM), ingredient("Miel", 40.0, GRAM, true)), vegetarian, setOf("Gluten", "Lait", "Fruits à coque"), 4),
        recipe("Verrines yaourt, fruits rouges et noix", 5, DESSERT, listOf("Répartissez les yaourts dans deux verres.", "Ajoutez fruits rouges et noix.", "Terminez avec un peu de miel."), listOf(ingredient("Yaourts", 2.0, ITEM), ingredient("Fruits rouges", 180.0, GRAM), ingredient("Noix", 40.0, GRAM), ingredient("Miel", 20.0, GRAM, true)), vegetarianGlutenFree, setOf("Lait", "Fruits à coque")),
        recipe("Energy balls dattes-amandes", 15, SNACK, listOf("Mixez dattes, amandes et cacao.", "Formez huit bouchées.", "Réservez au frais 30 minutes."), listOf(ingredient("Dattes", 180.0, GRAM), ingredient("Amandes", 120.0, GRAM), ingredient("Chocolat noir", 30.0, GRAM)), vegan, setOf("Fruits à coque"), 8),
        recipe("Barres d’avoine, noix et chocolat", 35, SNACK, listOf("Mélangez flocons, noix, miel et chocolat haché.", "Tassez dans un petit moule.", "Cuisez 20 minutes à 170 °C puis découpez froid."), listOf(ingredient("Flocons d’avoine", 220.0, GRAM), ingredient("Noix", 80.0, GRAM), ingredient("Chocolat noir", 80.0, GRAM), ingredient("Miel", 100.0, GRAM)), vegetarian, setOf("Gluten", "Fruits à coque"), 8),
        recipe("Pudding de chia aux fruits rouges", 10, SNACK, listOf("Mélangez les graines de chia et le lait.", "Laissez gonfler au frais au moins 2 heures.", "Ajoutez les fruits rouges avant de servir."), listOf(ingredient("Graines de chia", 45.0, GRAM), ingredient("Lait demi-écrémé", 350.0, MILLILITER), ingredient("Fruits rouges", 180.0, GRAM)), vegetarianGlutenFree, setOf("Lait")),
        recipe("Houmous minute et crudités", 10, SNACK, listOf("Mixez pois chiches, citron et huile d'olive.", "Ajustez avec un peu d'eau et de sel.", "Servez avec carottes et concombre."), listOf(ingredient("Pois chiches", 250.0, GRAM), ingredient("Citrons", 1.0, ITEM), ingredient("Carottes", 200.0, GRAM), ingredient("Concombre", 1.0, ITEM), ingredient("Huile d’olive", 20.0, MILLILITER, true)), vegan),
        recipe("Tartines avocat et œuf", 12, SNACK, listOf("Faites griller le pain.", "Écrasez l'avocat avec le citron.", "Ajoutez les œufs mollets et le poivre."), listOf(ingredient("Pain", 4.0, ITEM), ingredient("Avocats", 1.0, ITEM), ingredient("Œufs", 2.0, ITEM), ingredient("Citrons", 1.0, ITEM), ingredient("Poivre", 2.0, GRAM, true)), vegetarian, setOf("Gluten", "Œuf")),
        recipe("Smoothie banane, fruits rouges et chia", 5, SNACK, listOf("Placez tous les ingrédients dans un blender.", "Mixez jusqu'à texture lisse.", "Versez dans deux gourdes ou verres."), listOf(ingredient("Bananes", 2.0, ITEM), ingredient("Fruits rouges", 200.0, GRAM), ingredient("Lait demi-écrémé", 300.0, MILLILITER), ingredient("Graines de chia", 20.0, GRAM)), vegetarianGlutenFree, setOf("Lait")),
    )
}