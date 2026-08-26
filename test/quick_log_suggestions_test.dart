import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

final _now = DateTime(2026, 8, 26, 12);

MealEntry _meal(
  String foodId,
  String name, {
  required double quantity,
  required String unit,
  required int calories,
  required KosherFoodType type,
  required DateTime time,
  bool fromHome = true,
}) => MealEntry(
  foodId: foodId,
  name: name,
  quantity: quantity,
  unit: unit,
  grams: 0,
  calories: calories,
  protein: 0,
  carbs: 0,
  fat: 0,
  type: type,
  time: time,
  fromHome: fromHome,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('empty meal history yields no suggestions', () {
    final state = AppState();
    expect(state.quickLogSuggestions(_now), isEmpty);
  });

  test('a combination logged more often outranks one logged only once', () {
    final state = AppState()
      ..meals.addAll([
        _meal(
          'egg',
          'ביצה',
          quantity: 2,
          unit: 'יחידה',
          calories: 143,
          type: KosherFoodType.pareve,
          time: _now.subtract(const Duration(days: 10)),
        ),
        _meal(
          'egg',
          'ביצה',
          quantity: 2,
          unit: 'יחידה',
          calories: 143,
          type: KosherFoodType.pareve,
          time: _now.subtract(const Duration(days: 5)),
        ),
        _meal(
          'banana',
          'בננה',
          quantity: 1,
          unit: 'יחידה',
          calories: 107,
          type: KosherFoodType.pareve,
          time: _now.subtract(const Duration(hours: 1)),
        ),
      ]);

    final suggestions = state.quickLogSuggestions(_now);

    expect(suggestions.first.foodId, 'egg');
    expect(suggestions.map((s) => s.foodId), containsAll(['egg', 'banana']));
  });

  test(
    'among equally-frequent combinations, the more recently logged one wins',
    () {
      final state = AppState()
        ..meals.addAll([
          _meal(
            'egg',
            'ביצה',
            quantity: 2,
            unit: 'יחידה',
            calories: 143,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 20)),
          ),
          _meal(
            'banana',
            'בננה',
            quantity: 1,
            unit: 'יחידה',
            calories: 107,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 1)),
          ),
        ]);

      final suggestions = state.quickLogSuggestions(_now);

      expect(suggestions[0].foodId, 'banana');
      expect(suggestions[1].foodId, 'egg');
    },
  );

  test(
    'the same (food, quantity, unit) logged repeatedly collapses to one chip',
    () {
      final state = AppState()
        ..meals.addAll([
          _meal(
            'egg',
            'ביצה',
            quantity: 2,
            unit: 'יחידה',
            calories: 143,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 3)),
          ),
          _meal(
            'egg',
            'ביצה',
            quantity: 2,
            unit: 'יחידה',
            calories: 143,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 2)),
          ),
          _meal(
            'egg',
            'ביצה',
            quantity: 2,
            unit: 'יחידה',
            calories: 143,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 1)),
          ),
        ]);

      final suggestions = state.quickLogSuggestions(_now);

      expect(suggestions, hasLength(1));
      expect(suggestions.single.quantity, 2);
      expect(suggestions.single.unit, 'יחידה');
    },
  );

  test(
    'different quantities/units of the same food are kept as separate chips',
    () {
      final state = AppState()
        ..meals.addAll([
          _meal(
            'egg',
            'ביצה',
            quantity: 1,
            unit: 'יחידה',
            calories: 72,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 3)),
          ),
          _meal(
            'egg',
            'ביצה',
            quantity: 2,
            unit: 'יחידה',
            calories: 143,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 2)),
          ),
        ]);

      final suggestions = state.quickLogSuggestions(_now);

      expect(suggestions, hasLength(2));
    },
  );

  test(
    'a meal referencing a since-deleted personal food is skipped without crashing',
    () {
      final state = AppState()
        ..meals.addAll([
          _meal(
            'deleted-custom-food',
            'מזון שנמחק',
            quantity: 1,
            unit: 'יחידה',
            calories: 200,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 1)),
          ),
          _meal(
            'egg',
            'ביצה',
            quantity: 1,
            unit: 'יחידה',
            calories: 72,
            type: KosherFoodType.pareve,
            time: _now.subtract(const Duration(days: 2)),
          ),
        ]);

      final suggestions = state.quickLogSuggestions(_now);

      expect(
        suggestions.map((s) => s.foodId),
        isNot(contains('deleted-custom-food')),
      );
      expect(suggestions.map((s) => s.foodId), contains('egg'));
    },
  );

  test('meals older than 30 days are ignored entirely', () {
    final state = AppState()
      ..meals.add(
        _meal(
          'egg',
          'ביצה',
          quantity: 2,
          unit: 'יחידה',
          calories: 143,
          type: KosherFoodType.pareve,
          time: _now.subtract(const Duration(days: 31)),
        ),
      );

    expect(state.quickLogSuggestions(_now), isEmpty);
  });

  test(
    'suggestions are not filtered by the current kosher wait state',
    () {
      // `dairyAllowed` reads the real wall clock (see `_kosherDairyAllowed`),
      // so this scenario is built off `DateTime.now()` rather than the
      // fixed `_now` the other tests use, to reliably land the meat meal
      // inside the real 360-minute wait window.
      final realNow = DateTime.now();
      final state = AppState()
        ..meatDairySeparationEnabled = true
        ..meatWaitMinutes = 360
        ..meals.addAll([
          _meal(
            'chicken',
            'חזה עוף',
            quantity: 1,
            unit: 'חתיכה בינונית',
            calories: 231,
            type: KosherFoodType.meat,
            time: realNow.subtract(const Duration(minutes: 10)),
          ),
          _meal(
            'cottage5',
            'קוטג׳ 5%',
            quantity: 1,
            unit: 'כף',
            calories: 20,
            type: KosherFoodType.dairy,
            time: realNow.subtract(const Duration(days: 4)),
          ),
        ]);

      // Sanity check the scenario actually exercises the "not allowed"
      // kosher state this test claims to be independent of.
      expect(state.dairyAllowed, isFalse);

      final suggestions = state.quickLogSuggestions(realNow);
      expect(suggestions.map((s) => s.foodId), contains('cottage5'));
    },
  );

  test('at most 8 chips are returned', () {
    const foodIds = [
      'egg',
      'cottage5',
      'yogurt',
      'yellow_cheese',
      'tuna',
      'salmon',
      'chicken',
      'pargit',
      'beef',
      'rice',
    ];
    final state = AppState()
      ..meals.addAll([
        for (var i = 0; i < foodIds.length; i++)
          _meal(
            foodIds[i],
            foodIds[i],
            quantity: 1,
            unit: 'גרם',
            calories: 100,
            type: KosherFoodType.pareve,
            time: _now.subtract(Duration(days: i)),
          ),
      ]);

    final suggestions = state.quickLogSuggestions(_now);

    expect(suggestions.length, lessThanOrEqualTo(8));
    // The most recently logged combinations should be the ones kept.
    expect(suggestions.map((s) => s.foodId), contains('egg'));
    expect(suggestions.map((s) => s.foodId), isNot(contains('rice')));
  });
}
