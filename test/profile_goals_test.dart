import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/profile/profile_goals_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('first goals save creates a recovery copy', () async {
    await ProfileGoalsStore.save(['שיפור הכושר']);

    final prefs=await SharedPreferences.getInstance();
    expect(
      prefs.getString(ProfileGoalsStore.backupStorageKey),
      jsonEncode(['שיפור הכושר']),
    );
  });

  test('goals recover from backup and repair corrupt primary data', () async {
    final backup=jsonEncode(['עלייה במסת שריר','שיפור הכושר']);
    SharedPreferences.setMockInitialValues(<String, Object>{
      ProfileGoalsStore.storageKey: '{broken-json',
      ProfileGoalsStore.backupStorageKey: backup,
    });

    final loaded=await ProfileGoalsStore.load(fallbackGoal:'ירידה במשקל');
    expect(loaded,['עלייה במסת שריר','שיפור הכושר']);

    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getString(ProfileGoalsStore.storageKey),backup);
  });

  test('saving changed goals keeps the previous valid payload as backup', () async {
    await ProfileGoalsStore.save(['ירידה במשקל']);
    await ProfileGoalsStore.save(['שיפור הכושר']);

    final prefs=await SharedPreferences.getInstance();
    expect(
      prefs.getString(ProfileGoalsStore.backupStorageKey),
      jsonEncode(['ירידה במשקל']),
    );
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
