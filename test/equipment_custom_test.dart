import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_item.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_workout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('custom equipment persists all editable fields and source', () async {
    const item = CustomEquipmentItem(
      id: 'custom-1',
      name: 'מכשיר ביתי מיוחד',
      category: 'אחר',
      categoryDetail: 'מכשיר משיכה',
      quantity: 2,
      notes: 'נמצא בחדר העבודה',
      available: true,
      source: 'photo',
    );

    await EquipmentStore.save(const [item]);
    final restored = await EquipmentStore.load();

    expect(restored, hasLength(1));
    expect(restored.single.name, item.name);
    expect(restored.single.category, 'אחר');
    expect(restored.single.categoryDetail, 'מכשיר משיכה');
    expect(restored.single.quantity, 2);
    expect(restored.single.notes, 'נמצא בחדר העבודה');
    expect(restored.single.available, isTrue);
    expect(restored.single.source, 'photo');
  });

  test('equipment recovers from backup when primary data is corrupt', () async {
    final backup = jsonEncode([
      const CustomEquipmentItem(
        id: 'backup-1',
        name: 'קטלבל גיבוי',
        category: 'קטלבל',
        source: 'photo_ai',
      ).toJson(),
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      EquipmentStore.storageKey: '{broken-json',
      EquipmentStore.backupStorageKey: backup,
    });

    final restored = await EquipmentStore.load();
    expect(restored, hasLength(1));
    expect(restored.single.id, 'backup-1');
    expect(restored.single.name, 'קטלבל גיבוי');
    expect(restored.single.source, 'photo_ai');
  });

  test('saving changed equipment keeps previous valid payload as backup', () async {
    const first = CustomEquipmentItem(
      id: 'first',
      name: 'משקולת ראשונה',
      category: 'משקולות',
    );
    const second = CustomEquipmentItem(
      id: 'second',
      name: 'גומייה שנייה',
      category: 'גומיות התנגדות',
    );

    await EquipmentStore.save(const [first]);
    await EquipmentStore.save(const [second]);

    final prefs = await SharedPreferences.getInstance();
    final backupRaw = prefs.getString(EquipmentStore.backupStorageKey);
    expect(backupRaw, isNotNull);
    final decoded = jsonDecode(backupRaw!) as List<dynamic>;
    expect(decoded, hasLength(1));
    expect((decoded.single as Map)['id'], 'first');
  });

  test('available custom weights can add an exercise to the workout', () {
    const item = CustomEquipmentItem(
      id: 'weights-1',
      name: 'דאמבלים 8 ק״ג',
      category: 'משקולות',
    );

    final workout = EquipmentWorkoutBuilder.combine(const [], const [item]);

    expect(workout, hasLength(1));
    expect(workout.single.equipment, 'דאמבלים 8 ק״ג');
    expect(workout.single.muscleGroup, 'יד קדמית');
  });

  test('unavailable custom equipment is not used in the workout', () {
    const item = CustomEquipmentItem(
      id: 'band-1',
      name: 'גומייה חזקה',
      category: 'גומיות התנגדות',
      available: false,
    );

    final workout = EquipmentWorkoutBuilder.combine(const [], const [item]);

    expect(workout, isEmpty);
  });

  test('unknown equipment is stored but does not invent an exercise', () {
    const item = CustomEquipmentItem(
      id: 'unknown-1',
      name: 'מכשיר מיוחד',
      category: 'אחר',
      categoryDetail: 'לא מוכר',
    );

    expect(EquipmentWorkoutBuilder.canSuggestExercise(item), isFalse);
  });
}
