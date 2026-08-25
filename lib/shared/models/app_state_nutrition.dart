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

/// Picks one meal out of [options] for a single day/slot, applying three
/// tiers in order — each tier only breaks ties left by the one before it:
///
/// 1. Variety: drop candidates whose description is in [recentlyUsed],
///    unless that would rule out every option (then nothing is dropped).
/// 2. Pantry awareness: keep only the candidate(s) with the highest
///    fraction of ingredients already in stock.
/// 3. Target fit: among what's left, the closest match to this slot's share
///    of the daily calorie/protein targets wins; ties fall back to list
///    order, so a given input is picked deterministically.
///
/// The winner's description is added to [recentlyUsed] so later slots in
/// the same run also treat it as "just used" (this is what keeps a single
/// generateWeeklyPlan call from handing the same breakfast to every day of
/// the week, not just across separate weeks).
PlannedMeal _pickPlannedMeal(
  AppState state,
  List<PlannedMeal> options,
  Set<String> recentlyUsed, {
  required double targetCalories,
  required double targetProtein,
}) {
  var pool =
      options.where((meal) => !recentlyUsed.contains(meal.description)).toList();
  if (pool.isEmpty) pool = options;

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
  recentlyUsed.add(chosen.description);
  return chosen;
}

void _nutritionGenerateWeeklyPlan(AppState state, {bool save = true}) {
  final days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
  // Protein values below are computed from the real per-100g figures in
  // `foodCatalog`, for a realistic serving of each listed ingredient (e.g.
  // 2 eggs at 50g/egg, a salad portion at ~120g/"כוס", tahini at 15g/"כף")
  // — not estimated by hand. See the "Protein values" note in this PR's
  // description for the full per-meal breakdown.
  final breakfasts = [
    PlannedMeal(
      title: 'בוקר',
      description: '2 ביצים, סלט וטחינה',
      type: KosherFoodType.pareve,
      calories: 360,
      protein: 16.9,
      shopping: {'ביצים': 2, 'ירקות לסלט': 2, 'טחינה': 1},
    ),
    PlannedMeal(
      title: 'בוקר',
      description: 'יוגורט עשיר בחלבון ושקדים',
      type: KosherFoodType.dairy,
      calories: 300,
      protein: 26.3,
      shopping: {'יוגורט עשיר בחלבון': 1, 'שקדים': 1},
    ),
    PlannedMeal(
      title: 'בוקר',
      description: 'קוטג׳, ירקות ופרוסת לחם מלא',
      type: KosherFoodType.dairy,
      calories: 340,
      protein: 24.7,
      shopping: {'קוטג׳ 5%': 1, 'ירקות לסלט': 2, 'לחם מלא': 2},
    ),
  ];
  final lunches = [
    PlannedMeal(
      title: 'צהריים',
      description: 'חזה עוף, סלט גדול וכף טחינה',
      type: KosherFoodType.meat,
      calories: 550,
      protein: 50.4,
      shopping: {'חזה עוף': 1, 'ירקות לסלט': 4, 'טחינה': 1},
    ),
    PlannedMeal(
      title: 'צהריים',
      description: 'פרגית, ירקות וקינואה',
      type: KosherFoodType.meat,
      calories: 620,
      protein: 49.0,
      shopping: {'פרגית': 1, 'ירקות לסלט': 3, 'קינואה': 1},
    ),
    PlannedMeal(
      title: 'צהריים',
      description: 'סלמון, ירקות ועדשים',
      type: KosherFoodType.pareve,
      calories: 560,
      protein: 52.7,
      shopping: {'סלמון': 1, 'ירקות לסלט': 3, 'עדשים': 1},
    ),
  ];
  final dinnersPareve = [
    PlannedMeal(
      title: 'ערב',
      description: 'טונה, ביצה וסלט גדול',
      type: KosherFoodType.pareve,
      calories: 410,
      protein: 39.8,
      shopping: {'טונה במים': 1, 'ביצים': 1, 'ירקות לסלט': 3},
    ),
    PlannedMeal(
      title: 'ערב',
      description: 'טופו מוקפץ עם ירקות',
      type: KosherFoodType.pareve,
      calories: 420,
      protein: 30.2,
      shopping: {'טופו': 1, 'ירקות לסלט': 3},
    ),
    PlannedMeal(
      title: 'ערב',
      description: 'ביצים, אבוקדו וירקות',
      type: KosherFoodType.pareve,
      calories: 430,
      protein: 18.1,
      shopping: {'ביצים': 2, 'אבוקדו': 1, 'ירקות לסלט': 2},
    ),
  ];
  final dinnersDairy = [
    PlannedMeal(
      title: 'ערב',
      description: 'קוטג׳, סלט ופרוסת לחם מלא',
      type: KosherFoodType.dairy,
      calories: 390,
      protein: 26.2,
      shopping: {'קוטג׳ 5%': 1, 'ירקות לסלט': 3, 'לחם מלא': 2},
    ),
    PlannedMeal(
      title: 'ערב',
      description: 'יוגורט עשיר בחלבון, פרי ושקדים',
      type: KosherFoodType.dairy,
      calories: 360,
      protein: 26.8,
      shopping: {'יוגורט עשיר בחלבון': 1, 'תפוח': 1, 'שקדים': 1},
    ),
  ];
  final snacks = [
    PlannedMeal(
      title: 'נשנוש',
      description: 'פרי + חופן קטן של שקדים',
      type: KosherFoodType.pareve,
      calories: 180,
      protein: 3.7,
      shopping: {'פרי': 1, 'שקדים': 1},
    ),
  ];

  final targetCalories = state.calorieTarget.toDouble();
  final targetProtein = state.proteinTarget.toDouble();
  final recentlyUsed = {...state.recentMealKeys};
  final chosenThisRun = <String>[];

  state.weeklyPlan.clear();
  for (var i = 0; i < days.length; i++) {
    final breakfast = _pickPlannedMeal(
      state,
      breakfasts,
      recentlyUsed,
      targetCalories: targetCalories * _breakfastShare,
      targetProtein: targetProtein * _breakfastShare,
    );
    final lunch = _pickPlannedMeal(
      state,
      lunches,
      recentlyUsed,
      targetCalories: targetCalories * _lunchShare,
      targetProtein: targetProtein * _lunchShare,
    );
    // Kosher rule (unchanged from before): a meat lunch must be followed by
    // a pareve dinner, never a dairy one.
    final dinnerOptions =
        lunch.type == KosherFoodType.meat ? dinnersPareve : dinnersDairy;
    final dinner = _pickPlannedMeal(
      state,
      dinnerOptions,
      recentlyUsed,
      targetCalories: targetCalories * _dinnerShare,
      targetProtein: targetProtein * _dinnerShare,
    );
    final snack = _pickPlannedMeal(
      state,
      snacks,
      recentlyUsed,
      targetCalories: targetCalories * _snackShare,
      targetProtein: targetProtein * _snackShare,
    );

    chosenThisRun.addAll([
      breakfast.description,
      lunch.description,
      dinner.description,
      snack.description,
    ]);
    state.weeklyPlan.add(
      PlannedDay(day: days[i], meals: [breakfast, lunch, dinner, snack]),
    );
  }

  state.recentMealKeys.addAll(chosenThisRun);
  final overflow = state.recentMealKeys.length - _recentMealKeysWindow;
  if (overflow > 0) state.recentMealKeys.removeRange(0, overflow);

  state.notifyListeners();
  if (save) state._save();
}

List<String> _nutritionSmartFoodSuggestions(AppState state) {
  final allowed = state.allFoods.where(state.foodAllowedForRecommendations).toList()
    ..sort((a, b) => b.proteinPer100g.compareTo(a.proteinPer100g));
  if (allowed.isEmpty) {
    return ['לא מצאתי כרגע מזון מתאים לכל ההגדרות'];
  }
  return allowed.take(3).map((food) => food.name).toList();
}
