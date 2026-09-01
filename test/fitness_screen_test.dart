import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/fitness/fitness_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

/// Sliver-backed ListViews only build widgets within the test viewport --
/// same fix as elsewhere in this suite.
void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'tapping the AI plan button on success shows the AI-picked exercises and records the muscle groups',
    (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: state,
            child: Scaffold(
              body: FitnessScreen(
                pickWorkout: ({
                  required Map<String, dynamic> context,
                  required List<Map<String, dynamic>> catalog,
                }) async =>
                    ['Plank', 'Pushups'],
              ),
            ),
          ),
        ),
      );

      // Deliberately not pumpAndSettle(): each exercise card carries a real
      // Image.network demo thumbnail (see _ExerciseThumbnail), and waiting
      // for that network round-trip to settle has no place in a unit test.
      // A couple of bounded pumps is enough to flush the mocked pickWorkout
      // future and the resulting setState -- the exercise name renders in
      // the same frame regardless of whether its thumbnail has loaded yet.
      await tester.tap(find.text('תכנן לי אימון AI להיום'));
      await tester.pump();
      await tester.pump();

      expect(find.text('פלאנק'), findsOneWidget);
      expect(find.text('שכיבות סמיכה'), findsOneWidget);
      expect(state.recentWorkoutMuscleGroups, containsAll(['ליבה', 'חזה']));
    },
  );

  testWidgets(
    'when the AI plan call fails, the screen silently keeps the existing rule-based workout',
    (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();
      final fallbackExerciseName = state.todayWorkout.first.name;

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: state,
            child: Scaffold(
              body: FitnessScreen(
                pickWorkout: ({
                  required Map<String, dynamic> context,
                  required List<Map<String, dynamic>> catalog,
                }) async =>
                    throw Exception('boom'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('תכנן לי אימון AI להיום'));
      await tester.pump();
      await tester.pump();

      expect(find.text(fallbackExerciseName), findsOneWidget);
      expect(find.text('מתכנן אימון...'), findsNothing);
    },
  );
}
