import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

FoodItem _testFood({required String id, required String name}) => FoodItem(
      id: id,
      name: name,
      category: 'אחר',
      type: KosherFoodType.pareve,
      caloriesPer100g: 100,
      proteinPer100g: 10,
      carbsPer100g: 0,
      fatPer100g: 0,
      units: {'גרם': 1},
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('disliking a food excludes it from recommendation eligibility', () {
    final state = AppState();
    final food = _testFood(id: 'test_disliked', name: 'מזון לא אהוב');
    state.addCustomFood(food);

    expect(state.foodAllowedForRecommendations(food), isTrue);

    state.setFoodDisliked(food, true);
    expect(state.foodDislikes, contains('test_disliked'));
    expect(state.foodAllowedForRecommendations(food), isFalse);

    state.setFoodDisliked(food, false);
    expect(state.foodDislikes, isNot(contains('test_disliked')));
    expect(state.foodAllowedForRecommendations(food), isTrue);
  });

  test('a disliked food is never among the smart food suggestions, even when '
      'it would otherwise rank first on variety', () {
    final state = AppState();
    // Eating the whole real catalog pushes every real food into the
    // "already eaten today" tier, isolating these two never-eaten custom
    // foods as the only tier-1 candidates (same isolation trick as
    // smart_food_suggestions_test.dart).
    for (final food in state.allFoods) {
      state.addFood(food, 1, food.units.keys.first, fromHome: false);
    }
    final disliked = _testFood(id: 'test_disliked2', name: 'מזון לא אהוב 2');
    final liked = _testFood(id: 'test_liked2', name: 'מזון אהוב 2');
    state.addCustomFood(disliked);
    state.addCustomFood(liked);
    state.setFoodDisliked(disliked, true);

    expect(state.smartFoodSuggestions, isNot(contains(disliked.name)));
    expect(state.smartFoodSuggestions, contains(liked.name));
  });

  test('setFoodDisliked ignores a food with no id', () {
    final state = AppState();
    const blank = FoodItem(
      id: '',
      name: 'ללא מזהה',
      category: 'אחר',
      type: KosherFoodType.pareve,
      caloriesPer100g: 0,
      proteinPer100g: 0,
      carbsPer100g: 0,
      fatPer100g: 0,
      units: {'גרם': 1},
    );

    state.setFoodDisliked(blank, true);
    expect(state.foodDislikes, isEmpty);
  });

  test('foodDislikes survives a local save/load roundtrip', () async {
    final state = AppState();
    final food = _testFood(id: 'test_persist', name: 'מזון לבדיקת שמירה');
    state.addCustomFood(food);
    state.setFoodDisliked(food, true);

    final reloaded = await AppState.load();
    expect(reloaded.foodDislikes, contains('test_persist'));
  });

  test('foodDislikes rides along in the cloud sync profile snapshot', () async {
    final source = AppState();
    final food = _testFood(id: 'test_cloud', name: 'מזון לבדיקת ענן');
    source.addCustomFood(food);
    source.setFoodDisliked(food, true);

    final payload = source.exportCloudSyncState();
    final restored = AppState();
    await restored.applyCloudSyncState(payload);

    expect(restored.foodDislikes, contains('test_cloud'));
  });
}
