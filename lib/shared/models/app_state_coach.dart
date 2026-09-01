part of 'app_state.dart';

/// Compact snapshot of AppState fed to the AI coach Worker as `context`
/// (see CoachAiService) -- exactly the same fields the existing rule-based
/// `AppState.coachResponse` already reads, so an AI answer is grounded in
/// the same facts the safety-net fallback uses, not a separate picture of
/// the user. Pure and synchronous (no network), so it's unit-tested on its
/// own, apart from any HTTP call.
Map<String, dynamic> _coachAiContext(AppState state) => {
      'primaryGoal': state.primaryGoal,
      'workoutDaysPerWeek': state.workoutDaysPerWeek,
      'activityLevel': state.activityLevel,
      'calorieTarget': state.calorieTarget,
      'caloriesEaten': state.caloriesEaten,
      'proteinTarget': state.proteinTarget,
      'proteinEaten': state.proteinEaten,
      'remainingCalories': state.remainingCalories,
      'remainingProtein': state.remainingProtein,
      'kosherStateText': state.kosherStateText,
      'todayWorkout': state.todayWorkout.map((e) => e.name).toList(),
      'waterCups': state.waterCups,
      'waterTarget': state.waterTarget,
      'weightTrend': state.weightTrend,
      'smartFoodSuggestions': state.smartFoodSuggestions.take(3).toList(),
      'dailyInsight': state.dailyInsight,
    };
