import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/add_food_to_catalog_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

/// AddFoodToCatalogScreen's body is a `ListView`, which is sliver-backed
/// and virtualized even though every child is passed as a plain list --
/// widgets well below the viewport (here, the calorie/protein/carbs/fat
/// fields, pushed down by the sizable "צילום תווית + AI" card above them)
/// simply aren't built at all, not just unpainted. `find.text` only sees
/// what's actually in the widget tree, so a viewport tall enough to fit
/// the whole form is needed for those assertions to mean anything.
void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'a barcode-scan prefill fills name/macros and shows the barcode, but '
    'leaves kosher status at its manual default',
    (tester) async {
      _useTallTestSurface(tester);
      const prefill = FoodItem(
        id: '',
        name: 'יוגורט טבעי 3%',
        category: 'אחר',
        type: KosherFoodType.pareve,
        kosherStatus: KosherStatus.unknown,
        caloriesPer100g: 62,
        proteinPer100g: 3.5,
        carbsPer100g: 4.7,
        fatPer100g: 3,
        units: {'מנה': 100},
        barcode: '7290000000001',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AddFoodToCatalogScreen(state: AppState(), prefill: prefill),
        ),
      );

      expect(find.text('יוגורט טבעי 3%'), findsOneWidget);
      expect(find.text('62'), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget);
      expect(find.byKey(const Key('food_barcode_card')), findsOneWidget);
      expect(find.textContaining('7290000000001'), findsOneWidget);
      // Kosher status dropdown still shows the manual default label, not
      // anything inferred from the prefill data.
      expect(find.text(kosherStatusLabel(KosherStatus.unknown)), findsOneWidget);
    },
  );

  testWidgets(
    'a prefill with missing macros (an OFF miss/network failure) leaves '
    'those fields empty for manual entry instead of showing 0',
    (tester) async {
      _useTallTestSurface(tester);
      const prefill = FoodItem(
        id: '',
        name: '',
        category: 'אחר',
        type: KosherFoodType.pareve,
        kosherStatus: KosherStatus.unknown,
        caloriesPer100g: 0,
        proteinPer100g: 0,
        carbsPer100g: 0,
        fatPer100g: 0,
        units: {'מנה': 100},
        barcode: '7290000000002',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AddFoodToCatalogScreen(state: AppState(), prefill: prefill),
        ),
      );

      // None of the macro fields were prefilled to a literal 0 -- they're
      // left genuinely empty for manual entry.
      expect(find.text('0'), findsNothing);
      expect(find.byKey(const Key('food_barcode_card')), findsOneWidget);
      expect(find.textContaining('7290000000002'), findsOneWidget);
    },
  );

  testWidgets('no barcode card shows for a plain new-food screen (no prefill)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AddFoodToCatalogScreen(state: AppState())),
    );

    expect(find.byKey(const Key('food_barcode_card')), findsNothing);
  });
}
