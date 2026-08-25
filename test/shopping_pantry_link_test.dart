import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

MealEntry _meal(String name, double quantity, {String foodId = 'test'}) =>
    MealEntry(
      foodId: foodId,
      name: name,
      quantity: quantity,
      unit: 'יחידה',
      grams: quantity * 100,
      calories: 100,
      protein: 10,
      carbs: 10,
      fat: 5,
      type: KosherFoodType.pareve,
      time: DateTime.now(),
    );

ShoppingItem _findByName(AppState state, String name) =>
    state.shoppingItems.firstWhere((item) => item.name == name);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('"have at home" is pulled from the pantry, not a stale field', () {
    final state = AppState();
    state.meals.add(_meal('עוף בדיקה', 1.8));
    state.addPantryItem('עוף בדיקה', 0.5, 'ק״ג', 'בשר ועוף');

    state.buildSmartShoppingList(force: true);
    final item = _findByName(state, 'עוף בדיקה');

    expect(item.haveAtHome, 0.5);
    expect(item.haveAtHomeOverride, isFalse);
    // need = 1.8 rounded up to the nearest 0.5 kg pack = 2.0; buy = 2.0 - 0.5
    expect(item.quantity, 1.5);
  });

  test('raising pantry stock lowers the smart quantity on the next rebuild', () {
    final state = AppState();
    state.meals.add(_meal('עוף בדיקה', 1.8));
    state.buildSmartShoppingList(force: true);
    expect(_findByName(state, 'עוף בדיקה').haveAtHome, 0);

    // Pantry now fully covers the rounded 2.0kg need, so nothing left to buy.
    state.addPantryItem('עוף בדיקה', 2, 'ק״ג', 'בשר ועוף');
    state.buildSmartShoppingList(force: true);

    expect(
      state.shoppingItems.where((item) => item.name == 'עוף בדיקה'),
      isEmpty,
    );
  });

  test('a manual "have at home" edit overrides the pantry value and survives a rebuild', () {
    final state = AppState();
    // Consumption large enough that even after the override below, some is
    // still left to buy (so the item stays in the rebuilt list).
    state.meals.add(_meal('עוף בדיקה', 12));
    state.buildSmartShoppingList(force: true);
    final item = _findByName(state, 'עוף בדיקה');

    state.updateShoppingItem(item, haveAtHome: 5);
    expect(item.haveAtHomeOverride, isTrue);

    // Pantry stock changes, but the manual override should stick instead of
    // being replaced by the new pantry quantity.
    state.addPantryItem('עוף בדיקה', 2, 'ק״ג', 'בשר ועוף');
    state.buildSmartShoppingList(force: true);
    final rebuilt = _findByName(state, 'עוף בדיקה');

    expect(rebuilt.haveAtHome, 5);
    expect(rebuilt.haveAtHomeOverride, isTrue);
    expect(rebuilt.quantity, 12 - 5);
  });

  test('meat/fish round up to the nearest half-kilo real package', () {
    final state = AppState();
    state.meals.add(_meal('עוף בדיקה', 1.8));

    state.buildSmartShoppingList(force: true);
    final item = _findByName(state, 'עוף בדיקה');

    expect(item.unit, 'ק״ג');
    expect(item.quantity, 2.0);
  });

  test('dairy/beverages round up to the nearest half-liter real package', () {
    final state = AppState();
    state.meals.add(_meal('יוגורט בדיקה', 1.2));

    state.buildSmartShoppingList(force: true);
    final item = _findByName(state, 'יוגורט בדיקה');

    expect(item.unit, 'ליטר');
    expect(item.quantity, 1.5);
  });

  test('eggs still round up to dozen-style cartons', () {
    final state = AppState();
    // 3 units logged at 100g each -> ~5.5 egg-equivalents by weight + buffer.
    state.meals.add(_meal('ביצה', 3));
    state.buildSmartShoppingList(force: true);
    final item = _findByName(state, 'ביצים');

    expect(item.unit, 'יחידות');
    expect(const [6, 12, 18, 30], contains(item.quantity));
  });

  test('uncategorized products round up to the nearest whole package', () {
    final state = AppState();
    state.meals.add(_meal('ממתק בדיקה', 2.3));

    state.buildSmartShoppingList(force: true);
    final item = _findByName(state, 'ממתק בדיקה');

    expect(item.unit, 'חבילה');
    expect(item.quantity, 3);
  });
}
