import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_app/shared/models/app_state.dart';
import 'package:healthy_lifestyle_app/shared/models/food.dart';

void main() {
  test('nutrition public API keeps logical-day totals', () {
    final state = AppState();
    final now = DateTime.now();
    state.meals.add(
      MealEntry(
        foodId: 'test',
        name: 'בדיקה',
        quantity: 1,
        unit: 'יחידה',
        grams: 100,
        calories: 250,
        protein: 20,
        carbs: 15,
        fat: 8,
        type: KosherFoodType.pareve,
        time: now,
      ),
    );

    expect(state.todayMeals.length, 1);
    expect(state.caloriesEaten, 250);
    expect(state.proteinEaten, 20);
    expect(state.remainingCalories, state.calorieTarget - 250);
  });

  test('weekly plan public API still builds seven days', () {
    final state = AppState();
    state.generateWeeklyPlan(save: false);

    expect(state.weeklyPlan.length, 7);
    expect(state.weeklyPlan.every((day) => day.meals.length == 4), isTrue);
  });

  test('profile public API keeps legacy calorie and protein suggestions', () {
    final state = AppState()
      ..currentWeight = 100
      ..activityLevel = 'נמוכה'
      ..primaryGoal = 'ירידה במשקל';

    expect(state.suggestedCalories(), 2180);
    expect(state.suggestedProtein(), 150);
  });

  test('weight trend public API is unchanged', () {
    final state = AppState();
    state.weights
      ..clear()
      ..add(WeightEntry(DateTime(2026, 8, 1), 100))
      ..add(WeightEntry(DateTime(2026, 8, 20), 98.5));

    expect(state.weightTrend, contains('ירידה של 1.5 ק״ג'));
  });
}
