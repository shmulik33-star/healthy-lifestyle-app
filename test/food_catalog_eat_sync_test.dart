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
    state.addPantryItem(
      waterTuna.name,
      2,
      'קופסאות',
      waterTuna.category,
      foodId: waterTuna.id,
    );
    state.addPantryItem(
      oilTuna.name,
      2,
      'קופסאות',
      oilTuna.category,
      foodId: oilTuna.id,
    );

    state.addFood(oilTuna, 1, 'קופסה');

    final waterStock = state.pantryItems.singleWhere(
      (item) => item.foodId == waterTuna.id,
    );
    final oilStock = state.pantryItems.singleWhere(
      (item) => item.foodId == oilTuna.id,
    );
    expect(waterStock.quantity, 2);
    expect(oilStock.quantity, 1);
  });

  test('manual pantry entry links to one exact catalog food id', () {
    final state = AppState();
    const food = FoodItem(
      id: 'custom_exact_name_link',
      name: 'ממרח עדשים ייחודי',
      category: 'ממרחים ורטבים',
      type: KosherFoodType.pareve,
      caloriesPer100g: 160,
      proteinPer100g: 8,
      carbsPer100g: 20,
      fatPer100g: 5,
      units: {'מנה': 50, 'גרם': 1},
      userCreated: true,
    );

    state.addCustomFood(food);
    state.addPantryItem(food.name, 2, 'מנות', food.category);

    expect(state.pantryItems.single.foodId, food.id);
  });

  test('egg aliases do not merge or consume egg salad as plain eggs', () {
    final state = AppState();
    state.addPantryItem(
      'ביצים',
      6,
      'יחידות',
      'ביצים',
      foodId: 'egg',
    );
    state.addPantryItem(
      'סלט ביצים',
      2,
      'מנות',
      'מאפים ומזון מוכן',
      foodId: 'egg_salad',
    );

    expect(state.pantryItems, hasLength(2));

    final meal = MealEntry(
      foodId: 'egg_salad',
      name: 'סלט ביצים',
      quantity: 1,
      unit: 'מנה',
      grams: 200,
      calories: 300,
      protein: 14,
      carbs: 8,
      fat: 22,
      type: KosherFoodType.pareve,
      time: DateTime.now(),
    );
    state.consumeFromPantryByMeal(meal);

    final eggs = state.pantryItems.singleWhere((item) => item.foodId == 'egg');
    final eggSalad = state.pantryItems.singleWhere(
      (item) => item.foodId == 'egg_salad',
    );
    expect(eggs.quantity, 6);
    expect(eggSalad.quantity, 1);
  });

  test('egg salad consumption is not converted into egg-unit shopping data', () {
    final state = AppState();
    state.meals.add(
      MealEntry(
        foodId: 'egg_salad',
        name: 'סלט ביצים',
        quantity: 2,
        unit: 'מנה',
        grams: 400,
        calories: 600,
        protein: 28,
        carbs: 16,
        fat: 44,
        type: KosherFoodType.pareve,
        time: DateTime.now(),
      ),
    );

    final consumption = state.last7DayConsumption;
    expect(consumption['סלט ביצים'], 2);
    expect(consumption.containsKey('ביצים'), isFalse);
  });
}
