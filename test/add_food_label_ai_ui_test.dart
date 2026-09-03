import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/add_food_to_catalog_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

/// AddFoodToCatalogScreen's body is a sliver-backed ListView, which only
/// builds widgets within the test viewport -- same fix used elsewhere in
/// this suite (see add_food_prefill_test.dart). Needed here now that the
/// barcode-scan card pushes the label-AI card further down the list.
void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('add-food screen exposes camera and gallery label AI actions', (
    tester,
  ) async {
    _useTallTestSurface(tester);
    await tester.pumpWidget(
      MaterialApp(home: AddFoodToCatalogScreen(state: AppState())),
    );

    expect(find.text('צילום תווית + AI'), findsOneWidget);
    expect(find.byKey(const Key('nutrition_label_camera')), findsOneWidget);
    expect(find.byKey(const Key('nutrition_label_gallery')), findsOneWidget);
    expect(find.textContaining('לא ישמור דבר לבד'), findsOneWidget);
  });

  testWidgets('add-food screen also exposes a barcode-scan action', (
    tester,
  ) async {
    _useTallTestSurface(tester);
    await tester.pumpWidget(
      MaterialApp(home: AddFoodToCatalogScreen(state: AppState())),
    );

    expect(find.text('סריקת ברקוד'), findsOneWidget);
    expect(find.byKey(const Key('food_barcode_scan_button')), findsOneWidget);
    // No status shown until a scan is actually attempted.
    expect(find.byKey(const Key('food_barcode_status')), findsNothing);
  });
}
