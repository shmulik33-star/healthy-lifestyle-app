import 'dart:convert';

import '../../shared/storage/app_local_storage.dart';

class ProfileGoalsStore {
  static const storageKey = 'profile_goals_v1';

  static const options = <String>[
    'ירידה במשקל',
    'שמירה על המשקל',
    'עלייה במסת שריר',
    'שיפור הכושר',
  ];

  static Future<List<String>> load({required String fallbackGoal}) async {
    final raw = await AppLocalStorage.readString(storageKey);
    if (raw == null || raw.isEmpty) return [fallbackGoal];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [fallbackGoal];
      final goals = decoded
          .whereType<String>()
          .where(options.contains)
          .toSet()
          .toList();
      return goals.isEmpty ? [fallbackGoal] : goals;
    } catch (_) {
      return [fallbackGoal];
    }
  }

  static Future<void> save(List<String> goals) async {
    final clean = goals.where(options.contains).toSet().toList();
    if (clean.isEmpty) return;
    await AppLocalStorage.writeString(storageKey, jsonEncode(clean));
  }

  static List<String> toggleGoal(List<String> current, String goal) {
    final next = [...current];
    if (next.contains(goal)) {
      if (next.length > 1) next.remove(goal);
      return next;
    }

    if (goal == 'ירידה במשקל') next.remove('שמירה על המשקל');
    if (goal == 'שמירה על המשקל') next.remove('ירידה במשקל');
    next.add(goal);
    return options.where(next.contains).toList();
  }

  static int suggestedCalories({
    required double weightKg,
    required String activityLevel,
    required List<String> goals,
  }) {
    final base = (weightKg * 22).round();
    final activityFactor = switch (activityLevel) {
      'נמוכה' => 1.15,
      'גבוהה' => 1.45,
      _ => 1.30,
    };
    var estimate = (base * activityFactor).round();

    final losing = goals.contains('ירידה במשקל');
    final gainingMuscle = goals.contains('עלייה במסת שריר');

    if (losing && gainingMuscle) {
      estimate -= 200;
    } else if (losing) {
      estimate -= 350;
    } else if (gainingMuscle) {
      estimate += 200;
    }

    return estimate.clamp(1200, 4000);
  }

  static int suggestedProtein({
    required double weightKg,
    required List<String> goals,
  }) {
    final factor = goals.contains('עלייה במסת שריר')
        ? 1.8
        : goals.contains('שיפור הכושר')
            ? 1.6
            : 1.5;
    return (weightKg * factor).round().clamp(60, 250);
  }
}
