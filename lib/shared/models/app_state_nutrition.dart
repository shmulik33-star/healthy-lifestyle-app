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
  String unit,
) {
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
  );
  state.meals.add(entry);
  state.consumeFromPantryByMeal(entry);
  state.notifyListeners();
  state._save();
}

void _nutritionAddCustomFood(AppState state, FoodItem food) {
  state.customFoods.removeWhere(
    (existing) =>
        existing.id == food.id ||
        existing.name.trim().toLowerCase() == food.name.trim().toLowerCase(),
  );
  state.customFoods.add(food);

  for (final pantryItem in state.pantryItems) {
    if (AppState._sameFoodName(pantryItem.name, food.name)) {
      pantryItem.foodId = food.id;
    }
  }
  state.notifyListeners();
  state._save();
}

void _nutritionDeleteCustomFood(AppState state, FoodItem food) {
  state.customFoods.removeWhere((existing) => existing.id == food.id);
  state.notifyListeners();
  state._save();
}

void _nutritionRemoveMeal(AppState state, MealEntry meal) {
  state.meals.remove(meal);
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

void _nutritionGenerateWeeklyPlan(AppState state, {bool save = true}) {
  final days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
  final breakfasts = [
    PlannedMeal(
      title: 'בוקר',
      description: '2 ביצים, סלט וטחינה',
      type: KosherFoodType.pareve,
      calories: 360,
      shopping: {'ביצים': 2, 'ירקות לסלט': 2, 'טחינה': 1},
    ),
    PlannedMeal(
      title: 'בוקר',
      description: 'יוגורט עשיר בחלבון ושקדים',
      type: KosherFoodType.dairy,
      calories: 300,
      shopping: {'יוגורט עשיר בחלבון': 1, 'שקדים': 1},
    ),
    PlannedMeal(
      title: 'בוקר',
      description: 'קוטג׳, ירקות ופרוסת לחם מלא',
      type: KosherFoodType.dairy,
      calories: 340,
      shopping: {'קוטג׳ 5%': 1, 'ירקות לסלט': 2, 'לחם מלא': 2},
    ),
  ];
  final lunches = [
    PlannedMeal(
      title: 'צהריים',
      description: 'חזה עוף, סלט גדול וכף טחינה',
      type: KosherFoodType.meat,
      calories: 550,
      shopping: {'חזה עוף': 1, 'ירקות לסלט': 4, 'טחינה': 1},
    ),
    PlannedMeal(
      title: 'צהריים',
      description: 'פרגית, ירקות וקינואה',
      type: KosherFoodType.meat,
      calories: 620,
      shopping: {'פרגית': 1, 'ירקות לסלט': 3, 'קינואה': 1},
    ),
    PlannedMeal(
      title: 'צהריים',
      description: 'סלמון, ירקות ועדשים',
      type: KosherFoodType.pareve,
      calories: 560,
      shopping: {'סלמון': 1, 'ירקות לסלט': 3, 'עדשים': 1},
    ),
  ];
  final dinnersPareve = [
    PlannedMeal(
      title: 'ערב',
      description: 'טונה, ביצה וסלט גדול',
      type: KosherFoodType.pareve,
      calories: 410,
      shopping: {'טונה במים': 1, 'ביצים': 1, 'ירקות לסלט': 3},
    ),
    PlannedMeal(
      title: 'ערב',
      description: 'טופו מוקפץ עם ירקות',
      type: KosherFoodType.pareve,
      calories: 420,
      shopping: {'טופו': 1, 'ירקות לסלט': 3},
    ),
    PlannedMeal(
      title: 'ערב',
      description: 'ביצים, אבוקדו וירקות',
      type: KosherFoodType.pareve,
      calories: 430,
      shopping: {'ביצים': 2, 'אבוקדו': 1, 'ירקות לסלט': 2},
    ),
  ];
  final dinnersDairy = [
    PlannedMeal(
      title: 'ערב',
      description: 'קוטג׳, סלט ופרוסת לחם מלא',
      type: KosherFoodType.dairy,
      calories: 390,
      shopping: {'קוטג׳ 5%': 1, 'ירקות לסלט': 3, 'לחם מלא': 2},
    ),
    PlannedMeal(
      title: 'ערב',
      description: 'יוגורט עשיר בחלבון, פרי ושקדים',
      type: KosherFoodType.dairy,
      calories: 360,
      shopping: {'יוגורט עשיר בחלבון': 1, 'תפוח': 1, 'שקדים': 1},
    ),
  ];
  final snack = PlannedMeal(
    title: 'נשנוש',
    description: 'פרי + חופן קטן של שקדים',
    type: KosherFoodType.pareve,
    calories: 180,
    shopping: {'פרי': 1, 'שקדים': 1},
  );

  state.weeklyPlan.clear();
  for (var i = 0; i < days.length; i++) {
    final breakfast = breakfasts[i % breakfasts.length];
    final lunch = lunches[i % lunches.length];
    final dinner = lunch.type == KosherFoodType.meat
        ? dinnersPareve[i % dinnersPareve.length]
        : dinnersDairy[i % dinnersDairy.length];
    state.weeklyPlan.add(
      PlannedDay(day: days[i], meals: [breakfast, lunch, dinner, snack]),
    );
  }
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
