import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('05:00 boundary treats early-morning time as previous logical day', () {
    final state=AppState()..dayStartMinutes=300;

    expect(state.dayKeyAt(DateTime(2026,8,18,4,59)),'2026-08-17');
    expect(state.dayKeyAt(DateTime(2026,8,18,5,0)),'2026-08-18');
    expect(state.dayStartAt(DateTime(2026,8,18,4,59)),DateTime(2026,8,17,5,0));
    expect(state.dayEndAt(DateTime(2026,8,18,4,59)),DateTime(2026,8,18,5,0));
  });

  test('new logical day resets daily counters and preserves a snapshot', () {
    final state=AppState()
      ..dayStartMinutes=300
      ..dailyStateKey='2026-08-17'
      ..waterCups=8
      ..steps=6421
      ..workoutCompleted=true;

    final changed=state.ensureCurrentDay(
      now:DateTime(2026,8,18,5,1),
      notify:false,
      save:false,
    );

    expect(changed,isTrue);
    expect(state.dailyStateKey,'2026-08-18');
    expect(state.waterCups,0);
    expect(state.steps,0);
    expect(state.workoutCompleted,isFalse);
    expect(state.dailyHistory,last);
    expect(state.dailyHistory.last.dayKey,'2026-08-17');
    expect(state.dailyHistory.last.waterCups,8);
    expect(state.dailyHistory.last.steps,6421);
    expect(state.dailyHistory.last.workoutCompleted,isTrue);
  });

  test('meal totals follow the configured day window instead of midnight', () {
    final state=AppState()..dayStartMinutes=300;

    MealEntry mealAt(DateTime time,String name)=>MealEntry(
      foodId:name,
      name:name,
      quantity:1,
      unit:'מנה',
      grams:100,
      calories:100,
      protein:10,
      carbs:5,
      fat:2,
      type:KosherFoodType.pareve,
      time:time,
    );

    state.meals.addAll([
      mealAt(DateTime(2026,8,17,23,0),'לילה'),
      mealAt(DateTime(2026,8,18,4,30),'לפנות בוקר'),
      mealAt(DateTime(2026,8,18,5,5),'יום חדש'),
    ]);

    final beforeBoundary=state.mealsForDayAt(DateTime(2026,8,18,4,45));
    expect(beforeBoundary.map((m)=>m.name),['לילה','לפנות בוקר']);

    final afterBoundary=state.mealsForDayAt(DateTime(2026,8,18,6,0));
    expect(afterBoundary.map((m)=>m.name),['יום חדש']);
  });
}
