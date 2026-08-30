// This file is a `part` of AppState's library and intentionally performs
// ChangeNotifier lifecycle calls on the owning AppState instance.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'app_state.dart';

List<MealEntry> _nutritionMealsForDayAt(AppState state, DateTime now) {
  final start = state.dayStartAt(now);
  final end = state.dayEndAt(now);
  return state.meals
      .where((meal) => !meal.time.isBefore(start) && meal.time.isBefore(end))
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));
}

int _nutritionCaloriesEaten(AppState state) =>
    state.todayMeals.fold(0, (sum, meal) => sum + meal.calories);

double _nutritionProteinEaten(AppState state) =>
    state.todayMeals.fold(0, (sum, meal) => sum + meal.protein);

double _nutritionCarbsEaten(AppState state) =>
    state.todayMeals.fold(0, (sum, meal) => sum + meal.carbs);

double _nutritionFatEaten(AppState state) =>
    state.todayMeals.fold(0, (sum, meal) => sum + meal.fat);

int _nutritionRemainingCalories(AppState state) =>
    (state.calorieTarget - state.caloriesEaten).clamp(0, state.calorieTarget);

double _nutritionRemainingProtein(AppState state) =>
    (state.proteinTarget - state.proteinEaten)
        .clamp(0, state.proteinTarget.toDouble());

List<FoodItem> _nutritionAllFoods(AppState state) =>
    [...foodCatalog, ...state.customFoods];

FoodItem _nutritionFoodById(AppState state, String id) =>
    state.allFoods.firstWhere((food) => food.id == id);

/// Finds a food already in the catalog/custom foods by its scanned
/// barcode, or null if none matches -- unlike [_nutritionFoodById], "no
/// match" is the expected common case here (most scans are a new product),
/// not an error.
FoodItem? _nutritionFoodByBarcode(AppState state, String barcode) {
  final normalized = barcode.trim();
  if (normalized.isEmpty) return null;
  for (final food in state.allFoods) {
    if (food.barcode == normalized) return food;
  }
  return null;
}

// How far back `_nutritionQuickLogSuggestions` looks when tallying a past
// (food, quantity, unit) combination's frequency and recency.
const _quickLogLookbackWindow = Duration(days: 30);

// Max number of quick-log chips `AddMealSheet` shows.
const _quickLogSuggestionLimit = 8;

/// Running frequency/recency tally for one (foodId, quantity, unit)
/// combination while `_nutritionQuickLogSuggestions` walks `state.meals`.
/// `entry` tracks the most recent [MealEntry] seen for the combination, so
/// its `fromHome` flag reflects how the user *last* ate it.
class _QuickLogTally {
  _QuickLogTally(this.entry) : count = 1, lastUsed = entry.time;

  MealEntry entry;
  int count;
  DateTime lastUsed;
}

/// Ranking score for one tallied combination: frequency (count, within the
/// last 30 days) as the primary signal, plus a same-window recency bonus in
/// (0, 1] that only matters as a tiebreaker between equally-frequent
/// combinations -- a combination logged twice always outranks one logged
/// once, no matter how recent the single logging was.
double _quickLogScore(_QuickLogTally tally, DateTime now) {
  final daysSinceLastUsed =
      now.difference(tally.lastUsed).inHours / 24;
  final recencyBonus =
      1.0 - (daysSinceLastUsed / _quickLogLookbackWindow.inDays).clamp(0, 1);
  return tally.count.toDouble() + recencyBonus;
}

/// Ranks past (foodId, quantity, unit) combinations from [state.meals] for
/// the quick-log chips in `AddMealSheet`, most relevant first (see
/// [_quickLogScore]). Only meals logged within the last 30 days are
/// considered at all.
///
/// A combination referencing a personal food that has since been deleted
/// (its id no longer in [state.allFoods]) is skipped silently rather than
/// crashing -- there is no food left to compute its calories or kosher type
/// from. This intentionally does *not* filter by the user's current kosher
/// state the way meal recommendations do: it is a record of what was
/// actually eaten, not a suggestion of what to eat next.
List<QuickLogSuggestion> _nutritionQuickLogSuggestions(
  AppState state,
  DateTime now,
) {
  final cutoff = now.subtract(_quickLogLookbackWindow);
  final foodIds = {for (final food in state.allFoods) food.id};

  final tallies = <String, _QuickLogTally>{};
  for (final meal in state.meals) {
    if (meal.time.isBefore(cutoff)) continue;
    if (!foodIds.contains(meal.foodId)) continue;
    final key = '${meal.foodId}|${meal.quantity}|${meal.unit}';
    final existing = tallies[key];
    if (existing == null) {
      tallies[key] = _QuickLogTally(meal);
    } else {
      existing.count++;
      if (meal.time.isAfter(existing.lastUsed)) {
        existing.lastUsed = meal.time;
        existing.entry = meal;
      }
    }
  }

  final ranked = tallies.values.toList()
    ..sort((a, b) {
      final scoreCompare =
          _quickLogScore(b, now).compareTo(_quickLogScore(a, now));
      if (scoreCompare != 0) return scoreCompare;
      final recencyCompare = b.lastUsed.compareTo(a.lastUsed);
      if (recencyCompare != 0) return recencyCompare;
      return a.entry.foodId.compareTo(b.entry.foodId);
    });

  return ranked
      .take(_quickLogSuggestionLimit)
      .map((tally) {
        final entry = tally.entry;
        final food = state.allFoods.firstWhere((f) => f.id == entry.foodId);
        return QuickLogSuggestion(
          foodId: food.id,
          name: food.name,
          quantity: entry.quantity,
          unit: entry.unit,
          calories: food.caloriesFor(entry.unit, entry.quantity),
          fromHome: entry.fromHome,
        );
      })
      .toList();
}

void _nutritionAddFood(
  AppState state,
  FoodItem food,
  double quantity,
  String unit, {
  bool fromHome = true,
}) {
  state.ensureCurrentDay();
  final grams = food.gramsFor(unit, quantity);
  final entry = MealEntry(
    foodId: food.id,
    name: food.name,
    quantity: quantity,
    unit: unit,
    grams: grams,
    calories: food.caloriesFor(unit, quantity),
    protein: food.proteinFor(unit, quantity),
    carbs: food.carbsFor(unit, quantity),
    fat: food.fatFor(unit, quantity),
    type: food.type,
    time: DateTime.now(),
    fromHome: fromHome,
  );
  state.meals.add(entry);
  if (fromHome) state.consumeFromPantryByMeal(entry);
  state.notifyListeners();
  state._save();
}

void _nutritionAddCustomFood(AppState state, FoodItem food) {
  final replacedIds = state.customFoods
      .where(
        (existing) =>
            existing.id == food.id ||
            existing.name.trim().toLowerCase() == food.name.trim().toLowerCase(),
      )
      .map((existing) => existing.id)
      .toSet();

  state.customFoods.removeWhere(
    (existing) =>
        existing.id == food.id ||
        existing.name.trim().toLowerCase() == food.name.trim().toLowerCase(),
  );
  state.customFoods.add(food);
  // This is the single local entry point for both "create" and "edit" (an
  // edit calls this with the same id and changed fields), so stamping here
  // is what lets CloudSyncService.syncCustomFoods tell a genuine local edit
  // apart from a value just pulled down from the cloud.
  state.customFoodUpdatedAt[food.id] = DateTime.now().toUtc();

  for (final pantryItem in state.pantryItems) {
    if (replacedIds.contains(pantryItem.foodId) ||
        (pantryItem.foodId.isEmpty &&
            AppState._sameFoodName(pantryItem.name, food.name))) {
      pantryItem.foodId = food.id;
      pantryItem.name = food.name;
      pantryItem.category = food.category;
    }
  }
  state.notifyListeners();
  state._save();
}

/// Applies a custom food pulled from the cloud during sync. Same list
/// replacement as `_nutritionAddCustomFood`, but stamps `customFoodUpdatedAt`
/// with the cloud row's own `updated_at` instead of `now()` — a pull is not
/// a new local edit, and stamping it "now" would make it look like one and
/// bounce straight back up to the cloud on the very next sync cycle.
void _nutritionApplyRemoteCustomFood(
  AppState state,
  FoodItem food,
  DateTime remoteUpdatedAt,
) {
  final replacedIds = state.customFoods
      .where(
        (existing) =>
            existing.id == food.id ||
            existing.name.trim().toLowerCase() == food.name.trim().toLowerCase(),
      )
      .map((existing) => existing.id)
      .toSet();

  state.customFoods.removeWhere(
    (existing) =>
        existing.id == food.id ||
        existing.name.trim().toLowerCase() == food.name.trim().toLowerCase(),
  );
  state.customFoods.add(food);
  state.customFoodUpdatedAt[food.id] = remoteUpdatedAt;

  for (final pantryItem in state.pantryItems) {
    if (replacedIds.contains(pantryItem.foodId) ||
        (pantryItem.foodId.isEmpty &&
            AppState._sameFoodName(pantryItem.name, food.name))) {
      pantryItem.foodId = food.id;
      pantryItem.name = food.name;
      pantryItem.category = food.category;
    }
  }
  state.notifyListeners();
  state._save();
}

void _nutritionDeleteCustomFood(AppState state, FoodItem food) {
  state.customFoods.removeWhere((existing) => existing.id == food.id);
  state.deletedCustomFoodIds[food.id] = DateTime.now().toUtc();
  for (final pantryItem in state.pantryItems) {
    if (pantryItem.foodId == food.id) {
      pantryItem.foodId = '';
    }
  }
  state.notifyListeners();
  state._save();
}

/// Marks [food] as disliked or not. A food with no id (shouldn't happen for
/// anything reachable from the catalog/custom foods, but guards against a
/// stray placeholder) is silently ignored -- there'd be nothing stable to
/// key the dislike on.
void _nutritionSetFoodDisliked(AppState state, FoodItem food, bool disliked) {
  if (food.id.isEmpty) return;
  if (disliked) {
    state.foodDislikes.add(food.id);
  } else {
    state.foodDislikes.remove(food.id);
  }
  state.notifyListeners();
  state._save();
}

void _nutritionRemoveMeal(AppState state, MealEntry meal) {
  state.meals.remove(meal);
  state.deletedMealKeys[mealTombstoneKey(meal)] = DateTime.now().toUtc();
  state.notifyListeners();
  state._save();
}

String _nutritionDailyInsight(AppState state) {
  if (state.caloriesEaten == 0) {
    return 'עוד לא תיעדת ארוחה היום. התחלה פשוטה היא לתעד את הארוחה הבאה בלי לחפש דיוק מושלם.';
  }
  if (state.proteinEaten < state.proteinTarget * .55 &&
      state.caloriesEaten > state.calorieTarget * .55) {
    return 'יותר ממחצית הקלוריות כבר נוצלו, אבל החלבון עדיין נמוך יחסית. בארוחה הבאה כדאי לתת עדיפות למקור חלבון.';
  }
  if (state.waterCups < state.waterTarget * .5) {
    return 'המים מעט מאחור היום. אפשר להוסיף כוס עכשיו ולהמשיך בהדרגה.';
  }
  if (!state.dairyAllowed) {
    return 'מצב הכשרות כרגע בשרי. ההמלצות מסוננות לפי זמן ההמתנה שהגדרת בפרופיל.';
  }
  return 'היום מתקדם בצורה מאוזנת. נשארו ${state.remainingCalories} קלוריות וכ-${state.remainingProtein.toStringAsFixed(0)} גרם חלבון ליעד.';
}

// Roughly how much of the daily calorie/protein target each meal slot
// should carry. Used only to rank otherwise-tied candidates (see
// `_pickPlannedMeal`) — not enforced as a hard budget.
const _breakfastShare = 0.25;
const _lunchShare = 0.35;
const _dinnerShare = 0.30;
const _snackShare = 0.10;

// How many recently-assigned meal slots `AppState.recentMealKeys` keeps
// around: 7 days * 4 meals/day * 3 weeks. Old entries fall off the front
// once a newer generation pushes the list past this size.
const _recentMealKeysWindow = 7 * 4 * 3;

// The "keep the pool size off a multiple of 7" concern from the old
// hand-written meal lists doesn't apply anymore: the candidate pool below
// is built fresh from the user's real food catalog (built-in + custom) on
// every call, not a fixed hard-coded list, so its size already varies with
// what's actually in the catalog instead of being pinned at a specific
// count that could accidentally divide 7 evenly.

// Categories whose foods can anchor a "main dish" for בוקר/צהריים/ערב --
// chosen by inspecting foodCatalog's actual categories rather than a raw
// proteinPer100g threshold, which would have let odd candidates like
// שקדים (21g/100g) or לחם מלא (13g/100g) show up as a "main dish" on their
// own. נשנוש intentionally applies no such narrowing at all -- any food is
// a valid snack candidate, matching how varied the old snacks list already
// was (fruit, dairy, veg sticks, nuts...).
const _mainDishCategories = {
  'בשר ועוף',
  'דגים',
  'ביצים',
  'מוצרי חלב',
  'קטניות',
};

// Calorie anchor used to size a synthesized main dish's portion, weighted
// by the food's own calorie density instead of a flat gram amount -- a
// flat portion would give a wildly oversized "snack" for something
// calorie-dense like שקדים/שמן זית (150g of almonds alone is ~870 kcal) and
// a wildly undersized one for something calorie-light. Clamped to a sane
// grams range on both ends so an extreme density doesn't produce an
// unrealistic portion either.
const _slotCalorieAnchor = {
  'בוקר': 300.0,
  'צהריים': 450.0,
  'ערב': 350.0,
  'נשנוש': 100.0,
};
const _minPortionGrams = 10.0;
const _maxPortionGrams = 350.0;

double _mainDishPortionGrams(FoodItem food, String slotTitle) {
  final anchor = _slotCalorieAnchor[slotTitle] ?? 200.0;
  if (food.caloriesPer100g <= 0) return _minPortionGrams;
  final grams = anchor / food.caloriesPer100g * 100;
  return grams.clamp(_minPortionGrams, _maxPortionGrams).toDouble();
}

// Fixed "veggie side" text appended to every בוקר/צהריים/ערב description --
// a constant phrase, not a second selection algorithm choosing a specific
// side dish. נשנוש gets no side at all, matching how standalone most of the
// old static snacks already were.
String _weeklyPlanSideText(String slotTitle) => switch (slotTitle) {
      'בוקר' => 'וסלט ירקות',
      'נשנוש' => '',
      _ => 'ירקות וסלט', // צהריים / ערב
    };

// Fixed calorie contribution of the veggie side above -- not computed from
// a real FoodItem since the side is a fixed phrase, not a chosen
// ingredient. Small on purpose, just enough to keep the target-fit tier in
// `_pickPlannedMeal` meaningful.
const _sideCalories = 80;
const _sideShoppingKey = 'ירקות לסלט';

/// Synthesizes a [PlannedMeal] for [slotTitle] anchored on [food] -- the
/// weekly-plan equivalent of one hand-written template from the old static
/// lists, but built from a real catalog food so `type` reflects the food's
/// actual kosher classification and `shopping` uses the food's real name
/// (which is also why `_plannedMealHasDislikedIngredient` and
/// `_plannedMealPantryCoverage` now match better than they did against the
/// old hand-typed shopping strings).
PlannedMeal _syntheticPlannedMeal(FoodItem food, String slotTitle) {
  final side = _weeklyPlanSideText(slotTitle);
  final grams = _mainDishPortionGrams(food, slotTitle);
  final calories = (food.caloriesPer100g * grams / 100).round() +
      (side.isEmpty ? 0 : _sideCalories);
  final protein = food.proteinPer100g * grams / 100;
  return PlannedMeal(
    title: slotTitle,
    description: side.isEmpty ? food.name : '${food.name}, $side',
    type: food.type,
    calories: calories,
    protein: protein,
    shopping: {
      food.name: 1,
      if (side.isNotEmpty) _sideShoppingKey: 1,
    },
  );
}

/// Builds the candidate pool for one weekly-plan slot straight from the
/// user's real food catalog (built-in + custom), instead of a hand-written
/// list of meal templates. Applies these narrowings in strict priority
/// order, each one only if it doesn't empty the pool entirely -- kosher
/// constraints always win over "is this a sensible main dish" (see the PR
/// description's "never empty the pool" rule, same principle
/// `_pickPlannedMeal`'s tiers already follow):
///
/// 1. Only `KosherStatus.kosher` foods -- an auto-generated plan should
///    never suggest a food whose kosher status isn't the known-safe one.
///    Falls back to every food only in the degenerate case where literally
///    none are marked kosher (shouldn't happen with the real catalog).
/// 2. [excludeType], when given, drops that KosherFoodType -- used to keep
///    dairy out of every slot for the rest of a day that already had a
///    meat slot earlier (see the per-day loop in
///    `_nutritionGenerateWeeklyPlan`). This is a hard rule; it only gets
///    relaxed if it would otherwise empty the pool.
/// 3. For בוקר/צהריים/ערב: prefer [_mainDishCategories] -- but again only
///    when that doesn't empty the pool. נשנוש never applies this at all.
List<PlannedMeal> _weeklyPlanCandidates(
  AppState state,
  String slotTitle, {
  KosherFoodType? excludeType,
}) {
  final kosherFoods = state.allFoods
      .where((food) => food.kosherStatus == KosherStatus.kosher)
      .toList();
  final kosherBase = kosherFoods.isNotEmpty ? kosherFoods : state.allFoods;

  final typeAllowed = excludeType == null
      ? kosherBase
      : kosherBase.where((food) => food.type != excludeType).toList();
  final pool = typeAllowed.isNotEmpty ? typeAllowed : kosherBase;

  if (slotTitle == 'נשנוש') {
    return pool.map((food) => _syntheticPlannedMeal(food, slotTitle)).toList();
  }

  final mainDishes =
      pool.where((food) => _mainDishCategories.contains(food.category)).toList();
  final finalPool = mainDishes.isNotEmpty ? mainDishes : pool;
  return finalPool.map((food) => _syntheticPlannedMeal(food, slotTitle)).toList();
}

/// Fraction of a [PlannedMeal.shopping] ingredient list that's already
/// sitting in the pantry (matched by name the same way the rest of the app
/// matches food names — see `AppState._sameFoodName`). A meal with no
/// ingredients listed counts as fully covered so it isn't penalized.
double _plannedMealPantryCoverage(AppState state, PlannedMeal meal) {
  if (meal.shopping.isEmpty) return 1;
  final covered = meal.shopping.keys.where(
    (name) => state.pantryItems.any(
      (item) => AppState._sameFoodName(item.name, name) && item.quantity > 0,
    ),
  ).length;
  return covered / meal.shopping.length;
}

/// How far a candidate's calories/protein sit from this slot's share of the
/// user's daily targets, as a sum of relative errors (so a scale difference
/// between "calories" and "grams of protein" doesn't let one dominate).
double _plannedMealTargetFit(
  PlannedMeal meal,
  double targetCalories,
  double targetProtein,
) {
  final calorieError = targetCalories == 0
      ? 0.0
      : (meal.calories - targetCalories).abs() / targetCalories;
  final proteinError = targetProtein == 0
      ? 0.0
      : (meal.protein - targetProtein).abs() / targetProtein;
  return calorieError + proteinError;
}

/// How long ago [meal] was last used, as its most recent position in
/// [history] (higher = more recent). A meal never seen in [history] scores
/// -1 — ranking as *the* least recently used, ahead of anything that was
/// ever picked.
///
/// This is what tier 1 in [_pickPlannedMeal] ranks by. A plain "exclude
/// anything in the last N picks" set would instead hit a cliff once every
/// candidate in a pool has appeared at least once within the window: at
/// that point every candidate is simultaneously "recently used", the
/// exclusion filter would drop the *entire* pool, and the two lower tiers
/// would fall back to choosing from every candidate unfiltered — which,
/// since tiers 2/3 are deterministic, hands back the exact same winner
/// every time and can even degenerate into repeating one meal every day.
/// Ranking by recency instead of a binary in/out keeps tier 1 meaningful
/// forever: the candidate least recently used always wins that tier, even
/// after the whole pool has been through a full rotation.
int _lastUsedIndex(PlannedMeal meal, List<String> history) =>
    history.lastIndexOf(meal.description);

/// Whether any of [meal]'s shopping-list ingredients is a food the user has
/// disliked (per [AppState.isFoodDisliked]).
///
/// Deliberately *not* [AppState._sameFoodName] (used elsewhere for
/// pantry/meal matching): catalog food names carry a preparation descriptor
/// the weekly-plan shopping keys drop -- 'קינואה מבושלת' in the catalog vs.
/// 'קינואה' as a shopping key, 'טונה במים מסוננת' vs. 'טונה במים', and
/// roughly half the 29-item catalog follows the same pattern. `_sameFoodName`
/// requires equality after light normalization and would silently miss all
/// of these. A substring match after the same normalization catches them
/// without touching `_sameFoodName` itself, which stays exact on purpose
/// elsewhere (e.g. so pantry matching doesn't confuse "ביצה" with "סלט
/// ביצים"). This still won't catch a plural/singular mismatch (e.g.
/// 'עגבנייה' vs 'עגבניות', 'פריכית' vs 'פריכיות') -- that needs the planned
/// future move to matching planned-meal ingredients by food ID instead of
/// free-text names, already tracked elsewhere in the project.
bool _plannedMealHasDislikedIngredient(AppState state, PlannedMeal meal) {
  if (state.foodDislikes.isEmpty) return false;
  final dislikedNames = state.allFoods
      .where(state.isFoodDisliked)
      .map((food) => AppState._normalizeFoodName(food.name));
  return meal.shopping.keys.any((ingredient) {
    final normalized = AppState._normalizeFoodName(ingredient);
    return dislikedNames.any(
      (disliked) =>
          disliked == normalized ||
          disliked.contains(normalized) ||
          normalized.contains(disliked),
    );
  });
}

/// Picks one meal out of [options] for a single day/slot, applying four
/// tiers in order — each tier only breaks ties left by the one before it:
///
/// 0. Preference: prefer candidates with no disliked ingredient (per
///    [_plannedMealHasDislikedIngredient]) -- but only if at least one such
///    candidate exists; otherwise every option in [options] stays in the
///    pool, same "never empty the pool" rule the other tiers below follow.
/// 1. Variety: keep only the candidate(s) that were used longest ago (or
///    never used at all) per [_lastUsedIndex].
/// 2. Pantry awareness: among those, keep only the candidate(s) with the
///    highest fraction of ingredients already in stock.
/// 3. Target fit: among what's left, the closest match to this slot's share
///    of the daily calorie/protein targets wins; ties fall back to list
///    order, so a given input is picked deterministically.
///
/// The winner's description is appended to [history] so later slots in the
/// same run also treat it as "just used" (this is what keeps a single
/// generateWeeklyPlan call from handing the same breakfast to every day of
/// the week, not just across separate weeks).
PlannedMeal _pickPlannedMeal(
  AppState state,
  List<PlannedMeal> options,
  List<String> history, {
  required double targetCalories,
  required double targetProtein,
}) {
  final undisliked = options
      .where((meal) => !_plannedMealHasDislikedIngredient(state, meal))
      .toList();
  final candidates = undisliked.isNotEmpty ? undisliked : options;

  final leastRecentRank = candidates
      .map((meal) => _lastUsedIndex(meal, history))
      .reduce((a, b) => a < b ? a : b);
  var pool = candidates
      .where((meal) => _lastUsedIndex(meal, history) == leastRecentRank)
      .toList();

  final coverage = {
    for (final meal in pool) meal: _plannedMealPantryCoverage(state, meal),
  };
  final bestCoverage = coverage.values.reduce((a, b) => a > b ? a : b);
  pool = pool.where((meal) => coverage[meal] == bestCoverage).toList();

  pool.sort(
    (a, b) => _plannedMealTargetFit(a, targetCalories, targetProtein)
        .compareTo(_plannedMealTargetFit(b, targetCalories, targetProtein)),
  );

  final chosen = pool.first;
  history.add(chosen.description);
  return chosen;
}

void _nutritionGenerateWeeklyPlan(AppState state, {bool save = true}) {
  final days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];

  // The real, shipped `foodCatalog` is never empty, so this can't happen in
  // the app itself -- but `_weeklyPlanCandidates` now derives every slot's
  // pool from `state.allFoods`, and `_pickPlannedMeal` requires a non-empty
  // list by design (see its docstring), so a genuinely empty catalog (e.g.
  // a test double overriding `allFoods` to simulate one) would otherwise
  // crash deep in `_pickPlannedMeal`'s `.reduce()` instead of just leaving
  // the plan empty.
  if (state.allFoods.isEmpty) {
    state.weeklyPlan.clear();
    state.notifyListeners();
    if (save) state._save();
    return;
  }

  final targetCalories = state.calorieTarget.toDouble();
  final targetProtein = state.proteinTarget.toDouble();
  // A working copy of the persisted history: _pickPlannedMeal appends to it
  // as each slot is chosen, so later slots in this same run (and later
  // weeks, once written back below) see earlier picks as "used".
  final history = List<String>.from(state.recentMealKeys);

  state.weeklyPlan.clear();
  for (var i = 0; i < days.length; i++) {
    // Kosher rule, generalized beyond just צהריים→ערב now that any food can
    // anchor any slot: once a slot earlier *today* lands on meat, every
    // later slot today (in בוקר→צהריים→ערב→נשנוש order) is barred from
    // dairy -- never reset back once set, and never relaxed except as the
    // absolute last resort inside `_weeklyPlanCandidates` itself if it
    // would otherwise empty a slot's pool entirely.
    KosherFoodType? excludeType;

    final breakfast = _pickPlannedMeal(
      state,
      _weeklyPlanCandidates(state, 'בוקר', excludeType: excludeType),
      history,
      targetCalories: targetCalories * _breakfastShare,
      targetProtein: targetProtein * _breakfastShare,
    );
    if (breakfast.type == KosherFoodType.meat) {
      excludeType = KosherFoodType.dairy;
    }

    final lunch = _pickPlannedMeal(
      state,
      _weeklyPlanCandidates(state, 'צהריים', excludeType: excludeType),
      history,
      targetCalories: targetCalories * _lunchShare,
      targetProtein: targetProtein * _lunchShare,
    );
    if (lunch.type == KosherFoodType.meat) excludeType = KosherFoodType.dairy;

    final dinner = _pickPlannedMeal(
      state,
      _weeklyPlanCandidates(state, 'ערב', excludeType: excludeType),
      history,
      targetCalories: targetCalories * _dinnerShare,
      targetProtein: targetProtein * _dinnerShare,
    );
    if (dinner.type == KosherFoodType.meat) excludeType = KosherFoodType.dairy;

    final snack = _pickPlannedMeal(
      state,
      _weeklyPlanCandidates(state, 'נשנוש', excludeType: excludeType),
      history,
      targetCalories: targetCalories * _snackShare,
      targetProtein: targetProtein * _snackShare,
    );

    state.weeklyPlan.add(
      PlannedDay(day: days[i], meals: [breakfast, lunch, dinner, snack]),
    );
  }

  final overflow = history.length - _recentMealKeysWindow;
  state.recentMealKeys
    ..clear()
    ..addAll(overflow > 0 ? history.sublist(overflow) : history);

  state.notifyListeners();
  if (save) state._save();
}

/// Whether [food] was already logged today, matched by food ID -- the same
/// precedence pantry matching gives an ID when one is available (see
/// `_foodInPantry` below and golden rule #6 in CLAUDE.md). A meal entry with
/// no foodId (e.g. legacy data) never counts as "already eaten" here rather
/// than risk a false match on name alone.
bool _foodEatenToday(AppState state, FoodItem food) =>
    food.id.isNotEmpty && state.todayMeals.any((meal) => meal.foodId == food.id);

/// Whether [food] is in stock in the pantry, ID first and name as a
/// fallback -- same precedence as `_plannedMealPantryCoverage` and the rest
/// of the app's pantry/food matching (AppState._sameFoodName).
bool _foodInPantry(AppState state, FoodItem food) => state.pantryItems.any(
      (item) =>
          item.quantity > 0 &&
          (item.foodId.isNotEmpty && food.id.isNotEmpty
              ? item.foodId == food.id
              : AppState._sameFoodName(item.name, food.name)),
    );

/// Protein grams delivered per calorie. The final tiebreaker in
/// [_nutritionSmartFoodSuggestions] -- ranking by this instead of raw
/// proteinPer100g means a suggestion implicitly accounts for the user's
/// calorie budget, not just "which food has the most protein".
double _foodProteinEfficiency(FoodItem food) =>
    food.caloriesPer100g <= 0 ? 0 : food.proteinPer100g / food.caloriesPer100g;

/// Ranks the allowed catalog by four tiers, same pattern as
/// `_pickPlannedMeal`'s tiers -- each is a *sort*, not a filter, so even a
/// pool where every candidate loses every tie (e.g. everything already
/// eaten today, or everything disliked) still produces a full,
/// deterministically-ordered ranking instead of an empty result.
///
/// 1. Preference: not disliked (per [AppState.isFoodDisliked]) ranks above
///    disliked. Deliberately a ranking tier, not a filter on the allowed
///    pool -- with a 29-item catalog, filtering out disliked foods outright
///    could combine with kosher restrictions to empty the pool entirely.
/// 2. Variety: not eaten today (per [_foodEatenToday]) ranks above eaten.
/// 3. Pantry: in stock (per [_foodInPantry]) ranks above not in stock.
/// 4. Protein efficiency (per [_foodProteinEfficiency]) as the tiebreaker.
List<String> _nutritionSmartFoodSuggestions(AppState state) {
  final allowed = state.allFoods.where(state.foodAllowedForRecommendations).toList();
  if (allowed.isEmpty) {
    return ['לא מצאתי כרגע מזון מתאים לכל ההגדרות'];
  }

  allowed.sort((a, b) {
    final dislikedCompare = state.isFoodDisliked(a) == state.isFoodDisliked(b)
        ? 0
        : (state.isFoodDisliked(a) ? 1 : -1);
    if (dislikedCompare != 0) return dislikedCompare;

    final eatenCompare = _foodEatenToday(state, a) == _foodEatenToday(state, b)
        ? 0
        : (_foodEatenToday(state, a) ? 1 : -1);
    if (eatenCompare != 0) return eatenCompare;

    final pantryCompare = _foodInPantry(state, a) == _foodInPantry(state, b)
        ? 0
        : (_foodInPantry(state, a) ? -1 : 1);
    if (pantryCompare != 0) return pantryCompare;

    return _foodProteinEfficiency(b).compareTo(_foodProteinEfficiency(a));
  });

  return allowed.take(3).map((food) => food.name).toList();
}
