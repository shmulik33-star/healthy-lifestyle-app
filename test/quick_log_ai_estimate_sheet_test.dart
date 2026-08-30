import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/nutrition_label_ai_service.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/quick_log_ai_estimate_sheet.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

/// SingleChildScrollView (unlike ListView) always builds every child, but
/// the sheet is still tall enough that a small default test viewport can
/// make some fields require scrolling to interact with -- use a generous
/// surface so every field and the save button are reachable directly.
void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _suggestion = NutritionLabelAiSuggestion(
  recognized: true,
  name: 'חזה עוף עם אורז וירקות',
  caloriesPer100g: 145,
  proteinPer100g: 12,
  carbsPer100g: 15,
  fatPer100g: 4,
  servingName: 'מנה כפי שנראתה בתמונה',
  servingGrams: 350,
  confidence: 0.72,
  reason: '',
);

Future<void> _pump(WidgetTester tester, AppState state) async {
  _useTallTestSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuickLogAiEstimateSheet(state: state, suggestion: _suggestion),
      ),
    ),
  );
}

void main() {
  test('fields default from the AI suggestion', () {
    // Covered implicitly by the widget tests below via find.text, but
    // documented here as the expected starting values.
    expect(_suggestion.servingGrams, 350);
    expect(_suggestion.name, 'חזה עוף עם אורז וירקות');
  });

  testWidgets(
    'when meat/dairy separation is on, saving without choosing a type is '
    'blocked -- kosher status is never inferred from the AI estimate',
    (tester) async {
      final state = AppState()
        ..kosherEnabled = true
        ..meatDairySeparationEnabled = true;

      await _pump(tester, state);

      expect(find.byKey(const Key('quick_log_ai_kosher_type_field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_log_ai_save_button')));
      await tester.pumpAndSettle();

      expect(state.meals, isEmpty);
      expect(find.text('יש לבחור סוג לפני השמירה'), findsOneWidget);
    },
  );

  testWidgets(
    'choosing a type and saving logs a meal entry without touching the '
    'catalog when "save to catalog" is left unchecked',
    (tester) async {
      final state = AppState()
        ..kosherEnabled = true
        ..meatDairySeparationEnabled = true;
      final customFoodsBefore = state.customFoods.length;

      await _pump(tester, state);

      await tester.tap(find.byKey(const Key('quick_log_ai_kosher_type_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('פרווה').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_log_ai_save_button')));
      await tester.pumpAndSettle();

      expect(state.meals, hasLength(1));
      expect(state.meals.single.name, 'חזה עוף עם אורז וירקות');
      expect(state.meals.single.type, KosherFoodType.pareve);
      expect(state.customFoods.length, customFoodsBefore);
    },
  );

  testWidgets(
    'checking "save also to catalog" also creates a permanent, always-kosher '
    'FoodItem via the existing catalog save path',
    (tester) async {
      final state = AppState()
        ..kosherEnabled = true
        ..meatDairySeparationEnabled = true;

      await _pump(tester, state);

      await tester.tap(find.byKey(const Key('quick_log_ai_kosher_type_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('בשרי').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_log_ai_save_to_catalog_checkbox')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_log_ai_save_button')));
      await tester.pumpAndSettle();

      expect(state.meals, hasLength(1));
      final saved = state.customFoods.singleWhere(
        (food) => food.name == 'חזה עוף עם אורז וירקות',
      );
      expect(saved.kosherStatus, KosherStatus.kosher);
      expect(saved.type, KosherFoodType.meat);
      expect(saved.userCreated, isTrue);
    },
  );

  testWidgets(
    'when meat/dairy separation is off, the type field is hidden and saving '
    'works immediately with a silent pareve default',
    (tester) async {
      final state = AppState()
        ..kosherEnabled = true
        ..meatDairySeparationEnabled = false;

      await _pump(tester, state);

      expect(find.byKey(const Key('quick_log_ai_kosher_type_field')), findsNothing);

      await tester.tap(find.byKey(const Key('quick_log_ai_save_button')));
      await tester.pumpAndSettle();

      expect(state.meals, hasLength(1));
      expect(state.meals.single.type, KosherFoodType.pareve);
    },
  );

  testWidgets(
    'editing the grams and macro fields changes what gets logged',
    (tester) async {
      final state = AppState()
        ..kosherEnabled = false
        ..meatDairySeparationEnabled = false;

      await _pump(tester, state);

      await tester.enterText(
        find.byKey(const Key('quick_log_ai_grams_field')),
        '200',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_log_ai_save_button')));
      await tester.pumpAndSettle();

      expect(state.meals, hasLength(1));
      expect(state.meals.single.grams, 200);
      // 200g at 145 kcal/100g.
      expect(state.meals.single.calories, 290);
    },
  );
}
