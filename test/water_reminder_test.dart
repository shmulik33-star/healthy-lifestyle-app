import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/home/home_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

/// AddFoodToCatalogScreen's ListView taught us sliver-backed lists don't
/// build widgets below the default ~600px test viewport -- use a generous
/// surface so the water metric card is reachable regardless of layout.
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

  group('AppState.shouldRemindToDrink', () {
    test('is false when the reminder is off, even if under target', () {
      final state = AppState()
        ..waterReminderMinutes = 0
        ..waterCups = 0;
      expect(state.shouldRemindToDrink, isFalse);
    });

    test('is true when the reminder is on and under target', () {
      final state = AppState()
        ..waterReminderMinutes = 60
        ..waterCups = 2;
      expect(state.waterTarget, greaterThan(2));
      expect(state.shouldRemindToDrink, isTrue);
    });

    test('is false once the daily target is already met, even with the '
        "reminder on -- don't nag after the goal is reached", () {
      final state = AppState()..waterReminderMinutes = 60;
      state.waterCups = state.waterTarget;
      expect(state.shouldRemindToDrink, isFalse);
    });
  });

  group('water metric card', () {
    testWidgets('tapping it adds a cup, same as "שתיתי מים"', (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();
      final before = state.waterCups;

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: state,
            child: HomeScreen(onNavigate: (_) {}),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('water_metric_card')));
      await tester.pumpAndSettle();

      expect(state.waterCups, before + 1);
      expect(find.textContaining('נוספה כוס מים'), findsOneWidget);
    });
  });
}
