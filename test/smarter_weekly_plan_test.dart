import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

/// Overrides `allFoods` to just [_foods], so a ranking tier can be observed
/// in isolation without the real 29-item catalog burying the signal in
/// noise -- same trick as `_FixedCatalogAppState` in food_dislikes_test.dart.
class _FixedCatalogAppState extends AppState {
  _FixedCatalogAppState(this._foods);
  final List<FoodItem> _foods;
  @override
  List<FoodItem> get allFoods => _foods;
}

FoodItem _mainDish({
  required String id,
  required String name,
  required String category,
  required KosherFoodType type,
  double caloriesPer100g = 300,
  double proteinPer100g = 40,
}) =>
    FoodItem(
      id: id,
      name: name,
      category: category,
      type: type,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: 0,
      fatPer100g: 5,
      units: {'גרם': 1},
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'target fit decides between tied candidates when variety and pantry do '
    'not narrow the field',
    () {
      // Both are "בשר ועוף" (main-dish category) and never used, so tier 0
      // (dislike) and tier 1 (variety) don't distinguish them, and neither
      // is in the pantry, so tier 2 doesn't either -- only tier 3 (target
      // fit) can decide. calorieTarget/proteinTarget are picked so
      // breakfast's 25% share (see _breakfastShare) exactly matches
      // closeMatch's own computed calories/protein at its portion size
      // (300 kcal/100g -> 100g portion at the 300 kcal breakfast anchor,
      // so 300 kcal + 80 for the fixed veggie side = 380 kcal, 40g protein).
      final closeMatch = _mainDish(
        id: 'close',
        name: 'התאמה קרובה',
        category: 'בשר ועוף',
        type: KosherFoodType.meat,
        caloriesPer100g: 300,
        proteinPer100g: 40,
      );
      final farMatch = _mainDish(
        id: 'far',
        name: 'התאמה רחוקה',
        category: 'בשר ועוף',
        type: KosherFoodType.meat,
        caloriesPer100g: 80,
        proteinPer100g: 8,
      );
      final state = _FixedCatalogAppState([closeMatch, farMatch])
        // AppState's own constructor already auto-generates one plan on
        // construction (see `AppState()` in app_state.dart), using default
        // targets against this same 2-item catalog -- without clearing
        // that out first, its leftover history could let tier 1 (variety)
        // override tier 3 here instead of leaving target-fit to decide.
        ..recentMealKeys.clear()
        ..calorieTarget = 1520
        ..proteinTarget = 160;

      state.generateWeeklyPlan(save: false);

      expect(state.weeklyPlan[0].meals[0].description, contains('התאמה קרובה'));
    },
  );

  test(
    "variety avoids repeating the previous day's meal when an alternative "
    'exists',
    () {
      // Identical in every ranking-relevant way, so only tier 1 (variety)
      // can tell day 1 and day 2 apart: day 1 is a tie (arbitrary but
      // deterministic), day 2 must differ because day 1's pick is no longer
      // the least-recently-used candidate.
      final a = _mainDish(id: 'a', name: 'מאכל א', category: 'בשר ועוף', type: KosherFoodType.meat);
      final b = _mainDish(id: 'b', name: 'מאכל ב', category: 'בשר ועוף', type: KosherFoodType.meat);
      final state = _FixedCatalogAppState([a, b])..recentMealKeys.clear();

      state.generateWeeklyPlan(save: false);

      expect(
        state.weeklyPlan[1].meals[0].description,
        isNot(state.weeklyPlan[0].meals[0].description),
      );
    },
  );

  test(
    'variety holds across separate weekly generations too, not just within '
    'a single week',
    () {
      // With only 2 candidates, a full week (7 days) alternates a, b, a, b,
      // ... -- so by the end of week 1 the *most* recently used is whichever
      // ran on day 7, and the *least* recently used is whichever ran on day
      // 6. Week 2's Sunday must therefore pick day 6's food, never day 7's
      // (= week 1 Sunday's) again.
      final a = _mainDish(id: 'a', name: 'מאכל א', category: 'בשר ועוף', type: KosherFoodType.meat);
      final b = _mainDish(id: 'b', name: 'מאכל ב', category: 'בשר ועוף', type: KosherFoodType.meat);
      final state = _FixedCatalogAppState([a, b])..recentMealKeys.clear();

      state.generateWeeklyPlan(save: false);
      final week1Sunday = state.weeklyPlan[0].meals[0].description;
      state.generateWeeklyPlan(save: false);
      final week2Sunday = state.weeklyPlan[0].meals[0].description;

      expect(week2Sunday, isNot(week1Sunday));
    },
  );

  test(
    'a disliked food is skipped in favor of a liked alternative -- matches '
    "by the food's real catalog name directly now (the shopping key IS "
    'food.name), so the old preparation-descriptor mismatch this used to '
    'need a substring-match workaround for no longer comes up here',
    () {
      final disliked = _mainDish(id: 'dis', name: 'מנה לא אהובה', category: 'בשר ועוף', type: KosherFoodType.meat);
      final liked = _mainDish(id: 'lik', name: 'מנה אהובה', category: 'בשר ועוף', type: KosherFoodType.meat);
      final state = _FixedCatalogAppState([disliked, liked])..recentMealKeys.clear();
      state.setFoodDisliked(disliked, true);

      state.generateWeeklyPlan(save: false);

      for (final day in state.weeklyPlan) {
        expect(day.meals[0].description, isNot(contains('מנה לא אהובה')));
      }
    },
  );

  test(
    'disliking a real catalog food keeps it out of every day\'s meals for '
    'the whole week',
    () {
      // קינואה מבושלת's category (לחמים ודגנים) isn't a main-dish category,
      // so it's only ever a candidate for נשנוש -- but the real catalog has
      // plenty of other snack candidates, so disliking it should never
      // force it back in.
      final state = AppState();
      final quinoa = state.allFoods.firstWhere((food) => food.id == 'quinoa');
      state.setFoodDisliked(quinoa, true);

      state.generateWeeklyPlan(save: false);

      for (final day in state.weeklyPlan) {
        for (final meal in day.meals) {
          expect(meal.description, isNot(contains('קינואה')));
        }
      }
    },
  );

  test(
    'pantry awareness prefers a candidate whose ingredients are already in '
    'stock',
    () {
      final stocked = _mainDish(id: 'st', name: 'מלאי קיים', category: 'בשר ועוף', type: KosherFoodType.meat);
      final notStocked = _mainDish(id: 'ns', name: 'אין מלאי', category: 'בשר ועוף', type: KosherFoodType.meat);
      final state = _FixedCatalogAppState([stocked, notStocked])..recentMealKeys.clear();
      state.addPantryItem('מלאי קיים', 1, 'יחידות', 'בשר ועוף');
      state.addPantryItem('ירקות לסלט', 1, 'יחידות', 'ירקות');

      state.generateWeeklyPlan(save: false);

      expect(state.weeklyPlan[0].meals[0].description, contains('מלאי קיים'));
    },
  );

  test(
    'falls back to any kosher food for a main-dish slot when nothing '
    'matches the main-dish categories, instead of emptying the pool',
    () {
      final onlyVeg = _mainDish(
        id: 'veg',
        name: 'ירק בדיקה',
        category: 'ירקות',
        type: KosherFoodType.pareve,
        caloriesPer100g: 30,
        proteinPer100g: 1,
      );
      final state = _FixedCatalogAppState([onlyVeg])..recentMealKeys.clear();

      state.generateWeeklyPlan(save: false);

      for (final day in state.weeklyPlan) {
        expect(day.meals[0].description, contains('ירק בדיקה'));
      }
    },
  );

  test(
    'a meat slot blocks dairy for every later slot the same day, not just '
    "lunch→dinner -- the rule is sequential across the whole day's slot "
    'order now that any food can anchor any slot',
    () {
      final meat = _mainDish(
        id: 'meat',
        name: 'בשר בדיקה',
        category: 'בשר ועוף',
        type: KosherFoodType.meat,
        caloriesPer100g: 300,
        proteinPer100g: 40,
      );
      final dairy = _mainDish(
        id: 'dairy',
        name: 'חלבי בדיקה',
        category: 'מוצרי חלב',
        type: KosherFoodType.dairy,
        caloriesPer100g: 80,
        proteinPer100g: 8,
      );
      final state = _FixedCatalogAppState([meat, dairy])
        // See the target-fit test above for why this needs clearing first.
        ..recentMealKeys.clear()
        // Chosen so breakfast's target-fit clearly favors meat (see the
        // target-fit test above for the same math) -- meat has to win day
        // 1's breakfast deterministically for this test to prove anything.
        ..calorieTarget = 1520
        ..proteinTarget = 160;

      state.generateWeeklyPlan(save: false);

      expect(state.weeklyPlan[0].meals[0].type, KosherFoodType.meat);
      for (final meal in state.weeklyPlan[0].meals) {
        expect(meal.type, isNot(KosherFoodType.dairy));
      }
    },
  );

  test(
    'once any slot in a day is meat, no later slot that day is dairy '
    '(same rule, exercised against the real catalog)',
    () {
      final state = AppState();
      state.generateWeeklyPlan(save: false);

      for (final day in state.weeklyPlan) {
        var sawMeat = false;
        for (final meal in day.meals) {
          if (sawMeat) {
            expect(
              meal.type,
              isNot(KosherFoodType.dairy),
              reason: '${day.day}: dairy after an earlier meat slot',
            );
          }
          if (meal.type == KosherFoodType.meat) sawMeat = true;
        }
      }
    },
  );

  test(
    'the real built-in catalog has enough candidates that a single week '
    "doesn't repeat a slot's meal -- explicit sanity check that 29 items "
    'is diverse enough for the dynamic candidate pool (a failure here is a '
    'catalog-content gap to report, not something to patch around in the '
    'ranking algorithm)',
    () {
      final state = AppState();
      state.generateWeeklyPlan(save: false);

      for (var slot = 0; slot < 4; slot++) {
        final descriptions =
            state.weeklyPlan.map((day) => day.meals[slot].description).toSet();
        expect(
          descriptions,
          hasLength(7),
          reason: 'slot $slot repeated within a single week',
        );
      }
    },
  );

  test(
    'legacy weekly-plan JSON without protein/recentMealKeys loads with safe defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        'stage10_state_v1': jsonEncode({
          'schemaVersion': 1,
          'firstName': 'ותיק',
          // A non-empty weeklyPlan so AppState.load() doesn't regenerate it,
          // and its meal is missing `protein` -- exactly what a snapshot
          // saved before this feature would look like. `recentMealKeys` is
          // omitted from the top-level map entirely, like an old snapshot.
          'weeklyPlan': [
            {
              'day': 'ראשון',
              'meals': [
                {
                  'title': 'בוקר',
                  'description': 'ארוחה ישנה',
                  'type': 'pareve',
                  'calories': 300,
                  'shopping': {'משהו': 1},
                },
              ],
            },
          ],
        }),
      });

      final state = await AppState.load();

      expect(state.recentMealKeys, isEmpty);
      expect(state.weeklyPlan, hasLength(1));
      expect(state.weeklyPlan.single.meals.single.protein, 0);
    },
  );
}
