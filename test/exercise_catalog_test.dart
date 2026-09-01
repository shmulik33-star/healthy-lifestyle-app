import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('every catalog entry has a unique id, real fields and a well-formed image URL', () {
    final ids = <String>{};
    for (final item in kExerciseCatalog) {
      expect(ids.add(item.id), isTrue, reason: 'duplicate id: ${item.id}');
      expect(item.nameHe, isNotEmpty);
      expect(item.muscleGroup, isNotEmpty);
      expect(item.sets, greaterThan(0));
      expect(item.reps, greaterThan(0));
      expect(item.imageUrl, startsWith('https://raw.githubusercontent.com/yuhonas/free-exercise-db/'));
      expect(item.imageUrl, contains(item.id));
      expect(item.imageUrl2, startsWith('https://raw.githubusercontent.com/yuhonas/free-exercise-db/'));
      expect(item.imageUrl2, contains(item.id));
      expect(item.imageUrl2, isNot(item.imageUrl), reason: 'the two frames must be different images');
    }
    expect(kExerciseCatalog, isNotEmpty);
  });

  test('exerciseCatalogById finds a known id and returns null for an unknown one', () {
    expect(exerciseCatalogById('Plank')?.nameHe, 'פלאנק');
    expect(exerciseCatalogById('not-a-real-id'), isNull);
  });

  test('toWorkoutExercise carries both image frames through', () {
    final item = exerciseCatalogById('Plank')!;
    final exercise = item.toWorkoutExercise();
    expect(exercise.name, item.nameHe);
    expect(exercise.imageUrl, item.imageUrl);
    expect(exercise.imageUrl2, item.imageUrl2);
  });

  test('eligibleExerciseCatalog always includes bodyweight-only exercises', () {
    final state = AppState();
    for (final key in state.equipment.keys) {
      state.equipment[key] = false;
    }

    final eligible = eligibleExerciseCatalog(state);
    expect(eligible, isNotEmpty);
    expect(eligible.every((item) => item.equipmentKey == kNoEquipmentKey), isTrue);
  });

  test('eligibleExerciseCatalog includes an exercise once its equipment is toggled on', () {
    final state = AppState();
    for (final key in state.equipment.keys) {
      state.equipment[key] = false;
    }
    state.equipment['Cable Machine'] = true;

    final eligible = eligibleExerciseCatalog(state);
    expect(eligible.any((item) => item.equipmentKey == 'Cable Machine'), isTrue);
    expect(eligible.any((item) => item.equipmentKey == 'משקולות יד'), isFalse);
  });

  test('eligibleExerciseCatalog also picks up available custom equipment by name', () {
    final state = AppState();
    for (final key in state.equipment.keys) {
      state.equipment[key] = false;
    }
    state.customEquipment.add(
      const CustomEquipmentItem(id: 'x1', name: 'Cable Machine', category: 'אחר'),
    );

    final eligible = eligibleExerciseCatalog(state);
    expect(eligible.any((item) => item.equipmentKey == 'Cable Machine'), isTrue);
  });
}
