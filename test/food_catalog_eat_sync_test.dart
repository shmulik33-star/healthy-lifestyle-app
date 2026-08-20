import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('custom catalog food keeps the same id through eating and pantry use', () {
    final state = AppState();
    const food = FoodItem(
      id: 'custom_sync_test',
      name: 'קציצת עדשים בדיקה',
      category: 'קטניות',
      type: KosherFoodType.pareve,
      kosherStatus: KosherStatus.kosher,
      caloriesPer100g: 200,
      proteinPer100g: 10,
      carbsPer100g: 30,
      fatPer100g: 4,
      units: {'מנה': 150, 'גרם': 1},
      userCreated: true,
    );

    state.addCustomFood(food);

    final catalogFood = state.allFoods.singleWhere((item) => item.id == food.id);
    expect(catalogFood.name, food.name);
    expect(catalogFood.userCreated, isTrue);

    state.addPantryItem(
      food.name,
      3,
      'מנות',
      food.category,
      foodId: food.id,
    );

    state.addFood(catalogFood, 1, 'מנה');

    final meal = state.meals.last;
    expect(meal.foodId, food.id);
    expect(meal.name, food.name);
    expect(meal.calories, 300);
    expect(meal.protein, closeTo(15, 0.001));
    expect(meal.carbs, closeTo(45, 0.001));
    expect(meal.fat, closeTo(6, 0.001));

    final pantry = state.pantryItems.singleWhere((item) => item.foodId == food.id);
    expect(pantry.quantity, 2);
  });

  test('pantry consumption prefers exact food id over a similar food name', () {
    final state = AppState();
    const waterTuna = FoodItem(
      id: 'custom_tuna_water',
      name: 'טונה במים בדיקה',
      category: 'דגים',
      type: KosherFoodType.pareve,
      caloriesPer100g: 110,
      proteinPer100g: 25,
      carbsPer100g: 0,
      fatPer100g: 1,
      units: {'קופסה': 100, 'גרם': 1},
      userCreated: true,
    );
    const oilTuna = FoodItem(
      id: 'custom_tuna_oil',
      name: 'טונה בשמן בדיקה',
      category: 'דגים',
      type: KosherFoodType.pareve,
      caloriesPer100g: 190,
      proteinPer100g: 24,
      carbsPer100g: 0,
      fatPer100g: 10,
      units: {'קופסה': 100, 'גרם': 1},
      userCreated: true,
    );

    state.addCustomFood(waterTuna);
    state.addCustomFood(oilTuna);
    state.addPantryItem(waterTuna.name, 2, 'קופסאות', waterTuna.category, foodId: waterTuna.id);
    state.addPantryItem(oilTuna.name, 2, 'קופסאות', oilTuna.category, foodId: oilTuna.id);

    state.addFood(oilTuna, 1, 'קופסה');

    final waterStock = state.pantryItems.singleWhere((item) => item.foodId == waterTuna.id);
    final oilStock = state.pantryItems.singleWhere((item) => item.foodId == oilTuna.id);
    expect(waterStock.quantity, 2);
    expect(oilStock.quantity, 1);
  });
}
