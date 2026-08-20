// This file is a `part` of AppState's library and intentionally performs
// ChangeNotifier lifecycle calls on the owning AppState instance.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'app_state.dart';

void _profileUpdate(
  AppState state, {
  required String name,
  required double weight,
  required double target,
  required int calories,
  required int protein,
  String? goal,
  String? activity,
  int? workoutDays,
  String? style,
  bool? keepKosher,
  bool? separateMeatDairy,
  int? waitMinutes,
  int? dailyStartMinutes,
}) {
  state.firstName = name;
  state.currentWeight = weight;
  state.targetWeight = target;
  state.calorieTarget = calories;
  state.proteinTarget = protein;
  if (goal != null) state.primaryGoal = goal;
  if (activity != null) state.activityLevel = activity;
  if (workoutDays != null) state.workoutDaysPerWeek = workoutDays;
  if (style != null) state.eatingStyle = style;
  if (keepKosher != null) state.kosherEnabled = keepKosher;
  if (separateMeatDairy != null) {
    state.meatDairySeparationEnabled = separateMeatDairy;
  }
  if (waitMinutes != null) state.meatWaitMinutes = waitMinutes;
  if (dailyStartMinutes != null) {
    state.dayStartMinutes = dailyStartMinutes.clamp(0, 1439);
    state.dailyStateKey = state.dayKeyAt(DateTime.now());
  }
  state.notifyListeners();
  state.generateWeeklyPlan();
}

int _profileSuggestedCalories(AppState state) {
  final base = (state.currentWeight * 22).round();
  final factor = switch (state.activityLevel) {
    'נמוכה' => 1.15,
    'גבוהה' => 1.45,
    _ => 1.30,
  };
  var estimate = (base * factor).round();
  if (state.primaryGoal == 'ירידה במשקל') estimate -= 350;
  if (state.primaryGoal == 'עלייה במסת שריר') estimate += 200;
  return estimate.clamp(1200, 4000);
}

int _profileSuggestedProtein(AppState state) {
  final factor = state.primaryGoal == 'עלייה במסת שריר' ? 1.8 : 1.5;
  return (state.currentWeight * factor).round().clamp(60, 250);
}

String _profileWeightTrend(AppState state) {
  if (state.weights.length < 2) {
    return 'נדרשות לפחות שתי שקילות כדי לזהות מגמה.';
  }
  final sorted = [...state.weights]
    ..sort((a, b) => a.date.compareTo(b.date));
  final delta = sorted.last.weight - sorted.first.weight;
  if (delta.abs() < 0.2) {
    return 'המשקל יציב יחסית בתקופה המתועדת.';
  }
  return delta < 0
      ? 'ירידה של ${delta.abs().toStringAsFixed(1)} ק״ג בתקופה המתועדת.'
      : 'עלייה של ${delta.toStringAsFixed(1)} ק״ג בתקופה המתועדת.';
}

void _profileAddWeight(AppState state, double value) {
  state.currentWeight = value;
  state.weights.add(WeightEntry(DateTime.now(), value));
  state.notifyListeners();
  state._save();
}
