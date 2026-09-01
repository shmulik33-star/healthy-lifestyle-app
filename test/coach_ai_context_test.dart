import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'coachAiContext exposes exactly the same facts the rule-based '
    'coachResponse() already reads, so an AI answer is grounded in the '
    'same picture the safety-net fallback uses',
    () {
      final state = AppState();
      final context = state.coachAiContext();

      expect(context['primaryGoal'], state.primaryGoal);
      expect(context['workoutDaysPerWeek'], state.workoutDaysPerWeek);
      expect(context['activityLevel'], state.activityLevel);
      expect(context['calorieTarget'], state.calorieTarget);
      expect(context['caloriesEaten'], state.caloriesEaten);
      expect(context['proteinTarget'], state.proteinTarget);
      expect(context['proteinEaten'], state.proteinEaten);
      expect(context['remainingCalories'], state.remainingCalories);
      expect(context['remainingProtein'], state.remainingProtein);
      expect(context['kosherStateText'], state.kosherStateText);
      expect(context['todayWorkout'], state.todayWorkout.map((e) => e.name).toList());
      expect(context['waterCups'], state.waterCups);
      expect(context['waterTarget'], state.waterTarget);
      expect(context['weightTrend'], state.weightTrend);
      expect(context['smartFoodSuggestions'], state.smartFoodSuggestions.take(3).toList());
      expect(context['dailyInsight'], state.dailyInsight);
    },
  );

  test('reflects live state, not a stale snapshot from construction time', () {
    final state = AppState()..addWater();
    final context = state.coachAiContext();

    expect(context['waterCups'], 1);
    expect(context['waterCups'], state.waterCups);
  });
}
