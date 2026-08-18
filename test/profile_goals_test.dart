import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_lifestyle_stage9/features/profile/profile_goals_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('legacy single goal is used when no multi-goal data exists', () async {
    final goals=await ProfileGoalsStore.load(fallbackGoal:'ירידה במשקל');
    expect(goals,['ירידה במשקל']);
  });

  test('multiple goals are persisted and restored', () async {
    const selected=['ירידה במשקל','עלייה במסת שריר','שיפור הכושר'];
    await ProfileGoalsStore.save(selected);
    final loaded=await ProfileGoalsStore.load(fallbackGoal:'שמירה על המשקל');
    expect(loaded,selected);
  });

  test('weight loss and maintenance cannot be selected together', () {
    final result=ProfileGoalsStore.toggleGoal(
      ['שמירה על המשקל','שיפור הכושר'],
      'ירידה במשקל',
    );
    expect(result,contains('ירידה במשקל'));
    expect(result,contains('שיפור הכושר'));
    expect(result,isNot(contains('שמירה על המשקל')));
  });

  test('weight loss plus muscle gain uses a mild deficit and high protein', () {
    const goals=['ירידה במשקל','עלייה במסת שריר'];
    final calories=ProfileGoalsStore.suggestedCalories(
      weightKg:100,
      activityLevel:'נמוכה',
      goals:goals,
    );
    final protein=ProfileGoalsStore.suggestedProtein(
      weightKg:100,
      goals:goals,
    );
    expect(calories,2330);
    expect(protein,180);
  });
}
