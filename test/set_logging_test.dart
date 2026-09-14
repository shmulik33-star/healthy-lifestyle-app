import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/fitness/fitness_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

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

  group('AppState.logSet / lastSetFor / todaysSetsFor', () {
    test('logSet records a completed set retrievable via todaysSetsFor', () {
      final state = AppState();
      state.logSet(exerciseName: 'פלאנק', setIndex: 0, weightKg: 0, reps: 1);
      final today = state.todaysSetsFor('פלאנק');
      expect(today.length, 1);
      expect(today[0]!.reps, 1);
      expect(today[0]!.completed, isTrue);
    });

    test('logging the same setIndex again on the same day replaces, not duplicates', () {
      final state = AppState();
      state.logSet(exerciseName: 'סקוואט', setIndex: 0, weightKg: 20, reps: 10);
      state.logSet(exerciseName: 'סקוואט', setIndex: 0, weightKg: 25, reps: 8);
      final today = state.todaysSetsFor('סקוואט');
      expect(today.length, 1);
      expect(today[0]!.weightKg, 25);
      expect(today[0]!.reps, 8);
      expect(state.workoutSetLogs.length, 1);
    });

    test('lastSetFor returns the most recently completed non-warmup set for that exercise', () {
      final state = AppState();
      state.logSet(exerciseName: 'סקוואט', setIndex: 0, weightKg: 20, reps: 10);
      state.logSet(exerciseName: 'סקוואט', setIndex: 1, weightKg: 22, reps: 9);
      final last = state.lastSetFor('סקוואט');
      expect(last, isNotNull);
      expect(last!.weightKg, 22);
    });

    test('lastSetFor returns null when nothing was ever logged for that exercise', () {
      final state = AppState();
      expect(state.lastSetFor('תרגיל שלא קיים'), isNull);
    });

    test('workoutSetLogs round-trips through the local save/load JSON cycle', () async {
      final state = AppState();
      state.logSet(exerciseName: 'לחיצת חזה', setIndex: 0, weightKg: 40, reps: 10);
      // logSet's _save() is fire-and-forget (same pattern as
      // addCustomFood/setFoodDisliked -- see food_dislikes_test.dart);
      // pump the event queue so it lands before reloading.
      await pumpEventQueue();

      final reloaded = await AppState.load();
      expect(reloaded.workoutSetLogs.length, 1);
      expect(reloaded.workoutSetLogs.first.exerciseName, 'לחיצת חזה');
      expect(reloaded.workoutSetLogs.first.weightKg, 40);
    });

    test('exportCloudSyncState/applyCloudSyncState carry workoutSetLogs', () async {
      final state = AppState();
      state.logSet(exerciseName: 'משיכת פולי עליון', setIndex: 0, weightKg: 30, reps: 12);
      final exported = state.exportCloudSyncState();

      final other = AppState();
      await other.applyCloudSyncState(exported);
      expect(other.workoutSetLogs.length, 1);
      expect(other.workoutSetLogs.first.exerciseName, 'משיכת פולי עליון');
    });
  });

  group('SetLoggingSheet UI', () {
    testWidgets('tapping an exercise opens the set-logging sheet, and finishing a set updates the count',
        (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: state,
            child: const Scaffold(body: FitnessScreen()),
          ),
        ),
      );
      await tester.pump();

      final exerciseName = state.todayWorkout.first.name;
      await tester.tap(find.text(exerciseName).first);
      await tester.pumpAndSettle();

      expect(find.text('סיום סט'), findsWidgets);

      await tester.tap(find.text('סיום סט').first);
      await tester.pump();

      // Finishing a non-last set starts the rest timer card instead of
      // showing the remaining set rows.
      expect(find.textContaining('מנוחה בין סטים'), findsOneWidget);

      // Close the sheet so its rest-timer Timer.periodic is cancelled in
      // dispose() -- otherwise it keeps firing in real wall-clock time
      // after this test ends.
      Navigator.of(tester.element(find.textContaining('מנוחה בין סטים'))).pop();
      await tester.pumpAndSettle();
    });
  });
}
