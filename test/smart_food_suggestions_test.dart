import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

FoodItem _testFood({
  required String id,
  required String name,
  required double protein,
  required double calories,
}) =>
    FoodItem(
      id: id,
      name: name,
      category: 'אחר',
      type: KosherFoodType.pareve,
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: 0,
      fatPer100g: 0,
      units: {'גרם': 1},
    );

/// Overrides `allFoods` to simulate a real catalog with nothing left after
/// kosher filtering -- something the real, non-empty `foodCatalog` const
/// can never produce on its own (see `_nutritionSmartFoodSuggestions`'s
/// guard clause in app_state_nutrition.dart).
class _EmptyCatalogAppState extends AppState {
  @override
  List<FoodItem> get allFoods => const [];
}

void _eatEntireCatalog(AppState state) {
  for (final food in state.allFoods) {
    state.addFood(food, 1, food.units.keys.first, fromHome: false);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'variety: a food not eaten today outranks every food already eaten today, '
    'even a much higher-protein one',
    () {
      final state = AppState();
      // Puts the entire real catalog -- including its most protein-efficient
      // items -- into the "already eaten" tier, isolating this one uneaten,
      // deliberately low-protein candidate as the only tier-1 winner.
      _eatEntireCatalog(state);
      final notEaten = _testFood(
        id: 'test_not_eaten',
        name: 'מזון וראייטי',
        protein: 1,
        calories: 200,
      );
      state.addCustomFood(notEaten);

      expect(state.smartFoodSuggestions.first, notEaten.name);
    },
  );

  test(
    'pantry: a food in stock outranks every food not in stock, '
    'even a much higher-protein one',
    () {
      final state = AppState();
      final stocked = _testFood(
        id: 'test_stocked',
        name: 'מזון במזווה',
        protein: 1,
        calories: 200,
      );
      state.addCustomFood(stocked);
      state.addPantryItem(stocked.name, 1, 'גרם', 'אחר', foodId: stocked.id);

      expect(state.smartFoodSuggestions.first, stocked.name);
    },
  );

  test(
    'protein efficiency (protein per calorie) breaks ties once variety and pantry do not',
    () {
      final state = AppState();
      // Same isolation trick as the variety test: eating the whole catalog
      // pushes every real food behind these two custom, never-eaten,
      // never-stocked candidates, so only tier 3 can separate them.
      _eatEntireCatalog(state);
      final inefficient = _testFood(
        id: 'test_inefficient',
        name: 'מזון פחות יעיל',
        protein: 10,
        calories: 100, // 0.1 g protein/kcal
      );
      final efficient = _testFood(
        id: 'test_efficient',
        name: 'מזון יעיל',
        protein: 40,
        calories: 100, // 0.4 g protein/kcal
      );
      state.addCustomFood(inefficient);
      state.addCustomFood(efficient);

      final suggestions = state.smartFoodSuggestions;
      expect(suggestions[0], efficient.name);
      expect(suggestions[1], inefficient.name);
    },
  );

  test(
    'still returns a full ranking, not an empty/crashed result, when every allowed '
    'food has already been eaten today',
    () {
      final state = AppState();
      _eatEntireCatalog(state);

      expect(state.smartFoodSuggestions, hasLength(3));
      expect(
        state.smartFoodSuggestions,
        isNot(contains('לא מצאתי כרגע מזון מתאים לכל ההגדרות')),
      );
    },
  );

  test(
    'falls back to the existing message when the allowed catalog is empty',
    () {
      final state = _EmptyCatalogAppState();

      expect(state.smartFoodSuggestions, ['לא מצאתי כרגע מזון מתאים לכל ההגדרות']);
    },
  );
}
