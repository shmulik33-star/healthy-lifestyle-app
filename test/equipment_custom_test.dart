import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_item.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_workout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('custom equipment persists all editable fields', () async {
    const item = CustomEquipmentItem(
      id: 'custom-1',
      name: 'מכשיר ביתי מיוחד',
      category: 'אחר',
      categoryDetail: 'מכשיר משיכה',
      quantity: 2,
      notes: 'נמצא בחדר העבודה',
      available: true,
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
