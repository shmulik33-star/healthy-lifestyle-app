import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fitness public API still builds the default workout', () {
    final state = AppState();

    expect(state.todayWorkout, isNotEmpty);
    expect(
      state.todayWorkout.map((exercise) => exercise.name),
      contains('משיכת פולי עליון'),
    );
  });

  test('kosher public API still reflects disabled kosher mode', () {
    final state = AppState()..kosherEnabled = false;

    expect(state.dairyAllowed, isTrue);
    expect(state.kosherStateText, 'לא הוגדרה שמירת כשרות');
  });

  test('shopping public API still derives items from the weekly plan', () {
    final state = AppState();

    expect(state.shoppingTotals, isNotEmpty);
    state.buildSmartShoppingList(force: true);
    expect(state.shoppingItems, isNotEmpty);
  });
}
