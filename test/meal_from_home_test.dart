import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a meal logged as not-from-home does not draw down the pantry', () {
    final state = AppState();
    final food = state.allFoods.firstWhere((f) => f.id == 'chicken');
    state.addPantryItem('חזה עוף מבושל', 5, 'יחידות', 'בשר ועוף', foodId: 'chicken');

    state.addFood(food, 1, 'חתיכה בינונית', fromHome: false);

    expect(state.pantryItems.single.quantity, 5);
    expect(state.meals.single.fromHome, isFalse);
  });

  test('a meal logged as from-home (default) still draws down the pantry', () {
    final state = AppState();
    final food = state.allFoods.firstWhere((f) => f.id == 'chicken');
    state.addPantryItem('חזה עוף מבושל', 5, 'יחידות', 'בשר ועוף', foodId: 'chicken');

    // fromHome omitted on purpose: exercises the default, not just the
    // explicit true path.
    state.addFood(food, 1, 'חתיכה בינונית');

    expect(state.pantryItems.single.quantity, 4);
    expect(state.meals.single.fromHome, isTrue);
  });

  test('MealEntry.fromHome round-trips through JSON, and missing field '
      'defaults to true for records saved before this field existed', () {
    final meal = MealEntry(
      foodId: 'chicken',
      name: 'חזה עוף מבושל',
      quantity: 1,
      unit: 'חתיכה בינונית',
      grams: 140,
      calories: 231,
      protein: 43.4,
      carbs: 0,
      fat: 5.04,
      type: KosherFoodType.meat,
      time: DateTime(2026, 8, 25, 12, 0),
      fromHome: false,
    );

    final json = meal.toJson();
    expect(json['fromHome'], false);

    final restored = MealEntry.fromJson(json);
    expect(restored.fromHome, isFalse);

    final legacyJson = Map<String, dynamic>.from(json)..remove('fromHome');
    final legacyRestored = MealEntry.fromJson(legacyJson);
    expect(legacyRestored.fromHome, isTrue);
  });
}
