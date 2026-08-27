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

/// Overrides `allFoods` to just [_foods], so a ranking tier can be observed
/// in isolation without the real 29-item catalog (all allowed, all
/// non-disliked) burying the signal in noise -- same trick as
/// `_EmptyCatalogAppState` in smart_food_suggestions_test.dart.
class _FixedCatalogAppState extends AppState {
  _FixedCatalogAppState(this._foods);
  final List<FoodItem> _foods;
  @override
  List<FoodItem> get allFoods => _foods;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('disliking a food is tracked by isFoodDisliked, and does not affect '
      'foodAllowedForRecommendations (that stays kosher-only -- a dislike is '
      'a ranking signal, not a filter, see its docstring)', () {
    final state = AppState();
    final food = _testFood(id: 'test_disliked', name: 'מזון לא אהוב');
    state.addCustomFood(food);

    expect(state.foodAllowedForRecommendations(food), isTrue);
    expect(state.isFoodDisliked(food), isFalse);

    state.setFoodDisliked(food, true);
    expect(state.foodDislikes, contains('test_disliked'));
    expect(state.isFoodDisliked(food), isTrue);
    expect(state.foodAllowedForRecommendations(food), isTrue);

    state.setFoodDisliked(food, false);
    expect(state.foodDislikes, isNot(contains('test_disliked')));
    expect(state.isFoodDisliked(food), isFalse);
  });

  test('a disliked food ranks below an otherwise-tied non-disliked food, but '
      'still appears in the suggestions -- dislike demotes, it does not '
      'exclude', () {
    final disliked = _testFood(id: 'test_disliked2', name: 'מזון לא אהוב 2');
    final liked = _testFood(id: 'test_liked2', name: 'מזון אהוב 2');
    // Only these two foods are in the allowed pool at all here (see
    // _FixedCatalogAppState) -- with the real 29-item catalog also in the
    // mix, every one of those real (non-disliked) foods would rank ahead
    // of `disliked` too, since "not disliked" is the top ranking tier, and
    // the point being tested -- that a dislike demotes rather than filters
    // -- would be invisible past the take(3) cutoff.
    final state = _FixedCatalogAppState([disliked, liked]);
    state.setFoodDisliked(disliked, true);

    final suggestions = state.smartFoodSuggestions;
    expect(suggestions.first, liked.name);
    expect(suggestions, contains(disliked.name));
  });

  test('smartFoodSuggestions still returns a full ranking, not the empty '
      'fallback, when every allowed food is disliked', () {
    final state = AppState();
    for (final food in state.allFoods) {
      state.setFoodDisliked(food, true);
    }

    expect(state.smartFoodSuggestions, hasLength(3));
    expect(
      state.smartFoodSuggestions,
      isNot(contains('לא מצאתי כרגע מזון מתאים לכל ההגדרות')),
    );
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
    // addCustomFood/setFoodDisliked trigger AppState._save() without
    // awaiting it (same fire-and-forget pattern as addPantryItem/
    // upsertCustomEquipmentItem -- see the equivalent note in
    // equipment_cloud_sync_test.dart). Flushing the microtask queue after
    // each mutation lets each save land before the next one starts, so
    // they apply in order instead of racing the same storage key.
    final state = AppState();
    final food = _testFood(id: 'test_persist', name: 'מזון לבדיקת שמירה');
    state.addCustomFood(food);
    await Future<void>.delayed(Duration.zero);
    state.setFoodDisliked(food, true);
    await Future<void>.delayed(Duration.zero);

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
