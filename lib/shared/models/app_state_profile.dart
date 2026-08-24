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

/// Stable bridge used by the cloud-sync service.
///
/// The cloud intentionally contains cross-device personal data. Daily counters
/// still stay local until their own conflict rules are defined.
extension AppStateCloudSyncBridge on AppState {
  Map<String, dynamic> exportCloudSyncState() => {
        'version': 1,
        'profile': {
          'firstName': firstName,
          'age': age,
          'heightCm': heightCm,
          'currentWeight': currentWeight,
          'targetWeight': targetWeight,
          'calorieTarget': calorieTarget,
          'proteinTarget': proteinTarget,
          'carbTarget': carbTarget,
          'fatTarget': fatTarget,
          'waterTarget': waterTarget,
          'stepsTarget': stepsTarget,
          'dayStartMinutes': dayStartMinutes,
          'kosherEnabled': kosherEnabled,
          'meatDairySeparationEnabled': meatDairySeparationEnabled,
          'meatWaitMinutes': meatWaitMinutes,
          'primaryGoal': primaryGoal,
          'activityLevel': activityLevel,
          'workoutDaysPerWeek': workoutDaysPerWeek,
          'eatingStyle': eatingStyle,
          'equipment': Map<String, bool>.from(equipment),
        },
        'weights': weights.map((entry) => entry.toJson()).toList(),
        'meals': meals.map((entry) => entry.toJson()).toList(),
        'pantryItems': pantryItems.map((item) => item.toJson()).toList(),
        'shoppingItems': shoppingItems.map((item) => item.toJson()).toList(),
        'shoppingChecked': Map<String, bool>.from(shoppingChecked),
        'shoppingInitialized': shoppingInitialized,
        'deletedPantryItemIds': _encodeTombstoneMap(deletedPantryItemIds),
        'deletedShoppingItemIds': _encodeTombstoneMap(deletedShoppingItemIds),
        'deletedMealKeys': _encodeTombstoneMap(deletedMealKeys),
        // Custom foods themselves live in the user_custom_foods table (see
        // CloudSyncService.syncCustomFoods), but the deletion tombstones ride
        // along in this snapshot so they reach every device the same way the
        // other tombstones above do.
        'deletedCustomFoodIds': _encodeTombstoneMap(deletedCustomFoodIds),
      };

  Future<void> applyCloudSyncState(Map<String, dynamic> data) async {
    final profileRaw = data['profile'];
    if (profileRaw is Map) {
      final profile = Map<String, dynamic>.from(profileRaw);
      firstName = profile['firstName'] as String? ?? firstName;
      age = (profile['age'] as num?)?.toInt() ?? age;
      heightCm = (profile['heightCm'] as num?)?.toDouble() ?? heightCm;
      currentWeight =
          (profile['currentWeight'] as num?)?.toDouble() ?? currentWeight;
      targetWeight =
          (profile['targetWeight'] as num?)?.toDouble() ?? targetWeight;
      calorieTarget =
          (profile['calorieTarget'] as num?)?.toInt() ?? calorieTarget;
      proteinTarget =
          (profile['proteinTarget'] as num?)?.toInt() ?? proteinTarget;
      carbTarget = (profile['carbTarget'] as num?)?.toInt() ?? carbTarget;
      fatTarget = (profile['fatTarget'] as num?)?.toInt() ?? fatTarget;
      waterTarget = (profile['waterTarget'] as num?)?.toInt() ?? waterTarget;
      stepsTarget = (profile['stepsTarget'] as num?)?.toInt() ?? stepsTarget;
      dayStartMinutes = ((profile['dayStartMinutes'] as num?)?.toInt() ??
              dayStartMinutes)
          .clamp(0, 1439);
      kosherEnabled = profile['kosherEnabled'] as bool? ?? kosherEnabled;
      meatDairySeparationEnabled =
          profile['meatDairySeparationEnabled'] as bool? ??
              meatDairySeparationEnabled;
      meatWaitMinutes =
          (profile['meatWaitMinutes'] as num?)?.toInt() ?? meatWaitMinutes;
      primaryGoal = profile['primaryGoal'] as String? ?? primaryGoal;
      activityLevel = profile['activityLevel'] as String? ?? activityLevel;
      workoutDaysPerWeek =
          (profile['workoutDaysPerWeek'] as num?)?.toInt() ??
              workoutDaysPerWeek;
      eatingStyle = profile['eatingStyle'] as String? ?? eatingStyle;
      final equipmentRaw = profile['equipment'];
      if (equipmentRaw is Map) {
        equipment.addAll(Map<String, dynamic>.from(equipmentRaw)
            .map((key, value) => MapEntry(key, value == true)));
      }
      dailyStateKey = dayKeyAt(DateTime.now());
    }

    final weightsRaw = data['weights'];
    if (weightsRaw is List) {
      weights
        ..clear()
        ..addAll(weightsRaw.whereType<Map>().map(
              (item) => WeightEntry.fromJson(Map<String, dynamic>.from(item)),
            ));
    }

    final mealsRaw = data['meals'];
    if (mealsRaw is List) {
      meals
        ..clear()
        ..addAll(mealsRaw.whereType<Map>().map(
              (item) => MealEntry.fromJson(Map<String, dynamic>.from(item)),
            ));
    }

    final pantryRaw = data['pantryItems'];
    if (pantryRaw is List) {
      pantryItems
        ..clear()
        ..addAll(pantryRaw.whereType<Map>().map(
              (item) => PantryItem.fromJson(Map<String, dynamic>.from(item)),
            ));
    }

    final shoppingRaw = data['shoppingItems'];
    if (shoppingRaw is List) {
      shoppingItems
        ..clear()
        ..addAll(shoppingRaw.whereType<Map>().map(
              (item) => ShoppingItem.fromJson(Map<String, dynamic>.from(item)),
            ));
    }

    final checkedRaw = data['shoppingChecked'];
    if (checkedRaw is Map) {
      shoppingChecked
        ..clear()
        ..addAll(Map<String, dynamic>.from(checkedRaw)
            .map((key, value) => MapEntry(key, value == true)));
    }
    shoppingInitialized =
        data['shoppingInitialized'] as bool? ?? shoppingInitialized;

    // The incoming payload already reflects the merged (local ∪ remote)
    // tombstone set when it comes from CloudSyncService's merge helpers, so
    // this is a plain replace, matching every other list field above.
    deletedPantryItemIds
      ..clear()
      ..addAll(decodeTombstoneMap(data['deletedPantryItemIds']));
    deletedShoppingItemIds
      ..clear()
      ..addAll(decodeTombstoneMap(data['deletedShoppingItemIds']));
    deletedMealKeys
      ..clear()
      ..addAll(decodeTombstoneMap(data['deletedMealKeys']));
    deletedCustomFoodIds
      ..clear()
      ..addAll(decodeTombstoneMap(data['deletedCustomFoodIds']));

    generateWeeklyPlan(save: false);
    await _save();
  }
}
