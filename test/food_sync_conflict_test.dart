import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_lifestyle_stage9/features/profile/food_sync_conflict.dart';
import 'package:healthy_lifestyle_stage9/features/profile/food_conflict_card.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

FoodItem food(String name, {String id = 'custom_a', double protein = 10}) =>
    FoodItem(
      id: id,
      name: name,
      category: 'אחר',
      type: KosherFoodType.pareve,
      caloriesPer100g: 100,
      proteinPer100g: protein,
      carbsPer100g: 20,
      fatPer100g: 3,
      units: {'מנה': 100},
      userCreated: true,
      barcode: '123',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('consent binds exact local, remote, owner and preserved copy', () {
    final local = food('מקומי');
    final remote = food('ענן');
    final conflict = FoodSyncConflict(
      ownerId: 'owner',
      local: local,
      remote: remote,
    );
    final copy = conflict.remoteCopy('copy', [local]);
    final consent = FoodSyncConsent(conflict, copy);
    expect(consent.permits('owner', local, remote, copy), isTrue);
    expect(consent.permits('other', local, remote, copy), isFalse);
    expect(consent.permits('owner', food('נערך שוב'), remote, copy), isFalse);
    expect(
      consent.permits('owner', local, food('ענן', protein: 11), copy),
      isFalse,
    );
    expect(consent.permits('owner', local, null, copy), isFalse);
    expect(consent.permits('owner', null, remote, copy), isFalse);
    expect(consent.permits('owner', local, remote, null), isFalse);
    expect(
      consent.permits('owner', local, remote, food('נערך', id: 'copy')),
      isFalse,
    );
  });

  test('display snapshots detach mutable units and canonicalize key order', () {
    final local = food('מקומי');
    final conflict = FoodSyncConflict(
      ownerId: 'owner',
      local: local,
      remote: food('ענן'),
    );
    local.units['מנה'] = 250;
    expect(conflict.local.units['מנה'], 100);
    expect(conflict.matches('owner', local, conflict.remote), isFalse);
  });

  test(
    'Appwrite download retains separate IDs even when food names match',
    () async {
      final state = AppState();
      state.customFoods.add(food('אותו שם', id: 'local'));
      state.applyRemoteCustomFood(
        food('אותו שם', id: 'remote'),
        DateTime.utc(2026),
        matchByName: false,
      );
      expect(
        state.customFoods.map((food) => food.id),
        containsAll(['local', 'remote']),
      );
      // Await durable persistence through the new copy operation.
      await state.preserveFoodConflictCopy(food('עותק', id: 'copy'));
      final restored = await AppState.load();
      expect(restored.customFoods, hasLength(3));
    },
    skip: const String.fromEnvironment('CLOUD_BACKEND') != 'appwrite',
  );

  test(
    'separate cloud copy avoids ID and name replacement and persists before consent',
    () async {
      final state = AppState();
      final local = food('מזון');
      final remote = food('מזון', protein: 25);
      state.customFoods.addAll([
        local,
        food('מזון (גרסת ענן 1)', id: 'another'),
      ]);
      final conflict = FoodSyncConflict(
        ownerId: 'owner',
        local: local,
        remote: remote,
      );
      final copy = conflict.remoteCopy('copy', state.customFoods);
      expect(copy.name, 'מזון (גרסת ענן 2)');
      await state.preserveFoodConflictCopy(copy);
      expect(state.customFoods, hasLength(3));
      expect(state.customFoods.first.proteinPer100g, 10);
      expect(copy.proteinPer100g, 25);
      expect(copy.barcode, remote.barcode);
      expect(copy.units, remote.units);
      final restored = await AppState.load();
      expect(
        restored.customFoods.map((food) => food.id),
        containsAll(['custom_a', 'another', 'copy']),
      );
      await expectLater(state.preserveFoodConflictCopy(copy), throwsStateError);
    },
  );

  testWidgets(
    'shows both versions, preserves cancel-by-inaction and requires a tap',
    (tester) async {
      var confirmed = 0;
      final conflict = FoodSyncConflict(
        ownerId: 'owner',
        local: food('מקומי'),
        remote: food('ענן', protein: 25),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FoodConflictCard(
                conflict: conflict,
                onKeepBoth: () => confirmed++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('מקומי'), findsOneWidget);
      expect(find.text('ענן'), findsOneWidget);
      expect(find.text('במכשיר הזה'), findsOneWidget);
      expect(find.text('בענן'), findsOneWidget);
      expect(confirmed, 0);
      await tester.tap(find.text('שמור את שתי הגרסאות'));
      expect(confirmed, 1);
    },
  );
}
