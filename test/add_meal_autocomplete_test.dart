import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/add_meal_sheet.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

void main() {
  testWidgets('eaten flow finds a catalog food while typing', (tester) async {
    final state = AppState();
    state.customFoods.add(
      const FoodItem(
        id: 'custom_lentil_patty',
        name: 'קציצות עדשים שלי',
        category: 'קטניות',
        type: KosherFoodType.pareve,
        caloriesPer100g: 180,
        proteinPer100g: 11,
        carbsPer100g: 24,
        fatPer100g: 5,
        units: {'מנה': 100, 'גרם': 1},
        userCreated: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppStateScope(
            state: state,
            child: const AddMealSheet(),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('meal_food_search')),
      'קציצ',
    );
    await tester.pumpAndSettle();

    expect(find.text('קציצות עדשים שלי'), findsOneWidget);

    await tester.tap(find.text('קציצות עדשים שלי'));
    await tester.pumpAndSettle();

    expect(find.text('אומדן משקל: 100 גרם'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('meal_save_button')),
    );
    expect(saveButton.onPressed, isNotNull);
  });
}
