import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/quick_add_food_sheet.dart';
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
  // Only the sheet's own structure is covered here -- not the camera itself,
  // which needs real hardware/permissions and can't run in CI's headless
  // widget-test environment (a known limitation). The barcode option tile
  // is asserted present but never tapped, so it never reaches
  // BarcodeScannerScreen/MobileScanner.
  testWidgets('quick-add sheet shows a title and the barcode-scan option', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickAddFoodSheet(state: AppState()),
        ),
      ),
    );

    expect(find.text('הוסף מהיר'), findsOneWidget);
    expect(find.text('סרוק ברקוד'), findsOneWidget);
    expect(find.byKey(const Key('quick_add_barcode_option')), findsOneWidget);
    expect(find.textContaining('Open Food Facts'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });

  // Regression test: tapping "סרוק ברקוד" used the sheet's own BuildContext
  // (torn down the moment the sheet closed, a line earlier) after the scan
  // returned -- so `context.mounted` was already false by then and the
  // whole flow silently no-op'd, on every single scan. `scanBarcode` here
  // stands in for the real camera screen (unavailable in CI's headless
  // test runner) so the pop -> scan -> keep-navigating sequence itself
  // gets exercised. Uses the existing-food-match branch specifically
  // because it needs no network call (unlike the Open Food Facts lookup
  // branch), so it stays fast and deterministic.
  testWidgets(
    'tapping the barcode option still navigates onward after the scan '
    'completes, once the sheet that started it has already closed',
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
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => QuickAddFoodSheet(
                    state: state,
                    scanBarcode: (navigator) async => '7290000000001',
                  ),
                ),
                child: const Text('פתח הוסף מהיר'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('פתח הוסף מהיר'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick_add_barcode_option')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_add_barcode_option')));
      await tester.pumpAndSettle();

      // The quick-add sheet is gone, and the existing food's "add to meal"
      // sheet is showing instead -- not silently nothing.
      expect(find.text('הוסף מהיר'), findsNothing);
      expect(find.text('מוצר קיים בברקוד'), findsOneWidget);
      expect(find.text('הוסף ליומן'), findsOneWidget);
    },
  );
}
