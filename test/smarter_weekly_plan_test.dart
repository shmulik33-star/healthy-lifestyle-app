import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

const _highProteinBreakfast = 'יוגורט עשיר בחלבון ושקדים';
const _pargitLunch = 'פרגית, ירקות וקינואה';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'target fit decides between candidates when variety and pantry do not narrow the field',
    () {
      final state = AppState()
        // 25% of these exactly matches _highProteinBreakfast's 300 kcal /
        // ~26.3g protein, making it the clear closest-fit breakfast.
        ..calorieTarget = 1200
        ..proteinTarget = 105
        ..recentMealKeys.clear();

      state.generateWeeklyPlan(save: false);

      expect(state.weeklyPlan[0].meals[0].description, _highProteinBreakfast);
    },
  );

  test(
    'variety avoids repeating the previous day\'s meal when an alternative exists',
    () {
      final state = AppState()
        ..calorieTarget = 1200
        ..proteinTarget = 105
        ..recentMealKeys.clear();

      state.generateWeeklyPlan(save: false);

      // Day 0 is the objectively best target-fit breakfast (see the target
      // fit test above); day 1 should not repeat it even though it would
      // still be the best fit, because it was *just* used and the other two
      // breakfasts are still available alternatives.
      expect(state.weeklyPlan[0].meals[0].description, _highProteinBreakfast);
      expect(
        state.weeklyPlan[1].meals[0].description,
        isNot(_highProteinBreakfast),
      );
    },
  );

  test(
    'variety holds across multiple weeks, not just within a single round',
    () {
      final state = AppState()..recentMealKeys.clear();

      // Each candidate list now has 6 options rather than 2-3, and 6 does
      // not divide evenly into the 7-day week -- see the comment above
      // `_recentMealKeysWindow` in app_state_nutrition.dart for why that
      // matters. Regenerating 6 weeks in a row should cycle a given
      // weekday's breakfast through every distinct candidate before any of
      // them repeats, instead of settling back into the same weekly
      // pattern after the very first round.
      final sundayBreakfasts = <String>[];
      for (var week = 0; week < 6; week++) {
        state.generateWeeklyPlan(save: false);
        sundayBreakfasts.add(state.weeklyPlan[0].meals[0].description);
      }

      expect(sundayBreakfasts.toSet(), hasLength(6));
    },
  );

  test(
    'snack variety holds across multiple weeks too, not just breakfast/lunch/dinner',
    () {
      final state = AppState()..recentMealKeys.clear();

      state.generateWeeklyPlan(save: false);
      // Within one week, all 7 days should not need a repeated snack until
      // every one of the 6 candidates has had a turn.
      final weekSnacks =
          state.weeklyPlan.map((d) => d.meals[3].description).toList();
      expect(weekSnacks.toSet(), hasLength(6));

      // And, like breakfast, the same weekday's snack should keep cycling
      // across several weeks rather than settling into a fixed pick.
      final sundaySnacks = <String>[weekSnacks[0]];
      for (var week = 1; week < 6; week++) {
        state.generateWeeklyPlan(save: false);
        sundaySnacks.add(state.weeklyPlan[0].meals[3].description);
      }
      expect(sundaySnacks.toSet(), hasLength(6));
    },
  );

  test(
    'a disliked ingredient makes generateWeeklyPlan skip that meal in favor '
    'of an alternative, instead of ignoring the dislike (see foodDislikes)',
    () {
      final state = AppState()
        // Same setup as the target-fit test above: this makes
        // _highProteinBreakfast (whose shopping list includes 'שקדים') the
        // objectively best target fit, so disliking שקדים is what has to
        // be the reason it's passed over here, not target fit or variety.
        ..calorieTarget = 1200
        ..proteinTarget = 105
        ..recentMealKeys.clear();
      final almonds = state.allFoods.firstWhere((food) => food.id == 'almonds');
      state.setFoodDisliked(almonds, true);

      state.generateWeeklyPlan(save: false);

      expect(
        state.weeklyPlan[0].meals[0].description,
        isNot(_highProteinBreakfast),
      );
    },
  );

  test(
    'a disliked ingredient is still matched when the catalog name adds a '
    'preparation descriptor the shopping key drops (e.g. קינואה מבושלת vs. '
    'קינואה) -- generateWeeklyPlan skips the meal even though the names are '
    'not exactly equal',
    () {
      final state = AppState()..recentMealKeys.clear();
      // Stock exactly what the pargit lunch needs -- see the pantry-
      // awareness test below, where this alone makes it the clear winner.
      // Disliking קינואה has to be what rules it out here, not pantry
      // coverage or anything else.
      state.addPantryItem('פרגית', 1, 'יחידות', 'בשר ועוף');
      state.addPantryItem('ירקות לסלט', 1, 'יחידות', 'ירקות');
      state.addPantryItem('קינואה', 1, 'יחידות', 'לחמים ודגנים');

      final quinoa = state.allFoods.firstWhere((food) => food.id == 'quinoa');
      state.setFoodDisliked(quinoa, true);

      state.generateWeeklyPlan(save: false);

      expect(state.weeklyPlan[0].meals[1].description, isNot(_pargitLunch));
    },
  );

  test('pantry awareness prefers a lunch whose ingredients are already in stock', () {
    final state = AppState()..recentMealKeys.clear();

    // Stock exactly what the pargit lunch needs. "ירקות לסלט" also appears
    // in the other two lunches' shopping lists, so on its own it wouldn't
    // be decisive -- the win has to come from covering all three ingredients.
    state.addPantryItem('פרגית', 1, 'יחידות', 'בשר ועוף');
    state.addPantryItem('ירקות לסלט', 1, 'יחידות', 'ירקות');
    state.addPantryItem('קינואה', 1, 'יחידות', 'לחמים ודגנים');

    state.generateWeeklyPlan(save: false);

    expect(state.weeklyPlan[0].meals[1].description, _pargitLunch);
  });

  test('a meat lunch is still always followed by a pareve dinner (kosher rule)', () {
    final state = AppState();
    state.generateWeeklyPlan(save: false);

    for (final day in state.weeklyPlan) {
      final lunch = day.meals[1];
      final dinner = day.meals[2];
      if (lunch.type == KosherFoodType.meat) {
        expect(dinner.type, KosherFoodType.pareve, reason: '${day.day}: meat lunch');
      } else {
        expect(dinner.type, KosherFoodType.dairy, reason: '${day.day}: non-meat lunch');
      }
    }
  });

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
