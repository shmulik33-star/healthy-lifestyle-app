import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

FoodItem _testFood({
  required String id,
  required String name,
  String? barcode,
}) =>
    FoodItem(
      id: id,
      name: name,
      category: 'אחר',
      type: KosherFoodType.pareve,
      caloriesPer100g: 100,
      proteinPer100g: 10,
      carbsPer100g: 5,
      fatPer100g: 2,
      units: const {'גרם': 1},
      barcode: barcode,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('foodByBarcode finds a custom food with a matching barcode', () {
    final state = AppState();
    final food = _testFood(id: 'scanned_1', name: 'מוצר סרוק', barcode: '7290000000001');
    state.addCustomFood(food);

    final found = state.foodByBarcode('7290000000001');

    expect(found, isNotNull);
    expect(found!.id, 'scanned_1');
  });

  test('foodByBarcode returns null when no food has that barcode', () {
    final state = AppState();
    state.addCustomFood(
      _testFood(id: 'scanned_1', name: 'מוצר סרוק', barcode: '7290000000001'),
    );

    expect(state.foodByBarcode('0000000000000'), isNull);
  });

  test('foodByBarcode returns null for foods with no barcode at all '
      '(the real catalog, and hand-entered custom foods)', () {
    final state = AppState();
    state.addCustomFood(_testFood(id: 'no_barcode', name: 'מוצר ידני'));

    // The real catalog has no barcodes; an empty-string lookup must not
    // accidentally match a food whose barcode is null.
    expect(state.foodByBarcode(''), isNull);
    expect(state.foodByBarcode('7290000000001'), isNull);
  });

  test('foodByBarcode trims the input barcode before matching', () {
    final state = AppState();
    state.addCustomFood(
      _testFood(id: 'scanned_1', name: 'מוצר סרוק', barcode: '7290000000001'),
    );

    expect(state.foodByBarcode('  7290000000001  ')?.id, 'scanned_1');
  });

  test('FoodItem.barcode survives a toJson/fromJson round-trip', () {
    final food = _testFood(id: 'scanned_1', name: 'מוצר סרוק', barcode: '7290000000001');

    final restored = FoodItem.fromJson(food.toJson());

    expect(restored.barcode, '7290000000001');
  });

  test('FoodItem.barcode defaults to null for JSON saved before this field '
      'existed', () {
    final legacyJson = {
      'id': 'legacy_1',
      'name': 'מזון ישן',
      'category': 'אחר',
      'type': 'pareve',
      'caloriesPer100g': 50,
      'proteinPer100g': 1,
      'carbsPer100g': 1,
      'fatPer100g': 1,
      'units': {'גרם': 1},
      // no 'barcode' key at all.
    };

    final restored = FoodItem.fromJson(legacyJson);

    expect(restored.barcode, isNull);
  });
}
