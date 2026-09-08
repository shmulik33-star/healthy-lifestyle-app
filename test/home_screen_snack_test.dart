import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/home/home_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

/// Same trick as smart_food_suggestions_test.dart's own _EmptyCatalogAppState:
/// simulates a real catalog with nothing left after kosher filtering, which
/// the real, non-empty `foodCatalog` const can never produce on its own.
class _EmptyCatalogAppState extends AppState {
  @override
  List<FoodItem> get allFoods => const [];
}

/// Sliver-backed ListViews only build widgets within the test viewport --
/// same fix home_screen_redesign_test.dart already uses for this screen.
void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget wrap(AppState state) => MaterialApp(
        home: AppStateScope(
          state: state,
          child: Scaffold(body: HomeScreen(onNavigate: (_) {})),
        ),
      );

  testWidgets(
    'tapping a snack suggestion logs it as eaten (from home, quantity 1) '
    'and closes the sheet',
    (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();
      await tester.pumpWidget(wrap(state));

      final mealsBefore = state.meals.length;
      final suggestion = state.smartSnackSuggestions.first;
      // The suggested snack can also appear in the "ההמלצה שלי עכשיו" chips
      // higher up on the same (still-visible-underneath) home screen, so
      // matching by its own tile key -- not by its name text, which isn't
      // guaranteed unique on screen -- is what actually identifies it here.
      final tileFinder = find.byKey(Key('snack_option_${suggestion.id}'));

      await tester.tap(find.text('בא לי לנשנש'));
      await tester.pumpAndSettle();
      expect(find.text('מה אפשר לנשנש?'), findsOneWidget);
      expect(tileFinder, findsOneWidget);

      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      expect(find.text('מה אפשר לנשנש?'), findsNothing);
      expect(state.meals.length, mealsBefore + 1);
      expect(state.meals.last.foodId, suggestion.id);
      expect(state.meals.last.quantity, 1);
      expect(state.meals.last.fromHome, isTrue);
      expect(
        find.textContaining('נוסף מהיר: ${suggestion.name}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'double-tapping a snack suggestion logs it only once -- addFood has no '
    'Undo, so a fast double-tap or a slow frame before the sheet pops must '
    'not double-log',
    (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();
      await tester.pumpWidget(wrap(state));

      final mealsBefore = state.meals.length;
      final suggestion = state.smartSnackSuggestions.first;
      final tileFinder = find.byKey(Key('snack_option_${suggestion.id}'));

      await tester.tap(find.text('בא לי לנשנש'));
      await tester.pumpAndSettle();

      await tester.tap(tileFinder, warnIfMissed: false);
      await tester.tap(tileFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(state.meals.length, mealsBefore + 1);
    },
  );

  testWidgets(
    'an empty suggestion list shows a friendly message instead of a fake item',
    (tester) async {
      _useTallTestSurface(tester);
      final state = _EmptyCatalogAppState();
      await tester.pumpWidget(wrap(state));

      await tester.tap(find.text('בא לי לנשנש'));
      await tester.pumpAndSettle();

      expect(find.text('מה אפשר לנשנש?'), findsOneWidget);
      expect(find.text('לא מצאתי כרגע נשנוש מתאים.'), findsOneWidget);
    },
  );
}
