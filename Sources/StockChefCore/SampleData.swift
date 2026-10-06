import Foundation

public enum SampleData {
    public static let recipes: [Recipe] = [
        Recipe(title: "Bruschettas tomate-pesto", baseServings: 2, prepTimeMinutes: 10, instructions: ["Faites griller le pain.", "Coupez les tomates et assaisonnez-les.", "Tartinez le pesto puis ajoutez les tomates."], ingredients: [
            RecipeIngredient(name: "Pain", baseQuantity: 4, unit: .item), RecipeIngredient(name: "Tomates", baseQuantity: 250, unit: .gram), RecipeIngredient(name: "Pesto", baseQuantity: 40, unit: .gram), RecipeIngredient(name: "Huile d’olive", baseQuantity: 10, unit: .milliliter, isPantryStaple: true)
        ], dietaryTags: [.vegetarian], allergens: [.gluten, .nuts], course: .starter),
        Recipe(title: "Salade quinoa, avocat et pois chiches", baseServings: 2, prepTimeMinutes: 20, instructions: ["Faites cuire le quinoa puis refroidissez-le.", "Rincez les pois chiches et coupez l’avocat.", "Mélangez avec citron et huile d’olive."], ingredients: [
            RecipeIngredient(name: "Quinoa", baseQuantity: 140, unit: .gram), RecipeIngredient(name: "Pois chiches", baseQuantity: 250, unit: .gram), RecipeIngredient(name: "Avocats", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Citrons", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Huile d’olive", baseQuantity: 15, unit: .milliliter, isPantryStaple: true)
        ], dietaryTags: [.vegetarian, .vegan, .glutenFree], course: .starter),
        Recipe(title: "Velouté carotte-coco", baseServings: 2, prepTimeMinutes: 30, instructions: ["Faites revenir les oignons et carottes.", "Couvrez d’eau et laissez mijoter.", "Ajoutez le lait de coco et mixez."], ingredients: [
            RecipeIngredient(name: "Carottes", baseQuantity: 500, unit: .gram), RecipeIngredient(name: "Oignons", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Lait de coco", baseQuantity: 200, unit: .milliliter), RecipeIngredient(name: "Curry", baseQuantity: 5, unit: .gram, isPantryStaple: true)
        ], dietaryTags: [.vegetarian, .vegan, .glutenFree], course: .starter),
        Recipe(title: "Pâtes crémeuses aux légumes", baseServings: 2, prepTimeMinutes: 20, instructions: ["Faites cuire les pâtes.", "Faites revenir les courgettes et tomates.", "Ajoutez le lait et le fromage, puis mélangez."], ingredients: [
            RecipeIngredient(name: "Pâtes", baseQuantity: 180, unit: .gram),
            RecipeIngredient(name: "Courgettes", baseQuantity: 250, unit: .gram),
            RecipeIngredient(name: "Tomates", baseQuantity: 200, unit: .gram),
            RecipeIngredient(name: "Lait demi-écrémé", baseQuantity: 150, unit: .milliliter),
            RecipeIngredient(name: "Fromage râpé", baseQuantity: 60, unit: .gram),
            RecipeIngredient(name: "Huile d’olive", baseQuantity: 10, unit: .milliliter, isPantryStaple: true)
        ], dietaryTags: [.vegetarian], allergens: [.gluten, .milk], course: .main),
        Recipe(title: "Omelette aux tomates", baseServings: 2, prepTimeMinutes: 12, instructions: ["Battez les œufs.", "Faites revenir les tomates.", "Versez les œufs et cuisez à feu doux."], ingredients: [
            RecipeIngredient(name: "Œufs", baseQuantity: 4, unit: .item),
            RecipeIngredient(name: "Tomates", baseQuantity: 180, unit: .gram),
            RecipeIngredient(name: "Fromage râpé", baseQuantity: 40, unit: .gram)
        ], dietaryTags: [.vegetarian, .glutenFree], allergens: [.milk, .egg], course: .main),
        Recipe(title: "Poulet coco-curry et riz", baseServings: 2, prepTimeMinutes: 30, instructions: ["Faites cuire le riz.", "Saisissez le poulet avec l’oignon.", "Ajoutez curry et lait de coco, puis laissez réduire."], ingredients: [
            RecipeIngredient(name: "Poulet", baseQuantity: 300, unit: .gram), RecipeIngredient(name: "Riz", baseQuantity: 160, unit: .gram), RecipeIngredient(name: "Lait de coco", baseQuantity: 250, unit: .milliliter), RecipeIngredient(name: "Oignons", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Curry", baseQuantity: 8, unit: .gram, isPantryStaple: true)
        ], dietaryTags: [.glutenFree], course: .main),
        Recipe(title: "Chili végétarien express", baseServings: 2, prepTimeMinutes: 25, instructions: ["Faites revenir oignon et poivron.", "Ajoutez haricots rouges, tomates et épices.", "Laissez mijoter puis servez avec le riz."], ingredients: [
            RecipeIngredient(name: "Haricots rouges", baseQuantity: 250, unit: .gram), RecipeIngredient(name: "Tomates", baseQuantity: 300, unit: .gram), RecipeIngredient(name: "Poivrons", baseQuantity: 200, unit: .gram), RecipeIngredient(name: "Oignons", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Riz", baseQuantity: 150, unit: .gram), RecipeIngredient(name: "Paprika", baseQuantity: 5, unit: .gram, isPantryStaple: true)
        ], dietaryTags: [.vegetarian, .vegan, .glutenFree], course: .main),
        Recipe(title: "Saumon citronné, quinoa et épinards", baseServings: 2, prepTimeMinutes: 25, instructions: ["Faites cuire le quinoa.", "Cuisez le saumon à la poêle.", "Faites tomber les épinards et ajoutez le citron."], ingredients: [
            RecipeIngredient(name: "Saumon", baseQuantity: 280, unit: .gram), RecipeIngredient(name: "Quinoa", baseQuantity: 150, unit: .gram), RecipeIngredient(name: "Épinards", baseQuantity: 250, unit: .gram), RecipeIngredient(name: "Citrons", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Huile d’olive", baseQuantity: 10, unit: .milliliter, isPantryStaple: true)
        ], dietaryTags: [.glutenFree], allergens: [.fish], course: .main),
        Recipe(title: "Dahl de lentilles corail", baseServings: 2, prepTimeMinutes: 30, instructions: ["Faites revenir l’oignon avec le curry.", "Ajoutez les lentilles, tomates et lait de coco.", "Laissez cuire jusqu’à ce que les lentilles soient fondantes."], ingredients: [
            RecipeIngredient(name: "Lentilles", baseQuantity: 180, unit: .gram), RecipeIngredient(name: "Tomates", baseQuantity: 300, unit: .gram), RecipeIngredient(name: "Lait de coco", baseQuantity: 200, unit: .milliliter), RecipeIngredient(name: "Oignons", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Curry", baseQuantity: 8, unit: .gram, isPantryStaple: true)
        ], dietaryTags: [.vegetarian, .vegan, .glutenFree], course: .main),
        Recipe(title: "Wraps thon-avocat", baseServings: 2, prepTimeMinutes: 12, instructions: ["Écrasez l’avocat avec le citron.", "Répartissez thon, salade et avocat dans les tortillas.", "Roulez et servez."], ingredients: [
            RecipeIngredient(name: "Tortillas", baseQuantity: 4, unit: .item), RecipeIngredient(name: "Thon", baseQuantity: 200, unit: .gram), RecipeIngredient(name: "Avocats", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Salade verte", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Citrons", baseQuantity: 1, unit: .item)
        ], allergens: [.gluten, .fish], course: .main),
        Recipe(title: "Pancakes banane et avoine", baseServings: 2, prepTimeMinutes: 15, instructions: ["Mixez banane, œufs et flocons.", "Cuisez de petites louches de pâte à la poêle.", "Servez avec un filet de miel."], ingredients: [
            RecipeIngredient(name: "Bananes", baseQuantity: 2, unit: .item), RecipeIngredient(name: "Œufs", baseQuantity: 2, unit: .item), RecipeIngredient(name: "Flocons d’avoine", baseQuantity: 100, unit: .gram), RecipeIngredient(name: "Miel", baseQuantity: 20, unit: .gram, isPantryStaple: true)
        ], dietaryTags: [.vegetarian], allergens: [.egg, .gluten], course: .dessert),
        Recipe(title: "Crumble pommes-amandes", baseServings: 4, prepTimeMinutes: 40, instructions: ["Coupez les pommes et placez-les dans un plat.", "Mélangez farine, beurre et amandes.", "Parsemez et enfournez 25 minutes à 180 °C."], ingredients: [
            RecipeIngredient(name: "Pommes", baseQuantity: 5, unit: .item), RecipeIngredient(name: "Farine", baseQuantity: 150, unit: .gram), RecipeIngredient(name: "Beurre", baseQuantity: 90, unit: .gram), RecipeIngredient(name: "Amandes", baseQuantity: 70, unit: .gram), RecipeIngredient(name: "Miel", baseQuantity: 40, unit: .gram, isPantryStaple: true)
        ], dietaryTags: [.vegetarian], allergens: [.gluten, .milk, .nuts], course: .dessert),
        Recipe(title: "Verrines yaourt, fruits rouges et noix", baseServings: 2, prepTimeMinutes: 5, instructions: ["Répartissez les yaourts dans deux verres.", "Ajoutez fruits rouges et noix.", "Terminez avec un peu de miel."], ingredients: [
            RecipeIngredient(name: "Yaourts", baseQuantity: 2, unit: .item), RecipeIngredient(name: "Fruits rouges", baseQuantity: 180, unit: .gram), RecipeIngredient(name: "Noix", baseQuantity: 40, unit: .gram), RecipeIngredient(name: "Miel", baseQuantity: 20, unit: .gram, isPantryStaple: true)
        ], dietaryTags: [.vegetarian, .glutenFree], allergens: [.milk, .nuts], course: .dessert),
        Recipe(title: "Energy balls dattes-amandes", baseServings: 8, prepTimeMinutes: 15, instructions: ["Mixez dattes, amandes et cacao.", "Formez huit bouchées.", "Réservez au frais 30 minutes."], ingredients: [
            RecipeIngredient(name: "Dattes", baseQuantity: 180, unit: .gram), RecipeIngredient(name: "Amandes", baseQuantity: 120, unit: .gram), RecipeIngredient(name: "Chocolat noir", baseQuantity: 30, unit: .gram)
        ], dietaryTags: [.vegetarian, .vegan, .glutenFree], allergens: [.nuts], course: .snack),
        Recipe(title: "Barres d’avoine, noix et chocolat", baseServings: 8, prepTimeMinutes: 35, instructions: ["Mélangez flocons, noix, miel et chocolat haché.", "Tassez dans un petit moule.", "Cuisez 20 minutes à 170 °C puis découpez froid."], ingredients: [
            RecipeIngredient(name: "Flocons d’avoine", baseQuantity: 220, unit: .gram), RecipeIngredient(name: "Noix", baseQuantity: 80, unit: .gram), RecipeIngredient(name: "Chocolat noir", baseQuantity: 80, unit: .gram), RecipeIngredient(name: "Miel", baseQuantity: 100, unit: .gram)
        ], dietaryTags: [.vegetarian], allergens: [.gluten, .nuts], course: .snack),
        Recipe(title: "Pudding de chia aux fruits rouges", baseServings: 2, prepTimeMinutes: 10, instructions: ["Mélangez les graines de chia et le lait.", "Laissez gonfler au frais au moins 2 heures.", "Ajoutez les fruits rouges avant de servir."], ingredients: [
            RecipeIngredient(name: "Graines de chia", baseQuantity: 45, unit: .gram), RecipeIngredient(name: "Lait demi-écrémé", baseQuantity: 350, unit: .milliliter), RecipeIngredient(name: "Fruits rouges", baseQuantity: 180, unit: .gram)
        ], dietaryTags: [.vegetarian, .glutenFree], allergens: [.milk], course: .snack),
        Recipe(title: "Houmous minute et crudités", baseServings: 2, prepTimeMinutes: 10, instructions: ["Mixez pois chiches, citron et huile d’olive.", "Ajustez avec un peu d’eau et de sel.", "Servez avec carottes et concombre."], ingredients: [
            RecipeIngredient(name: "Pois chiches", baseQuantity: 250, unit: .gram), RecipeIngredient(name: "Citrons", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Carottes", baseQuantity: 200, unit: .gram), RecipeIngredient(name: "Concombre", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Huile d’olive", baseQuantity: 20, unit: .milliliter, isPantryStaple: true)
        ], dietaryTags: [.vegetarian, .vegan, .glutenFree], course: .snack),
        Recipe(title: "Tartines avocat et œuf", baseServings: 2, prepTimeMinutes: 12, instructions: ["Faites griller le pain.", "Écrasez l’avocat avec le citron.", "Ajoutez les œufs mollets et le poivre."], ingredients: [
            RecipeIngredient(name: "Pain", baseQuantity: 4, unit: .item), RecipeIngredient(name: "Avocats", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Œufs", baseQuantity: 2, unit: .item), RecipeIngredient(name: "Citrons", baseQuantity: 1, unit: .item), RecipeIngredient(name: "Poivre", baseQuantity: 2, unit: .gram, isPantryStaple: true)
        ], dietaryTags: [.vegetarian], allergens: [.gluten, .egg], course: .snack),
        Recipe(title: "Smoothie banane, fruits rouges et chia", baseServings: 2, prepTimeMinutes: 5, instructions: ["Placez tous les ingrédients dans un blender.", "Mixez jusqu’à texture lisse.", "Versez dans deux gourdes ou verres."], ingredients: [
            RecipeIngredient(name: "Bananes", baseQuantity: 2, unit: .item), RecipeIngredient(name: "Fruits rouges", baseQuantity: 200, unit: .gram), RecipeIngredient(name: "Lait demi-écrémé", baseQuantity: 300, unit: .milliliter), RecipeIngredient(name: "Graines de chia", baseQuantity: 20, unit: .gram)
        ], dietaryTags: [.vegetarian, .glutenFree], allergens: [.milk], course: .snack)
    ]

    public static let inventory: [InventoryItem] = [
        InventoryItem(name: "Lait demi-écrémé", category: .dairy, quantity: 1.5, unit: .liter, expiryDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)),
        InventoryItem(name: "Œufs", category: .grocery, quantity: 6, unit: .item, expiryDate: Calendar.current.date(byAdding: .day, value: 8, to: .now)),
        InventoryItem(name: "Tomates", category: .vegetable, quantity: 500, unit: .gram, expiryDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)),
        InventoryItem(name: "Courgettes", category: .vegetable, quantity: 350, unit: .gram),
        InventoryItem(name: "Pâtes", category: .grocery, quantity: 500, unit: .gram),
        InventoryItem(name: "Fromage râpé", category: .dairy, quantity: 150, unit: .gram)
    ]
}
