part of 'app_state.dart';

DateTime? _kosherLastMeatTime(AppState state) {
  if (!state.kosherEnabled ||
      !state.meatDairySeparationEnabled ||
      state.meatWaitMinutes <= 0) {
    return null;
  }
  final meatMeals = state.meals
      .where((meal) => meal.type == KosherFoodType.meat)
      .toList()
    ..sort((a, b) => b.time.compareTo(a.time));
  return meatMeals.isEmpty ? null : meatMeals.first.time;
}

DateTime? _kosherDairyAllowedAt(AppState state) =>
    _kosherLastMeatTime(state)?.add(Duration(minutes: state.meatWaitMinutes));

bool _kosherDairyAllowed(AppState state) {
  if (!state.kosherEnabled ||
      !state.meatDairySeparationEnabled ||
      state.meatWaitMinutes <= 0) {
    return true;
  }
  final allowedAt = _kosherDairyAllowedAt(state);
  return allowedAt == null || !DateTime.now().isBefore(allowedAt);
}

Duration _kosherDairyRemaining(AppState state) {
  final allowedAt = _kosherDairyAllowedAt(state);
  if (allowedAt == null) return Duration.zero;
  final remaining = allowedAt.difference(DateTime.now());
  return remaining.isNegative ? Duration.zero : remaining;
}

bool _kosherFoodAllowedForRecommendations(AppState state, FoodItem food) {
  if (!state.kosherEnabled) return true;
  if (food.kosherStatus != KosherStatus.kosher) return false;
  if (!_kosherDairyAllowed(state) && food.type == KosherFoodType.dairy) {
    return false;
  }
  return true;
}

String _kosherStateText(AppState state) {
  if (!state.kosherEnabled) return 'לא הוגדרה שמירת כשרות';
  if (!state.meatDairySeparationEnabled || state.meatWaitMinutes <= 0) {
    return 'כשרות פעילה ללא טיימר המתנה';
  }
  if (_kosherDairyAllowed(state)) return 'אין כרגע מגבלת חלב';
  final remaining = _kosherDairyRemaining(state);
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  return 'נשארו עוד ${hours > 0 ? '$hours שעות ו־' : ''}$minutes דקות עד חלבי לפי ההגדרה שלך';
}
