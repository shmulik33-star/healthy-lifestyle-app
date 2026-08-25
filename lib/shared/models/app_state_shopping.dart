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

String _shoppingCategoryFor(AppState state, String name) {
  for (final food in state.allFoods) {
    if (AppState._sameFoodName(food.name, name) &&
        isKnownFoodCategory(food.category)) {
      return food.category;
    }
  }

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
  if (name.contains('עגבנ') ||
      name.contains('מלפפון') ||
      name.contains('פלפל') ||
      name.contains('גזר') ||
      name.contains('ירק') ||
      name.contains('סלט')) {
    return 'ירקות';
  }
  if (name.contains('תפוח') ||
      name.contains('בננ') ||
      name.contains('תפוז') ||
      name.contains('אבוקדו') ||
      name.contains('פרי')) {
    return 'פירות';
  }
  if (name.contains('לחם') ||
      name.contains('אורז') ||
      name.contains('קינואה') ||
      name.contains('פריכ')) {
    return 'לחמים ודגנים';
  }
  if (name.contains('עדשים') ||
      name.contains('טופו') ||
      name.contains('קטני')) {
    return 'קטניות';
  }
  if (name.contains('שקדים') ||
      name.contains('אגוז') ||
      name.contains('זרע')) {
    return 'אגוזים וזרעים';
  }
  if (name.contains('טחינה') ||
      name.contains('חומוס') ||
      name.contains('שמן') ||
      name.contains('רוטב') ||
      name.contains('ממרח')) {
    return 'ממרחים ורטבים';
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

/// A "how this gets sold" rule used to round a raw need (a count of
/// servings/portions, or eggs-equivalent — see `_last7DayConsumptionFor`)
/// up to a realistic purchasable package, and the unit that package is
/// expressed in. Categories not listed here fall back to [_defaultPackRule]
/// (round up to the next whole package).
class _PackRule {
  const _PackRule(this.unit, this.step, {this.packs});
  final String unit;
  final double step;
  final List<double>? packs;

  double roundUp(double need) {
    if (packs != null) {
      final list = packs!;
      return list.firstWhere(
        (pack) => pack >= need,
        orElse: () => ((need / list.first).ceil() * list.first).toDouble(),
      );
    }
    return (need / step).ceil() * step;
  }
}

const _defaultPackRule = _PackRule('חבילה', 1);

/// Real-world package sizes by product category. Meat/fish are commonly
/// sold by weight in half-kilo steps; dairy/beverages are commonly sold by
/// volume in half-liter steps; eggs are sold in fixed dozen-style cartons.
/// Everything else just rounds up to the next whole package.
const _packRulesByCategory = <String, _PackRule>{
  'ביצים': _PackRule('יחידות', 6, packs: [6, 12, 18, 30]),
  'בשר ועוף': _PackRule('ק״ג', 0.5),
  'דגים': _PackRule('ק״ג', 0.5),
  'מוצרי חלב': _PackRule('ליטר', 0.5),
  'משקאות': _PackRule('ליטר', 0.5),
};

/// Sums pantry stock for [name], matching pantry items the same way the
/// rest of the shopping logic matches food names (case/whitespace
/// insensitive, with egg-name aliases collapsed).
double _pantryQuantityFor(AppState state, String name) {
  var total = 0.0;
  for (final item in state.pantryItems) {
    if (AppState._sameFoodName(item.name, name)) total += item.quantity;
  }
  return total;
}

List<ShoppingItem> _smartShoppingItemsFor(AppState state) {
  final oldOverrides = <String, double>{
    for (final item in state.shoppingItems)
      if (item.haveAtHomeOverride) item.name: item.haveAtHome,
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
    final category = _shoppingCategoryFor(state, name);
    final packRule = _packRulesByCategory[category] ?? _defaultPackRule;

    if (isEggs) need += 2;
    if (need > 0) need = packRule.roundUp(need);

    final isOverride = oldOverrides.containsKey(name);
    final home =
        isOverride ? oldOverrides[name]! : _pantryQuantityFor(state, name);
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
      reasonParts.add(
        isOverride
            ? 'סימנת שיש בבית: ${_shoppingFormat(home)}'
            : 'יש במזווה: ${_shoppingFormat(home)}',
      );
    }

    next.add(
      ShoppingItem(
        id: 'smart_${name.hashCode}',
        name: name,
        quantity: buy,
        unit: packRule.unit,
        category: category,
        source: 'חכם',
        reason: reasonParts.join(' · '),
        checked: oldChecked[name] ?? false,
        haveAtHome: home,
        haveAtHomeOverride: isOverride,
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
