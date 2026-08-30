import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/quick_add_food_sheet.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

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
}
