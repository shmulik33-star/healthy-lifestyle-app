import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/shared/data/food_catalog.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void main() {
  test('dairy wait follows the user profile setting', () {
    final state = AppState()
      ..kosherEnabled = true
      ..meatDairySeparationEnabled = true
      ..meatWaitMinutes = 180;

    final chicken = foodCatalog.firstWhere((food) => food.id == 'chicken');
    state.addFood(chicken, 1, 'חתיכה בינונית');

    expect(state.lastMeatTime, isNotNull);
    expect(
      state.dairyAllowedAt!.difference(state.lastMeatTime!).inMinutes,
      180,
    );
    expect(state.dairyAllowed, isFalse);
  });

  test('dairy wait can be disabled by the user', () {
    final state = AppState()
      ..kosherEnabled = true
      ..meatDairySeparationEnabled = false
      ..meatWaitMinutes = 360;

    final chicken = foodCatalog.firstWhere((food) => food.id == 'chicken');
    state.addFood(chicken, 1, 'חתיכה בינונית');

    expect(state.dairyAllowed, isTrue);
    expect(state.dairyAllowedAt, isNull);
  });
}
