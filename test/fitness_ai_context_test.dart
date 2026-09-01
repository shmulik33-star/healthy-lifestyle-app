import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fitnessAiContext exposes goal/activity/recent-history facts, not the catalog itself', () {
    final state = AppState();
    final context = state.fitnessAiContext();

    expect(context['primaryGoal'], state.primaryGoal);
    expect(context['activityLevel'], state.activityLevel);
    expect(context['workoutDaysPerWeek'], state.workoutDaysPerWeek);
    expect(context['dayOfWeek'], isA<String>());
    expect(context['recentMuscleGroups'], state.recentWorkoutMuscleGroups);
    expect(context.containsKey('catalog'), isFalse);
  });

  test('recordWorkoutMuscleGroups appends and is reflected in a later context read', () {
    final state = AppState();
    state.recordWorkoutMuscleGroups(['גב', 'חזה']);

    expect(state.recentWorkoutMuscleGroups, ['גב', 'חזה']);
    expect(state.fitnessAiContext()['recentMuscleGroups'], ['גב', 'חזה']);
  });

  test('recordWorkoutMuscleGroups trims to the LRU window instead of growing forever', () {
    final state = AppState();
    for (var i = 0; i < 100; i++) {
      state.recordWorkoutMuscleGroups(['קבוצה$i']);
    }

    expect(state.recentWorkoutMuscleGroups.length, lessThan(100));
    expect(state.recentWorkoutMuscleGroups.last, 'קבוצה99');
  });
}
