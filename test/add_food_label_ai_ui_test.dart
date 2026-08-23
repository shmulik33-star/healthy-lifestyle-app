import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/add_food_to_catalog_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void main() {
  testWidgets('add-food screen exposes camera and gallery label AI actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AddFoodToCatalogScreen(state: AppState())),
    );

    expect(find.text('צילום תווית + AI'), findsOneWidget);
    expect(find.byKey(const Key('nutrition_label_camera')), findsOneWidget);
    expect(find.byKey(const Key('nutrition_label_gallery')), findsOneWidget);
    expect(find.textContaining('לא ישמור דבר לבד'), findsOneWidget);
  });
}
