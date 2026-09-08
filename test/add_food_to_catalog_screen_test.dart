import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/add_food_to_catalog_screen.dart';
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
      proteinPer100g: 5,
      carbsPer100g: 5,
      fatPer100g: 5,
      units: const {'גרם': 1},
      barcode: barcode,
    );

void main() {
  // The barcode-scan button is a new-food-only shortcut (see
  // AddFoodToCatalogScreen.scanBarcode) -- it makes no sense once editing an
  // existing food, so it's hidden there instead of just disabled.
  testWidgets('shows a barcode-scan button only when adding a new food', (
    tester,
  ) async {
    final state = AppState();

    await tester.pumpWidget(
      MaterialApp(
        home: AddFoodToCatalogScreen(state: state),
      ),
    );
    expect(find.byKey(const Key('add_food_scan_barcode')), findsOneWidget);

    final existing = _testFood(id: 'food_1', name: 'מזון קיים');
    await tester.pumpWidget(
      MaterialApp(
        home: AddFoodToCatalogScreen(state: state, editingFood: existing),
      ),
    );
    expect(find.byKey(const Key('add_food_scan_barcode')), findsNothing);
  });

  // Regression coverage for the "local match first, no network" rule (see
  // CLAUDE.md golden rule #6): scanning a barcode that's already in the
  // catalog must not silently overwrite whatever the user already typed.
  // Uses the existing-food-match branch specifically because it needs no
  // network call (unlike the Open Food Facts lookup branch for an unknown
  // barcode), so it stays fast and deterministic -- same reasoning as
  // quick_add_food_sheet_test.dart's equivalent case.
  testWidgets(
    'scanning a barcode that already exists in the catalog shows a message '
    'and does not overwrite the form',
    (tester) async {
      final state = AppState();
      final existing = _testFood(
        id: 'scanned_1',
        name: 'מוצר קיים בברקוד',
        barcode: '7290000000001',
      );
      state.addCustomFood(existing);

      await tester.pumpWidget(
        MaterialApp(
          home: AddFoodToCatalogScreen(
            state: state,
            scanBarcode: (navigator) async => '7290000000001',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_food_scan_barcode')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('מוצר קיים בברקוד'),
        findsOneWidget,
      );
      final nameField = tester.widget<TextField>(
        find.byKey(const Key('add_food_name_field')),
      );
      expect(nameField.controller!.text, isEmpty);
    },
  );
}
