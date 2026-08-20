import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../shared/storage/app_local_storage.dart';

class ProfileGoalsStore {
  static const storageKey = 'profile_goals_v1';
  static const backupStorageKey = 'profile_goals_v1_backup';

  static const options = <String>[
    'ירידה במשקל',
    'שמירה על המשקל',
    'עלייה במסת שריר',
    'שיפור הכושר',
  ];

  static List<String> _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved profile goals are not a JSON list');
    }
    final goals = decoded
        .whereType<String>()
        .where(options.contains)
        .toSet()
        .toList();
    if (goals.isEmpty) {
      throw const FormatException('Saved profile goals contain no valid goals');
    }
    return goals;
  }

  static bool _isValid(String raw) {
    try {
      _decode(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> load({required String fallbackGoal}) async {
    final primary = await AppLocalStorage.readString(storageKey);
    final backup = await AppLocalStorage.readString(backupStorageKey);

    if (primary != null && primary.isNotEmpty) {
      try {
        return _decode(primary);
      } catch (error) {
        debugPrint('ProfileGoalsStore: failed to load primary data: $error');
      }
    }

    if (backup != null && backup.isNotEmpty) {
      try {
        final recovered = _decode(backup);
        debugPrint('ProfileGoalsStore: recovered goals from backup.');
        return recovered;
      } catch (error) {
        debugPrint('ProfileGoalsStore: failed to load backup data: $error');
      }
    }

    return [fallbackGoal];
  }

  static Future<void> save(List<String> goals) async {
    final clean = goals.where(options.contains).toSet().toList();
    if (clean.isEmpty) return;

    final encoded = jsonEncode(clean);
    final previous = await AppLocalStorage.readString(storageKey);
    if (previous != null && previous != encoded && _isValid(previous)) {
      await AppLocalStorage.writeString(backupStorageKey, previous);
    }
    await AppLocalStorage.writeString(storageKey, encoded);
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
