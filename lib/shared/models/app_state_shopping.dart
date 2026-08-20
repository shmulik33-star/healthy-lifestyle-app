part of 'app_state.dart';

Map<String, int> _shoppingTotalsFor(AppState state) {
  final totals = <String, int>{};
  for (final day in state.weeklyPlan) {
    for (final meal in day.meals) {
      for (final entry in meal.shopping.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
  }
  return totals;
}

String _shoppingCategoryFor(String name) {
  if (name.contains('ביצה')) return 'ביצים';
  if (name.contains('עוף') ||
      name.contains('פרגית') ||
      name.contains('בשר')) {
    return 'בשר ועוף';
  }
  if (name.contains('טונה') ||
      name.contains('סלמון') ||
      name.contains('דג')) {
    return 'דגים';
  }
  if (name.contains('קוטג') ||
      name.contains('יוגורט') ||
      name.contains('גבינ')) {
    return 'מוצרי חלב';
  }
  if (name.contains('ירק') ||
      name.contains('תפוח') ||
      name.contains('פרי') ||
      name.contains('אבוקדו')) {
    return 'ירקות ופירות';
  }
  if (name.contains('לחם') ||
      name.contains('קינואה') ||
      name.contains('עדשים') ||
      name.contains('טחינה') ||
      name.contains('שקדים')) {
    return 'מזווה';
  }
  return 'אחר';
}

String _shoppingCurrentFoodName(AppState state, MealEntry meal) {
  if (meal.foodId.isNotEmpty) {
    for (final food in state.allFoods) {
      if (food.id == meal.foodId) return food.name;
    }
  }
  return meal.name;
}

Map<String, double> _last7DayConsumptionFor(AppState state) {
  final since = DateTime.now().subtract(const Duration(days: 7));
  final totals = <String, double>{};
  for (final meal in state.meals.where((m) => !m.time.isBefore(since))) {
    final currentName = _shoppingCurrentFoodName(state, meal);
    if (meal.foodId == 'egg' ||
        AppState._sameFoodName(currentName, 'ביצה')) {
      totals['ביצים'] = (totals['ביצים'] ?? 0) + meal.grams / 55.0;
    } else {
      totals[currentName] = (totals[currentName] ?? 0) + meal.quantity;
    }
  }
  return totals;
}

List<ShoppingItem> _smartShoppingItemsFor(AppState state) {
  final oldHome = <String, double>{
    for (final item in state.shoppingItems) item.name: item.haveAtHome,
  };
  final oldChecked = <String, bool>{
    for (final item in state.shoppingItems) item.name: item.checked,
  };
  final plan = _shoppingTotalsFor(state);
  final consumption = _last7DayConsumptionFor(state);
  final names = <String>{...plan.keys, ...consumption.keys};
  final next = <ShoppingItem>[];

  for (final name in names) {
    final planned = (plan[name] ?? 0).toDouble();
    final consumed = (consumption[name] ?? 0).toDouble();
    var need = planned > consumed ? planned : consumed;
    final isEggs = AppState._sameFoodName(name, 'ביצים');

    if (isEggs) {
      need += 2;
      final packs = <double>[6, 12, 18, 30];
      need = packs.firstWhere(
        (pack) => pack >= need,
        orElse: () => ((need / 6).ceil() * 6).toDouble(),
      );
    } else if (need > 0) {
      need = need.ceilToDouble();
    }

    final home = oldHome[name] ?? 0;
    final buy = (need - home).clamp(0, double.infinity).toDouble();
    if (buy <= 0 && home > 0) continue;

    final reasonParts = <String>[];
    if (consumed > 0) {
      reasonParts.add(
        'צריכה ב־7 הימים האחרונים: ${_shoppingFormat(consumed)}',
      );
    }
    if (planned > 0) {
      reasonParts.add('מתוכנן בתפריט הבא: ${_shoppingFormat(planned)}');
    }
    if (home > 0) {
      reasonParts.add('סימנת שיש בבית: ${_shoppingFormat(home)}');
    }

    next.add(
      ShoppingItem(
        id: 'smart_${name.hashCode}',
        name: name,
        quantity: buy,
        unit: isEggs ? 'יחידות' : 'יחידות/מנות',
        category: _shoppingCategoryFor(name),
        source: 'חכם',
        reason: reasonParts.join(' · '),
        checked: oldChecked[name] ?? false,
        haveAtHome: home,
      ),
    );
  }

  return next;
}

String _shoppingFormat(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

PantryItem? _pantryByExactName(AppState state, String name) {
  for (final item in state.pantryItems) {
    if (item.name == name) return item;
  }
  return null;
}
